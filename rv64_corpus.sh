#!/bin/sh
# rv64_corpus.sh — run the corpus through mere-ruby COMPILED FOR RISC-V,
# executing on the Mere-written emulator, and compare against the reference ruby.
#
# The host build of mere-ruby is C. This measures the other target: main.mere
# compiled to a flat RV64IM binary and run on a CPU that is itself a Mere
# program. Everything the interpreter needs -- the parser, the object model, the
# GC, string building -- has to work on a machine with no libc under it.
#
# The number this prints was measured by hand during the RV64 arc and quoted
# from a note afterwards, which is how a measurement stops being reproducible.
# It lives here now so the next person can re-run it instead of trusting it.
#
# A program that DIFFERS is reported by name. A program the backend refuses at
# compile time is reported separately: refusing is a documented limit, answering
# wrongly is not, and a gate that adds them together hides which one moved.
#
# Usage:
#   MERE=/path/to/mere.exe MEMU=/path/to/memu sh rv64_corpus.sh
#   ... RAM=256 TIMEOUT=120 sh rv64_corpus.sh
set -u
: "${MERE:?set MERE to a mere binary}"
: "${MEMU:?set MEMU to a memu checkout}"
RAM="${RAM:-256}"
TIMEOUT="${TIMEOUT:-120}"
CC="${CC:-cc}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"; export RUBYOPT
TMP=$(mktemp -d "${TMPDIR:-/tmp}/mere_ruby_rv64.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

echo "rv64_corpus: building the RV64 emulator"
"$MERE" -c "$MEMU/riscv-runc/rv64i_run.mere" > "$TMP/rvrun64.c" 2>"$TMP/err" \
  || { echo "FAIL: the emulator did not emit"; head -5 "$TMP/err"; exit 1; }
$CC -O2 -w -o "$TMP/rvrun64" "$TMP/rvrun64.c" 2>"$TMP/err" \
  || { echo "FAIL: cc refused the emulator"; head -5 "$TMP/err"; exit 1; }

echo "rv64_corpus: compiling main.mere for RV64 (--ram $RAM)"
if ! "$MERE" -rv64 --ram "$RAM" "$ROOT/main.mere" > "$TMP/prog.bin" 2>"$TMP/err"; then
  echo "FAIL: the RISC-V backend refused mere-ruby itself"; head -20 "$TMP/err"; exit 1
fi
echo "rv64_corpus: prog.bin is $(wc -c < "$TMP/prog.bin") bytes"

# "answers differently" and "did not finish in $TIMEOUT seconds on an emulated
# CPU" are different facts, and adding them together makes the slow ones look
# like wrong ones. The alarm's exit status separates them.
same=0; diff_n=0; slow=0; noref=0; diff_names=""; slow_names=""
for f in "$ROOT"/corpus/*.rb; do
  name=$(basename "$f")
  if ! ruby "$f" > "$TMP/exp.txt" 2>/dev/null; then noref=$((noref+1)); continue; fi
  # The emulator loads prog.bin from its working directory and passes what
  # follows `--` to the guest, so the .rb path has to be one the guest can open.
  ( cd "$TMP" && perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" \
      ./rvrun64 "$RAM" -- "$f" 2>/dev/null ) > "$TMP/raw.txt" 2>/dev/null
  grc=$?
  grep -a -v '^rvrun: ' "$TMP/raw.txt" > "$TMP/got.txt"
  # SIGALRM is 14; perl's alarm kills the exec'd emulator, so 14 or 128+14
  if [ "$grc" -eq 14 ] || [ "$grc" -eq 142 ]; then
    slow=$((slow+1)); slow_names="$slow_names $name"; continue
  fi
  if cmp -s "$TMP/exp.txt" "$TMP/got.txt"; then same=$((same+1))
  else diff_n=$((diff_n+1)); diff_names="$diff_names $name"; fi
done

total=$((same + diff_n + slow))
echo
echo "rv64_corpus: $same/$total agree with the reference ruby (mere-ruby on RV64)"
[ "$noref" -gt 0 ] && echo "rv64_corpus: $noref skipped (the reference ruby itself failed)"
if [ "$diff_n" -gt 0 ]; then
  echo "rv64_corpus: $diff_n answer differently, by name:"
  for n in $diff_names; do echo "    $n"; done
fi
if [ "$slow" -gt 0 ]; then
  echo "rv64_corpus: $slow did not finish in ${TIMEOUT}s (emulation speed, not a wrong answer):"
  for n in $slow_names; do echo "    $n"; done
fi
