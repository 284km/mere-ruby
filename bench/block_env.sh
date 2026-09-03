#!/bin/sh
# What does one BLOCK invocation cost against one `while` iteration, and is
# either given back?
#
#   ./bench/block_env.sh [path/to/mere-ruby]
#
# Four programs, each run at 100k / 200k / 400k iterations; the slope
# (bytes per iteration, from the 100k->400k peak-RSS difference) is the answer,
# because a constant is a fixed cost and a slope is a leak. The four differ in
# exactly one thing each:
#
#   while_bare    while i < n;  x = x + 1; i += 1; end       (a statement)
#   while_call    while i < n;  x = f(x);  i += 1; end       (+ a method call)
#   times_bare    n.times { x = x + 1 }                      (block instead of while)
#   times_call    n.times { x = f(x) }                       (both)
#
# Measured 2026-09-03 (HEAD c2ea241, before block-env pooling):
#   while_bare 135 B/iter  while_call 599  times_bare 1004  times_call 1617
#   -> a method call costs ~460 B, a block invocation ~870 B MORE than a while
#      iteration. CRuby is flat at 34 MB for all four.
# The block's extra was `lv_child`: a fresh env Map in the default region plus
# a permanent lv_up entry per invocation, where a method call takes its frame
# from frame_pool and gives it back. The `pool_*` / `blk_*` rows printed at the
# end (MERE_RUBY_STORE_STATS) are the deterministic side of the same question:
# `blk_puts` close to the iteration count means the block envs came back.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="${1:-$here/../mere-ruby}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gen() { # form n -> writes $tmp/p.rb
  case "$1" in
    while_bare) printf 'x = 0; i = 0\nwhile i < %s\n  x = x + 1\n  i += 1\nend\nputs x\n' "$2" ;;
    while_call) printf 'def f(a); a + 1; end\nx = 0; i = 0\nwhile i < %s\n  x = f(x)\n  i += 1\nend\nputs x\n' "$2" ;;
    times_bare) printf 'x = 0\n%s.times { |i| x = x + 1 }\nputs x\n' "$2" ;;
    times_call) printf 'def f(a); a + 1; end\nx = 0\n%s.times { |i| x = f(x) }\nputs x\n' "$2" ;;
    lambda_call) printf 'l = ->(a) { a + 1 }\nx = 0\n%s.times { |i| x = l.call(x) }\nputs x\n' "$2" ;;
  esac > "$tmp/p.rb"
}

rss() { /usr/bin/time -l "$@" 2>&1 >/dev/null | awk '/maximum resident set size/ {print $1}'; }

# Peak RSS is the OS's answer and it is not reproducible here: the same binary
# on the same program gave 265 MB and 406 MB in two runs (2026-09-03). The
# region allocator's own counters are (MERE_REGION_STATS=1, mere v0.1.307+):
#   default   bytes ever allocated into the region nothing gives back
#   stmt_peak the largest a `region STMT` block grew -- an iterator's enclosing
#             statement holding per-iteration scratch until the loop ends
# Both are printed for the 400k run; the RSS slope stays as the coarse check.
printf '%-12s %12s %12s %12s %8s %14s %12s\n' form 100k 200k 400k B/iter default@400k stmt_peak
for form in while_bare while_call times_bare times_call lambda_call; do
  row=""; first=0; last=0
  for n in 100000 200000 400000; do
    gen "$form" "$n"
    r=$(rss "$mr" "$tmp/p.rb")
    row="$row $(printf '%12s' "$r")"
    [ "$n" = 100000 ] && first=$r
    last=$r
  done
  st=$(MERE_REGION_STATS=1 "$mr" "$tmp/p.rb" 2>&1 >/dev/null)
  dflt=$(printf '%s\n' "$st" | awk '/region-stats default:/ {sub("alloc_total=","",$NF); print $NF}')
  stmt=$(printf '%s\n' "$st" | awk '/named region STMT:/ {for(i=1;i<=NF;i++) if ($i ~ /^peak_cap=/) {sub("peak_cap=","",$i); print $i}}')
  printf '%-12s%s %8s %14s %12s\n' "$form" "$row" "$(( (last - first) / 300000 ))" "${dflt:-n/a}" "${stmt:-n/a}"
done

echo
echo "pool rows for times_call at 400k (MERE_RUBY_STORE_STATS=1):"
gen times_call 400000
MERE_RUBY_STORE_STATS=1 "$mr" "$tmp/p.rb" 2>&1 >/dev/null | grep -E '^(pool_|blk_|lv_up)' | tr '\n' ' '
echo
