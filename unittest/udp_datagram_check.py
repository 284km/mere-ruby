#!/usr/bin/env python3
"""Compare addressed UDP behavior with a deadline on every child."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
reference = os.environ.get('REF_RUBY_BIN', 'ruby')
program = ROOT / 'corpus/496_udp_datagrams.rb'


def run(binary, env):
    result = subprocess.run([str(binary), str(program)], env=env,
                            capture_output=True, timeout=15, check=True)
    return result.stdout


expected = run(reference, os.environ.copy())
for mode in ('on', 'off'):
    env = os.environ.copy()
    env.pop('MERE_RUBY_NO_HASH_INDEX', None)
    if mode == 'off':
        env['MERE_RUBY_NO_HASH_INDEX'] = '1'
    actual = run(ROOT / 'mere-ruby', env)
    assert actual == expected, f'UDP regression differs with hash index {mode}'
    print(f'UDP datagrams: matches reference, hash index {mode}', flush=True)
