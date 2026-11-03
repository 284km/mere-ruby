#!/usr/bin/env python3
"""Prove the reference executes Unicode assertions and builds Rust gems."""
import argparse
import os
import subprocess
import tempfile
from pathlib import Path

import ci
import test_data
import transcript


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ruby-src', type=Path, required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source, binary = args.ruby_src.resolve(), args.binary.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    os.environ['REF_RUBY_BIN'] = str(binary)
    data = test_data.verify(source)
    rust = ci.rust_info()
    if not rust:
        raise ValueError('UNITTEST_RUST_BIN must select the installed toolchain binaries')
    version, unicode_version, emoji_version, arch = subprocess.check_output(
        [str(binary), '-rrbconfig', '-e',
         'puts RUBY_VERSION, RbConfig::CONFIG.fetch("UNICODE_VERSION"), RbConfig::CONFIG.fetch("UNICODE_EMOJI_VERSION"), RbConfig::CONFIG.fetch("arch")'],
        text=True, timeout=10).splitlines()
    if unicode_version != test_data.VERSION or emoji_version != test_data.EMOJI_VERSION:
        raise ValueError('reference Unicode version differs from the pinned data')
    report = dict(test_data=data, rust_toolchain=rust, results=[])
    failed = False
    with tempfile.TemporaryDirectory(prefix='mre-', dir='/tmp') as folder:
        private = Path(folder)
        checks = [
            ('ruby/enc/test_regex_casefold.rb', 58, None),
            ('ruby/enc/test_case_comprehensive.rb', None, None),
            ('ruby/enc/test_grapheme_breaks.rb', None, None),
            ('ruby/enc/test_emoji_breaks.rb', None, None),
            ('test_unicode_normalize.rb', None, None),
            ('rubygems/test_gem_ext_cargo_builder.rb', 4, '/test_(build_cdylib|build_fail|full_integration|custom_name)/'),
            ('-ext-/iter/test_iter_break.rb', 1, None),
            ('-ext-/iter/test_yield_block.rb', 2, None),
            ('ruby/test_backtrace.rb', 1, '/test_caller_locations_absolute_path$/'),
            ('ruby/test_file_exhaustive.rb', 2, '/test_(stat_)?socket_p$/'),
            ('ruby/test_enum.rb', 1, '/test_sum$/'),
            ('rubygems/test_gem.rb', 1, '/test_self_prefix$/'),
        ]
        for index, (file, count, selection) in enumerate(checks):
            work = private / str(index)
            work.mkdir()
            stdout, stderr, metadata = [work / name for name in ('stdout', 'stderr', 'encodings')]
            env = ci.test_environment(work / 'environment', binary, version)
            native = Path(os.environ.get('UNITTEST_REF_EXT_PATH', source / '.ext' / arch))
            libraries = [source / 'tool/lib', source / 'test', native]
            if file.startswith('rubygems/'):
                libraries.insert(0, source / 'lib')
            env.update(RUBY=str(binary), RUBYLIB=os.pathsep.join(map(str, libraries)), UNITTEST_TEST_FILE=file,
                       UNITTEST_CASE_ENCODINGS=str(metadata), UNITTEST_STDOUT=str(stdout))
            command = [str(binary), *[arg for path in libraries for arg in ('-I', str(path))], '-r', 'test/unit',
                       '-r', str(ci.ROOT / 'unittest/bootstrap.rb'),
                       '-r', str(ci.ROOT / 'unittest/case_encodings.rb'),
                       str(source / 'test' / file), '-v', '--show-skip', '--seed=1']
            if selection:
                # Exercise build success/failure and both gem install/load
                # paths. The full sweep still runs all nine upstream tests,
                # including its argument-less assert_raise defect.
                command.append('--name=' + selection)
            # Keep stdout separate from diagnostics, under the normal family
            # supervisor. Shell arguments remain positional and quoted.
            run = ci.supervise(['sh', '-c', 'exec "$@" > "$UNITTEST_STDOUT"', 'reference-smoke', *command],
                               env, stderr, 2097152, 300)
            result = transcript.parse(stdout, run['exit'], metadata)
            summary = result['summary']
            passed = (not run['limit'] and result['state'] == 'COMPLETE'
                      and (result['discovered'] == count if count is not None else result['discovered'] > 1)
                      and summary['assertions'] > 0
                      and all(summary[key] == 0 for key in ('failures', 'errors', 'skips')))
            report['results'].append(dict(file=file, passed=passed, state=result['state'],
                                          summary=summary, discovered=result['discovered'], **run))
            ci.sanitize_parts([stdout, stderr], args.output / (file.replace('/', '_') + '.out'))
            ci.save(args.output / 'result.json', report)
            print(f'{file}: {result["state"]}; {summary}; passed={passed}', flush=True)
            failed |= not passed
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
