#!/bin/sh
# Extract every CRuby bootstraptest file into a pairs directory and tally the
# lot under ./mere-ruby.
#
#   ./bootstraptest/all.sh <path/to/ruby/checkout> [pairs_dir]
#
# The pairs are derived, not checked in: point this at a ruby checkout and it
# rebuilds them. (They used to live only in /tmp, which meant a cleared /tmp
# took the gate with it.)
#
# No `set -e`: a test whose interpreter exits non-zero is a RESULT (err), not
# a reason to stop counting -- that is the whole point of the tally.
here="$(cd "$(dirname "$0")" && pwd)"
ruby_src="$1"
dir="${2:-/tmp/mrb_bt}"
[ -d "$ruby_src/bootstraptest" ] || { echo "usage: all.sh <ruby-checkout> [pairs_dir]"; exit 2; }
mkdir -p "$dir"
for f in "$ruby_src"/bootstraptest/test_*.rb; do
  b=$(basename "$f" .rb)
  ruby "$here/extract.rb" "$f" "$dir/$b" >/dev/null 2>&1 || true
done
# The expectations come from the ruby CHECKOUT, which may be far newer than
# the ruby this interpreter emulates (3.2.2, which is also what every other
# gate compares against). A pair whose expectation the reference ruby itself
# does not produce is DRIFT -- ruby 3.4 froze string literals and changed
# Hash#inspect, and "fixing" those here would break the corpus. Set
# BT_NO_DRIFT_CHECK=1 to skip the check (it doubles the run time).
pass=0; fail=0; err=0; drift=0; total=0
for rb in "$dir"/*/p*.rb; do
  [ -f "$rb" ] || continue
  exp=$(cat "${rb%.rb}.exp")
  flags=""
  [ -f "${rb%.rb}.flags" ] && flags=$(cat "${rb%.rb}.flags")
  # 60s, not 15: the largest generated test (a 241k-line if/else chain) runs
  # in ~16s here, so a 15s alarm made the tally flip between pass and err run
  # to run. A gate has to measure the interpreter, not the cutoff.
  if [ "${BT_NO_DRIFT_CHECK:-}" != 1 ]; then
    rbgot=$(perl -e 'alarm 20; exec @ARGV' ruby $flags -e 'print(eval(File.read(ARGV[0]), TOPLEVEL_BINDING, ARGV[0]))' "$rb" 2>/dev/null)
    if [ "$rbgot" != "$exp" ]; then
      drift=$((drift + 1))
      total=$((total + 1))
      continue
    fi
  fi
  got=$(perl -e 'alarm 60; exec @ARGV' "$here/../mere-ruby" $flags --eval-print "$rb" 2>/dev/null)
  code=$?
  total=$((total + 1))
  if [ "$got" = "$exp" ] && [ "$code" -eq 0 ]; then pass=$((pass + 1))
  elif [ "$code" -ne 0 ]; then err=$((err + 1))
  else fail=$((fail + 1)); fi
done
echo "pass=$pass fail=$fail err=$err drift=$drift total=$total (of $((total - drift)) pairs the reference ruby reproduces)"
