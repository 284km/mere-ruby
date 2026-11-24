#!/usr/bin/env python3
"""Replay the original iclass case on the actual failed source without changing its bounds."""
from pathlib import Path
import argparse
import os, sys, json, re, hashlib, platform, subprocess
ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'unittest'))
import ci, transcript
from iclass_resource_assess import SOURCE, RUBY, TEST_SHA, COMPILERS, assess
OBSERVER = r'''module IclassObserver
  def invoke_ruby(args, stdin = "", *rest, **options, &block)
    selected = stdin.include?("3_000_000.times(&code)")
    File.binwrite(ENV.fetch("ICLASS_INPUT"), stdin) if selected
    raise "scaled upstream timeout" if selected && EnvUtil.timeout_scale && EnvUtil.timeout_scale != 1
    result = super
    STDERR.write("\nICLASS_CHILD_BEGIN\n", result[1], "ICLASS_CHILD_END\n") if selected
    result
  rescue Exception => error
    STDERR.write("\nICLASS_EXCEPTION_BEGIN\n", error.message, "\nICLASS_EXCEPTION_END\n") if selected
    raise
  end
end
EnvUtil.singleton_class.prepend(IclassObserver)
'''
TIMER = r'''import os,sys,subprocess,json,signal
from pathlib import Path
p=subprocess.Popen(sys.argv[2:])
pid,status,usage=os.wait4(p.pid,0)
p.returncode=os.waitstatus_to_exitcode(status)
Path(sys.argv[1]).write_text(json.dumps(dict(exit=p.returncode,wait4_user_seconds=usage.ru_utime,wait4_system_seconds=usage.ru_stime,wait4_maxrss=usage.ru_maxrss)))
if p.returncode<0:
    signal.signal(-p.returncode,signal.SIG_DFL)
    os.kill(os.getpid(),-p.returncode)
raise SystemExit(p.returncode)
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('before', 'repair', 'before-compiler', 'repair-compiler', 'ruby-src', 'reference', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    roots = {k: getattr(args, k).resolve() for k in ('before', 'repair')}
    (source, reference, out) = (args.ruby_src.resolve(), args.reference.resolve(), args.output.resolve())
    git = lambda path, *opts: subprocess.check_output(['git', '-C', str(path), *opts], text=True).strip()
    if git(source, 'rev-parse', 'HEAD') != RUBY or ci.digest(source / 'test/ruby/test_module.rb') != TEST_SHA:
        parser.error('the exact pinned Ruby source is required')
    if not subprocess.check_output([str(reference), '-v'], text=True).startswith('ruby 4.0.10 '):
        parser.error('reference Ruby 4.0.10 is required')
    for (label, root) in roots.items():
        if git(root, 'rev-parse', 'HEAD') != SOURCE or (root / '.build_mode').read_text().strip() != 'O2':
            parser.error('both ordinary O2 binaries must use the failed source SHA')
        git(root, 'diff', '--exit-code', 'HEAD')
        compiler = getattr(args, label + '_compiler').resolve()
        if git(compiler, 'rev-parse', 'HEAD') != COMPILERS[label]:
            parser.error('the compiler checkout must match its published SHA')
    (before, after) = [(roots[k] / 'mr.c').read_text() for k in ('before', 'repair')]
    clear = '  if (m->len > 0) {\n    memset(m->keys, 0, (size_t)m->len * sizeof(*m->keys));\n    memset(m->values, 0, (size_t)m->len * sizeof(*m->values));\n  }\n'
    delete = '      memset(&m->keys[i], 0, sizeof(m->keys[i]));\n      memset(&m->values[i], 0, sizeof(m->values[i]));\n'
    if after.count(clear) != 32 or after.count(delete) != 32 or after.replace(clear, '').replace(delete, '') != before:
        parser.error('only the removed Map-slot clearing fragments may differ')
    inputs = dict(source_ref=SOURCE, ruby_ref=RUBY, test_sha256=TEST_SHA, compiler_refs=COMPILERS, map_slots_only=True, clear_sites=32, delete_sites=32, c_sha256={k: ci.digest(v / 'mr.c') for (k, v) in roots.items()}, compiler_binary_sha256={k: ci.digest(getattr(args, k + '_compiler') / '_build/default/bin/mere.exe') for k in roots})
    del before, after
    out.mkdir(parents=True, exist_ok=False)
    support = out / 'support'
    support.mkdir()
    (support / 'observer.rb').write_text(OBSERVER)
    (support / 'timer.py').write_text(TIMER)
    record = inputs
    record.update(platform=dict(system=platform.system(), machine=platform.machine()), bounds=dict(wall_seconds=600, rss_kb=2097152, child_seconds=10), order=['reference', 'before', 'repair', 'repair', 'before'], selected=[], module={}, method={})
    os.environ['REF_RUBY_BIN'] = str(reference)

    def environment(root, binary, folder):
        ci.ROOT = root
        env = ci.test_environment(folder / 'environment', binary, '4.0.10')
        runtime = subprocess.check_output(['sh', str(root / 'tools/runtime_load_path.sh'), str(binary)], text=True, timeout=20).split(os.pathsep)
        env.update(RUBY=str(binary), UNITTEST_CHILD_RUBY=str(binary), UNITTEST_TEST_FILE='ruby/test_module.rb', RUBYLIB=os.pathsep.join(map(str, [source / 'tool/lib', source / 'test', root / 'unittest/shim', *runtime, source / 'lib'])))
        env['PATH'] = str(root / 'unittest/child-bin') + os.pathsep + env['PATH']
        return env
    expected = None
    for (i, label) in enumerate(record['order']):
        root = roots['before' if label == 'reference' else label]
        binary = reference if label == 'reference' else root / 'mere-ruby'
        folder = out / (str(i) + '-' + label)
        folder.mkdir()
        env = environment(root, binary, folder)
        env['ICLASS_INPUT'] = str(folder / 'original_child.rb')
        log = folder / 'test.log'
        cpu = folder / 'usage.json'
        command = [str(binary), '-r', 'test/unit', '-r', str(root / 'unittest/bootstrap.rb'), '-r', str(support / 'observer.rb'), str(source / 'test/ruby/test_module.rb'), '-v', '--show-skip', '--seed=1', '-n', '/test_iclass_memory_leak/']
        execution = ci.supervise(['python3', str(support / 'timer.py'), str(cpu), *command], env, log, 2097152, 600)
        raw = log.read_text(errors='replace')
        parsed = transcript.parse(log, execution['exit'])
        transcript.save(folder / 'cases.json', parsed)
        original = (folder / 'original_child.rb').read_text() if (folder / 'original_child.rb').exists() else ''
        (canonical, count) = re.subn('\\\\e\\[7;1m\\d+:[0-9.]+:[0-9a-fA-F]+:\\\\e\\[m', '<UPSTREAM_TEST_TOKEN>', original)
        sha = hashlib.sha256(canonical.encode()).hexdigest()
        if expected is None:
            expected = sha
        statuses = {name: {k: int(v) for (k, v) in re.findall('(\\w+):(\\d+)', value)} for (name, value) in re.findall('(START|FINAL)=(\\{[^\\n]*\\})', raw)}
        value = dict(label=label, execution=execution, usage=json.loads(cpu.read_text()) if cpu.exists() else None, parsed=parsed, raw_sha256=ci.digest(log), canonical_input_sha256=sha, canonical_nonce_count=count, original_input_matches=count == 2 and sha == expected, child_statuses=statuses, binary_sha256=ci.digest(binary))
        record['selected'].append(value)
        ci.save(out / 'result.json', record)
        print('ICLASS', i, label, execution, value['usage'], parsed['summary'], value['original_input_matches'], flush=True)
    for label in ['reference', 'before', 'repair']:
        root = roots['before' if label == 'reference' else label]
        binary = reference if label == 'reference' else root / 'mere-ruby'
        folder = out / ('module-' + label)
        folder.mkdir()
        env = environment(root, binary, folder)
        log = folder / 'test.log'
        execution = ci.supervise([str(binary), '-r', 'test/unit', '-r', str(root / 'unittest/bootstrap.rb'), str(source / 'test/ruby/test_module.rb'), '-v', '--show-skip', '--seed=1'], env, log, 2097152, 600)
        parsed = transcript.parse(log, execution['exit'])
        transcript.save(folder / 'cases.json', parsed)
        record['module'][label] = dict(execution=execution, parsed=parsed, raw_sha256=ci.digest(log))
        ci.save(out / 'result.json', record)
        print('MODULE', label, execution, parsed['summary'], flush=True)
    for label in ['before', 'repair']:
        root = roots[label]
        folder = out / ('method-' + label)
        with (out / ('method-' + label + '-driver.log')).open('w') as log:
            status = subprocess.run(['python3', str(root / 'tools/method_copy_memory_check.py'), '--binary', str(root / 'mere-ruby'), '--reference', str(reference), '--output', str(folder)], stdout=log, stderr=subprocess.STDOUT).returncode
        value = json.loads((folder / 'result.json').read_text())
        record['method'][label] = dict(driver_exit=status, result=value, program_sha256=ci.digest(folder / 'method_copy.rb'))
        ci.save(out / 'result.json', record)
        print('METHOD', label, status, {k: v['post_gc_peak_to_initial'] for (k, v) in value['sides'].items()}, flush=True)
    record['assessment'] = assess(record)
    ci.save(out / 'result.json', record)
    print(record['assessment'], flush=True)
    return int(not record['assessment']['passed'])
if __name__ == '__main__':
    raise SystemExit(main())
