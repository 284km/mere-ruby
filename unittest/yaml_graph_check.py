#!/usr/bin/env python3
"""Catch quadratic identity tracking when dumping unshared YAML collections."""
import argparse
import os
from pathlib import Path
import resource
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--binary', default=os.environ.get('MR_BIN', str(root / 'mere-ruby')))
parser.add_argument('--preload', help='optional emitter override for a negative control')
args = parser.parse_args()
env = os.environ.copy()
# This checks the indexed path. Output correctness is tested separately in both modes.
env.pop('MERE_RUBY_NO_HASH_INDEX', None)
env.pop('MERE_RUBY_GC_STRESS', None)
command = [str(Path(args.binary).resolve())]
if args.preload:
    command += ['-r', str(Path(args.preload).resolve())]
with tempfile.TemporaryDirectory(prefix='yaml-graph-check-') as directory:
    program = Path(directory) / 'dump.rb'
    program.write_text("require 'psych'\nn = Integer(ARGV.fetch(0))\n"
                       "puts Psych.dump(Array.new(n) { [] }).bytesize\n")
    times = []
    for count in (8000, 32000):
        before = resource.getrusage(resource.RUSAGE_CHILDREN).ru_utime
        result = subprocess.run(command + [str(program), str(count)], env=env,
                                text=True, capture_output=True, timeout=120, check=True)
        elapsed = resource.getrusage(resource.RUSAGE_CHILDREN).ru_utime - before
        assert result.stdout.strip() == str(4 + 5 * count), result.stdout
        times.append(elapsed)
        print(f'{count} unshared nodes: {elapsed:.3f}s child user CPU', flush=True)
    # Four times as many nodes should not approach the 16x quadratic curve.
    # A generous slope plus a fixed allowance avoids policing machine speed.
    if times[1] > 8 * times[0] + 1:
        raise SystemExit('YAML graph lookup scales superlinearly: inspect identity storage')
print('YAML graph scaling check passed')
