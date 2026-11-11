#!/usr/bin/env python3
"""Require complete upstream Unicode coverage in the collected CI shards."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('input', type=Path)
args = parser.parse_args()
file = 'ruby/enc/test_case_comprehensive.rb'
found = []
for path in args.input.rglob('result.json'):
    shard = json.loads(path.read_text())
    found.extend((shard, row) for row in shard['rows'] if row['file'] == file)
assert len(found) == 1, ('Unicode measurement missing or duplicated', len(found))
shard, row = found[0]
assert shard['bounds']['wall_per_side'] == 600, shard['bounds']
assert shard['bounds']['rss_family_kb'] == 2097152, shard['bounds']
assert row['tests'] == row['match'] == 422, row
assert row['red'] == row['both'] == row['extra'] == 0, row
for side, assertions in [('ref', 2901791), ('mere', 2901771)]:
    assert row[side + '_state'] == 'COMPLETE' and int(row[side + '_exit']) == 0, row
    summary = row[side + '_summary']
    assert summary['tests'] == 422 and summary['assertions'] == assertions, summary
    assert summary['failures'] == summary['errors'] == summary['skips'] == 0, summary
    assert not row[side + '_parse_issues'], row[side + '_parse_issues']
    print(side, summary, flush=True)
print('Upstream Unicode completed under the original bounds', flush=True)
