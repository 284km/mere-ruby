#!/usr/bin/env python3
"""Compare the unchanged upstream Module file and observe its original leak case.

Build both sources with the same pinned compiler before running sequentially.
The selected-case observer runs in the parent; child input and timeout stay
upstream's. A local pass does not waive a failed hosted observation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'unittest'))
import ci
import transcript

RUBY_REF = '3e93b23afcec3433f6aecc34b5d832799d754238'
COMPILER_REF = '43f2994b7d2bc664e47afa1c9555f2dcf26214f2'
BASE_REF = '3b05689f57dbc0321c249523eacf4863eaa7c8bf'
CANDIDATE_REF = '949e46384c1c4190be443450c3bdef0f4d822112'
TEST_SHA = '6b9b0fe714d15e2d08ac9ac6954b5f429754b2507eec2960b9544bc54eb8cdbc'


def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()


def child_observation(text):
    statuses = {}
    for name, value in re.findall(r'(START|FINAL)=(\{[^\n]*\})', text):
        statuses[name] = {key: int(number) for key, number in
                          re.findall(r'(\w+):(\d+)', value)}
    ratio = (statuses['FINAL']['rss'] / statuses['START']['rss']
             if set(statuses) == {'START', 'FINAL'} and statuses['START'].get('rss', 0) > 0
             and 'rss' in statuses['FINAL'] else None)
    return statuses, ratio


def canonical_input(source):
    # Upstream embeds a fresh PID/time token twice; preserve the raw input too.
    canonical, count = re.subn(r'\\e\[7;1m\d+:[0-9.]+:[0-9a-fA-F]+:\\e\[m',
                               '<UPSTREAM_TEST_TOKEN>', source)
    if count != 2:
        raise ValueError('expected exactly two original upstream PID/time/hex tokens')
    return canonical


def case_differences(reference, actual):
    return dict(missing=sorted(reference.keys() - actual.keys()),
                extra=sorted(actual.keys() - reference.keys()),
                different={name: dict(reference=reference[name], actual=actual[name])
                           for name in sorted(reference.keys() & actual.keys())
                           if reference[name] != actual[name]})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('baseline', 'candidate', 'reference', 'ruby-src', 'compiler-root', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    source, compiler = args.ruby_src.resolve(), args.compiler_root.resolve()
    test = source / 'test/ruby/test_module.rb'
    if git(source, 'rev-parse', 'HEAD') != RUBY_REF or ci.digest(test) != TEST_SHA:
        parser.error('the original pinned Ruby test source is required')
    if git(compiler, 'rev-parse', 'HEAD') != COMPILER_REF:
        parser.error('build both interpreters with the pinned CI compiler')
    sides = [('reference', args.reference.resolve()),
             ('main', args.baseline.resolve()), ('pr90', args.candidate.resolve())]
    for label, binary in sides[1:]:
        expected = BASE_REF if label == 'main' else CANDIDATE_REF
        if git(binary.parent, 'rev-parse', 'HEAD') != expected:
            parser.error('use separate source checkouts at the locked comparison commits')
        if (binary.parent / '.build_mode').read_text().strip() != 'O2':
            parser.error('both comparison binaries must be ordinary O2 builds')
        git(binary.parent, 'diff', '--exit-code', 'HEAD', '--', '*.mere', '*.c', '*.h', 'tools/build.sh')
    args.output.mkdir(parents=True, exist_ok=False)
    os.environ['REF_RUBY_BIN'] = str(args.reference.resolve())
    record = dict(bounds=dict(wall_seconds=600, rss_kb=2097152,
                              upstream_child_seconds=10, rss_assertion='strictly less than 2.0'),
                  baseline_ref=BASE_REF, candidate_ref=CANDIDATE_REF,
                  ruby_source_ref=RUBY_REF, compiler_ref=COMPILER_REF,
                  compiler_sha256=ci.digest(compiler / '_build/default/bin/mere.exe'),
                  test_sha256=TEST_SHA, observer_parent_only=True, cases={})
    failed = False
    observed_inputs = []
    for mode in ('complete_file', 'observed_original_case'):
        reference_cases = None
        for label, binary in sides:
            key = mode + '-' + label
            directory = args.output / key
            directory.mkdir()
            env = ci.test_environment(directory / 'environment', binary, '4.0.9')
            runtime = subprocess.check_output(
                ['sh', str(ROOT / 'tools/runtime_load_path.sh'), str(binary)],
                text=True, timeout=20).split(os.pathsep)
            env.update(RUBY=str(binary), UNITTEST_CHILD_RUBY=str(binary),
                       UNITTEST_TEST_FILE='ruby/test_module.rb',
                       RUBYLIB=os.pathsep.join(map(str, [source / 'tool/lib', source / 'test',
                                                        ROOT / 'unittest/shim', *runtime, source / 'lib'])))
            env['PATH'] = str(ROOT / 'unittest/child-bin') + os.pathsep + env['PATH']
            command = [str(binary), '-r', 'test/unit', '-r', str(ROOT / 'unittest/bootstrap.rb')]
            observed = mode == 'observed_original_case'
            if observed:
                command += ['-r', str(ROOT / 'tools/module_rss_observer.rb')]
                env['MODULE_RSS_CAPTURE_INPUT'] = str(directory / 'original_child_input.rb')
            command += [str(test), '-v', '--show-skip', '--seed=1']
            if observed:
                command += ['-n', '/test_complemented_method_entry_memory_leak/']
            log = directory / 'module.log'
            execution = ci.supervise(command, env, log, 2097152, 600)
            parsed = transcript.parse(log, execution['exit'])
            transcript.save(directory / 'cases.json', parsed)
            statuses, ratio = child_observation(log.read_text(errors='replace'))
            value = dict(execution=execution, state=parsed['state'], summary=parsed['summary'],
                         discovered=parsed['discovered'], issues=parsed['issues'],
                         cases=parsed['cases'],
                         binary_sha256=ci.digest(binary), raw_sha256=ci.digest(log),
                         observed_child_status=statuses, observed_child_rss_ratio=ratio,
                         parent_observer_only=observed)
            if label == 'reference':
                reference_cases = parsed['cases']
            differences = case_differences(reference_cases, parsed['cases'])
            value['case_differences_from_reference'] = differences
            if label != 'reference':
                value['binary_source_ref'] = BASE_REF if label == 'main' else CANDIDATE_REF
            child = directory / 'original_child_input.rb'
            if child.exists():
                value['child_input_sha256'] = ci.digest(child)
                canonical = canonical_input(child.read_text())
                value['canonical_child_input_sha256'] = hashlib.sha256(canonical.encode()).hexdigest()
                observed_inputs.append(value['canonical_child_input_sha256'])
            expected_tests, expected_assertions = (1, 3) if observed else (195, 1240)
            passed = (execution['exit'] == 0 and execution['limit'] is None
                      and not any(differences.values())
                      and parsed['state'] == 'COMPLETE' and not parsed['issues']
                      and parsed['discovered'] == expected_tests
                      and parsed['summary'] == dict(tests=expected_tests, assertions=expected_assertions,
                                                   failures=0, errors=0, skips=0)
                      and (not observed or (child.exists() and ratio is not None and ratio < 2.0)))
            value['passed'] = passed
            failed |= not passed
            record['cases'][key] = value
            ci.save(args.output / 'result.json', record)
            print(key, json.dumps(value), flush=True)
    record['observed_inputs_equal_except_upstream_token'] = (
        len(observed_inputs) == 3 and len(set(observed_inputs)) == 1)
    failed |= not record['observed_inputs_equal_except_upstream_token']
    ci.save(args.output / 'result.json', record)
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
