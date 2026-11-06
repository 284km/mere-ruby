#!/usr/bin/env python3
"""Measure tool/test on each subject through the unmodified upstream runner."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'unittest'))
import ci
import transcript

POLICY = 'native-tool-durable-cases-v1'


def unrun():
    return dict(schema=1, policy=transcript.POLICY, state='NOT_RUN', exit=None,
                summary=None, discovered=0, issues=[], cases={})


def empty_row(file):
    row = dict(file=file, reference=unrun(), mere=unrun())
    row['counts'], _ = transcript.compare(row['reference'], row['mere'])
    return row


def inputs(source):
    return {str(p.relative_to(source)): ci.digest(p)
            for p in sorted((source / 'tool/test').rglob('*.rb'))}


def run_side(source, reference, binary, private, output, version, wall, rss_kb, persist=None):
    private.mkdir(parents=True)
    # Upstream --ruby splits on spaces rather than parsing shell quoting.
    # The private directory is allocated under /tmp, so a launcher there can
    # select a real interpreter whose original path contains spaces.
    child = binary
    if any(char.isspace() for char in str(binary)):
        child = private.resolve() / 'ruby'
        if any(char.isspace() for char in str(child)):
            raise ValueError('tool private directory must have a whitespace-free path')
        child.symlink_to(binary)
    env = ci.test_environment(private / 'environment', binary, version)
    libraries = [str(source / 'tool/lib'), str(source / 'test')]
    if binary == reference:
        extension = os.environ.get('UNITTEST_REF_EXT_PATH')
        if extension:
            libraries.insert(0, extension)
    else:
        libraries.append(str(ROOT / 'unittest/shim'))
        # Only the Mere side needs explicit pure Ruby standard/default gems.
        libraries += subprocess.check_output([
            str(reference), '-e',
            'puts RbConfig::CONFIG.fetch("rubylibdir"); '
            'puts Dir[File.join(Gem.default_dir,"gems","*","lib")].sort'
        ], text=True, timeout=10).splitlines()
    env.update(RUBYLIB=os.pathsep.join(libraries), RUBY=str(child),
               UNITTEST_CHILD_RUBY=str(binary),
               UNITTEST_CASE_ENCODINGS=str(private / 'encodings'))
    env['PATH'] = str(ROOT / 'unittest/child-bin') + os.pathsep + env['PATH']
    stdout, stderr = private / 'stdout', private / 'stderr'
    command = [str(binary), '-I', str(source / 'tool/lib'), '-r', 'test/unit',
               '-r', str(ROOT / 'unittest/case_encodings.rb'),
               str(source / 'tool/test/runner.rb'), '--ruby', str(child),
               '-v', '--show-skip', '--seed=1', str(source / output['file'])]
    # Redirection keeps warnings from joining a case name on stdout. The
    # shell execs the selected subject; neither framework runs on a host Ruby.
    launch = ['sh', '-c', 'out=$1; err=$2; shift 2; exec "$@" >"$out" 2>"$err"',
              'tool-test', str(stdout), str(stderr), *command]
    previous = Path.cwd()
    execution = dict(exit=None, limit=None)
    try:
        os.chdir(private)
        execution = ci.supervise(launch, env, private / 'driver', rss_kb, wall)
    finally:
        os.chdir(previous)
        parsed = transcript.parse(stdout, execution['exit'], private / 'encodings')
        if execution['limit']:
            parsed['state'] = execution['limit']
            parsed['cases'] = {key: ('X' if value == '.' else value)
                               for key, value in parsed['cases'].items()}
        parsed['execution'] = execution
        if persist:
            persist(parsed, stdout, stderr)
    return parsed, stdout, stderr


def measure(args):
    source, reference, binary = args.ruby_src.resolve(), args.reference.resolve(), args.binary.resolve()
    manifest, suites = ci.load(args.plan), ci.load(args.suites)
    build, ref = ci.load(args.build_info), ci.load(args.reference_info)
    revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if args.wall <= 0 or args.rss_kb <= 0 or not 1 <= args.shards <= 256 or not 0 <= args.shard < args.shards:
        raise ValueError('invalid tool measurement bounds or shard')
    if (revision != suites['ruby_ref'] or revision != manifest['ruby_ref']
            or revision != ref['ruby_ref'] or ref['version'] != manifest['ruby_version']):
        raise ValueError('tool reference source mismatch')
    if (build['source_ref'] != manifest['source_ref'] or build['mere_ref'] != manifest['mere_ref']
            or build['optimization'] != 'O2' or ci.digest(binary) != build['binary_sha256']
            or ci.digest(reference) != ref['binary_sha256']):
        raise ValueError('tool measurement binary provenance mismatch')
    inventory = next(s for s in suites['suites'] if s['suite'] == 'tool/test')
    actual = inputs(source)
    candidates = sorted(path for path in actual
                        if Path(path).name.startswith('test_') or Path(path).name.endswith('_test.rb'))
    if (inventory['runner'] != 'tool/test/runner.rb'
            or inventory['runner_sha256'] != actual['tool/test/runner.rb']
            or len(inventory['files']) != inventory['candidate_files']
            or len({i['path'] for i in inventory['files']}) != inventory['candidate_files']
            or sorted(i['path'] for i in inventory['files']) != candidates
            or any(actual.get(i['path']) != i['sha256'] for i in inventory['files'])):
        raise ValueError('tool input inventory mismatch')
    files = sorted(i['path'] for i in inventory['files'])
    result = dict(schema=1, policy=POLICY, case_policy=transcript.POLICY,
                  environment_policy='per-side-path-ruby-v6', manifest=manifest,
                  build=build, reference=ref, shard=args.shard, shards=args.shards,
                  files=files, inputs=actual, wall_seconds=args.wall, rss_kb=args.rss_kb,
                  harness={p: ci.digest(ROOT / p) for p in [
                      'tooltest/measure.py', 'unittest/transcript.py', 'unittest/ci.py',
                      'unittest/process_family.py', 'unittest/child-bin/ruby', 'unittest/case_encodings.rb']},
                  rows=[empty_row(file) for file in files[args.shard::args.shards]],
                  completed=False, infrastructure_error=None)
    args.output.mkdir(parents=True, exist_ok=True)
    ci.save(args.output / 'result.json', result)
    os.environ['REF_RUBY_BIN'] = str(reference)
    try:
        for row in result['rows']:
            file = row['file']
            with tempfile.TemporaryDirectory(prefix='mr-tool-', dir='/tmp') as temp:
                private = Path(temp)
                for side, subject in [('reference', reference), ('mere', binary)]:
                    def persist(parsed, stdout, stderr):
                        row[side] = parsed
                        row['counts'], _ = transcript.compare(row['reference'], row['mere'])
                        # Commit the cases before processing diagnostic output.
                        ci.save(args.output / 'result.json', result)
                        key = file.replace('/', '_')[:-3] + '.' + side
                        transcript.save(args.output / 'cases' / (key + '.json'), parsed)
                        ci.sanitize_parts([stdout, stderr], args.output / 'logs' / (key + '.out'))
                    run_side(source, reference, subject, private / side,
                             row, ref['version'], args.wall, args.rss_kb, persist)
            row['counts'], tags = transcript.compare(row['reference'], row['mere'])
            (args.output / 'cases' / (file.replace('/', '_')[:-3] + '.tags')).write_text(tags)
            ci.save(args.output / 'result.json', result)
            print(file, row['reference']['state'], row['mere']['state'], row['counts'], flush=True)
    except BaseException as error:
        result['infrastructure_error'] = type(error).__name__
        ci.save(args.output / 'result.json', result)
        raise
    result['completed'] = True
    ci.save(args.output / 'result.json', result)
    if any(row['reference']['state'] != 'COMPLETE' for row in result['rows']):
        raise SystemExit(1)


def collect(args):
    reports = [ci.load(p) for p in sorted(args.input.rglob('result.json'))]
    if not reports:
        raise ValueError('no tool measurement shards')
    first = reports[0]
    keys = ['schema', 'policy', 'case_policy', 'environment_policy', 'manifest', 'build',
            'reference', 'shards', 'files', 'inputs', 'wall_seconds', 'rss_kb', 'harness']
    seen, rows, errors, interrupted = set(), {}, [], []
    for report in reports:
        if (any(report[k] != first[k] for k in keys)
                or report['shard'] in seen or not 0 <= report['shard'] < first['shards']):
            raise ValueError('tool shard provenance mismatch')
        seen.add(report['shard'])
        if not report['completed'] or any(row[side]['state'] == 'NOT_RUN'
                                         for row in report['rows'] for side in ('reference', 'mere')):
            interrupted.append(report['shard'])
        if report['infrastructure_error']:
            errors.append(dict(shard=report['shard'], error=report['infrastructure_error']))
        if ([r['file'] for r in report['rows']] != first['files'][report['shard']::first['shards']]):
            raise ValueError('tool shard input mismatch')
        for row in report['rows']:
            counts, _ = transcript.compare(row['reference'], row['mere'])
            if counts != row['counts']:
                raise ValueError('tool case counts differ')
        rows.update((row['file'], row) for row in report['rows'])
    missing = sorted(set(range(first['shards'])) - seen)
    rows = [rows.get(file, empty_row(file)) for file in first['files']]
    result = {k: first[k] for k in keys}
    result.update(rows=rows, received_shards=sorted(seen), missing_shards=missing,
                  interrupted_shards=sorted(interrupted), infrastructure_errors=errors,
                  totals={k: sum(r['counts'][k] for r in rows) for k in ci.COUNTS},
                  reference_gaps=[r['file'] for r in rows if r['reference']['state'] != 'COMPLETE'])
    args.output.mkdir(parents=True, exist_ok=True)
    ci.save(args.output / 'summary.json', result)
    text = ['# CRuby tool test measurement', '', '| File | Reference | Mere | MATCH | RED | BOTH | EXTRA |',
            '|---|---|---|---:|---:|---:|---:|']
    for row in result['rows']:
        text.append('| ' + ' | '.join([row['file'], row['reference']['state'], row['mere']['state']]
                                     + [str(row['counts'][k]) for k in ci.COUNTS[1:]]) + ' |')
    (args.output / 'SUMMARY.md').write_text('\n'.join(text) + '\n')
    print(json.dumps(result['totals']))
    if result['reference_gaps'] or missing or errors or interrupted:
        raise SystemExit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    measure_parser = sub.add_parser('measure')
    for name in ['ruby-src', 'plan', 'suites', 'build-info', 'reference-info', 'binary', 'reference', 'output']:
        measure_parser.add_argument('--' + name, type=Path, required=True)
    measure_parser.add_argument('--shard', type=int, required=True)
    measure_parser.add_argument('--shards', type=int, default=4)
    measure_parser.add_argument('--wall', type=int, default=600)
    measure_parser.add_argument('--rss-kb', type=int, default=2097152)
    measure_parser.set_defaults(function=measure)
    collect_parser = sub.add_parser('collect')
    collect_parser.add_argument('--input', type=Path, required=True)
    collect_parser.add_argument('--output', type=Path, required=True)
    collect_parser.set_defaults(function=collect)
    args = parser.parse_args()
    args.function(args)
