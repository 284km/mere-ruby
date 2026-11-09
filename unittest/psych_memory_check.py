#!/usr/bin/env python3
"""Bound large YAML wire/store round trips and repeated parser/visitor lifetimes."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise

WIRE = r'''
require 'psych'
mode, folder = ARGV
expected = {'plain' => 'x' * (4 * 1024 * 1024),
            'literal' => ((('y' * 1023) + "\n") * 4096),
            'unicode' => '雪' * 50000,
            'rows' => Array.new(1000) { |i| [i, {'name' => "row#{i}"}] }}
if mode == 'prepare'
  File.binwrite(folder + '/reference.yaml', Psych.dump(expected))
elsif mode == 'emit'
  File.binwrite(folder + '/candidate.yaml', Psych.dump(expected))
else
  name = mode == 'load' ? 'reference' : 'candidate'
  File.open(folder + '/' + name + '.yaml', 'rb') do |io|
    raise 'large wire changed data' unless Psych.safe_load(io) == expected
  end
end
puts 'large YAML wire preserved'
'''

QUOTED = r'''
require 'psych'
quoted = 'q' * (4 * 1024 * 1024)
raise 'quoted scalar changed' unless Psych.load('"' + quoted + '"') == quoted
puts 'large quoted scalar preserved'
'''

LIFETIME = r'''
require 'psych'
ARGV[0].to_i.times do
  value = {'row' => ['value', 1, nil]}
  raise 'lifecycle changed data' unless Psych.safe_load(Psych.dump(value)) == value
end
GC.start
puts 'Psych lifecycles preserved'
'''

STORE = r'''
require 'yaml/store'
path = ARGV[0]
store = YAML::Store.new(path)
store.transaction do
  1000.times { |i| store["key#{i}"] = [i, "雪#{i}"] }
end
store.transaction do
  raise 'large store read changed' unless store['key999'] == [999, '雪999']
  store['updated'] = true
end
store.transaction(true) do
  raise 'large store update lost' unless store['updated'] && store.roots.length == 1001
end
puts 'large YAML store preserved'
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', default=os.environ.get('MR_BIN', str(ROOT / 'mere-ruby')))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    reference = subprocess.check_output(
        ['sh', '-c', '. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"', 'sh', str(ROOT)], text=True)
    stdlib = subprocess.check_output([reference, '-e',
        'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir,"gems","*","lib")]).join(":"))'], text=True)
    results = {}

    def run(name, source, binary, *argv, stats=False):
        script = output / (name + '.rb')
        script.write_text(source)
        log = output / (name + '.out')
        env = dict(os.environ, RUBYLIB=stdlib)
        if stats:
            env['MERE_REGION_STATS'] = '1'
        result = supervise([str(Path(binary).resolve()), str(script), *map(str, argv)], env,
                           log, 2097152, 120)
        results[name] = result
        (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
        assert result['exit'] == 0 and result['limit'] is None, (name, result, log.read_text()[-2000:])
        print(name, 'passed', flush=True)
        return log.read_text()

    run('reference_prepare', WIRE, reference, 'prepare', output)
    run('candidate_load', WIRE, args.binary, 'load', output)
    run('candidate_emit', WIRE, args.binary, 'emit', output)
    run('candidate_quoted', QUOTED, args.binary)
    run('reference_verify', WIRE, reference, 'verify', output)
    run('candidate_store', STORE, args.binary, output / 'store.yaml')
    totals = []
    for count in (20, 200):
        log = run(f'lifetimes_{count}', LIFETIME, args.binary, count, stats=True)
        match = re.search(r'region-stats default:.*alloc_total=(\d+)', log)
        assert match, log[-1000:]
        totals.append(int(match[1]))
    (output / 'allocation.json').write_text(json.dumps(totals) + '\n')
    print('20/200 lifetimes: default arena allocations =', totals, flush=True)
    assert totals[1] - totals[0] < 8 * 1024 * 1024, totals
    print('Psych large input and lifetime checks passed')


if __name__ == '__main__':
    main()
