#!/usr/bin/env python3
"""Measure the unmodified CRuby basic body through its native host runner."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'unittest'))
import ci

POLICY = 'native-basic-durable-output-v1'
OUTPUT_BYTES = 16 * 1024 * 1024


def parse_output(path, source, execution, child_exit):
    cases, issues, final = {}, [], None
    occurrences = Counter()
    location = re.compile(re.escape(str(source)) + r':(\d+)(?::in .*)?')
    evaluated = re.compile(r'\(eval at ' + re.escape(str(source)) + r':(\d+)\):(\d+)(?::in .*)?')
    passed = re.compile(r'^ok \d+ \((.*)\)$')
    failed = re.compile(r'^not ok .+ \d+ -- (.*)$')
    success = re.compile(r'^end of test\(test: (\d+)\)$')
    failure = re.compile(r'^not ok/test: (\d+) failed (\d+)$')
    try:
        if path.stat().st_size > OUTPUT_BYTES:
            raise ValueError('basic output byte bound exceeded')
        for raw in path.read_text().splitlines():
            good, bad = passed.fullmatch(raw), failed.fullmatch(raw)
            summary, errors = success.fullmatch(raw), failure.fullmatch(raw)
            if good or bad:
                if final is not None:
                    raise ValueError('basic case after final summary')
                frame = (good or bad).group(1)
                origin, inside_eval = location.fullmatch(frame), evaluated.fullmatch(frame)
                if not origin and not inside_eval:
                    raise ValueError('unrecognized basic source location')
                line = int((origin or inside_eval).group(1))
                eval_line = int(inside_eval.group(2)) if inside_eval else 0
                if line <= 0 or (inside_eval and eval_line <= 0):
                    raise ValueError('invalid basic source line')
                base = (line, eval_line)
                occurrences[base] += 1
                cases[('basictest/test.rb', line, eval_line, occurrences[base])] = 'PASS' if good else 'FAIL'
            elif summary or errors:
                if final is not None:
                    raise ValueError('duplicate basic summary')
                final = dict(tests=int((summary or errors).group(1)), failures=int(errors.group(2)) if errors else 0)
            elif raw.startswith(('ok ', 'not ok ', 'end of test', 'not ok/test:')):
                raise ValueError('unrecognized basic case or summary')
            elif final is not None and raw.strip():
                raise ValueError('output after basic summary')
    except (OSError, UnicodeError, ValueError) as error:
        issues.append(type(error).__name__ + ': ' + str(error))
    complete = (not issues and final is not None and final['tests'] == len(cases)
                and final['failures'] == sum(v == 'FAIL' for v in cases.values())
                and child_exit == 0 and execution['exit'] == int(final['failures'] > 0))
    state = execution['limit'] or ('COMPLETE' if complete and cases else 'ZERO' if complete else 'INCOMPLETE')
    effective = {key: value if state == 'COMPLETE' else 'X' for key, value in cases.items()}
    return dict(state=state, execution=execution, child_exit=child_exit, summary=final,
                discovered=len(cases), verdicts=dict(Counter(effective.values())), issues=issues,
                cases=[dict(file=key[0], line=key[1], eval_line=key[2], occurrence=key[3], observed=cases[key], status=value)
                       for key, value in effective.items()]), effective


def compare(reference, mere):
    counts = dict.fromkeys(ci.COUNTS, 0)
    for key in reference.keys() | mere.keys():
        ref_pass, mere_pass = reference.get(key) == 'PASS', mere.get(key) == 'PASS'
        counts['tests'] += 1
        counts['match' if ref_pass and mere_pass else 'red' if ref_pass else 'extra' if mere_pass else 'both'] += 1
    return counts


def run_side(source, reference, binary, work, env, wall, rss_kb, output):
    work.mkdir()
    # Upstream interpolates its source directory into a shell command without
    # quoting. A private alias keeps that directory free of spaces while the
    # body and runner themselves remain byte-for-byte upstream inputs.
    source_alias = work / 'source'
    source_alias.symlink_to(source, target_is_directory=True)
    # The body invokes ./miniruby itself for command-line tests. This is an
    # actual selected interpreter, not the native host that drives the suite.
    (work / 'miniruby').symlink_to(binary)
    stdout, exit_file = work / 'body.stdout', work / 'body.exit'
    launcher = work / 'target.sh'
    launcher.write_text('#!/bin/sh\n' + shlex.quote(str(binary)) + ' "$@" > ' + shlex.quote(str(stdout))
                        + '\ncode=$?\nprintf \'%s\\n\' "$code" > ' + shlex.quote(str(exit_file) + '.new')
                        + '\nmv ' + shlex.quote(str(exit_file) + '.new') + ' ' + shlex.quote(str(exit_file))
                        + '\ncat ' + shlex.quote(str(stdout)) + '\nexit "$code"\n')
    launcher.chmod(0o755)
    side_env = dict(env, RUBY=str(launcher), UNITTEST_CHILD_RUBY=str(binary),
                    PATH=str(ROOT / 'unittest/child-bin') + os.pathsep + env['PATH'])
    command = [str(reference), str(source_alias / 'basictest/runner.rb'), '--tty=no', '--color=never']
    # The supervisor has no cwd parameter. A tiny exec-only host sets it without
    # changing the parent process's cwd or introducing shell quoting of args.
    command = [sys.executable, '-c', 'import os,sys; os.chdir(sys.argv[1]); os.execv(sys.argv[2],sys.argv[2:])', str(work)] + command
    log = work / 'runner.out'
    execution = ci.supervise(command, side_env, log, rss_kb, wall)
    child_exit = None
    if exit_file.is_file():
        try:
            child_exit = int(exit_file.read_text().strip())
        except ValueError:
            pass
    summary, verdicts = parse_output(stdout, source_alias / 'basictest/test.rb', execution, child_exit)
    ci.sanitize_parts([log], output.with_suffix('.runner.out'))
    if stdout.is_file():
        ci.sanitize_parts([stdout], output.with_suffix('.body.out'))
    return summary, verdicts


def measure(args):
    source, reference, binary = args.ruby_src.resolve(), args.reference.resolve(), args.binary.resolve()
    if args.wall <= 0 or args.rss_kb <= 0:
        raise ValueError('positive resource bounds required')
    manifest, build, ref = ci.load(args.plan), ci.load(args.build_info), ci.load(args.reference_info)
    revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != manifest['ruby_ref'] or ref['ruby_ref'] != revision:
        raise ValueError('basic reference source mismatch')
    if (build['source_ref'] != manifest['source_ref'] or build['mere_ref'] != manifest['mere_ref']
            or build['optimization'] != 'O2' or ci.digest(binary) != build['binary_sha256']
            or ci.digest(reference) != ref['binary_sha256']):
        raise ValueError('basic measurement binary provenance mismatch')
    suites = ci.load(args.suites)
    basic = next(s for s in suites['suites'] if s['suite'] == 'basictest')
    if (suites['ruby_ref'] != revision or basic['runner_sha256'] != ci.digest(source / 'basictest/runner.rb')
            or basic['files'] != [dict(path='basictest/test.rb', sha256=ci.digest(source / 'basictest/test.rb'))]):
        raise ValueError('basic input inventory mismatch')
    result = dict(schema=1, policy=POLICY, manifest=manifest, build=build, reference=ref,
                  inputs={p: ci.digest(source / p) for p in ['basictest/test.rb', 'basictest/runner.rb']},
                  harness=dict(measure_sha256=ci.digest(Path(__file__)), child_launcher_sha256=ci.digest(ROOT / 'unittest/child-bin/ruby')),
                  wall_seconds=args.wall, rss_kb=args.rss_kb, rows=[], infrastructure_error=None)
    args.output.mkdir(parents=True, exist_ok=True)
    ci.save(args.output / 'summary.json', result)
    os.environ['REF_RUBY_BIN'] = str(reference)
    row, verdicts = dict(file='basictest/test.rb'), {}
    try:
        with tempfile.TemporaryDirectory(prefix='mr-basic-', dir='/tmp') as temporary:
            private = Path(temporary)
            env = ci.test_environment(private / 'environment', binary, ref['version'])
            for side, subject in [('reference', reference), ('mere', binary)]:
                row[side], verdicts[side] = run_side(source, reference, subject, private / side, env,
                                                   args.wall, args.rss_kb, args.output / side)
                result['rows'] = [row]
                ci.save(args.output / 'summary.json', result)
        result['totals'] = row['counts'] = compare(verdicts['reference'], verdicts['mere'])
        result['reference_gaps'] = [] if row['reference']['state'] == 'COMPLETE' else ['basictest/test.rb']
        ci.save(args.output / 'summary.json', result)
        lines = ['# CRuby basic measurement', '', f'Policy: `{POLICY}`. Unmodified upstream body and native host runner.', '',
                 '| File | Reference | Mere | MATCH | RED | BOTH | EXTRA |', '|---|---|---|---:|---:|---:|---:|',
                 '| ' + ' | '.join([row['file'], row['reference']['state'], row['mere']['state']] + [str(row['counts'][key]) for key in ci.COUNTS[1:]]) + ' |', '']
        (args.output / 'SUMMARY.md').write_text('\n'.join(lines))
        print(json.dumps(dict(totals=result['totals'], reference=row['reference']['state'], mere=row['mere']['state'])))
    except Exception as error:
        result['infrastructure_error'] = type(error).__name__
        ci.save(args.output / 'summary.json', result)
        raise
    if result['reference_gaps']:
        raise SystemExit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('ruby-src', 'plan', 'suites', 'build-info', 'reference-info', 'binary', 'reference', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--wall', type=int, default=600)
    parser.add_argument('--rss-kb', type=int, default=2097152)
    measure(parser.parse_args())
