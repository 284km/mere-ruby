#!/bin/sh
# Why do the bootstraptest pairs not pass? `all.sh` counts pass / fail / err,
# but a count does not say whether it is 300 causes or 3. This groups them:
# an ERR (non-zero exit) by its message, a FAIL (ran, wrong output) by what it
# printed instead.
#
#   ./bootstraptest/triage.sh <path/to/ruby/checkout> [pairs_dir]
#   ./bootstraptest/triage.sh --fail <path/to/ruby/checkout> [pairs_dir]
#
# Writes bootstraptest/ERRORS.txt (one line per erroring pair, message first,
# sorted so the same cause groups together) and prints the top causes with a
# count and one example each.
#
# The message is normalised before grouping: a path, a line number, and the
# text inside quotes are what make two reports of the same missing feature
# look different.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mode=err
if [ "${1:-}" = "--fail" ]; then mode=fail; shift; fi
ruby_src="${1:?usage: triage.sh [--fail] <ruby-checkout> [pairs_dir]}"
dir="${2:-/tmp/mrb_bt}"
[ -d "$dir" ] || { echo "no pairs in $dir -- run all.sh first"; exit 2; }
out="$here/ERRORS.txt"
[ "$mode" = fail ] && out="$here/FAILS.txt"
: > "$out"
# Pairs that ran past the alarm, kept apart from the causes (see the timeout arm
# below). Written in both modes so the file never describes an older run.
slowout="$here/SLOW.txt"
: > "$slowout"

for rb in "$dir"/*/p*.rb; do
  [ -f "$rb" ] || continue
  flags=""
  [ -f "${rb%.rb}.flags" ] && flags=$(cat "${rb%.rb}.flags")
  # a pair whose expectation the reference ruby cannot reproduce is drift, not
  # a cause worth grouping (see all.sh)
  if [ "${BT_NO_DRIFT_CHECK:-}" != 1 ]; then
    exp=$(cat "${rb%.rb}.exp")
    rbgot=$(perl -e 'alarm 20; exec @ARGV' ruby $flags -e 'print(eval(File.read(ARGV[0]), TOPLEVEL_BINDING, ARGV[0]))' "$rb" 2>/dev/null)
    [ "$rbgot" != "$exp" ] && continue
  fi
  if [ "$mode" = fail ]; then
    # a FAIL ran to completion and printed the wrong thing: group by what it
    # printed, next to what was wanted
    got=$(perl -e 'alarm 60; exec @ARGV' "$here/../mere-ruby" $flags --eval-print "$rb" 2>/dev/null)
    [ $? -ne 0 ] && continue
    want=$(cat "${rb%.rb}.exp")
    [ "$got" = "$want" ] && continue
    printf 'want %s | got %s\t%s\n' "$(printf '%s' "$want" | tr '\n' ' ' | cut -c1-60)" \
      "$(printf '%s' "$got" | tr '\n' ' ' | cut -c1-60)" "$rb" >> "$out"
    continue
  fi
  msg=$(perl -e 'alarm 60; exec @ARGV' "$here/../mere-ruby" $flags --eval-print "$rb" 2>&1 >/dev/null)
  code=$?
  [ $code -eq 0 ] && continue
  # A timeout is not a cause, it is the harness's limit -- grouping it with the
  # NoMethodErrors put a pair that moves with machine load into the same tally
  # as pairs that move with the interpreter. It goes to its own file so
  # "err pairs" counts what the name says. all.sh keys on the same two codes.
  if [ $code -eq 142 ] || [ $code -eq 14 ]; then
    printf '(timeout)\t%s\n' "$rb" >> "$slowout"
    continue
  fi
  # last line of stderr, minus the parts that differ between two reports of
  # the same cause -- the path and the line number. The NAME inside the quotes
  # is kept: "undefined method" is not a cause, "undefined method 'itself'" is.
  norm=$(printf '%s' "$msg" | tail -1 \
    | sed "s#$dir/[^ :]*##g" \
    | sed 's/near line [0-9]*//' \
    | sed 's/  */ /g')
  [ -z "$norm" ] && norm="(no message, exit $code)"
  printf '%s\t%s\n' "$norm" "$rb" >> "$out"
done

sort "$out" -o "$out"
echo "$mode pairs: $(wc -l < "$out" | tr -d ' ')"
nslow=$(wc -l < "$slowout" | tr -d ' ')
[ "$nslow" -gt 0 ] && echo "slow pairs: $nslow (ran past the alarm -- see bootstraptest/SLOW.txt)"
echo
echo "top causes:"
cut -f1 "$out" | sort | uniq -c | sort -rn | head -20
