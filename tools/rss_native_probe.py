#!/usr/bin/env python3
"""Measure original RSS gates, then diagnose native ownership separately."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'unittest'))
import ci
import transcript
from method_copy_memory_check import PROGRAM

SUBJECT = '90c83c6e525fbac7c7b9cdf670bd5e6db1ca79a5'
RUBY = 'a704b7cd95a42cc0cf5f307137bf3aac0285b915'
TEST_SHA = '6b9b0fe714d15e2d08ac9ac6954b5f429754b2507eec2960b9544bc54eb8cdbc'
PROGRAM_SHA = '9bb9dd80ebc082cdb1c356e415f688598228cf8e075ddfb4ae509f5581ca38a3'
CLONE_SHA = '8789649ad88008ef963cd64e00fdee7ed92ef22b84aeb76362d3b1862b2f4fc9'
MODE = 'DIAGNOSTIC O2 RSS observer'


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()


def emit_probe(source, heap=False):
    observer = (ROOT / 'tools/rss_native_observer.c').read_text()
    if heap:
        from rss_heap_observer import extend
        observer = extend(source, observer)
    hooks = [
        (r'(static long long fd_open\(const char\* path, const char\* mode, long long perm\) \{)',
         '\n  if (path && !strcmp(path, "/proc/self/status")) gem_rss_snapshot("status");'),
        (r'(static long long __proc_spawn_go\([^{}]*\) \{)',
         '\n  if (path && (!strcmp(path, "/bin/ps") || !strcmp(path, "/usr/bin/ps"))) gem_rss_snapshot("ps");')]
    for pattern, hook in hooks:
        source, count = re.subn(pattern, lambda match: match[1] + hook, source)
        if count != 1:
            raise ValueError('expected one locked native observation site')
    # Preserve the original entry's one call and result. Observe whether the
    # native arena actually moved, independently of the Ruby-side due flag.
    wrapper = r'''
static int mu_compact_method_store__direct(int mu_u) {
    uintptr_t before = (uintptr_t)mu_meths_g->region;
    long long floor = mere_vec_int_get(mu_method_store_floor, 0);
    int due = gem_floor_original_compact_method_store(mu_u);
    gem_floor_calls++;
    if (due) {
        gem_floor_requested++;
        if (before != (uintptr_t)mu_meths_g->region) gem_floor_moved++;
        else {
            gem_floor_deferred++;
            if (floor > 0 && mere_vec_int_get(mu_method_store_floor, 0) > floor)
                gem_floor_raised_without_move++;
        }
    }
    return due;
}
'''
    pattern = r'^static int mu_compact_method_store__direct\(int mu_u\) \{\n.*?^\}'
    source, count = re.subn(pattern, lambda match:
        match[0].replace('mu_compact_method_store__direct',
                         'gem_floor_original_compact_method_store', 1) + wrapper,
        source, flags=re.M | re.S)
    if count != 1:
        raise ValueError('expected one locked method compaction entry')
    counters = ('static _Thread_local unsigned long long gem_floor_calls, gem_floor_requested, '
                'gem_floor_moved, gem_floor_deferred, gem_floor_raised_without_move;\n')
    return (counters + 'static void gem_rss_snapshot(const char *phase);\n' + source + '\n'
            + observer)


def build(subject, output, expected_ref=SUBJECT, heap=False):
    if git(subject, 'rev-parse', 'HEAD') != expected_ref:
        raise ValueError('the locked subject checkout is required')
    git(subject, 'diff', '--exit-code', 'HEAD', '--', '*.mere', '*.c', '*.h', 'tools', 'unittest', 'lib')
    if (subject / '.build_mode').read_text().strip() != 'O2':
        raise ValueError('build the ordinary O2 subject first')
    shutil.copytree(subject, output, ignore=shutil.ignore_patterns(
        '.git', '.mere-compiler', '.ruby-source', 'mere-ruby', 'mere-ruby.new', '__pycache__'))
    generated = subject / 'mr.c'
    (output / 'mr.c').write_text(emit_probe(generated.read_text(), heap=heap))
    script = output / 'tools/build.sh'
    original = script.read_text()
    if original.count('\nmode=O2\n') != 1:
        raise ValueError('expected the locked build mode declaration')
    # Same O2 flags; this private copy can never stamp a probe as ordinary O2.
    script.write_text(original.replace('\nmode=O2\n', "\nmode='" + MODE + "'\n"))
    (output / '.build_mode').write_text(MODE + '\n')
    with (output / 'probe-build.log').open('w') as log:
        result = subprocess.run(['sh', 'tools/build.sh', '--cc-only'], cwd=output,
                                stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print('\n'.join(line[:600] for line in
              (output / 'probe-build.log').read_text(errors='replace').splitlines()[-20:]), file=sys.stderr)
        raise RuntimeError('diagnostic native compilation failed')
    if (output / '.build_mode').read_text().strip() != MODE:
        raise ValueError('diagnostic mode marker was lost')
    ci.save(output / 'probe-build.json', dict(
        diagnostic_only=True, subject_ref=expected_ref, mode=MODE,
        ordinary_binary_sha256=ci.digest(subject / 'mere-ruby'),
        original_c_sha256=ci.digest(generated), probe_c_sha256=ci.digest(output / 'mr.c'),
        binary_sha256=ci.digest(output / 'mere-ruby'),
        observer_sha256=ci.digest(ROOT / 'tools/rss_native_observer.c'),
        heap_observer=heap,
        heap_fragment_sha256=ci.digest(ROOT / 'tools/rss_heap_observer.c') if heap else None,
        heap_emitter_sha256=ci.digest(ROOT / 'tools/rss_heap_observer.py') if heap else None))


def native_samples(raw):
    samples = []
    active = None
    for line in raw.splitlines():
        if not line.startswith('RSS_NATIVE_'):
            continue
        kind, fields = line.split(' ', 1)
        values = {key: int(value) if re.fullmatch(r'-?\d+', value) else value
                  for key, value in (field.split('=', 1) for field in fields.split())}
        if kind == 'RSS_NATIVE_BEGIN':
            if active is not None or values['sample'] != len(samples):
                raise ValueError('overlapping native observations')
            active = dict(begin=values, maps={}, retired=[], pins=[])
        elif active is None or values['sample'] != active['begin']['sample']:
            raise ValueError('native observation outside its sample')
        elif kind == 'RSS_NATIVE_MAP':
            name = values['name']
            if name in active['maps']:
                raise ValueError('duplicate native map observation')
            active['maps'][name] = values
        elif kind == 'RSS_NATIVE_DEFAULT':
            if 'default' in active:
                raise ValueError('duplicate native default observation')
            active['default'] = values
        elif kind == 'RSS_NATIVE_POLICY':
            if ('policy' in active or values['requested'] > values['calls']
                    or values['moved'] + values['deferred'] != values['requested']
                    or values['raised_without_move'] > values['deferred']
                    or any(value < 0 for value in values.values())):
                raise ValueError('invalid native compaction accounting')
            active['policy'] = values
        elif kind == 'RSS_NATIVE_RETIRED':
            active['retired'].append(values)
        elif kind == 'RSS_NATIVE_PIN':
            active['pins'].append(values)
        elif kind == 'RSS_NATIVE_END':
            if (active['begin']['rss_kb'] <= 0 or 'default' not in active
                    or not {'meths_g', 'meth_src', 'meth_cref', 'modules',
                            'anonymous_classes', 'cls_sup'} <= active['maps'].keys()
                    or len(active['retired']) != values['retired_regions']
                    or sum(r['capacity'] for r in active['retired']) != values['retired_capacity']
                    or {r['arena'] for r in active['retired']} != set(range(values['retired_regions']))
                    or any(sum(p['arena'] == r['arena'] for p in active['pins']) != r['pinners']
                           for r in active['retired'])
                    or sum(r['pinners'] for r in active['retired']) != len(active['pins'])):
                raise ValueError('incomplete native ownership observation')
            active['end'] = values
            samples.append(active)
            active = None
        else:
            raise ValueError('unknown native ownership record')
    if active is not None:
        raise ValueError('truncated native ownership observation')
    if not samples:
        raise ValueError('missing native ownership observations')
    return samples


def policy_observed(samples):
    return (bool(samples) and all('policy' in sample for sample in samples)
            and samples[-1]['policy']['calls'] > 0)


def environment(binary, directory, reference, source):
    os.environ['REF_RUBY_BIN'] = str(reference)
    env = ci.test_environment(directory / 'environment', binary, '4.0.10')
    runtime = subprocess.check_output(
        ['sh', str(ROOT / 'tools/runtime_load_path.sh'), str(binary)], text=True).split(os.pathsep)
    env.update(RUBY=str(binary), UNITTEST_CHILD_RUBY=str(binary),
               UNITTEST_TEST_FILE='ruby/test_module.rb',
               RUBYLIB=os.pathsep.join(map(str, [source / 'tool/lib', source / 'test',
                                                ROOT / 'unittest/shim', *runtime, source / 'lib'])))
    env['PATH'] = str(ROOT / 'unittest/child-bin') + os.pathsep + env['PATH']
    return env


def clone(binary, directory, reference, source, diagnostic):
    directory.mkdir()
    env = environment(binary, directory, reference, source)
    captured = directory / 'original_child_input.rb'
    env['RSS_PROBE_INPUT'] = str(captured)
    if diagnostic:
        env['RSS_NATIVE_ENABLE'] = '1'
    command = [str(binary), '-r', 'test/unit', '-r', str(ROOT / 'unittest/bootstrap.rb'),
               '-r', str(ROOT / 'tools/rss_probe_observer.rb'),
               str(source / 'test/ruby/test_module.rb'), '-v', '--show-skip', '--seed=1',
               '-n', '/test_module_clone_memory_leak/']
    if diagnostic:
        # Set the native environment before exec. Ruby's ENV write overlay
        # is intentionally separate from libc getenv in the locked runtime.
        command = ['/bin/sh', '-c', 'exec env RSS_NATIVE_EXCLUDE_PID=$$ "$@"',
                   'rss-probe-parent', *command]
    log = directory / 'module.log'
    execution = ci.supervise(command, env, log, 2097152, 600)
    parsed = transcript.parse(log, execution['exit'])
    transcript.save(directory / 'cases.json', parsed)
    raw = log.read_text(errors='replace')
    child = raw.split('RSS_PROBE_CHILD_BEGIN\n', 1)[-1].split('RSS_PROBE_CHILD_END', 1)[0]
    canonical, count = re.subn(r'\\e\[7;1m\d+:[0-9.]+:[0-9a-fA-F]+:\\e\[m',
                               '<UPSTREAM_TEST_TOKEN>', captured.read_text() if captured.exists() else '')
    original = count == 2 and hashlib.sha256(canonical.encode()).hexdigest() == CLONE_SHA
    statuses = {name: {key: int(number) for key, number in re.findall(r'(\w+):(\d+)', value)}
                for name, value in re.findall(r'(START|FINAL)=(\{[^\n]*\})', child)}
    samples = native_samples(child) if diagnostic else []
    complete = (original and parsed['state'] == 'COMPLETE' and not parsed['issues']
                and parsed['discovered'] == 1 and execution['limit'] is None
                and set(parsed['cases']) == {'TestModule#test_module_clone_memory_leak'})
    passed = (complete and execution['exit'] == 0
              and parsed['cases'] == {'TestModule#test_module_clone_memory_leak': '.'}
              and parsed['summary'] == dict(tests=1, assertions=3, failures=0, errors=0, skips=0))
    diagnostic_complete = (complete and set(statuses) == {'START', 'FINAL'}
        and parsed['summary'] is not None and parsed['summary']['errors'] == 0
        and parsed['summary']['assertions'] in (2, 3)
        and len([s for s in samples if s['begin']['phase'] in ('status', 'ps')]) >= 2
        and policy_observed(samples))
    return dict(execution=execution, summary=parsed['summary'], cases=parsed['cases'],
                diagnostic_only=diagnostic, passed=passed if not diagnostic else None,
                diagnostic_complete=diagnostic_complete if diagnostic else None,
                original_child_verified=original, child_statuses=statuses,
                native_samples=samples, raw_sha256=ci.digest(log))


def collect(args):
    subject, probe, reference, source, output = [getattr(args, key).resolve() for key in
                                               ('subject', 'diagnostic_root', 'reference', 'ruby_src', 'output')]
    git(subject, 'diff', '--exit-code', 'HEAD', '--', '*.mere', '*.c', '*.h', 'tools', 'unittest', 'lib')
    if (git(subject, 'rev-parse', 'HEAD') != args.subject_ref or git(source, 'rev-parse', 'HEAD') != RUBY
            or ci.digest(source / 'test/ruby/test_module.rb') != TEST_SHA
            or hashlib.sha256(PROGRAM.encode()).hexdigest() != PROGRAM_SHA
            or (subject / '.build_mode').read_text().strip() != 'O2'
            or (probe / '.build_mode').read_text().strip() != MODE):
        raise ValueError('locked inputs and separate ordinary / diagnostic binaries are required')
    if not subprocess.check_output([str(reference), '-v'], text=True).startswith('ruby 4.0.10 '):
        raise ValueError('reference Ruby 4.0.10 is required')
    receipt = json.loads((probe / 'probe-build.json').read_text())
    if (receipt['subject_ref'] != args.subject_ref or receipt['mode'] != MODE
            or receipt['ordinary_binary_sha256'] != ci.digest(subject / 'mere-ruby')
            or receipt['binary_sha256'] != ci.digest(probe / 'mere-ruby')
            or receipt['original_c_sha256'] != ci.digest(subject / 'mr.c')
            or receipt['probe_c_sha256'] != ci.digest(probe / 'mr.c')):
        raise ValueError('ordinary or diagnostic build no longer matches its receipt')
    compiler = None
    if args.compiler_root:
        compiler = args.compiler_root.resolve()
        if git(compiler, 'rev-parse', 'HEAD') != os.environ.get('MERE_REF'):
            raise ValueError('compiler checkout differs from its locked ref')
    output.mkdir(parents=True, exist_ok=False)
    record = dict(subject_ref=args.subject_ref, ruby_ref=RUBY, compiler_ref=os.environ.get('MERE_REF'),
                  ordinary_binary_sha256=ci.digest(subject / 'mere-ruby'),
                  diagnostic_build=receipt, reference_binary_sha256=ci.digest(reference),
                  compiler_binary_sha256=ci.digest(compiler / '_build/default/bin/mere.exe') if compiler else None,
                  bounds=dict(wall_per_side=600, rss_family_kb=2097152, upstream_child_seconds=10),
                  cases={}, controls={})
    rejection = subprocess.run([sys.executable, str(subject / 'tools/method_copy_memory_check.py'),
        '--binary', str(probe / 'mere-ruby'), '--reference', str(reference),
        '--output', str(output / 'must-not-run-probe-as-gate')], capture_output=True, text=True)
    (output / 'probe-gate-rejection.log').write_text(rejection.stdout + rejection.stderr)
    record['probe_rejected_by_ordinary_gate'] = (
        rejection.returncode == 2 and 'an O2 build is required' in rejection.stderr)
    ci.save(output / 'result.json', record)
    if not record['probe_rejected_by_ordinary_gate']:
        raise ValueError('ordinary gate must reject the diagnostic binary')
    # Execute both unchanged formal controls; keep a failure while collecting diagnostics.
    for name, script, options in [
        ('module', 'class_module_check.py', ['--ruby-src', str(source)]),
        ('method_copy', 'method_copy_memory_check.py', [])]:
        directory = output / ('ordinary-' + name)
        with (output / (name + '-driver.log')).open('w') as log:
            execution = subprocess.run([sys.executable, str(subject / 'tools' / script),
                '--binary', str(subject / 'mere-ruby'), '--reference', str(reference),
                '--output', str(directory), *options], stdout=log, stderr=subprocess.STDOUT)
        record['controls'][name] = dict(exit=execution.returncode,
            result=json.loads((directory / 'result.json').read_text()))
        ci.save(output / 'result.json', record)
        print('ordinary', name, execution.returncode, flush=True)
    for label, binary, diagnostic in [('reference', reference, False),
            ('ordinary-clone', subject / 'mere-ruby', False), ('diagnostic-clone', probe / 'mere-ruby', True)]:
        record['cases'][label] = clone(binary, output / label, reference, source, diagnostic)
        ci.save(output / 'result.json', record)
        print('selected', label, record['cases'][label]['execution'], flush=True)
    directory = output / 'diagnostic-method-copy'
    directory.mkdir()
    program = directory / 'method_copy.rb'
    program.write_text(PROGRAM)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('RUBY', 'GEM_', 'BUNDLE_', 'MERE_'))}
    env['LANG'] = 'en_US.UTF-8'
    env['RSS_NATIVE_ENABLE'] = '1'
    log = directory / 'native.log'
    execution = ci.supervise([str(probe / 'mere-ruby'), '--disable-gems', str(program)], env, log, 2097152, 600)
    raw = log.read_text(errors='replace')
    samples = native_samples(raw)
    rss = [(int(b), int(r)) for b, r in re.findall(r'^RSS (\d+) (\d+)$', raw, re.M)]
    complete = (execution['exit'] == 0 and execution['limit'] is None
                and [b for b, _ in rss] == list(range(21)) and 'METHOD_COPY_LIFETIME_COMPLETE\n' in raw
                and len([s for s in samples if s['begin']['phase'] == 'ps']) == 21
                and policy_observed(samples))
    record['cases']['diagnostic-method-copy'] = dict(diagnostic_only=True, diagnostic_complete=complete,
        execution=execution, program_sha256=ci.digest(program), samples_kb=rss, native_samples=samples,
        observed_rss_ratio=max(r for _, r in rss[1:]) / rss[0][1] if complete else None,
        raw_sha256=ci.digest(log))
    record['ordinary_gates_passed'] = (all(v['exit'] == 0 for v in record['controls'].values())
        and record['cases']['reference']['passed'] and record['cases']['ordinary-clone']['passed'])
    record['diagnostics_complete'] = complete and record['cases']['diagnostic-clone']['diagnostic_complete']
    ci.save(output / 'result.json', record)
    print(json.dumps({k: record[k] for k in ('ordinary_gates_passed', 'diagnostics_complete')}))
    return int(not (record['ordinary_gates_passed'] and record['diagnostics_complete']))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='operation', required=True)
    builder = sub.add_parser('build')
    builder.add_argument('--subject', type=Path, required=True)
    builder.add_argument('--diagnostic-root', type=Path, required=True)
    builder.add_argument('--subject-ref', default=SUBJECT)
    runner = sub.add_parser('collect')
    for name in ('subject', 'diagnostic-root', 'reference', 'ruby-src', 'output'):
        runner.add_argument('--' + name, type=Path, required=True)
    runner.add_argument('--compiler-root', type=Path)
    runner.add_argument('--subject-ref', default=SUBJECT)
    args = parser.parse_args()
    if args.operation == 'build':
        build(args.subject.resolve(), args.diagnostic_root.resolve(), args.subject_ref)
        return 0
    return collect(args)


if __name__ == '__main__':
    sys.exit(main())
