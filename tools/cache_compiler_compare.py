#!/usr/bin/env python3
"""Compare a locked cache-clearing compiler change using ordinary RSS gates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import rss_native_probe as native

SOURCE = native.SUBJECT
COMPILERS = dict(parent='01f5ad738748cc570cc04e3000f50b8c6965543f',
                 candidate='94da60b51e438404edf857ed09941c5db8361dca')
ORDER = ['parent', 'candidate', 'candidate', 'parent']
MODES = ('module', 'clone', 'complemented', 'refinement')
INPUTS = dict(clone=native.CLONE_SHA,
              complemented='d72dac14e7ab74fc09b0e3ff5f0bab8b8e8468fa7167cfeda2c9342f36fbfa48')
OBSERVER = '''module CacheCompilerObserver
  def invoke_ruby(args, stdin = "", *rest, **options, &block)
    selected = stdin.include?('$initial_status = Memory::Status.new')
    File.binwrite(ENV.fetch("CACHE_COMPARE_INPUT"), stdin) if selected
    result = super
    STDERR.write("\\nCACHE_COMPARE_CHILD_BEGIN\\n", result[1], "CACHE_COMPARE_CHILD_END\\n") if selected
    result
  end
end
EnvUtil.singleton_class.prepend(CacheCompilerObserver)
'''


def clearing_only(before, after):
    """Reject unrelated emitted-C changes, including instrumentation."""
    start = '#if defined(__linux__)\n#include <sys/mman.h>\n#endif\n/* Only discarded bytes'
    stop = 'static void __lang_region_block_release(__lang_region* r) {'
    if after.count(start) != 1 or after.count('if (zlen) __lang_region_clear_cached(zat, zlen);') != 1:
        return False
    prefix, rest = after.split(start, 1)
    if stop not in rest:
        return False
    restored = prefix + stop + rest.split(stop, 1)[1]
    restored = restored.replace('if (zlen) __lang_region_clear_cached(zat, zlen);',
                                'if (zlen) memset(zat, 0, zlen);')
    return restored == before


def method_side_passed(side):
    samples = side['samples_kb']
    if (side['execution']['exit'] != 0 or side['execution']['limit'] is not None
            or not side['healthy'] or [r[0] for r in samples] != list(range(21))
            or any(type(r[0]) is not int or type(r[1]) is not int or r[1] <= 0 for r in samples)):
        return False
    ratio = max(r[1] for r in samples[1:]) / samples[0][1]
    return ratio <= 2 and ratio == side['post_gc_peak_to_initial']


def method_passed(run):
    data = run['result']
    return (run['driver_exit'] == 0 and run['program_sha256'] == native.PROGRAM_SHA
            and data['bounds'] == dict(wall_seconds=600, rss_kb=2097152, post_gc_growth=2.0)
            and set(data['sides']) == {'mere', 'reference'}
            and all(method_side_passed(side) for side in data['sides'].values()))


def assess(record):
    """A successful diagnostic or later sample cannot replace a failed gate."""
    runs, core = record['method_runs'], record['core_cases']
    expected_keys = {mode + '-' + side for mode in MODES for side in ('reference', 'parent', 'candidate')}
    complete = (record.get('clearing_only') is True
                and record['compiler_refs'] == COMPILERS
                and record['source_refs'] == dict(parent=SOURCE, candidate=SOURCE)
                and [r['label'] for r in runs] == ORDER and set(core) == expected_keys)
    complete = complete and all(
        run['program_sha256'] == native.PROGRAM_SHA
        and run['result']['bounds'] == dict(wall_seconds=600, rss_kb=2097152, post_gc_growth=2.0)
        and set(run['result']['sides']) == {'mere', 'reference'}
        and run['result']['sides']['mere']['binary_sha256'] == record['binary_sha256'][run['label']]
        and run['result']['sides']['reference']['binary_sha256'] == record['reference_binary_sha256']
        for run in runs)
    method_ok = complete and all(method_passed(r) for r in runs if r['label'] == 'candidate')
    references_ok = complete and all(method_side_passed(r['result']['sides']['reference']) for r in runs)
    core_ok, lost = complete, {}
    for mode in MODES:
        if any(mode + '-' + side not in core for side in ('reference', 'parent', 'candidate')):
            core_ok = False
            continue
        ref, parent, candidate = [core[mode + '-' + side] for side in ('reference', 'parent', 'candidate')]
        expected = ref['parsed']['cases']
        lost[mode] = sorted(name for name, state in parent['parsed']['cases'].items()
                            if state == '.' and candidate['parsed']['cases'].get(name) != '.')
        for value in (ref, candidate):
            parsed = value['parsed']
            core_ok &= (value['execution']['exit'] == 0 and value['execution']['limit'] is None
                        and parsed['state'] == 'COMPLETE' and not parsed['issues']
                        and parsed['cases'] == expected and parsed['summary'] == ref['parsed']['summary'])
        for value in (ref, parent, candidate):
            parsed = value['parsed']
            core_ok &= (parsed['state'] == 'COMPLETE' and not parsed['issues']
                        and set(parsed['cases']) == set(expected)
                        and parsed['summary'] is not None
                        and parsed['discovered'] == len(parsed['cases'])
                        and parsed['summary']['tests'] == len(parsed['cases']))
            if mode in INPUTS:
                core_ok &= value.get('canonical_input_sha256') == INPUTS[mode]
        summary = ref['parsed']['summary'] or {}
        counts = dict(module=(195, 1240), clone=(1, 3), complemented=(1, 3))
        if mode in counts:
            tests, assertions = counts[mode]
            core_ok &= summary == dict(tests=tests, assertions=assertions, failures=0, errors=0, skips=0)
        else:
            core_ok &= (summary.get('tests') == 122 and summary.get('failures') == 0
                        and summary.get('errors') == 0
                        and (summary.get('assertions'), summary.get('skips')) in ((370, 0), (367, 1)))
        core_ok &= not lost[mode]
    return dict(complete=bool(complete), candidate_method_passed=bool(method_ok),
                references_passed=bool(references_ok), candidate_core_passed=bool(core_ok),
                lost_passing_cases=lost,
                passed=bool(complete and method_ok and references_ok and core_ok))


def collect(args):
    parent, candidate, source, reference, output = [getattr(args, key).resolve()
        for key in ('parent', 'candidate', 'ruby_src', 'reference', 'output')]
    roots = dict(parent=parent, candidate=candidate)
    if native.git(source, 'rev-parse', 'HEAD') != native.RUBY:
        raise ValueError('the locked Ruby source is required')
    native.git(source, 'diff', '--exit-code', 'HEAD', '--', 'test', 'tool', 'lib')
    for side, root in roots.items():
        if native.git(root, 'rev-parse', 'HEAD') != SOURCE or (root / '.build_mode').read_text().strip() != 'O2':
            raise ValueError('both ordinary O2 binaries must use the same locked runtime')
        native.git(root, 'diff', '--exit-code', 'HEAD', '--', '*.mere', '*.c', '*.h', 'tools', 'unittest', 'lib')
        compiler = getattr(args, side + '_compiler').resolve()
        if native.git(compiler, 'rev-parse', 'HEAD') != COMPILERS[side]:
            raise ValueError('the compiler sources must match their pinned revisions')
        native.git(compiler, 'diff', '--exit-code', 'HEAD')
    if native.ci.digest(source / 'test/ruby/test_module.rb') != native.TEST_SHA:
        raise ValueError('the original Module source changed')
    only = clearing_only((parent / 'mr.c').read_text(), (candidate / 'mr.c').read_text())
    if not only:
        raise ValueError('generated C must differ only in inactive cache clearing')
    output.mkdir(parents=True, exist_ok=False)
    os.environ['REF_RUBY_BIN'] = str(reference)
    record = dict(purpose='Ordinary O2 compiler-only comparison; failed observations are retained',
        source_refs={side: SOURCE for side in roots}, compiler_refs=COMPILERS, ruby_ref=native.RUBY,
        clearing_only=only, order=ORDER, platform=sys.platform,
        host_architecture=os.uname().machine,
        bounds=dict(wall_per_side=600, rss_family_kb=2097152, upstream_child_seconds=10),
        binary_sha256={side: native.ci.digest(root / 'mere-ruby') for side, root in roots.items()},
        c_sha256={side: native.ci.digest(root / 'mr.c') for side, root in roots.items()},
        compiler_binary_sha256={side: native.ci.digest(getattr(args, side + '_compiler').resolve()
                               / '_build/default/bin/mere.exe') for side in roots},
        comparison_sha256=native.ci.digest(Path(__file__)),
        method_driver_sha256=native.ci.digest(native.ROOT / 'tools/method_copy_memory_check.py'),
        reference_binary_sha256=native.ci.digest(reference), method_runs=[], core_cases={})
    def save():
        native.ci.save(output / 'result.json', record)
    save()
    for index, side in enumerate(ORDER):
        folder = output / ('method-' + str(index) + '-' + side)
        with (output / ('method-' + str(index) + '.driver.log')).open('w') as log:
            driver = subprocess.run([sys.executable, str(native.ROOT / 'tools/method_copy_memory_check.py'),
                '--binary', str(roots[side] / 'mere-ruby'), '--reference', str(reference), '--output', str(folder)],
                stdout=log, stderr=subprocess.STDOUT)
        value = dict(label=side, driver_exit=driver.returncode,
                     result=json.loads((folder / 'result.json').read_text()),
                     program_sha256=native.ci.digest(folder / 'method_copy.rb'))
        record['method_runs'].append(value)
        save()
        print('METHOD', index, side, {k: v['post_gc_peak_to_initial'] for k, v in value['result']['sides'].items()}, flush=True)
    observer = output / 'observer.rb'
    observer.write_text(OBSERVER)
    for mode in MODES:
        file = 'ruby/test_refinement.rb' if mode == 'refinement' else 'ruby/test_module.rb'
        selector = dict(clone='/test_module_clone_memory_leak/',
                        complemented='/test_complemented_method_entry_memory_leak/').get(mode)
        for side, binary in [('reference', reference), *[(side, root / 'mere-ruby') for side, root in roots.items()]]:
            key = mode + '-' + side
            folder = output / key
            folder.mkdir()
            env = native.environment(binary, folder, reference, source)
            env['UNITTEST_TEST_FILE'] = file
            env.pop('RSS_NATIVE_ENABLE', None)
            command = [str(binary), '-r', 'test/unit', '-r', str(native.ROOT / 'unittest/bootstrap.rb')]
            if selector:
                env['CACHE_COMPARE_INPUT'] = str(folder / 'original_child_input.rb')
                command += ['-r', str(observer)]
            command += [str(source / 'test' / file), '-v', '--show-skip', '--seed=1']
            if selector:
                command += ['-n', selector]
            log = folder / 'module.log'
            execution = native.ci.supervise(command, env, log, 2097152, 600)
            parsed = native.transcript.parse(log, execution['exit'])
            native.transcript.save(folder / 'cases.json', parsed)
            value = dict(execution=execution, parsed=parsed, raw_sha256=native.ci.digest(log))
            if selector:
                captured = folder / 'original_child_input.rb'
                canonical, count = re.subn(r'\\e\[7;1m\d+:[0-9.]+:[0-9a-fA-F]+:\\e\[m',
                    '<UPSTREAM_TEST_TOKEN>', captured.read_text() if captured.exists() else '')
                value['canonical_input_sha256'] = hashlib.sha256(canonical.encode()).hexdigest() if count == 2 else None
                raw = log.read_text(errors='replace')
                statuses = {name: {k: int(n) for k, n in re.findall(r'(\w+):(\d+)', status)}
                            for name, status in re.findall(r'(START|FINAL)=(\{[^\n]*\})', raw)}
                value['observed_statuses'] = statuses
                value['rss_ratio'] = statuses['FINAL']['rss'] / statuses['START']['rss'] if set(statuses) == {'START', 'FINAL'} else None
            record['core_cases'][key] = value
            save()
            print('CORE', key, parsed['summary'], value.get('rss_ratio'), flush=True)
    record['assessment'] = assess(record)
    save()
    print(json.dumps(record['assessment']), flush=True)
    return int(not record['assessment']['passed'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('parent', 'candidate', 'parent-compiler', 'candidate-compiler', 'ruby-src', 'reference', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        return collect(args)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
