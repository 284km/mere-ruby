#!/bin/sh
# How much memory does one Ruby method call cost, and is it ever given back?
#
#   ./bench/alloc_per_call.sh [path/to/mere-ruby]
#
# Runs the same program with 100k / 200k / 400k method calls and prints peak
# RSS for each. The answer is the slope: memory here is linear in the number of
# calls EXECUTED (not in the number of definitions made), because the
# interpreter allocates in a region that is never reclaimed. See KNOWN_GAPS.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="${1:-$here/../mere-ruby}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '%-10s %-10s %-12s %s\n' calls real peak-rss bytes/call
for n in 100000 200000 400000; do
  cat > "$tmp/loop.rb" <<EOF
def f(a)
  a + 1
end
x = 0
$n.times { |i| x = f(x) }
puts x
EOF
  out=$(/usr/bin/time -l "$mr" "$tmp/loop.rb" 2>&1 >/dev/null)
  real=$(printf '%s' "$out" | awk '/real/ {print $1}')
  rss=$(printf '%s' "$out" | awk '/maximum resident set size/ {print $1}')
  printf '%-10s %-10s %-12s %s\n' "$n" "$real" "$rss" "$((rss / n))"
done

# For comparison, the same shape of program with definitions instead of calls:
# 1600 classes with two methods each. That one IS cheap, which is what rules
# out "superlinear in the number of definitions" as the explanation.
{
  i=0
  while [ $i -lt 1600 ]; do
    echo "class K$i"
    echo "  def m1(a); a + 1; end"
    echo "  def m2(a); m1(a) * 2; end"
    echo "end"
    i=$((i + 1))
  done
  echo 'puts :done'
} > "$tmp/defs.rb"
out=$(/usr/bin/time -l "$mr" "$tmp/defs.rb" 2>&1 >/dev/null)
printf '%-10s %-10s %-12s %s\n' "1600defs" \
  "$(printf '%s' "$out" | awk '/real/ {print $1}')" \
  "$(printf '%s' "$out" | awk '/maximum resident set size/ {print $1}')" -
