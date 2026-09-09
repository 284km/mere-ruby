#!/bin/sh
# tools/bracket_depth_check.sh — how close the emitted C is to a C compiler's nesting cap.
#
# WHY THIS IS NOT A STALE FLAG. The build line carries `-fbracket-depth`, and the README
# used to explain it as a number that "kept needing to be bigger" -- which read like a
# workaround nobody had revisited. Measured on 2026-09-10, against a 157,121-line `mr.c`:
#
#     -fbracket-depth=239   fatal error: bracket nesting level exceeded maximum of 238
#     -fbracket-depth=240   ok
#
# So the requirement is 240 and mainline clang's default is 256. The flag is NOT stale --
# it is SIXTEEN brackets of headroom, about 7%, and removing it would leave the build one
# prelude concatenation away from an error whose text is about C and whose cause is Ruby.
# 4096 was simply far larger than it had to be, and a number that large hid how close the
# real one is.
#
# The number moves for two reasons and this reports both: mere's codegen changing how
# deeply it nests (v0.1.449 and v0.1.450 both cut it), and this interpreter's own source
# growing another long `++` chain. Either way, what matters is the distance to 256, so
# that is what is printed.
#
# Usage:  MERE=/path/to/mere.exe sh tools/bracket_depth_check.sh
#         BUDGET=... to change the ceiling this fails at (default 256, the mainline cap)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
BUDGET="${BUDGET:-256}"
command -v "$MERE" >/dev/null 2>&1 || { echo "bracket_depth: no mere — set MERE=..." >&2; exit 1; }
CC="${CC:-clang}"; command -v "$CC" >/dev/null 2>&1 || CC=cc
command -v "$CC" >/dev/null 2>&1 || { echo "bracket_depth: SKIP — no C compiler"; exit 0; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# Reuse the C the build already emitted when there is one -- on 157,121 lines the emit is
# most of this check's cost, and CI has just produced exactly that file. MR_C names it.
if [ -n "${MR_C:-}" ] && [ -s "${MR_C:-}" ]; then
  SRC="$MR_C"
else
  "$MERE" -c "$ROOT/main.mere" > "$TMP/mr.c" 2>"$TMP/err" || {
    echo "bracket_depth: FAIL — the emit did not run"; head -3 "$TMP/err"; exit 1; }
  SRC="$SRC"
fi

# ASK THE TOOL THAT WILL REFUSE YOU. Counting brackets here would be a second
# implementation of clang's rule, and the two would disagree eventually -- an earlier
# hand-written counter in the mere repository reported "still over" for a file clang was
# accepting. So: bisect on clang's own answer.
lo=1; hi=$BUDGET
"$CC" -O0 -w -fsyntax-only -fbracket-depth=$hi "$SRC" 2>/dev/null || {
  echo "bracket_depth: FAIL — the emitted C needs MORE than $hi, the mainline clang default."
  echo "  The build line's -fbracket-depth is now load-bearing rather than headroom."
  echo "  Either split whatever grew (a long ++ chain, a long let chain) or raise the flag"
  echo "  deliberately -- and update this budget in the same commit."
  exit 1; }
while [ $((hi - lo)) -gt 1 ]; do
  mid=$(( (lo + hi) / 2 ))
  if "$CC" -O0 -w -fsyntax-only -fbracket-depth=$mid "$SRC" 2>/dev/null
  then hi=$mid; else lo=$mid; fi
done

margin=$(( BUDGET - hi ))
echo "bracket_depth: needs $hi, the mainline clang default is $BUDGET — $margin to spare"
# A margin this thin is the thing worth saying out loud; it is not a failure.
[ "$margin" -lt 32 ] && echo "bracket_depth: that is thin. One more long chain in the prelude and the build stops."
echo "bracket_depth: ok"
