#!/bin/sh
# tools/rx_budget_rss_check.rb, run once: a search that walks hundreds of
# millions of steps must stay under 600 MB at its peak (1.6 GB at 20 million
# steps while the VM kept every choice it had made; about 175 MB now at 200
# million, most of it the interpreter itself).
#
#   ./tools/rx_budget_rss_check.sh [path/to/mere-ruby]     exit 1 over the cap
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="${1:-$here/../mere-ruby}"
CAP_MB=600
out=$( { /usr/bin/time -l "$mr" "$here/rx_budget_rss_check.rb"; } 2>&1 ) || true
kb=$(printf '%s\n' "$out" | awk '/maximum resident/ {print int($1 / 1024)}')
if [ -z "$kb" ]; then
  out=$( { /usr/bin/time -v "$mr" "$here/rx_budget_rss_check.rb"; } 2>&1 ) || true
  kb=$(printf '%s\n' "$out" | awk '/Maximum resident/ {print $6}')
fi
[ -n "$kb" ] || { echo "rx_budget_rss: no /usr/bin/time here -- cannot answer"; exit 2; }
# (it walks to the step budget, or -- were the budget ever past what the
#  search needs -- to its answer, nil: either way, hundreds of millions of steps)
printf '%s\n' "$out" | grep -q -e '^:timeout$' -e '^:miss$' || { echo "rx_budget_rss: FAIL -- the search answered $(printf '%s\n' "$out" | head -1), not a timeout or a miss"; exit 1; }
mb=$((kb / 1024))
if [ "$mb" -lt "$CAP_MB" ]; then echo "rx_budget_rss: ok -- $mb MB at the peak of a search of hundreds of millions of steps"; exit 0; fi
echo "rx_budget_rss: FAIL -- $mb MB at the peak of a search of hundreds of millions of steps (cap $CAP_MB)"; exit 1
