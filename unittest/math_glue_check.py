#!/usr/bin/env python3
"""Compare native cube-root bits against pinned Ruby, including glibc correction."""
import argparse
import ctypes
import ctypes.util
import math
import os
from pathlib import Path
import platform
import random
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
parser.add_argument('--binary', type=Path, default=ROOT/'mere-ruby')
args = parser.parse_args()
random_source = random.Random(409)
values = [0.0, -0.0, math.inf, -math.inf, 0.5, 1.5, 2.0, 1000.0,
          float.fromhex('0x0.0000000000001p-1022'), float.fromhex('0x1.fffffffffffffp+1023')]
values += [math.ldexp(random_source.uniform(-1, 1), random_source.randrange(-1022, 1024)) for _ in range(1000)]
with tempfile.TemporaryDirectory(prefix='mere-math-glue-') as folder:
    folder = Path(folder)
    library = folder / 'math.so'
    subprocess.run([os.environ.get('CC', 'clang'), '-O2', '-shared', '-fPIC', '-Wall', '-Wextra', '-Werror',
                    str(ROOT / 'tools/math_glue.c'), '-lm', '-o', str(library)], check=True, timeout=30)
    lib = ctypes.CDLL(str(library))
    lib.mr_math_cbrt.argtypes = [ctypes.c_double]
    lib.mr_math_cbrt.restype = ctypes.c_double
    assert math.isnan(lib.mr_math_cbrt(math.nan))
    source = folder / 'values.bin'
    source.write_bytes(b''.join(struct.pack('!d', value) for value in values))
    result = subprocess.run([args.reference, '-e',
        "raise 'reference version drift' unless RUBY_VERSION=='4.0.9'; STDOUT.binmode; STDOUT.write(File.binread(ARGV.fetch(0)).unpack('G*').map { |x| Math.cbrt(x) }.pack('G*'))",
        str(source)], capture_output=True, check=True, timeout=30)
    expected = result.stdout
    actual = b''.join(struct.pack('!d', lib.mr_math_cbrt(value)) for value in values)
    assert actual == expected, 'native cbrt bits differ from reference'
    if platform.libc_ver()[0] == 'glibc':
        raw = ctypes.CDLL(ctypes.util.find_library('m')).cbrt
        raw.argtypes = [ctypes.c_double]
        raw.restype = ctypes.c_double
        uncorrected = b''.join(struct.pack('!d', raw(value)) for value in values)
        assert uncorrected != expected, 'negative control failed to expose the missing glibc correction'
    print(f'native cbrt: {len(values)} bit-exact reference comparisons, special values and platform correction passed')


# Compare the interpreter's complete step pipeline against the actual reference
# loop, rather than assuming one architecture's multiply/add contraction.
program="STDOUT.binmode; a=[-0.0,0.0,1.0,-1.0,12.7,-12.7]; u=[0.1,-0.1,0.3,-0.3,1.3,-1.3,1e-100,-1e-100]; STDOUT.write(a.product(u).flat_map { |b,s| b.step(s>0 ? Float::INFINITY : -Float::INFINITY,s).take(12) }.pack('G*'))"
expected = subprocess.run([args.reference, '-e', program], capture_output=True, check=True, timeout=30)
actual = subprocess.run([str(args.binary.resolve()), '-e', program], capture_output=True, check=True, timeout=30)
assert actual.stdout == expected.stdout, 'step rounding differs from reference target'
print('Float#step:576 bit-exact pipeline comparisons including signed zero passed')

# Infinite bounds bypass the count helper. Exercise finite, inclusive and
# exclusive ends exactly at a computed boundary and one adjacent double away.
program = """
a=[-0.0,0.0,1.0,-1.0,12.7,-12.7]
u=[0.1,-0.1,0.3,-0.3,1.3,-1.3]
a.product(u).each do |b,s|
  [0,1,2,9,11].each do |n|
    e=b+n*s
    [e.prev_float,e,e.next_float].each do |endpoint|
      [false,true].each do |exclude|
        sequence=Range.new(b,endpoint,exclude).step(s)
        values=sequence.to_a
        p [sequence.size,values.length,values.pack('G*').unpack1('H*')]
      end
    end
  end
end
"""
expected = subprocess.run([args.reference, '-e', program], capture_output=True, check=True, timeout=30)
actual = subprocess.run([str(args.binary.resolve()), '-e', program], capture_output=True, check=True, timeout=30)
assert actual.stdout == expected.stdout, 'finite step size/cardinality/bits differ from reference target'
print('Float#step:1080 finite boundary size/cardinality/bit comparisons passed')
