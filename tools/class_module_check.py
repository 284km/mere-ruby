#!/usr/bin/env python3
"""Run the complete pinned upstream Module file with its original leak checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'unittest'))
import ci
import transcript

RUBY_REF = '3e93b23afcec3433f6aecc34b5d832799d754238'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ruby-src', type=Path, required=True)
    parser.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference', type=Path)
    args = parser.parse_args()
    source, binary, output = args.ruby_src.resolve(), args.binary.resolve(), args.output.resolve()
    actual = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != RUBY_REF:
        parser.error('Ruby source must match the pinned upstream revision')
    if (binary.parent / '.build_mode').read_text().strip() != 'O2':
        parser.error('an O2 binary is required')
    output.mkdir(parents=True, exist_ok=True)
    reference = str(args.reference) if args.reference else os.environ.get('REF_RUBY_BIN') or shutil.which('ruby')
    if not reference:
        parser.error('a reference Ruby executable is required for subprocess context')
    os.environ['REF_RUBY_BIN'] = str(Path(reference).resolve())
    env = ci.test_environment(output / 'environment', binary, '4.0.9')
    env.update(RUBY=str(binary), UNITTEST_CHILD_RUBY=str(binary),
               UNITTEST_TEST_FILE='ruby/test_module.rb',
               RUBYLIB=os.pathsep.join(map(str, [source / 'tool/lib', source / 'test',
                                                ROOT / 'unittest/shim', source / 'lib'])))
    env['PATH'] = str(ROOT / 'unittest/child-bin') + os.pathsep + env['PATH']
    test = source / 'test/ruby/test_module.rb'
    command = [str(binary), '-r', 'test/unit', '-r', str(ROOT / 'unittest/bootstrap.rb'),
               str(test), '-v', '--show-skip', '--seed=1']
    log = output / 'module.log'
    execution = ci.supervise(command, env, log, 2097152, 600)
    parsed = transcript.parse(log, execution['exit'])
    transcript.save(output / 'cases.json', parsed)
    working_diff = subprocess.check_output(['git', '-C', str(ROOT), 'diff', '--binary', 'HEAD'])
    result = dict(working_diff_sha256=hashlib.sha256(working_diff).hexdigest() if working_diff else None,
                  source_ref=subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
                  ruby_ref=actual, compiler_ref=os.environ.get('MERE_REF'),
                  binary_sha256=ci.digest(binary), test_sha256=ci.digest(test),
                  bounds=dict(wall_seconds=600, rss_kb=2097152, upstream_leak_seconds=10),
                  execution=execution, state=parsed['state'], summary=parsed['summary'],
                  discovered=parsed['discovered'], issues=parsed['issues'])
    ci.save(output / 'result.json', result)
    print(json.dumps(result), flush=True)
    summary = parsed['summary'] or {}
    passed = (execution['exit'] == 0 and execution['limit'] is None
              and parsed['state'] == 'COMPLETE' and parsed['discovered'] == 195
              and summary.get('tests') == 195 and summary.get('assertions') == 1240
              and summary.get('failures') == 0
              and summary.get('errors') == 0 and summary.get('skips') == 0)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
