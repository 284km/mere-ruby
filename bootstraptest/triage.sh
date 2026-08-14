#!/bin/sh
# Why do the bootstraptest pairs ERROR? `all.sh` counts pass / fail / err, and
# err (a non-zero exit) is the biggest of the three -- but a count does not say
# whether it is 300 causes or 3. This groups the error MESSAGES.
#
#   ./bootstraptest/triage.sh <path/to/ruby/checkout> [pairs_dir]
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
ruby_src="${1:?usage: triage.sh <ruby-checkout> [pairs_dir]}"
dir="${2:-/tmp/mrb_bt}"
[ -d "$dir" ] || { echo "no pairs in $dir -- run all.sh first"; exit 2; }
out="$here/ERRORS.txt"
: > "$out"

for rb in "$dir"/*/p*.rb; do
  [ -f "$rb" ] || continue
  flags=""
  [ -f "${rb%.rb}.flags" ] && flags=$(cat "${rb%.rb}.flags")
  msg=$(perl -e 'alarm 60; exec @ARGV' "$here/../mere-ruby" $flags --eval-print "$rb" 2>&1 >/dev/null)
  code=$?
  [ $code -eq 0 ] && continue
  if [ $code -eq 142 ] || [ $code -eq 14 ]; then
    printf '(timeout)\t%s\n' "$rb" >> "$out"
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
echo "erroring pairs: $(wc -l < "$out" | tr -d ' ')"
echo
echo "top causes:"
cut -f1 "$out" | sort | uniq -c | sort -rn | head -20
