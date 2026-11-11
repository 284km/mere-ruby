#!/usr/bin/env python3
"""Run the unmodified ruby/nkf 0.2.0 tests on both interpreters with bounds."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
sys.dont_write_bytecode = True
from ci import supervise

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ruby', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
p.add_argument('--ruby-source', type=Path, required=True)
p.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
helpers = a.ruby_source.resolve() / 'tool/lib'
assert (helpers / 'test/unit.rb').is_file()
libs = subprocess.check_output([a.ruby, '-e',
    'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir,"gems","*","lib")].sort).join(":"))'], text=True, timeout=20)
results = {}
for side, binary in [('reference', a.ruby), ('native', a.binary.resolve())]:
    for name, tests, assertions in [('test_nkf', 2, 3), ('test_kconv', 5, 41)]:
        env = dict(os.environ, RUBYLIB=str(helpers) + (':' + str(ROOT / 'unittest/shim') + ':' + libs if side == 'native' else ''))
        key = side + '-' + name
        log = a.output / (key + '.out')
        result = supervise(list(map(str, [binary, ROOT / 'vendor/nkf/test/nkf' / (name + '.rb'),
                                           '--verbose', '--seed=1'])), env, log, 2097152, 120)
        results[key] = result
        (a.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
        assert result['exit'] == 0 and result['limit'] is None, (key, result)
        summary = re.findall(r'(\d+) tests, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips', log.read_text())
        assert summary == [(str(tests), str(assertions), '0', '0', '0')], (key, summary)
        print(key, tests, 'tests', assertions, 'assertions passed', flush=True)
