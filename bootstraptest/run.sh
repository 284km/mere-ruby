#!/bin/sh
# Run every extracted bootstraptest pair through `mere-ruby --eval-print`
# and tally pass / fail (wrong output) / err (aborted). Pass the directory
# of extracted p<N>.rb / p<N>.exp files.
#
#   ./run.sh <pairs_dir> [--show-fails]
dir="$1"
mr="$(dirname "$0")/../mere-ruby"
pass=0; fail=0; err=0; total=0
for rb in "$dir"/p*.rb; do
  [ -f "$rb" ] || continue
  exp=$(cat "${rb%.rb}.exp")
  # per-test wall-clock cap so a runaway loop can't stall the run
  # (portable timeout via perl's alarm, since `timeout` may be absent).
  got=$(perl -e 'alarm 5; exec @ARGV' "$mr" --eval-print "$rb" 2>/dev/null)
  code=$?
  total=$((total + 1))
  if [ "$got" = "$exp" ] && [ "$code" -eq 0 ]; then
    pass=$((pass + 1))
  elif [ "$code" -ne 0 ]; then
    err=$((err + 1))
    [ "$2" = "--show-errs" ] && echo "ERR  $rb : $(head -1 "$rb")"
  else
    fail=$((fail + 1))
    [ "$2" = "--show-fails" ] && echo "FAIL $rb : got=[$got] exp=[$exp] : $(head -1 "$rb")"
  fi
done
echo "pass=$pass fail=$fail err=$err total=$total"
