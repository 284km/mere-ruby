#!/bin/sh
# Build mere-ruby. Two modes, because they answer different questions.
#
#   ./tools/build.sh            -O2 -- the build that sweeps and the build that ships
#   ./tools/build.sh --fast     -O0 -- the build for "edit, run one witness, edit again"
#   ./tools/build.sh --cc-only  skip the emit and compile the mr.c that is there
#
# Measured 2026-09-22 on this machine (Apple silicon), `/usr/bin/time -p`:
#
#   emit -- mere -c main.mere > mr.c      41s   inside the Mere compiler; not
#                                               reducible from this repository
#   clang -O2                            112s   a corpus program then runs in 0.04s
#   clang -O0                             30s   the same program runs in 0.07s
#
# 3.7x off the build for 1.7x on the run. Fifteen builds in a working day is
# normal here, so --fast is about twenty minutes of a day.
#
# ⚠ AND IT IS THE WRONG BUILD FOR THE RECORD. The sweep runs the interpreter
# five thousand times and bounds each run in CPU SECONDS, so a binary that is
# 1.7x slower measures a different table -- files near the budget would cross
# it and the record would report a regression that is the compiler's -O level.
# Which build made a binary is not visible in the binary, so this writes it
# down and mspec/scoreboard.sh refuses to sweep an -O0 one. A sentence in a
# README cannot refuse anything.
#
# The build line itself lived only in prose, in two dialects (README.md has
# macOS's and Linux's), which is three copies of one rule; see PAIN.md for why
# each flag is load-bearing.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
cd "$root" || exit 2

mode=O2
opt=-O2
emit=1
for a in "$@"; do
  case "$a" in
    --fast|-O0)  mode=O0; opt=-O0 ;;
    --cc-only)   emit=0 ;;
    -h|--help)   sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "build.sh: unknown argument '$a'" >&2; exit 2 ;;
  esac
done

# ⚠ REFUSE rather than half-build. The Mere compiler lives in its own
# repository and is not vendored here; CI puts it in .mere-compiler. With no
# compiler and no --cc-only this would otherwise compile whatever mr.c happened
# to be lying about, which is the most confusing failure available: a binary
# built from a source you did not edit.
MERE="${MERE:-}"
if [ "$emit" = 1 ]; then
  if [ -z "$MERE" ]; then
    for c in "$root/.mere-compiler/_build/default/bin/mere.exe" mere mere.exe; do
      p="$(command -v "$c" 2>/dev/null)" && { MERE="$p"; break; }
    done
  fi
  if [ -z "$MERE" ]; then
    echo "build.sh: no Mere compiler found. Set MERE=<path to mere/mere.exe>, or put one at" >&2
    echo "          .mere-compiler/_build/default/bin/mere.exe (which is where CI builds it)," >&2
    echo "          or pass --cc-only to compile the mr.c already in this directory." >&2
    exit 2
  fi
fi

# The platform differences, in one place instead of two paragraphs of README:
#   -Wl,-stack_size   Mach-O only; on Linux the main thread's stack is `ulimit -s`
#   -fbracket-depth   mainline clang caps nesting at 256 and the emitted C needs
#                     more; Apple's clang allows more by default but the flag is
#                     harmless there. tools/bracket_depth_check.sh is the gate.
#   -lm               Linux needs it spelled out
case "$(uname -s)" in
  Darwin) plat="-Wl,-stack_size,0x20000000 -fbracket-depth=1024" ;;
  *)      plat="-fbracket-depth=1024 -lm" ;;
esac

if [ "$emit" = 1 ]; then
  printf 'emit   %s -c main.mere > mr.c\n' "$MERE"
  "$MERE" -c main.mere > mr.c.new || { echo "build.sh: emit failed" >&2; rm -f mr.c.new; exit 1; }
  mv -f mr.c.new mr.c
fi
[ -f mr.c ] || { echo "build.sh: no mr.c to compile" >&2; exit 2; }

printf 'cc     clang %s %s mr.c -o mere-ruby\n' "$opt" "$plat"
# ⚠ NEVER `cp` OVER A RUNNING BINARY -- the text pages of a process that is
# mid-run are backed by that file, and overwriting them SIGKILLs it or, worse,
# gives it another build's instructions. Build beside it and rename.
# shellcheck disable=SC2086
clang $opt -w $plat mr.c -o mere-ruby.new || { rm -f mere-ruby.new; exit 1; }
/bin/mv -f mere-ruby.new mere-ruby

# ...and say which build this is, where something that must not be misled can
# read it. mspec/scoreboard.sh does.
printf '%s\n' "$mode" > .build_mode
printf 'ok     mere-ruby is an %s build (.build_mode)\n' "$mode"
