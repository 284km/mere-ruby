#!/usr/bin/env python3
"""Which C library functions does the target have?

ruby/config.h tells an extension what its platform provides (HAVE_FORK,
HAVE_STRLCPY, ...). CRuby's is written by autoconf when CRuby is built;
mere-ruby's is written by hand, per operating system, and this tool is what
the hand copies from and what holds the copy to the truth:

  config_probe.py --list           print the names that link, as #define lines
  config_probe.py --check CONFIG   every HAVE_<FUNCTION> that CONFIG defines
                                   for this platform must link here

A name is asked the way autoconf asks it: a program that declares `char
name();` and calls it is linked (never run). The check is one-directional on
purpose -- a runner whose C library gains a function must not fail a build.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import os
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
CANDIDATES = (HERE / 'config_functions.txt').read_text().split()


def links(cc, name, directory):
    source = Path(directory) / (name + '.c')
    source.write_text(
        '#ifdef __cplusplus\nextern "C"\n#endif\n'
        f'char {name}();\nint main(void) {{ return {name}(); }}\n')
    result = subprocess.run(
        [*cc, '-w', '-fno-builtin', '-Wno-error', str(source), '-lm', '-o',
         str(source.with_suffix('.out'))],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def probe(cc, names):
    with tempfile.TemporaryDirectory() as directory:
        with ThreadPoolExecutor(max_workers=os.cpu_count() or 2) as pool:
            found = list(pool.map(lambda n: links(cc, n, directory), names))
    return [n for n, ok in zip(names, found) if ok]


def claimed(config, cc):
    """The HAVE_ names CONFIG defines when preprocessed for this target."""
    text = subprocess.check_output(
        [*cc, '-dM', '-E', '-x', 'c', '-I', str(Path(config).parents[1]), str(config)], text=True)
    return {line.split()[1] for line in text.splitlines()
            if line.startswith('#define HAVE_')}


parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument('--cc', default=os.environ.get('CC', 'cc'))
parser.add_argument('--list', action='store_true')
parser.add_argument('--check', type=Path)
args = parser.parse_args()
cc = args.cc.split()
if args.list:
    for name in probe(cc, CANDIDATES):
        print(f'#define HAVE_{name.upper()} 1')
elif args.check:
    names = [n for n in CANDIDATES if 'HAVE_' + n.upper() in claimed(args.check, cc)]
    missing = sorted(set(names) - set(probe(cc, names)))
    if missing:
        sys.exit('config.h claims functions this C library does not link: ' + ' '.join(missing))
    print(f'{len(names)} claimed C library functions link')
else:
    parser.error('--list or --check')
