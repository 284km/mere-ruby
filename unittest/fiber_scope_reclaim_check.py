#!/usr/bin/env python3
"""A dropped Fiber that stopped inside an op-assign, a program's `==` or an
expression-position `require` must be given back.

Each form runs bench/fiber_scope_reclaim.rb at two counts. A fiber that is
never reclaimed keeps its stack, so the peak RSS grows with the count: 2.8
times from 1,000 to 3,000 turns when the scope rooted the stopped block
(review of #191), 1.25 times when it is reclaimed. The `==` and `require`
forms go through with_scratch_env on the evaluator (second review of #191). The bound is between."""
import os
from pathlib import Path
import resource
import subprocess

ROOT = Path(__file__).resolve().parent.parent
binary = os.environ.get('MR_BIN', str(ROOT / 'mere-ruby'))
LOW, HIGH, BOUND = 1000, 3000, 1.8


def peak_rss(mode, count):
    result = subprocess.run([binary, str(ROOT / 'bench/fiber_scope_reclaim.rb'), str(count), mode],
                            capture_output=True, text=True, timeout=300, check=True)
    assert result.stdout == f'fiber scope reclaim: {mode} done\n', result.stdout
    # ru_maxrss of the children is the largest so far, so each run is made
    # in a fresh process (measure) and read on its own
    return resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss


def measure(mode, count):
    out = subprocess.run(['python3', __file__, '--one', mode, str(count)],
                         capture_output=True, text=True, timeout=600, check=True, env=os.environ)
    return int(out.stdout.strip())


def main():
    import sys
    if len(sys.argv) == 4 and sys.argv[1] == '--one':
        rss = peak_rss(sys.argv[2], int(sys.argv[3]))
        print(rss)
        return
    for mode in ('value', 'getter', 'setter', 'aref', 'aset', 'eq', 'require'):
        low = measure(mode, LOW)
        high = measure(mode, HIGH)
        ratio = high / low
        print(f'{mode}: peak RSS at {LOW}/{HIGH} dropped fibers = {low}/{high} ({ratio:.2f}x)')
        assert ratio < BOUND, (mode, low, high, ratio)


main()
