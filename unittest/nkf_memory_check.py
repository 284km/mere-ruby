#!/usr/bin/env python3
"""Bound repeated NKF output ownership and large binary conversions in the VM."""
import argparse
import json
import os
from pathlib import Path
import sys
sys.dont_write_bytecode = True
from ci import supervise

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
source = '''require 'nkf'
def convert_many(count)
  source = "あ" * 10000
  count.times do
    result = NKF.nkf('-w32L', source)
    raise 'output length changed' unless result.bytesize == 40000
    raise 'encoding changed' unless result.encoding == Encoding::UTF_32LE
    raise 'guess changed' unless NKF.guess(source) == Encoding::UTF_8
    begin
      NKF.nkf('', Object.new)
    rescue ArgumentError
    end
  end
end
convert_many(ARGV[0].to_i)
GC.start
payload = "a\\0b" * (1024 * 1024)
converted = NKF.nkf('-w', payload)
raise 'large binary bytes changed' unless converted == payload
raise 'result aliased input' if converted.equal?(payload)
puts 'NKF output ownership and large binary conversion preserved'
'''
script = a.output.resolve() / 'lifetimes.rb'
script.write_text(source)
results = {}
for count in [20, 200]:
    log = a.output / (str(count) + '.out')
    result = supervise([str(a.binary.resolve()), str(script), str(count)], dict(os.environ), log, 2097152, 120)
    results[str(count)] = result
    (a.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert result['exit'] == 0 and result['limit'] is None, (count, result, log.read_text()[-2000:])
    assert 'NKF output ownership and large binary conversion preserved' in log.read_text()
    print(count, 'lifetimes and 3 MiB binary conversion passed', flush=True)
# Both execute under the same 2 GiB ceiling. Native C allocation counters and
# repeated VM teardown are checked separately by the embedding lifecycle gate.
