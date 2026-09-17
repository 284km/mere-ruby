#!/bin/sh
# Every dispatch arm carries a length test in front of its string compare
# (`str_len name == N && str_eq name "lit"`, see name_len_guard.py). The test is
# a NECESSARY condition derived from the literal, so N must BE the literal's
# length. Get N wrong and the arm becomes unreachable -- no build error, no
# crash, just a method that answers "undefined" forever. That has happened:
# "append_features" written as 16 and "prepend_features" as 17.
#
# Re-derive every N from its own literal and refuse a tree where one disagrees.
set -u
cd "$(dirname "$0")/.." || exit 2
python3 - <<'PY'
import io, re, sys, glob
bad = 0
total = 0
for path in sorted(glob.glob('*.mere')):
    src = io.open(path, encoding='utf-8').read()
    for m in re.finditer(r'str_len name == (\d+) && str_eq name "([^"]*)"', src):
        total += 1
        declared, lit = int(m.group(1)), m.group(2)
        if declared != len(lit):
            line = src[:m.start()].count('\n') + 1
            print('name_len: %s:%d  "%s" is %d bytes, the guard says %d'
                  % (path, line, lit, len(lit), declared))
            print('name_len:   the arm is UNREACHABLE -- that name answers "undefined".')
            bad += 1
if total == 0:
    print("name_len: found no guarded dispatch site at all -- the pattern moved")
    sys.exit(1)
if bad:
    sys.exit(1)
print("name_len: all %d guards match their literal" % total)
PY
