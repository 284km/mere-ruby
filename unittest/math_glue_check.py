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
