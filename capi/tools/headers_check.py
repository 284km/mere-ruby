#!/usr/bin/env python3
"""Compare the vendored CRuby files with a ruby source tree.

    headers_check.py <ruby source tree>            check
    headers_check.py <ruby source tree> --write    rewrite headers.patch

capi/include is ruby's include/ directory, and capi/vendor a few more of its
files. This says exactly how they differ from the tree they were copied from:

  - every file of include/ is in capi/include, byte for byte, except the
    ones headers.patch names, and those differ by that patch and nothing else
  - capi/include has three files of its own: ruby/config.h (written for this
    interpreter, checked by config_probe.py), and COPYING and BSDL, which are
    the tree's
  - every .c and .h of capi/vendor is the tree's file of the same path

The tree must be the version the headers were copied from (ruby 4.0.10, the
commit CI names RUBY_SOURCE_REF).
"""
from pathlib import Path
import difflib
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
CAPI = HERE.parent
PATCH = HERE / 'headers.patch'
OURS = {'ruby/config.h', 'COPYING', 'BSDL'}
args = [a for a in sys.argv[1:] if a != '--write']
if len(args) != 1:
    sys.exit(__doc__)
tree = Path(args[0]).resolve()
problems = []


def files(root):
    return {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()}


theirs, mine = files(tree / 'include'), files(CAPI / 'include')
for name in sorted(theirs - mine):
    problems.append(f'include/{name} is not in capi/include')
for name in sorted(mine - theirs - OURS):
    problems.append(f'capi/include/{name} is not a file of the tree')
for name in ('COPYING', 'BSDL'):
    if (CAPI / 'include' / name).read_bytes() != (tree / name).read_bytes():
        problems.append(f'capi/include/{name} is not the tree\'s')
patch = []
for name in sorted(theirs & mine):
    a, b = (tree / 'include' / name).read_bytes(), (CAPI / 'include' / name).read_bytes()
    if a != b:
        patch += difflib.unified_diff(a.decode().splitlines(True), b.decode().splitlines(True),
                                      'include/' + name, 'capi/include/' + name)
patch = ''.join(patch)
if '--write' in sys.argv:
    PATCH.write_text(patch)
elif not PATCH.exists() or PATCH.read_text() != patch:
    problems.append('capi/include differs from the tree by something other than capi/tools/headers.patch')
vendored = [p for p in (CAPI / 'vendor').rglob('*') if p.suffix in ('.c', '.h')]
for p in sorted(vendored):
    name = p.relative_to(CAPI / 'vendor')
    if not (tree / name).is_file() or (tree / name).read_bytes() != p.read_bytes():
        problems.append(f'capi/vendor/{name} is not the tree\'s file')
if problems:
    sys.exit('headers_check:\n  ' + '\n  '.join(problems))
changed = patch.count('\n--- include/')+ (1 if patch.startswith('--- include/') else 0)
print(f'headers_check: {len(theirs)} headers, {changed} of them patched (headers.patch); {len(vendored)} vendored sources unchanged')
