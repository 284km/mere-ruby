#!/usr/bin/env python3
"""Bound connection regression children, including timeout cleanup."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
program = ROOT / 'corpus/503_tcp_connect_deadlines.rb'


def run(binary, env):
    return subprocess.run([str(binary), str(program)], env=env,
                          capture_output=True, check=True, timeout=20).stdout


expected = run(os.environ.get('REF_RUBY_BIN', 'ruby'), os.environ.copy())
for mode in ('on', 'off'):
    env = os.environ.copy()
    env.pop('MERE_RUBY_NO_HASH_INDEX', None)
    if mode == 'off':
        env['MERE_RUBY_NO_HASH_INDEX'] = '1'
    actual = run(ROOT / 'mere-ruby', env)
    assert actual == expected, f'TCP regression differs with hash index {mode}'
    print(f'TCP deadlines: matches reference, hash index {mode}', flush=True)
