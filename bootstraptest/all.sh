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
pass=0; fail=0; err=0; total=0
for rb in "$dir"/*/p*.rb; do
  [ -f "$rb" ] || continue
  exp=$(cat "${rb%.rb}.exp")
  flags=""
  [ -f "${rb%.rb}.flags" ] && flags=$(cat "${rb%.rb}.flags")
  got=$(perl -e 'alarm 15; exec @ARGV' "$here/../mere-ruby" $flags --eval-print "$rb" 2>/dev/null)
  code=$?
  total=$((total + 1))
  if [ "$got" = "$exp" ] && [ "$code" -eq 0 ]; then pass=$((pass + 1))
  elif [ "$code" -ne 0 ]; then err=$((err + 1))
  else fail=$((fail + 1)); fi
done
echo "pass=$pass fail=$fail err=$err total=$total"
