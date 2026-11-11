#!/usr/bin/env python3
"""Compare the actual NKF API with ruby/nkf 0.2.0, including shipped Wasm.

The all-byte malformed input has a recorded local bounds policy: its unsafe
reference outputs are never counted as byte compatibility successes.
"""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ruby', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
p.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
p.add_argument('--wasm', action='store_true')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)

def run(name, command, timeout=120):
    r = subprocess.run(list(map(str, command)), capture_output=True, timeout=timeout)
    (a.output / (name + '.stdout')).write_bytes(r.stdout)
    (a.output / (name + '.stderr')).write_bytes(r.stderr)
    assert r.returncode == 0, (name, r.returncode, r.stderr[-2000:])
    return r.stdout.decode()

fixture = json.loads(run('reference', [a.ruby, ROOT / 'unittest/nkf_fixtures.rb']))
assert fixture['gem'] == '0.2.0', fixture['gem']
rows, guesses = fixture['rows'], fixture['guesses']
assert len(rows) == 1482 and len(guesses) == 19
inputs = [row[0] for row in guesses]
options = [row[0] for row in rows[::len(inputs)]]
assert [[o, b] for o in options for b in inputs] == [[r[0], r[1]] for r in rows]
# Compact input declarations matter in the interpreter too: each source byte
# should not be parsed into 78 identical ASTs just to run an option matrix.
source = '''require "nkf"
options = OPTIONS
inputs = INPUTS.map { |b| b.pack("C*") }
options.each do |option|
  inputs.each do |input|
    begin
      result = NKF.nkf(option, input)
      p [result.bytes, result.encoding.name]
    rescue => e
      p ["error", e.class.name, e.message]
    end
  end
end
inputs.each { |input| p ["guess", NKF.guess(input).name] }
'''.replace('OPTIONS', json.dumps(options)).replace('INPUTS', json.dumps(inputs))
program = a.output.resolve() / 'matrix.rb'
program.write_text(source)
policy = json.loads((ROOT / 'unittest/nkf_malformed_policy.json').read_text())
expected, policy_count = [], 0
for option, input_bytes, output, encoding, *error in rows:
    if input_bytes == policy['input'] and option in policy['outputs']:
        expected.append([policy['outputs'][option], encoding])
        policy_count += 1
    else:
        expected.append([output, encoding] if output is not None else ['error', encoding, error[0]])
expected += [['guess', row[1]] for row in guesses]
assert policy_count == 71
commands = {'native': [a.binary.resolve(), program]}
if a.wasm:
    commands['wasm'] = ['node', '--stack-size=8000', ROOT / 'docs/smoke.mjs', '--file', program]
results = {}
for name, command in commands.items():
    lines = run(name, command).splitlines()
    actual = [ast.literal_eval(line) for line in lines]
    assert len(actual) == len(expected), (name, len(actual), len(expected))
    differences = [i for i, (x, y) in enumerate(zip(actual, expected)) if x != y]
    results[name] = {'cases': len(actual), 'differences': differences,
                     'conversion_reference_matches': 1411, 'malformed_policy_cases': 71,
                     'guess_reference_matches': 19}
    (a.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert not differences, (name, differences[:10])
    print(name, '1411 reference conversions, 71 explicit safety-policy cases, 19 guesses passed', flush=True)
results['provenance'] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in [ROOT / 'tools/nkf_engine.c', ROOT / 'vendor/nkf/nkf-utf8/nkf.c',
                                      ROOT / 'unittest/nkf_malformed_policy.json']}
(a.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
