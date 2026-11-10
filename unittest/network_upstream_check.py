#!/usr/bin/env python3
"""Run the pinned network selection and reject RED, EXTRA or incomplete records."""
import argparse
import csv
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent

def check(output):
    expected = (ROOT / 'unittest/network_files.txt').read_text().splitlines()
    with (output / 'COVERAGE.tsv').open() as stream:
        rows = list(csv.DictReader(stream, delimiter='\t'))
    assert [row['file'] for row in rows] == expected, 'network file selection changed or incomplete'
    for row in rows:
        assert row['ref_state'] == row['mere_state'] == 'COMPLETE', row
        assert row['ref_exit'] == row['mere_exit'] == '0', row
        counts = [int(row[key]) for key in ('ref_summary_tests', 'ref_discovered_tests', 'mere_summary_tests', 'mere_discovered_tests')]
        assert counts[0] > 0 and len(set(counts)) == 1, row
    assert sum(int(row['ref_discovered_tests']) for row in rows) == 450, 'reference discovery changed'
    match = re.search(r'^\| \*\*total\*\* \| (\d+) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \|$',
                      (output / 'STATUS.md').read_text(), re.M)
    assert match, 'network totals missing'
    total, same, red, both, extra = map(int, match.groups())
    assert total == same + red + both + extra == 450 and red == extra == 0, match.group(0)
    print(f'network upstream: {total} tests, {same} MATCH, {red} RED, {both} shared skips, {extra} EXTRA', flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', nargs='?', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    if not args.check_only:
        assert args.source, 'provide the pinned Ruby source tree'
        assert not args.output.exists(), 'use a fresh record directory'
        env = dict(os.environ, UNITTEST_WALL='120', UNITTEST_REF_EXT_PATH=str(ROOT / 'vendor/network/lib'),
                   UNITTEST_RECORD_DIR=str(args.output.resolve()), UNITTEST_KEEP=str(args.output.resolve() / 'logs'))
        files = (ROOT / 'unittest/network_files.txt').read_text().splitlines()
        subprocess.run(['sh', str(ROOT / 'unittest/run.sh'), str(args.source.resolve()), *files], env=env, check=True)
    check(args.output)
