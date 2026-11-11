#!/usr/bin/env python3
"""Require the unchanged commit-email tool witness to complete and match Ruby."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tooltest'))
from measure import run_side, ci

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source', type=Path, required=True)
p.add_argument('--ruby', type=Path, required=True)
p.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
os.environ['REF_RUBY_BIN'] = str(a.ruby.resolve())
results = {}
for side, binary in [('reference', a.ruby), ('native', a.binary)]:
    result, stdout, stderr = run_side(a.source.resolve(), a.ruby.resolve(), binary.resolve(),
        a.output / side, {'file': 'tool/test/test_commit_email.rb'}, '4.0.9', 60, 2097152)
    results[side] = result
    ci.sanitize_parts([stdout, stderr], a.output / (side + '.out'))
    print(side, result['state'], result['summary'], flush=True)
    (a.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert result['state'] == 'COMPLETE' and result['exit'] == 0 and not result['issues']
    assert result['summary'] == dict(tests=1, assertions=4, failures=0, errors=0, skips=0)
assert results['reference']['cases'] == results['native']['cases']
results['sha256'] = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in [a.binary, a.source / 'tool/test/test_commit_email.rb']}
(a.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
