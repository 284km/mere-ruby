#!/usr/bin/env python3
"""Exercise NKF byte boundaries, allocation recovery and cleanup under ASan/UBSan."""
import argparse
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
f = json.loads(subprocess.check_output([a.ruby, ROOT / 'unittest/nkf_fixtures.rb'], timeout=30))
assert f['gem'] == '0.2.0' and len(f['rows']) == 1482
policy = json.loads((ROOT / 'unittest/nkf_malformed_policy.json').read_text())
def cbytes(value):
    if isinstance(value, str):
        value = value.encode()
    return '"' + ''.join('\\%03o' % x for x in value) + '"'
lines = ['static const check cases[] = {']
for option, data, output, encoding, *error in f['rows']:
    if data == policy['input'] and option in policy['outputs']:
        output = policy['outputs'][option]
    lines.append('{%s,(const unsigned char*)%s,%d,(const unsigned char*)%s,%d,%d,%s},' % (
        cbytes(option), cbytes(data), len(data), cbytes(output or []), len(output or []),
        int(output is None), cbytes(encoding)))
lines.append('};')
(a.output / 'nkf_cases.h').write_text('\n'.join(lines) + '\n')
commands = [
    ['clang', '-O1', '-g', '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
     '-fno-omit-frame-pointer', '-pthread', '-I', a.output.resolve(),
     ROOT / 'unittest/nkf_boundary.c', '-o', a.output.resolve() / 'boundary'],
    [a.output.resolve() / 'boundary'],
]
for name, command in zip(['compile', 'sanitizers'], commands):
    result = subprocess.run(list(map(str, command)), capture_output=True, timeout=120)
    (a.output / (name + '.out')).write_bytes(result.stdout + result.stderr)
    assert result.returncode == 0, (name, result.returncode, (result.stdout + result.stderr)[-3000:])
    print(name, 'passed', flush=True)
