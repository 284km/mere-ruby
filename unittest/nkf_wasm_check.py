#!/usr/bin/env python3
"""Compare portable NKF protocols through the actual shipped HTML host."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ruby', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
results = {'actual_html_host': True, 'wasm_sha256': hashlib.sha256((ROOT / 'docs/mere-ruby.wasm').read_bytes()).hexdigest(),
           'nkf_wasm_sha256': hashlib.sha256((ROOT / 'docs/nkf.wasm').read_bytes()).hexdigest(), 'cases': []}
# 628 uses Ruby threads, a native capability; the full native corpus runs it.
for number in [623, 624, 625, 626, 627, 629, 630, 631]:
    paths = list(ROOT.glob('corpus/' + str(number) + '_nkf*.rb'))
    assert len(paths) == 1, paths
    source = paths[0]
    commands = {'reference': [a.ruby, source], 'wasm': ['node', '--stack-size=8000', ROOT / 'docs/smoke.mjs', '--file', source]}
    outputs = {}
    for side, command in commands.items():
        result = subprocess.run(list(map(str, command)), capture_output=True, timeout=120)
        (a.output / (source.stem + '.' + side + '.stdout')).write_bytes(result.stdout)
        (a.output / (source.stem + '.' + side + '.stderr')).write_bytes(result.stderr)
        assert result.returncode == 0, (source.name, side, result.stderr[-2000:])
        outputs[side] = (result.stdout, result.stderr)
    match = outputs['reference'] == outputs['wasm']
    results['cases'].append({'file': source.name, 'match': match})
    (a.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert match, source.name
    print(source.name, 'passed', flush=True)
