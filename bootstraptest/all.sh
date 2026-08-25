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
# The reference ruby's own output depends on its default external encoding:
# with the locale unset (or not UTF-8) `p "にち"` escapes to "\u306B\u3061",
# while mere-ruby has one behaviour and prints the bytes. That made corpus/118
# fail on a machine where LANG is not set -- the interpreter measuring the same
# as ever, the environment answering differently. -Eutf-8 pins the reference
# instead of trusting the shell (a locale name would need that locale to exist;
# this option does not).
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
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
# Two pairs move on things that are not the interpreter, so neither belongs in
# err. test_thread/p24 runs a thread with `while true; // =~ "" end` and finishes
# or does not depending on which limit trips first -- the step budget or the
# native stack -- so it flips between -O1 and -Os. test_yjit_30k_methods/p0 is
# 121k lines and takes ~87s unloaded against the alarm below, so it flips with
# machine load. The second one cost a whole investigation: the tally read
# 1571/12/57 against a recorded 1572/12/56, and rebuilding the recorded commit
# reproduced 57 with a byte-identical err set -- the regression was in the meter,
# not the interpreter.
#
# A timeout is therefore its own verdict (SLOW), the way mspec/scoreboard.sh has
# counted it since 2026-08-19: it says "ran past this harness's limit", which is
# not what err says ("the interpreter exited non-zero"). Raising the alarm is not
# the fix -- it was already raised once (15 -> 60, see below) and a bigger
# generated test walked past the new number too. Only a separate column stops the
# tally from moving when nothing did.
pass=0; fail=0; err=0; slow=0; drift=0; total=0
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
  # 142 is perl's exit after the alarm signal (128+SIGALRM), 14 the bare signal
  # number -- triage.sh keys on the same two, so the two scripts agree on what a
  # timeout is rather than each deciding for itself.
  if [ "$got" = "$exp" ] && [ "$code" -eq 0 ]; then pass=$((pass + 1))
  elif [ "$code" -eq 142 ] || [ "$code" -eq 14 ]; then slow=$((slow + 1))
  elif [ "$code" -ne 0 ]; then err=$((err + 1))
  else fail=$((fail + 1)); fi
done
echo "pass=$pass fail=$fail err=$err slow=$slow drift=$drift total=$total (of $((total - drift)) pairs the reference ruby reproduces)"
