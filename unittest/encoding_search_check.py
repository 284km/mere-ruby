#!/usr/bin/env python3
"""Compare encoding folding and byte searches through native and actual Wasm hosts."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
parser.add_argument('--reference', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
args = parser.parse_args()
version = subprocess.check_output([args.reference, '-e', 'print RUBY_VERSION'], text=True, timeout=10)
assert version == '4.0.9', 'reference version drift: ' + version

for name in ['546_encoding_name_folding.rb', '563_byte_search_offsets.rb']:
    source = ROOT / 'corpus' / name
    expected = subprocess.run([args.reference, '-Eutf-8', str(source)],
                              capture_output=True, check=True, timeout=30).stdout
    commands = {
        'native': [str(args.binary.resolve()), str(source)],
        'Wasm': ['node', '--stack-size=8000', str(ROOT / 'docs/smoke.mjs'), source.read_text()],
    }
    for target, command in commands.items():
        result = subprocess.run(command, capture_output=True, timeout=240)
        assert result.returncode == 0 and result.stdout == expected and not result.stderr, (
            name, target, result.returncode, result.stdout[-1500:], result.stderr[-1500:])
        print(name, target, 'matches pinned reference', flush=True)
