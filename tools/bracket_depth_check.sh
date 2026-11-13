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
# ⚠ THAT HEADROOM IS GONE, and this check is how it was noticed -- 25 CI runs after the
# fact, because the run was already red for it and nobody read past the first failure.
# Re-measured 2026-09-17:
#
#     last green CI (e68c5c0)  253      still under the 256 default
#     the next commit          256      exactly at it
#     today                    269      over by thirteen
#
# The flag is LOAD-BEARING now, not headroom: a build without it does not compile, so
# the budget moved, deliberately, to the number the build line actually passes. What
# this check is FOR is unchanged: catching the growth before it reaches the flag.
#
# ⚠ WHAT THE LEVELS ARE -- not "every top-level `let`", which this note used to say.
# Measured 2026-11-13, when the need was 1012. The emitted C's main initializes every
# top-level VALUE in one statement expression, and a value some function reads (a C
# global) is assigned in a `({ mu_x = ...; ({ <the rest of the program> }) })` of its
# own: one level that everything after it sits inside. Between two globals, a run of
# anything else -- `let _ = ...`, a value only main reads -- is flattened into one more
# `({ ... })`. Functions are lifted out and cost nothing. The deepest point is the end
# of that chain plus what the last values nest inside themselves. In mr.c's main:
#
#     992 links:  825 globals + 160 `let _` runs + 6 other runs + the final `exit`
#     + 17        inside the last value, cli_feature_names (a list literal)
#     = 1009 parentheses deep, which clang reports as 1012
#
# and in small programs, one kind of `let` at a time (n of them):
#
#     a value a function reads                 n = 50 / 100 / 200:  56 / 106 / 206
#     the same, each followed by a `let _`                         106 / 206 / 406
#     values only main reads; functions; a 201-member `let rec`     15, flat
#     a 200-link `++` chain; a 20-tuple                            flat; one, as any global
#     a list literal [a, b, ...]       TWO PER ELEMENT, on top of where in the chain it sits
#
# Clang counts each kind of bracket separately: a link is one `(` and one `{`, and it
# is the parentheses that reach the cap first.
#
# So the cheap levels were the `let _` runs. `let x = vec_new (); let _ = vec_push x 0;`
# is two levels where `let x = (let v = vec_new () in let _ = vec_push v 0 in v)` is
# one -- the same effects, in the same order, on the same container. 142 runs written
# that way took the need from 1012 to 870 (see oid_next_v in m_state.mere). What is
# left grows by one per new global a function reads, by one per `let _` written between
# two of them, and by two per element of a list literal written late in the program.
#
# The number also moves when mere's codegen changes how deeply it nests (v0.1.449 and
# v0.1.450 both cut it). Either way, what matters is the distance to the flag, and to
# 256, so both are printed.
#
# Usage:  MERE=/path/to/mere.exe sh tools/bracket_depth_check.sh
#         BUDGET=... to change the ceiling this fails at (default 1024, the build's flag)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
BUDGET="${BUDGET:-1024}"
CC="${CC:-clang}"; command -v "$CC" >/dev/null 2>&1 || CC=cc
command -v "$CC" >/dev/null 2>&1 || { echo "bracket_depth: SKIP — no C compiler"; exit 0; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# Reuse the C the build already emitted when there is one -- on 157,121 lines the emit is
# most of this check's cost, and CI has just produced exactly that file. MR_C names it.
if [ -n "${MR_C:-}" ] && [ -s "${MR_C:-}" ]; then
  SRC="$MR_C"
else
  # Only HERE is a compiler needed. Requiring one up front made the CI step fail with
  # `no mere` on a runner that had just written the very file it was told to read --
  # a precondition checked for a branch that was not going to be taken.
  command -v "$MERE" >/dev/null 2>&1 || {
    echo "bracket_depth: no mere and no MR_C — set one of them" >&2; exit 1; }
  "$MERE" -c "$ROOT/main.mere" > "$TMP/mr.c" 2>"$TMP/err" || {
    echo "bracket_depth: FAIL — the emit did not run"; head -3 "$TMP/err"; exit 1; }
  SRC="$TMP/mr.c"
fi

# ASK THE TOOL THAT WILL REFUSE YOU. Counting brackets here would be a second
# implementation of clang's rule, and the two would disagree eventually -- an earlier
# hand-written counter in the mere repository reported "still over" for a file clang was
# accepting. So: bisect on clang's own answer.
# ⚠ SEEDED FAST PATH, AND IT CANNOT WEAKEN THE CHECK. A full bisection over
# [1, 1024] is ten `-fsyntax-only` passes over 302k lines of C -- 119 seconds of
# every CI run, measured 2026-09-22, and the answer is the same number almost
# every time. So try to PROVE the recorded answer first, in two probes:
#
#     SEED     must compile   (the need is at most SEED)
#     SEED-1   must NOT       (the need is at least SEED)
#
# Both together pin it exactly. Either one failing to behave means the number
# MOVED, and then the full bisection runs and reports the new value -- so a
# stale seed costs two extra probes and never a wrong answer. ⚠ This is the
# property that matters: the fast path can only ever CONFIRM, never conclude.
# A seed that made the check unable to report a larger value would be a check
# that can only agree with what it was told.
SEED="${BRACKET_SEED:-870}"
sb_bd_fast=0
if [ "$SEED" -gt 1 ] && [ "$SEED" -le "$BUDGET" ] \
   && "$CC" -O0 -w -fsyntax-only -fbracket-depth="$SEED" "$SRC" 2>/dev/null \
   && ! "$CC" -O0 -w -fsyntax-only -fbracket-depth="$(( SEED - 1 ))" "$SRC" 2>/dev/null; then
  hi="$SEED"; sb_bd_fast=1
fi

if [ "$sb_bd_fast" = 0 ]; then
lo=1; hi=$BUDGET
"$CC" -O0 -w -fsyntax-only -fbracket-depth=$hi "$SRC" 2>/dev/null || {
  echo "bracket_depth: FAIL — the emitted C needs MORE than $hi, which is the -fbracket-depth"
  echo "  the build line passes. The build does not compile: this is not a warning."
  echo "  Split whatever grew (a long ++ chain, a long top-level let chain) or raise BOTH"
  echo "  the flag and this budget -- in the same commit, with the new number measured."
  exit 1; }
while [ $((hi - lo)) -gt 1 ]; do
  mid=$(( (lo + hi) / 2 ))
  if "$CC" -O0 -w -fsyntax-only -fbracket-depth=$mid "$SRC" 2>/dev/null
  then hi=$mid; else lo=$mid; fi
done
  if [ "$hi" != "$SEED" ]; then
    echo "bracket_depth: the need is $hi, not the recorded $SEED -- update BRACKET_SEED"
    echo "bracket_depth: in tools/bracket_depth_check.sh (this run bisected, which is 10"
    echo "bracket_depth: compiles instead of 2; the number is right either way)."
  fi
fi

margin=$(( BUDGET - hi ))
echo "bracket_depth: needs $hi, the build passes $BUDGET — $margin to spare"
# ...and whether the DEFAULT would still do is reported separately: it is the thing that
# changed, and a check that only watched the flag would never have said so.
if [ "$hi" -le 256 ]; then
  echo "bracket_depth: the mainline default of 256 would also do — the flag is headroom"
else
  echo "bracket_depth: over the mainline default of 256 by $(( hi - 256 )) — the flag is LOAD-BEARING,"
  echo "bracket_depth: a build without -fbracket-depth does not compile."
fi
# A margin this thin is the thing worth saying out loud; it is not a failure.
[ "$margin" -lt 128 ] && echo "bracket_depth: that is thin. One more long chain and the build stops."
echo "bracket_depth: ok"
