#!/usr/bin/env python3
"""Exercise the actual string-page store under ASan/UBSan without the VM."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if len(sys.argv) > 1 and sys.argv[1] == '--emit':
    compiler, directory = sys.argv[2:]
    output = Path(directory)
    with (output / 'pages.c').open('w') as out:
        result = subprocess.run([compiler, '-c', str(output / 'pages.mere')], stdout=out)
    sys.exit(result.returncode)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--compiler', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
source = (ROOT / 'm_state.mere').read_text()
# Compile the production functions, supplying only their value tag and handle
# offset. The intervening regexp snapshot tables are unrelated to this test.
pages = source[source.index('let str_store ='):source.index('// ⚠ ONE SNAPSHOT PER SUBJECT')]
allocate = source[source.index('let str_slot_prepare ='):source.index('// ⚠ AN APPEND GOES')]
(output / 'pages.mere').write_text(
    'type Val = VStr of int;\nlet handle_base = 1000000;\n' + pages + allocate +
    (ROOT / 'tools/string_pages_regression.mere').read_text())
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise

results = {}
commands = [
    ('emit', [sys.executable, __file__, '--emit', args.compiler.resolve(), output]),
    ('compile', ['clang', '-O2', '-g', '-fsanitize=address,undefined',
                 '-fno-omit-frame-pointer', output / 'pages.c', '-pthread', '-lm',
                 '-o', output / 'pages']),
    ('run', [output / 'pages']),
]
for name, command in commands:
    log = output / (name + '.out')
    command = list(map(str, command))
    result = supervise(command, dict(os.environ), log, 2097152, 90)
    result['command'] = command
    results[name] = result
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert result['exit'] == 0 and result['limit'] is None, (name, result, log.read_text()[-2000:])
    print(name, 'passed', flush=True)
print('String page lifetime checks passed', flush=True)
