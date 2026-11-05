#!/usr/bin/env python3
"""Measure every bootstrap assertion through CRuby's native bootstrap runner."""
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

POLICY = 'native-bootstrap-knownbugs-v2'
CASE_BYTES = 16 * 1024 * 1024
CASE_LIMIT = 100000


def files(source):
    paths = [str(p.relative_to(source)) for p in (source / 'bootstraptest').glob('test_*.rb')]
    if (source / 'KNOWNBUGS.rb').is_file():
        paths.append('KNOWNBUGS.rb')
    return sorted(paths)


def empty_inputs(source):
    # The pinned KNOWNBUGS file is a comment-only sentinel. A later executable
    # body may not become a successful zero-case measurement through a guard.
    path = source / 'KNOWNBUGS.rb'
    return ['KNOWNBUGS.rb'] if path.is_file() and all(not line.strip() or line.lstrip().startswith('#')
                                                   for line in path.read_text().splitlines()) else []


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


def plan(args):
    selected = files(args.ruby_src)
    if not selected or not 1 <= args.shards <= len(selected):
        raise ValueError('empty bootstrap manifest or invalid shard count')
    for value in (args.source_ref, args.mere_ref, args.ruby_ref):
        if not re.fullmatch('[0-9a-f]{40}', value):
            raise ValueError('full commit SHAs required')
    if revision(args.ruby_src) != args.ruby_ref:
        raise ValueError('Ruby source does not match manifest')
    ci.save(args.output, dict(schema=1, policy=POLICY, source_ref=args.source_ref,
                             mere_ref=args.mere_ref, ruby_ref=args.ruby_ref,
                             shards=args.shards, files=selected, empty_inputs=empty_inputs(args.ruby_src),
                             input_sha256={file: ci.digest(args.ruby_src / file) for file in selected}))


def parse_cases(path, execution):
    cases, issues, final = {}, [], None
    occurrences = Counter()
    try:
        if path.stat().st_size > CASE_BYTES:
            raise ValueError('case log byte bound exceeded')
        with path.open() as stream:
            for line in stream:
                record = json.loads(line)
                event = record['event']
                if final is not None:
                    raise ValueError('record after final event')
                if event == 'final':
                    final = record
                    continue
                identifier = record['id']
                if type(identifier) is not int or not 1 <= identifier <= CASE_LIMIT:
                    raise ValueError('invalid assertion id')
                if event == 'discover':
                    if identifier in cases:
                        raise ValueError('duplicate assertion id')
                    if not re.fullmatch('[0-9a-f]{64}', record['source_sha256']):
                        raise ValueError('invalid assertion source digest')
                    if type(record['line']) is not int or record['line'] <= 0:
                        raise ValueError('invalid assertion line')
                    # Generated source can contain the driver's PID or paths.
                    # Upstream assertion identity is its location/occurrence;
                    # the digest remains audit data, not a different test name.
                    base = (record['file'], record['line'])
                    occurrences[base] += 1
                    cases[identifier] = dict(record, key=base + (occurrences[base],), status='X', started=False)
                elif event == 'start':
                    if identifier not in cases or cases[identifier]['started']:
                        raise ValueError('invalid assertion start')
                    cases[identifier]['started'] = True
                elif event == 'finish':
                    if identifier not in cases or not cases[identifier]['started'] or cases[identifier]['status'] != 'X':
                        raise ValueError('invalid assertion completion')
                    if record['status'] not in ('PASS', 'FAIL', 'ERROR', 'SKIP'):
                        raise ValueError('invalid assertion status')
                    cases[identifier]['status'] = record['status']
                else:
                    raise ValueError('unknown case event')
    except (OSError, ValueError, KeyError, TypeError) as error:
        issues.append(type(error).__name__ + ': ' + str(error))
    complete = (not issues and final is not None and final.get('normal_exit') is True
                and final.get('discovered') == len(cases)
                and final.get('exit') == execution['exit']
                and all(case['status'] != 'X' for case in cases.values())
                and (bool(execution['exit']) == any(case['status'] in ('FAIL', 'ERROR') for case in cases.values())))
    state = execution['limit'] or ('COMPLETE' if complete and cases else 'ZERO' if complete else 'INCOMPLETE')
    # A missing final result must not promote progress into passing tests.
    effective = {case['key']: case['status'] if state == 'COMPLETE' else 'X' for case in cases.values()}
    summary = dict(state=state, discovered=len(cases), finished=sum(c['status'] != 'X' for c in cases.values()),
                   verdicts=dict(Counter(effective.values())), kinds=dict(Counter(c.get('kind') for c in cases.values())),
                   issues=issues, execution=execution)
    return summary, effective


def compare(reference, mere):
    counts = dict.fromkeys(ci.COUNTS, 0)
    for key in reference.keys() | mere.keys():
        ref_pass = reference.get(key) == 'PASS'
        mere_pass = mere.get(key) == 'PASS'
        counts['tests'] += 1
        counts['match' if ref_pass and mere_pass else 'red' if ref_pass else 'extra' if mere_pass else 'both'] += 1
    return counts


def measure(args):
    manifest, build, reference = ci.load(args.plan), ci.load(args.build_info), ci.load(args.reference_info)
    args.output.mkdir(parents=True, exist_ok=True)
    if (manifest['policy'] != POLICY or files(args.ruby_src) != manifest['files']
            or manifest['empty_inputs'] != empty_inputs(args.ruby_src)
            or manifest['input_sha256'] != {file: ci.digest(args.ruby_src / file) for file in manifest['files']}):
        raise ValueError('bootstrap inventory changed')
    if not 0 <= args.shard < manifest['shards']:
        raise ValueError('invalid shard')
    if args.wall <= 0 or args.rss_kb <= 0:
        raise ValueError('positive resource bounds required')
    if revision(args.ruby_src) != manifest['ruby_ref'] or reference['ruby_ref'] != manifest['ruby_ref']:
        raise ValueError('reference source mismatch')
    if build['source_ref'] != manifest['source_ref'] or build['mere_ref'] != manifest['mere_ref'] or build['optimization'] != 'O2':
        raise ValueError('measurement binary source/build mismatch')
    if ci.digest(args.binary) != build['binary_sha256'] or ci.digest(args.reference) != reference['binary_sha256']:
        raise ValueError('measurement binary digest mismatch')
    result = dict(schema=1, policy=POLICY, shard=args.shard, manifest=manifest, build=build,
                  harness=dict(measure_sha256=ci.digest(Path(__file__)), audit_sha256=ci.digest(ROOT / 'bootstraptest/audit_runner.rb'),
                               child_launcher_sha256=ci.digest(ROOT / 'unittest/child-bin/ruby')),
                  reference=reference, wall_seconds=args.wall, rss_kb=args.rss_kb, rows=[], infrastructure_error=None)
    ci.save(args.output / 'result.json', result)
    os.environ['REF_RUBY_BIN'] = str(args.reference.resolve())
    try:
        for index, file in enumerate(manifest['files']):
            if index % manifest['shards'] != args.shard:
                continue
            row = dict(file=file, empty_input=file in manifest['empty_inputs'])
            parsed = {}
            with tempfile.TemporaryDirectory(prefix='mr-bootstrap-', dir='/tmp') as temp:
                private = Path(temp)
                env = ci.test_environment(private / 'environment', args.binary.resolve(), reference['version'])
                # Native Ruby owns its standard/default-gem path ordering.
                # Only the Mere child needs explicit installed library paths;
                # putting them in the native driver's RUBYLIB bypasses normal
                # default-gem activation and changes insertion precedence.
                stdlib = subprocess.check_output([str(args.reference.resolve()), '-e', 'print(([RbConfig::CONFIG.fetch("rubylibdir")] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))'], env=env, text=True).strip()
                libraries = [args.ruby_src.resolve() / 'lib']
                if os.environ.get('UNITTEST_REF_EXT_PATH'):
                    libraries.insert(0, Path(os.environ['UNITTEST_REF_EXT_PATH']))
                env['RUBYLIB'] = os.pathsep.join(map(str, libraries))
                for side, binary in [('reference', args.reference), ('mere', args.binary)]:
                    work = private / side; work.mkdir()
                    skips = work / 'skips'; skips.mkdir()
                    ledger = work / 'cases.jsonl'
                    launcher = work / 'target.sh'
                    child_libraries = env['RUBYLIB'] if side == 'reference' else str(args.ruby_src.resolve() / 'lib') + os.pathsep + stdlib
                    launcher.write_text('#!/bin/sh\nexport RUBYLIB=' + shlex.quote(child_libraries)
                                        + '\nexport UNITTEST_CHILD_RUBY=' + shlex.quote(str(binary.resolve()))
                                        + '\nexport PATH=' + shlex.quote(str(ROOT / 'unittest/child-bin')) + ':"$PATH"'
                                        + '\nexec ' + shlex.quote(str(binary.resolve())) + ' "$@"\n')
                    launcher.chmod(0o755)
                    side_env = dict(env, BOOTSTRAP_CASE_LOG=str(ledger), BOOTSTRAP_SKIP_DIR=str(skips), RUBY=str(launcher))
                    command = [str(args.reference.resolve()), str(ROOT / 'bootstraptest/audit_runner.rb'),
                               str(args.ruby_src.resolve() / 'bootstraptest/runner.rb'), '--ruby=' + str(launcher),
                               '-j1', '--timeout=60', str(args.ruby_src.resolve() / file)]
                    # The upstream runner owns assertion semantics and its
                    # assertion timeouts; the family supervisor also bounds
                    # escaped children and the whole source file.
                    log = work / 'driver.log'
                    execution = ci.supervise(command, side_env, log, args.rss_kb, args.wall)
                    summary, verdicts = parse_cases(ledger, execution)
                    row[side], parsed[side] = summary, verdicts
                    target = args.output / (Path(file).stem + '.' + side)
                    ci.sanitize_parts([log], target.with_suffix(target.suffix + '.out'))
                    if ledger.exists():
                        # Ledger entries contain ids, source digests and basename
                        # locations, never source text or inherited environment.
                        if ledger.stat().st_size <= CASE_BYTES:
                            target.with_suffix(target.suffix + '.cases.jsonl').write_bytes(ledger.read_bytes())
                row['counts'] = compare(parsed['reference'], parsed['mere'])
            result['rows'].append(row)
            ci.save(args.output / 'result.json', result)
            print(json.dumps(dict(file=file, counts=row['counts'], reference=row['reference']['state'], mere=row['mere']['state'])), flush=True)
    except Exception as error:
        result['infrastructure_error'] = type(error).__name__
        ci.save(args.output / 'result.json', result)
        raise


def merge(args):
    manifest = ci.load(args.plan)
    rows, seen, provenance, errors = [], set(), [], []
    for path in sorted(args.input.rglob('result.json')):
        result = ci.load(path)
        if (result['schema'] != 1 or result['manifest'] != manifest or result['policy'] != POLICY
                or type(result['shard']) is not int or not 0 <= result['shard'] < manifest['shards'] or result['shard'] in seen):
            raise ValueError('inconsistent or duplicate bootstrap shard')
        seen.add(result['shard'])
        if result['infrastructure_error']:
            errors.append(dict(shard=result['shard'], error=result['infrastructure_error']))
        provenance.append(dict(build=result['build'], reference=result['reference'], harness=result['harness'], wall_seconds=result['wall_seconds'], rss_kb=result['rss_kb']))
        for row in result['rows']:
            if row['file'] not in manifest['files'] or manifest['files'].index(row['file']) % manifest['shards'] != result['shard']:
                raise ValueError('unplanned bootstrap row')
            if any(type(row['counts'].get(key)) is not int or row['counts'][key] < 0 for key in ci.COUNTS):
                raise ValueError('invalid bootstrap counts')
            if row['counts']['tests'] != sum(row['counts'][key] for key in ci.COUNTS[1:]):
                raise ValueError('inconsistent bootstrap totals')
        rows.extend(result['rows'])
    if any(value != provenance[0] for value in provenance):
        raise ValueError('bootstrap provenance changed between shards')
    names = [row['file'] for row in rows]
    if len(names) != len(set(names)):
        raise ValueError('duplicate bootstrap file')
    missing = sorted(set(manifest['files']) - set(names))
    summary = dict(schema=1, policy=POLICY, manifest=manifest, received_shards=sorted(seen),
                   missing_files=missing, infrastructure_errors=errors,
                   reference_gaps=[row['file'] for row in rows if row['reference']['state'] != 'COMPLETE'
                                   and not (row['file'] in manifest.get('empty_inputs', [])
                                            and row['reference']['state'] == 'ZERO')],
                   empty_inputs=manifest.get('empty_inputs', []),
                   provenance=provenance[0] if provenance else None,
                   totals={key: sum(row['counts'][key] for row in rows) for key in ci.COUNTS},
                   reference_states=dict(Counter(row['reference']['state'] for row in rows)),
                   mere_states=dict(Counter(row['mere']['state'] for row in rows)), rows=rows)
    ci.save(args.output / 'summary.json', summary)
    lines = ['# CRuby bootstrap measurement', '', f'Policy: `{POLICY}`. Native upstream runner; explicit child skips remain SKIP.', '',
             '| File | Reference | Mere | MATCH | RED | BOTH | EXTRA |', '|---|---|---|---:|---:|---:|---:|']
    for row in sorted(rows, key=lambda row: row['file']):
        lines.append('| ' + ' | '.join([row['file'], row['reference']['state'], row['mere']['state']] + [str(row['counts'][key]) for key in ci.COUNTS[1:]]) + ' |')
    lines.extend(['', f'Missing files: {len(missing)}. Infrastructure errors: {len(errors)}.',
                  'Comment-only inputs (zero cases, not passing tests): ' + ', '.join(manifest.get('empty_inputs', [])), ''])
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'SUMMARY.md').write_text('\n'.join(lines))
    print(json.dumps({key: value for key, value in summary.items() if key not in ('rows', 'manifest', 'provenance')}))
    if missing or errors or summary['reference_gaps'] or seen != set(range(manifest['shards'])):
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('plan')
    p.add_argument('--ruby-src', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--shards', type=int, default=8)
    for name in ('source-ref', 'mere-ref', 'ruby-ref'):
        p.add_argument('--' + name, required=True)
    p.set_defaults(function=plan)
    p = sub.add_parser('run')
    for name in ('ruby-src', 'plan', 'build-info', 'reference-info', 'binary', 'reference', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--shard', type=int, required=True)
    p.add_argument('--wall', type=int, default=600)
    p.add_argument('--rss-kb', type=int, default=2097152)
    p.set_defaults(function=measure)
    p = sub.add_parser('merge')
    for name in ('plan', 'input', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.set_defaults(function=merge)
    args = parser.parse_args()
    args.function(args)


if __name__ == '__main__':
    main()
