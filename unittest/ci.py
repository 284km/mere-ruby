#!/usr/bin/env python3
"""Plan, bound and collect the CRuby test measurement used by CI."""
import argparse
import csv
import hashlib
import json
import os
import platform
import re
import selectors
import signal
import subprocess
import tempfile
import time
import uuid
from collections import Counter
from pathlib import Path

from process_family import MARKER, ProcessFamily
import transcript
import test_data

ROOT = Path(__file__).resolve().parent.parent
COUNTS = ("tests", "match", "red", "both", "extra")
COVERAGE = ("ref_state", "ref_exit", "ref_summary_tests", "ref_discovered_tests",
            "mere_state", "mere_exit", "mere_summary_tests", "mere_discovered_tests")
LOG_INPUT_CAP = 2 * 1024 * 1024
LOG_OUTPUT_CAP = 2 * 1024 * 1024
LOG_MASK_SECONDS = 10


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".new")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temp.replace(path)


def load(path):
    return json.loads(Path(path).read_text())


def plan(args):
    files = subprocess.check_output(
        ["sh", str(ROOT / "unittest/list.sh"), str(args.ruby_src), "--all"], text=True).splitlines()
    if not files or len(files) != len(set(files)) or not 1 <= args.shards <= 256:
        raise ValueError("empty/duplicate manifest or invalid shard count")
    if any(not re.fullmatch(r"[0-9a-f]{40}", getattr(args, key)) for key in ("source_ref", "mere_ref", "ruby_ref")):
        raise ValueError("measurement source refs must be full commit SHAs")
    manifest = dict(schema=1, source_ref=args.source_ref, mere_ref=args.mere_ref,
                    ruby_ref=args.ruby_ref, ruby_version=args.ruby_version,
                    shards=min(args.shards, len(files)), files=files)
    save(args.output / "manifest.json", manifest)
    (args.output / "files.txt").write_text("\n".join(files) + "\n")
    matrix = {"shard": list(range(manifest["shards"]))}
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as file:
            file.write("matrix=" + json.dumps(matrix, separators=(",", ":")) + "\n")
    print(f"Planned {len(files)} files in {manifest['shards']} shards")


def build_info(args):
    def revision(path):
        return subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
    value = dict(source_ref=revision(ROOT), mere_ref=revision(args.compiler),
                 binary_sha256=digest(ROOT / "mere-ruby"),
                 optimization=(ROOT / ".build_mode").read_text().strip(),
                 os=platform.system(), arch=platform.machine())
    if value["optimization"] != "O2":
        raise ValueError("measurement requires an O2 build")
    save(args.output, value)


def reference_info(args):
    save(args.output, dict(
        ruby_ref=subprocess.check_output(["git", "-C", str(args.ruby_src), "rev-parse", "HEAD"], text=True).strip(),
        version=subprocess.check_output([str(args.binary.resolve()), "-e", "print RUBY_VERSION"], text=True),
        binary_sha256=digest(args.binary), test_data=test_data.verify(args.ruby_src)))


def supervise(command, env, log, rss_kb, seconds):
    ProcessFamily.preflight()
    start = time.monotonic()
    peak = 0
    limit = None
    marker = uuid.uuid4().hex
    child_env = dict(env, **{MARKER: marker})
    with log.open("wb") as output:
        process = subprocess.Popen(command, env=child_env, stdout=output, stderr=output, start_new_session=True)
        family = ProcessFamily(process, marker)
        try:
            while process.poll() is None:
                peak = max(peak, family.sample())
                if peak > rss_kb:
                    limit = "MEMORY_LIMIT"
                    break
                if time.monotonic() - start > seconds:
                    limit = "WALL_LIMIT"
                    break
                time.sleep(0.1)
        finally:
            try:
                family.stop()
            finally:
                # Fail closed on monitor/cleanup errors. The shard aborts and
                # CI tears down its VM; no later file uses an uncertain runner.
                if process.poll() is None:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                process.wait(timeout=5)
    return dict(exit=process.returncode, peak_rss_kb=peak,
                seconds=round(time.monotonic() - start, 3), limit=limit)


def sanitize(source, target):
    # sed/perl buffer whole lines. Bound their input, including an unterminated
    # line, before starting them. Larger raw logs are never scanned to EOF.
    # Drain stdout in fixed chunks, keeping only the bounded prefix on disk.
    reasons = []
    with tempfile.TemporaryFile() as prefix, tempfile.TemporaryFile() as masked:
        with source.open("rb") as raw:
            remaining = LOG_INPUT_CAP
            while remaining:
                block = raw.read(min(65536, remaining))
                if not block:
                    break
                prefix.write(block)
                remaining -= len(block)
            if raw.read(1):
                reasons.append("input")
        prefix.seek(0)
        command = ["sh", "-c", '. "$1"; strip_noise', "mask", str(ROOT / "mspec/mask.sh")]
        process = subprocess.Popen(command, stdin=prefix, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   start_new_session=True,
                                   env=dict(PATH=os.environ.get("PATH", os.defpath),
                                            HOME=os.environ["HOME"], LC_ALL="C"))
        try:
            deadline = time.monotonic() + LOG_MASK_SECONDS
            remaining = LOG_OUTPUT_CAP + 1
            with process.stdout as pipe, selectors.DefaultSelector() as selector:
                selector.register(pipe, selectors.EVENT_READ)
                while True:
                    seconds = deadline - time.monotonic()
                    if seconds <= 0 or not selector.select(seconds):
                        raise subprocess.TimeoutExpired(command, LOG_MASK_SECONDS)
                    block = os.read(pipe.fileno(), 65536)
                    if not block:
                        break
                    if remaining:
                        kept = block[:remaining]
                        masked.write(kept)
                        remaining -= len(kept)
                status = process.wait(timeout=max(0, deadline - time.monotonic()))
        except BaseException:
            # This fixed mask pipeline only starts sed/perl in its own group.
            # It cannot leave an unbounded masking process after a timeout.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
            raise
        if status:
            raise subprocess.CalledProcessError(status, command)
        masked.seek(0)
        result = masked.read(LOG_OUTPUT_CAP + 1)
    if len(result) > LOG_OUTPUT_CAP:
        reasons.append("output")
        result = result[:LOG_OUTPUT_CAP]
    if reasons:
        # Do not leave a partial UTF-8 code point at the capped boundary.
        result = result.decode("utf-8", "ignore").encode()
        result += ("\n[diagnostic log truncated at 2 MiB (" + "/".join(reasons) + " limit)]\n").encode()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(result)


def sanitize_parts(sources, target):
    # Interrupted workers keep stdout/stderr separate. Bound concatenation
    # before feeding the already bounded mask, including the overflow byte.
    with tempfile.NamedTemporaryFile() as combined:
        remaining = LOG_INPUT_CAP + 1
        for source in sources:
            if not source.exists():
                continue
            with source.open('rb') as stream:
                while remaining:
                    block = stream.read(min(65536, remaining))
                    if not block:
                        break
                    combined.write(block)
                    remaining -= len(block)
        combined.flush()
        sanitize(Path(combined.name), target)


def recover_cases(work, index, file, phase, limit, records):
    reference, mere = transcript.recover(work, index, phase, limit)
    values = dict(zip(COVERAGE, transcript.coverage(reference) + transcript.coverage(mere)))
    for side, parsed in (('ref', reference), ('mere', mere)):
        values[side + '_summary'] = parsed['summary']
        values[side + '_parse_issues'] = parsed['issues']
    counts, tags = transcript.compare(reference, mere)
    values.update(counts)
    key = file[:-3].replace('/', '_')
    transcript.atomic(records / 'tags' / (key + '.txt'), tags)
    return values


def test_environment(private, binary, ruby_version):
    # Whole failure reports can pretty-print ENV as multiline hashes or pairs.
    # Formatting masks cannot reliably remove arbitrary inherited credentials.
    # Give both interpreters the same small environment and an empty home.
    home, temp = private / "home", private / "tmp"
    home.mkdir(parents=True)
    temp.mkdir()
    env = dict(PATH=os.environ.get("PATH", os.defpath), HOME=str(home), TMPDIR=str(temp),
               LANG="C", LC_ALL="C", REF_RUBY_BIN=os.environ["REF_RUBY_BIN"],
               REF_RUBY_VERSION=ruby_version, MR_BIN=str(binary),
               UNITTEST_SEED="1")
    # RubyGems defaults to <source>/tmp, inside Ruby's Cargo workspace.
    # Rust caches/config also need a fresh location when HOME is isolated.
    env.update(GEM_TEST_TMPDIR=str(temp / 'gems'), CARGO_HOME=str(private / 'cargo'))
    if os.environ.get('UNITTEST_RUST_BIN'):
        rust_bin = Path(os.environ['UNITTEST_RUST_BIN']).resolve()
        env['PATH'] = str(rust_bin) + os.pathsep + env['PATH']
        env['RUSTC'] = str(rust_bin / 'rustc')
    if os.environ.get("UNITTEST_REF_EXT_PATH"):
        env["UNITTEST_REF_EXT_PATH"] = os.environ["UNITTEST_REF_EXT_PATH"]
    return env


def rust_info():
    if not os.environ.get('UNITTEST_RUST_BIN'):
        return None
    directory = Path(os.environ['UNITTEST_RUST_BIN']).resolve()
    return {name: subprocess.check_output([str(directory / name), '--version'],
                                         env={'PATH': str(directory), 'HOME': '/nonexistent'},
                                         text=True, timeout=10).strip()
            for name in ('rustc', 'cargo')}


def run_shard(args):
    manifest = load(args.plan)
    build = load(args.build_info)
    reference = load(args.reference_info)
    binary = Path(os.environ.get("MR_BIN", ROOT / "mere-ruby")).resolve()
    if (build["source_ref"] != manifest["source_ref"] or build["mere_ref"] != manifest["mere_ref"]
            or build["binary_sha256"] != digest(binary) or build["optimization"] != "O2"):
        raise ValueError("build does not match this measurement plan")
    if (reference["ruby_ref"] != manifest["ruby_ref"] or reference["version"] != manifest["ruby_version"]
            or reference["binary_sha256"] != digest(os.environ["REF_RUBY_BIN"])):
        raise ValueError("reference does not match this measurement plan")
    if not 0 <= args.shard < manifest["shards"]:
        raise ValueError("shard index out of range")
    if args.wall <= 0 or args.rss_kb <= 0:
        raise ValueError("measurement bounds must be positive")
    data = test_data.verify(args.ruby_src) if reference.get('test_data') else None
    if data != reference.get('test_data'):
        raise ValueError('reference test data differs from build provenance')
    files = manifest["files"][args.shard::manifest["shards"]]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    result = dict(schema=1, shard=args.shard, source_ref=manifest["source_ref"],
                  mere_ref=manifest["mere_ref"], ruby_ref=manifest["ruby_ref"],
                  binary_sha256=build["binary_sha256"],
                  reference_sha256=digest(os.environ["REF_RUBY_BIN"]),
                  environment_policy="isolated-native-reference-v3",
                  test_data=data, rust_toolchain=rust_info(),
                  case_policy=transcript.POLICY,
                  bounds=dict(wall_per_side=args.wall, rss_family_kb=args.rss_kb,
                              process_scope="descendants-and-marker-v1",
                              diagnostic_input_bytes=LOG_INPUT_CAP, diagnostic_output_bytes=LOG_OUTPUT_CAP,
                              diagnostic_mask_seconds=LOG_MASK_SECONDS,
                              transcript_input_bytes=transcript.INPUT_BYTES,
                              transcript_line_bytes=transcript.LINE_BYTES,
                              transcript_name_bytes=transcript.NAME_BYTES,
                              transcript_case_bytes=transcript.CASE_BYTES,
                              transcript_cases=transcript.CASE_LIMIT,
                              transcript_snapshot_bytes=transcript.SNAPSHOT_BYTES,
                              transcript_encoding_bytes=transcript.ENCODING_BYTES,
                              transcript_seconds=transcript.PARSE_SECONDS),
                  rows=[dict(file=file, ref_state="NOT_RUN", mere_state="NOT_RUN") for file in files])
    save(output / "result.json", result)
    infra_error = False
    # Raw outputs stay outside the artifact. Only masked logs are uploaded.
    # macOS sun_path is limited to 104 bytes. A nested runner TMPDIR can
    # exceed that before the test adds its own socket filename.
    with tempfile.TemporaryDirectory(prefix="mru-", dir='/tmp') as private:
        private = Path(private)
        work = private / "work"
        raw = private / "raw"
        work.mkdir(); raw.mkdir()
        for index, file in enumerate(files):
            env = test_environment(private / f"environment-{index}", binary, manifest["ruby_version"])
            env.update(UNITTEST_WALL=str(args.wall), UNITTEST_RECORD_DIR=str(private / "records"),
                       UNITTEST_KEEP=str(raw))
            row = dict(file=file, **dict.fromkeys(COUNTS), ref_state="NOT_RUN", mere_state="NOT_RUN")
            log = private / "driver.log"
            supervised = False
            try:
                run = supervise(["sh", str(ROOT / "unittest/run.sh"), str(args.ruby_src.resolve()),
                                 "--one", str(work), str(index), file], env, log,
                                args.rss_kb, args.wall * 2 + 60)
                supervised = True
                row["execution"] = run
                coverage = work / f"{index}.coverage"
                counts = work / f"{index}.row"
                if coverage.exists() and counts.exists():
                    values = coverage.read_text().strip().split("\t")
                    if values[0] != file or len(values) != 9:
                        raise ValueError("invalid worker coverage row")
                    row.update(zip(COVERAGE, values[1:]))
                    for side in ("ref", "mere"):
                        if row[side + "_state"] == "INCOMPLETE" and row[side + "_exit"] == "142":
                            row[side + "_state"] = "WALL_LIMIT"
                    numbers = list(map(int, counts.read_text().split()))
                    if len(numbers) != 5 or numbers[0] != sum(numbers[1:]) or min(numbers) < 0:
                        raise ValueError("invalid worker test counts")
                    row.update(zip(COUNTS, numbers))
                elif run["limit"]:
                    phase = (work / f"{index}.phase").read_text().strip()
                    if phase not in ("ref", "mere"):
                        raise ValueError("invalid worker phase")
                    row.update(recover_cases(work, index, file, phase, run['limit'], private / 'records'))
                else:
                    raise ValueError("worker did not publish a result")
                for side in ('ref', 'mere'):
                    snapshot = work / f'{index}.{side}.json'
                    if snapshot.exists():
                        parsed = transcript.load(snapshot)
                        row[side + '_summary'] = parsed['summary']
                        row[side + '_parse_issues'] = parsed['issues']
            except Exception as error:
                row.update(ref_state="INFRA_ERROR", mere_state="INFRA_ERROR", error=type(error).__name__)
                infra_error = True
                if (work / f'{index}.ref.json').exists():
                    # Preserve a known reference result even when inspection
                    # or collection failed. The infrastructure flag still
                    # fails CI and the shard aborts on supervision errors.
                    try:
                        phase = (work / f'{index}.phase').read_text().strip()
                        if phase not in ('ref', 'mere'):
                            raise ValueError('invalid worker phase')
                        row.update(recover_cases(work, index, file, phase, 'INFRA_ERROR', private / 'records'))
                    except Exception as recovery_error:
                        row['recovery_error'] = type(recovery_error).__name__
            finally:
                key = file[:-3].replace("/", "_")
                try:
                    for side, name in (('ref', key + '.reference.out'), ('mere', key + '.out')):
                        stdout = work / f'{index}.{side}.stdout'
                        stderr = work / f'{index}.{side}.stderr'
                        if stdout.exists() or stderr.exists():
                            sanitize_parts([stdout, stderr], output / 'logs' / name)
                            if not supervised or run.get('limit'):
                                for suffix in ('stdout', 'stderr'):
                                    partial = work / f'{index}.{side}.{suffix}'
                                    if partial.exists():
                                        sanitize(partial, output / 'logs' / (key + '.partial.' + side + '.' + suffix))
                        elif (raw / name).exists():
                            sanitize(raw / name, output / 'logs' / name)
                    tag = private / "records/tags" / (key + ".txt")
                    if tag.exists():
                        sanitize(tag, output / "tags" / tag.name)
                    if log.exists():
                        sanitize(log, output / "logs" / (key + ".driver.out"))
                except Exception as error:
                    row["log_error"] = type(error).__name__
                    infra_error = True
                result["rows"][index] = row
                save(output / "result.json", result)
            print(f"{file}: {row['ref_state']} / {row['mere_state']}", flush=True)
            if not supervised:
                break
    result["infrastructure_error"] = infra_error
    save(output / "result.json", result)
    return int(infra_error)


def merge(args):
    manifest = load(args.plan)
    expected = manifest["files"]
    rows = {file: dict(file=file, ref_state="MISSING_SHARD", mere_state="MISSING_SHARD") for file in expected}
    seen = set()
    shards = set()
    binary_hashes = set()
    reference_hashes = set()
    bounds = set()
    environment_policies = set()
    case_policies = set()
    test_inputs = set()
    errors = []
    for path in sorted(args.input.rglob("result.json")):
        try:
            result = load(path)
            shard = result["shard"]
            if shard in shards or not 0 <= shard < manifest["shards"]:
                raise ValueError("duplicate or invalid shard")
            if any(result[key] != manifest[key] for key in ("source_ref", "mere_ref", "ruby_ref")):
                raise ValueError("shard provenance differs")
            wanted = expected[shard::manifest["shards"]]
            if [row["file"] for row in result["rows"]] != wanted:
                raise ValueError("shard file list differs")
            for row in result["rows"]:
                if row["file"] in seen:
                    raise ValueError("duplicate file")
                numbers = [row.get(key) for key in COUNTS]
                if not all(value is None for value in numbers):
                    if (not all(type(value) is int and value >= 0 for value in numbers)
                            or numbers[0] != sum(numbers[1:])):
                        raise ValueError("invalid case counts")
                if not isinstance(row["ref_state"], str) or not isinstance(row["mere_state"], str):
                    raise ValueError("invalid execution state")
            shards.add(shard)
            binary_hashes.add(result["binary_sha256"])
            reference_hashes.add(result["reference_sha256"])
            bounds.add(json.dumps(result["bounds"], sort_keys=True))
            environment_policies.add(result.get("environment_policy", "legacy-inherited"))
            case_policies.add(result.get('case_policy', 'legacy-awk'))
            test_inputs.add(json.dumps(dict(test_data=result.get('test_data'),
                                            rust_toolchain=result.get('rust_toolchain')), sort_keys=True))
            if result.get("infrastructure_error"):
                errors.append(f"Shard {shard} reported an infrastructure error")
            for row in result["rows"]:
                seen.add(row["file"])
                rows[row["file"]] = row
        except (ValueError, KeyError, TypeError) as error:
            errors.append(f"Invalid shard artifact: {type(error).__name__}")
    if len(binary_hashes) > 1 or len(reference_hashes) > 1:
        errors.append("Different interpreter binaries were measured")
    if len(bounds) > 1:
        errors.append("Different resource bounds were measured")
    if len(environment_policies) > 1:
        errors.append("Different environment policies were measured")
    if len(case_policies) > 1:
        errors.append('Different case parsing policies were measured')
    if len(test_inputs) > 1:
        errors.append('Different test data or Rust toolchains were measured')
    conditions = {}
    condition_path = ROOT / 'unittest/reference_conditions.tsv'
    if condition_path.exists():
        with condition_path.open() as stream:
            for item in csv.DictReader(stream, delimiter='\t'):
                if item['file'] in conditions or not item['condition'] or not item['needed']:
                    raise ValueError('invalid reference condition inventory')
                conditions[item['file']] = item
    zero_conditions = Counter()
    unclassified = []
    for file, row in rows.items():
        row.update(ref_zero_condition='-', ref_zero_needed='-')
        if row['ref_state'] == 'ZERO':
            condition = conditions.get(file)
            category = condition['condition'] if condition else 'UNCLASSIFIED'
            row.update(ref_zero_condition=category,
                       ref_zero_needed=condition['needed'] if condition else 'Investigate zero-test reference result')
            zero_conditions[category] += 1
            if condition is None:
                unclassified.append(file)
    totals = {key: sum(row.get(key) or 0 for row in rows.values()) for key in COUNTS}
    incomplete = sum(row["ref_state"] != "COMPLETE" or row["mere_state"] != "COMPLETE" for row in rows.values())
    missing = sum(row["ref_state"] in ("MISSING_SHARD", "NOT_RUN", "INFRA_ERROR")
                  and row["mere_state"] in ("MISSING_SHARD", "NOT_RUN", "INFRA_ERROR") for row in rows.values())
    # An interrupted file is attempted and remains visible, even if no case
    # counts survived. A missing shard or unattempted file is an infrastructure failure.
    failed = bool(errors or missing or len(shards) != manifest["shards"])
    summary = dict(source_ref=manifest["source_ref"], mere_ref=manifest["mere_ref"],
                   ruby_ref=manifest["ruby_ref"], expected_files=len(expected),
                   received_shards=len(shards), expected_shards=manifest["shards"],
                   incomplete_files=incomplete, missing_files=missing, totals=totals,
                   ref_states=dict(Counter(row["ref_state"] for row in rows.values())),
                   ref_zero_conditions=dict(zero_conditions), ref_zero_unclassified=unclassified,
                   mere_states=dict(Counter(row["mere_state"] for row in rows.values())),
                   binary_sha256=sorted(binary_hashes), reference_sha256=sorted(reference_hashes),
                   resource_bounds=[json.loads(value) for value in sorted(bounds)],
                   environment_policies=sorted(environment_policies),
                   case_policies=sorted(case_policies),
                   test_inputs=[json.loads(value) for value in sorted(test_inputs)],
                   infrastructure_errors=errors, measurement_collected=not failed)
    save(args.output / "summary.json", summary)
    args.output.mkdir(parents=True, exist_ok=True)
    fields = ["file", *COUNTS, *COVERAGE, 'ref_zero_condition', 'ref_zero_needed']
    with (args.output / "files.tsv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader(); writer.writerows(rows.values())
    lines = ["# CRuby test measurement", "",
             f"Files: {len(expected)} planned; {missing} missing; {incomplete} incomplete or zero-test.",
             f"Shards: {len(shards)}/{manifest['shards']} received.", "",
             "| named tests | MATCH | RED | BOTH | EXTRA |", "|---:|---:|---:|---:|---:|",
             "| " + " | ".join(str(totals[key]) for key in COUNTS) + " |", "",
             "Counts cover named tests only. Zero-test and incomplete files remain in files.tsv.",
             "Collected results do not mean Ruby conformance: RED, BOTH, EXTRA and file coverage need review.", "",
             f"mere-ruby source: `{manifest['source_ref']}`", f"Mere compiler: `{manifest['mere_ref']}`",
             f"Ruby tests: `{manifest['ruby_ref']}`", "", *errors, ""]
    if zero_conditions:
        lines.extend(['Reference ZERO files remain unmeasured; conditions do not mark them as passing.', '',
                      '| Reference ZERO condition | Files |', '|---|---:|',
                      *[f'| {key} | {value} |' for key, value in sorted(zero_conditions.items())], ''])
    (args.output / "SUMMARY.md").write_text("\n".join(lines))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as file:
            file.write("\n".join(lines))
    return int(failed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("plan")
    command.add_argument("--ruby-src", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    command.add_argument("--shards", type=int, default=64)
    for key in ("source-ref", "mere-ref", "ruby-ref", "ruby-version"):
        command.add_argument("--" + key, required=True)
    command.set_defaults(func=plan)
    command = commands.add_parser("build-info")
    command.add_argument("--compiler", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    command.set_defaults(func=build_info)
    command = commands.add_parser("reference-info")
    for key in ("ruby-src", "binary", "output"):
        command.add_argument("--" + key, type=Path, required=True)
    command.set_defaults(func=reference_info)
    command = commands.add_parser("run")
    for key in ("ruby-src", "plan", "build-info", "reference-info", "output"):
        command.add_argument("--" + key, type=Path, required=True)
    command.add_argument("--shard", type=int, required=True)
    command.add_argument("--wall", type=int, default=600)
    command.add_argument("--rss-kb", type=int, default=2097152)
    command.set_defaults(func=run_shard)
    command = commands.add_parser("merge")
    for key in ("plan", "input", "output"):
        command.add_argument("--" + key, type=Path, required=True)
    command.set_defaults(func=merge)
    args = parser.parse_args()
    return args.func(args) or 0


if __name__ == "__main__":
    raise SystemExit(main())
