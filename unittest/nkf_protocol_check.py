#!/usr/bin/env python3
"""Compare every NKF corpus witness under forced GC and both cache controls."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ruby', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
p.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
report = {'binary_sha256': hashlib.sha256(a.binary.read_bytes()).hexdigest(), 'cases': []}
for number in range(623, 632):
    paths = list(ROOT.glob('corpus/' + str(number) + '_nkf*.rb'))
    assert len(paths) == 1, paths
    source = paths[0]
    reference = subprocess.run([a.ruby, str(source)], capture_output=True, timeout=90)
    assert reference.returncode == 0, (source.name, reference.stderr[-2000:])
    for mode, settings in [('normal', {}), ('hash-off', {'MERE_RUBY_NO_HASH_INDEX': '1'}),
                           ('mro-off', {'MERE_RUBY_NO_MRO_CACHE': '1'})]:
        result = subprocess.run([str(a.binary.resolve()), str(source)], capture_output=True, timeout=90,
                                env=dict(os.environ, MERE_RUBY_GC_STRESS='100', **settings))
        match = result.returncode == 0 and (result.stdout, result.stderr) == (reference.stdout, reference.stderr)
        report['cases'].append({'file': source.name, 'mode': mode, 'match': match})
        (a.output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
        if not match:
            (a.output / (source.stem + '.' + mode + '.actual')).write_bytes(result.stdout + result.stderr)
            (a.output / (source.stem + '.reference')).write_bytes(reference.stdout + reference.stderr)
        assert match, (source.name, mode)
    print(source.name, 'three GC100 modes passed', flush=True)
