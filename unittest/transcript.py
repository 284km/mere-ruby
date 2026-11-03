#!/usr/bin/env python3
"""Bounded Test::Unit transcript parsing and durable per-side case results."""
import argparse
import json
import re
import time
from pathlib import Path

POLICY = "encoding-aware-durable-cases-v2"
INPUT_BYTES = 64 * 1024 * 1024
LINE_BYTES = 64 * 1024
NAME_BYTES = 16 * 1024
CASE_BYTES = 4 * 1024 * 1024
CASE_LIMIT = 100000
SNAPSHOT_BYTES = 16 * 1024 * 1024
ENCODING_BYTES = 16 * 1024 * 1024
PARSE_SECONDS = 10
COUNTS = ("tests", "match", "red", "both", "extra")
STATES = {"COMPLETE", "ZERO", "INCOMPLETE", "COUNT_MISMATCH", "EXIT_ERROR", "IDENTITY_AMBIGUOUS",
          "REPORT_MISMATCH", "PARSE_LIMIT", "MEMORY_LIMIT", "WALL_LIMIT", "NOT_RUN"}
PROGRESS = re.compile(rb'^\[ *[0-9]+/[0-9]+\] (.*?)#(?=test|\")')
SUMMARY = re.compile(rb'^(\d+) tests, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips')
REPORT = re.compile(rb'^ *\d+\) (Failure|Error|Timeout|Skipped):\s*$')
FIELDS = ("tests", "assertions", "failures", "errors", "skips")
VERDICTS = {"Failure": "F", "Error": "E", "Timeout": "T", "Skipped": "S"}


def atomic(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_suffix(path.suffix + ".new")
    pending.write_text(text, encoding="utf-8")
    pending.replace(path)


def symbol(data, spelling=False):
    """Read only the Symbol.inspect token, never adjacent test diagnostics."""
    if not data.startswith(b'"'):
        found = re.match(rb'test[A-Za-z0-9_\x80-\xff]*[!?=]?', data)
        if not found:
            raise ValueError("invalid bare method name")
        return (found[0], found[0]) if spelling else found[0]
    output = bytearray()
    index = 1
    escapes = {ord(k): v for k, v in {'a': b'\a', 'b': b'\b', 't': b'\t', 'n': b'\n',
               'v': b'\v', 'f': b'\f', 'r': b'\r', 'e': b'\x1b', 's': b' ',
               '\\': b'\\', '"': b'"', '#': b'#'}.items()}
    while index < min(len(data), NAME_BYTES):
        byte = data[index]
        index += 1
        if byte == ord('"'):
            return (bytes(output), data[:index]) if spelling else bytes(output)
        if byte != ord('\\'):
            output.append(byte)
            continue
        if index >= len(data):
            break
        escape = data[index]
        index += 1
        if escape in escapes:
            output.extend(escapes[escape])
        elif escape == ord('x'):
            digits = data[index:index + 2]
            if not re.fullmatch(rb'[0-9a-fA-F]{2}', digits):
                raise ValueError("invalid byte escape")
            output.append(int(digits, 16))
            index += 2
        elif escape == ord('u'):
            if data[index:index + 1] == b'{':
                end = data.find(b'}', index + 1, index + 65)
                if end < 0:
                    raise ValueError("invalid Unicode escape")
                digits = data[index + 1:end].split()
                index = end + 1
            else:
                digits = [data[index:index + 4]]
                index += 4
            if not digits or any(not re.fullmatch(rb'[0-9a-fA-F]{1,6}', d) for d in digits):
                raise ValueError("invalid Unicode escape")
            for value in digits:
                output.extend(chr(int(value, 16)).encode('utf-8'))
        else:
            raise ValueError("unsupported inspected-name escape")
    raise ValueError("unterminated or oversized inspected name")


def identity(raw):
    # Escape separators and literal backslashes distinctly; keep names on one
    # TSV line, including binary symbols, without conflating them with escapes.
    output = []
    for char in raw.decode('utf-8', 'surrogateescape'):
        value = ord(char)
        if char == '\\':
            output.append('\\\\')
        elif value < 32 or value == 127:
            output.append('\\x%02x' % value)
        elif 128 <= value < 160:
            output.append('\\u%04x' % value)
        elif 0xdc80 <= value <= 0xdcff:
            output.append('\\x%02x' % (value - 0xdc00))
        else:
            output.append(char)
    return ''.join(output)


def lines(stream, issues):
    remaining = INPUT_BYTES
    start = True
    deadline = time.monotonic() + PARSE_SECONDS
    while remaining:
        if time.monotonic() >= deadline:
            issues.add('time_limit')
            return
        block = stream.readline(min(LINE_BYTES, remaining))
        if not block:
            return
        remaining -= len(block)
        if start:
            yield block.rstrip(b'\r\n')
        start = block.endswith(b'\n')
    if stream.read(1):
        issues.add('input_limit')


def case_identity(suite, suite_encoding, method, method_encoding):
    def component(raw, encoding):
        return identity(raw) + ('\\{' + encoding + '}' if not raw.isascii() else '')
    return component(suite, suite_encoding) + '#' + component(method, method_encoding)


def parse(path, exit_code, encodings=None):
    cases, aliases, bad = {}, {}, {}
    reports = dict.fromkeys(('F', 'E', 'T', 'S'), 0)
    issues = set()
    summary = None
    want = None
    used = 0

    typed = set()

    def add(raw, key=None):
        nonlocal used
        key = identity(raw) if key is None else key
        size = len(key.encode('utf-8'))
        if key not in cases:
            if size > NAME_BYTES or len(cases) >= CASE_LIMIT or used + size > CASE_BYTES:
                issues.add('case_limit')
                return None
            used += size
            cases[key] = 'X'
        aliases.setdefault(raw, set()).add(key)
        return key

    if encodings is not None and Path(encodings).exists():
        with Path(encodings).open('rb') as stream:
            if stream.readline(32) != b'case-encodings-v1\n':
                issues.add('encoding_metadata_invalid')
            remaining = ENCODING_BYTES
            deadline = time.monotonic() + PARSE_SECONDS
            while remaining:
                line = stream.readline(min(LINE_BYTES, remaining))
                if not line:
                    break
                remaining -= len(line)
                if time.monotonic() >= deadline:
                    issues.add('time_limit')
                    break
                try:
                    kind, suite_hex, suite_enc, method_hex, method_enc = line.rstrip(b'\n').split(b'\t')
                    if (not line.endswith(b'\n') or kind not in (b'N', b'F', b'E', b'T', b'S')
                            or not all(re.fullmatch(rb'[A-Za-z0-9_-]{1,64}', e) for e in (suite_enc, method_enc))
                            or not all(re.fullmatch(rb'(?:[0-9a-f]{2})+', h) for h in (suite_hex, method_hex))
                            or len(suite_hex) + len(method_hex) > NAME_BYTES * 2):
                        raise ValueError('invalid encoding record')
                    suite, method = bytes.fromhex(suite_hex.decode()), bytes.fromhex(method_hex.decode())
                    raw = suite + b'#' + method
                    key = add(raw, case_identity(suite, suite_enc.decode(), method, method_enc.decode()))
                    typed.add(raw)
                    if key is not None and kind != b'N':
                        verdict = kind.decode()
                        bad[key] = verdict
                        reports[verdict] += 1
                except ValueError:
                    issues.add('encoding_metadata_invalid')
                    break
            if not remaining and stream.read(1):
                issues.add('encoding_metadata_limit')

    if Path(path).exists():
        with Path(path).open('rb') as stream:
            for line in lines(stream, issues):
                progress = PROGRESS.match(line)
                if progress:
                    summary = None  # A summary from an earlier nested run is not final.
                    try:
                        method, token = symbol(line[progress.end():], spelling=True)
                        raw = progress[1] + b'#' + method
                        if raw not in typed:
                            if raw.isascii():
                                add(raw)
                            else:
                                issues.add('encoding_metadata_missing')
                                add(raw, identity(progress[1]) + '#\\{unknown:' + token.hex() + '}')
                    except (ValueError, UnicodeError):
                        issues.add('name_parse')
                    want = None
                    continue
                found = SUMMARY.match(line)
                if found:
                    if any(len(value) > 12 for value in found.groups()):
                        issues.add('summary_limit')
                    else:
                        summary = dict(zip(FIELDS, map(int, found.groups())))
                    want = None
                    continue
                report = REPORT.match(line)
                if report:
                    want = VERDICTS[report[1].decode()]
                    continue
                if want:
                    raw = line[:-1] if line.endswith(b':') else line
                    keys = aliases.get(raw)
                    if keys is None and b' [' in line:
                        raw = line[:line.rfind(b' [')]
                        keys = aliases.get(raw)
                    if raw in typed:
                        # Exact error callbacks already attributed this report,
                        # including names whose human-readable headers collide.
                        want = None
                        continue
                    key = next(iter(keys)) if keys and len(keys) == 1 else None
                    if key is None and line.endswith(b':') and re.match(rb'^.*?#test', raw) and raw.isascii():
                        key = add(raw)
                    if key is not None:
                        bad[key] = want
                        reports[want] += 1
                        want = None
    state = 'INCOMPLETE'
    if issues:
        state = 'IDENTITY_AMBIGUOUS' if issues == {'encoding_metadata_missing'} else 'PARSE_LIMIT'
    elif summary is not None and exit_code is not None:
        if summary['tests'] == 0:
            state = 'ZERO'
        elif summary['tests'] != len(cases):
            state = 'COUNT_MISMATCH'
        elif exit_code != (summary['failures'] + summary['errors']) % 256:
            state = 'EXIT_ERROR'
        elif (reports['F'], reports['E'] + reports['T'], reports['S']) != (
                summary['failures'], summary['errors'], summary['skips']):
            state = 'REPORT_MISMATCH'
        else:
            state = 'COMPLETE'
    cases = {key: bad.get(key, '.' if state == 'COMPLETE' else 'X') for key in cases}
    return dict(schema=1, policy=POLICY, state=state, exit=exit_code, summary=summary,
                discovered=len(cases), issues=sorted(issues), cases=cases)


def save(path, result):
    data = json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n'
    if len(data.encode('utf-8')) > SNAPSHOT_BYTES:
        raise ValueError('case snapshot is too large')
    atomic(path, data)


def load(path):
    with Path(path).open('rb') as stream:
        data = stream.read(SNAPSHOT_BYTES + 1)
    if len(data) > SNAPSHOT_BYTES:
        raise ValueError('case snapshot is too large')
    result = json.loads(data)
    cases = result['cases']
    if (result['schema'] != 1 or result['policy'] != POLICY or result['state'] not in STATES
            or not isinstance(cases, dict) or len(cases) > CASE_LIMIT
            or result['discovered'] != len(cases)
            or any(not isinstance(k, str) or not isinstance(v, str) or v not in {'.', 'F', 'E', 'T', 'S', 'X'}
                   or len(k.encode('utf-8')) > NAME_BYTES or any(c in k for c in '\t\r\n\0') for k, v in cases.items())
            or sum(len(k.encode('utf-8')) for k in cases) > CASE_BYTES):
        raise ValueError('invalid case snapshot')
    summary, code = result['summary'], result['exit']
    if (code is not None and type(code) is not int) or (summary is not None and (
            not isinstance(summary, dict) or set(summary) != set(FIELDS)
            or any(type(v) is not int or v < 0 or v >= 10**12 for v in summary.values()))):
        raise ValueError('invalid case summary')
    if result['state'] == 'COMPLETE':
        if (not summary or not cases or summary['tests'] != len(cases) or result['issues']
                or code != (summary['failures'] + summary['errors']) % 256):
            raise ValueError('inconsistent complete result')
    elif '.' in cases.values():
        raise ValueError('unfinalized cases cannot pass')
    return result


def coverage(result):
    return [result['state'], str(result['exit']) if result['exit'] is not None else '-',
            str(result['summary']['tests']) if result['summary'] is not None else '-',
            str(result['discovered'])]


def compare(reference, mere):
    counts = dict.fromkeys(COUNTS, 0)
    tags = []
    for case in sorted(reference['cases'].keys() | mere['cases'].keys()):
        rp = reference['cases'].get(case) == '.'
        mp = mere['cases'].get(case) == '.'
        verdict = 'match' if rp and mp else 'red' if rp else 'extra' if mp else 'both'
        counts['tests'] += 1
        counts[verdict] += 1
        if verdict == 'red':
            tags.append(case + '\t' + mere['cases'].get(case, 'ABSENT') + '\n')
    return counts, ''.join(tags)


def recover(work, index, phase, limit):
    pair = []
    for side in ('ref', 'mere'):
        snapshot = work / f'{index}.{side}.json'
        exit_path = work / f'{index}.{side}.exit'
        if side == 'ref' and phase == 'mere' and not snapshot.exists() and not exit_path.exists():
            raise ValueError('mere phase has no durable reference result')
        if snapshot.exists():
            result = load(snapshot)
        else:
            code = int(exit_path.read_text()) if exit_path.exists() else None
            result = parse(work / f'{index}.{side}.stdout', code, work / f'{index}.{side}.encodings')
            if code is None:
                result['state'] = limit if side == phase else 'NOT_RUN'
        pair.append(result)
    return pair


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    command = commands.add_parser('parse')
    command.add_argument('stdout', type=Path)
    command.add_argument('exit_code', type=int)
    command.add_argument('output', type=Path)
    command.add_argument('--encodings', type=Path)
    command = commands.add_parser('compare')
    command.add_argument('reference', type=Path)
    command.add_argument('mere', type=Path)
    command.add_argument('--file', required=True)
    command.add_argument('output', type=Path)
    command.add_argument('tag', type=Path)
    args = parser.parse_args()
    if args.command == 'parse':
        save(args.output, parse(args.stdout, args.exit_code, args.encodings))
    else:
        reference, mere = load(args.reference), load(args.mere)
        counts, tags = compare(reference, mere)
        atomic(args.tag, tags)
        atomic(args.output.with_suffix('.coverage'), '\t'.join([args.file, *coverage(reference), *coverage(mere)]) + '\n')
        atomic(args.output.with_suffix('.row'), ' '.join(str(counts[key]) for key in COUNTS) + '\n')


if __name__ == '__main__':
    main()
