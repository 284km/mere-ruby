#!/bin/sh
# Where a regexp's time goes, workload by workload, against the reference
# ruby: the CPU seconds of each (best of REPS, default 3) and the count it
# answered, which must agree before the seconds mean anything.
#
#   ./bench/regexp.sh [path/to/mere-ruby]
#
# The workloads (bench/regexp_bench.rb) are the shapes a program asks of a
# regexp: scanning words, a literal in a long text, an alternation, /i, a
# capture per line, `=~` on many small strings. Small strings measure the
# call; long ones the search and the engine.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="${1:-$here/../mere-ruby}"
. "$here/../tools/ref_ruby.sh"
W="scan_words scan_email gsub_digits split_csv match_lines capture_log literal_find anchored alternation dotstar classes ci nomatch"
best() {
  bin=$1; wl=$2; m=""; c=""
  for _ in $(seq 1 "${REPS:-3}"); do
    set -- $("$bin" "$here/regexp_bench.rb" "$wl")
    t=$2; c=$3
    if [ -z "$m" ] || [ "$(echo "$t < $m" | bc)" = 1 ]; then m=$t; fi
  done
  echo "$m $c"
}
printf '%-13s %9s %9s %7s  %s\n' workload ruby mere-ruby ratio count
for w in $W; do
  set -- $(best "$REF_RUBY_BIN" "$w"); rt=$1; rc=$2
  set -- $(best "$mr" "$w"); mt=$1; mc=$2
  ratio=$(echo "scale=1; $mt / ($rt + 0.0005)" | bc)
  [ "$rc" = "$mc" ] && cnt=$rc || cnt="DIFFER ruby=$rc mere-ruby=$mc"
  printf '%-13s %9s %9s %6sx  %s\n' "$w" "$rt" "$mt" "$ratio" "$cnt"
done
