#!/bin/sh
# WHY are the DIFFs different? The scoreboard counts 603 of them, and a wording
# difference and a wrong answer are the same verdict there -- so working any
# single DIFF down without this is guesswork.
#
#   ./mspec/classify.sh <spec-root> [group ...]     # default: the recorded groups
#
# For every DIFF (and CRASH) file in mspec/tags/, this runs the spec under both
# interpreters again, takes mere-ruby's FAILED/ERROR lines, and buckets them by
# CAUSE rather than by file: the example's description is dropped and what is
# left -- "expected X, got Y", or the error class -- is the bucket. The most
# common failure is the one worth naming, and it is the one nobody has named yet
# (a per-file list makes every cause look equally rare).
#
# One bucket is asked for explicitly: a difference that is ONLY the wording of an
# error message. This interpreter follows ruby 3.4's wording ("undefined method
# 'x' for an instance of C") while every gate compares against 3.2.2 (`x' for
# x:C), so those DIFFs are a choice, not a gap, and counting them tells us how
# much of the 603 is real.
#
# Writes mspec/DIFF_CAUSES.txt (the ranked causes) and mspec/DIFF_LINES.txt
# (one line per failing example, so a cause can be traced back to its files).
#
# Both are CHECKED IN and public, so the recorded line gets the same treatment
# scoreboard.sh gives its causes: $HOME, the tmpdir and heap addresses masked,
# and a length cap. core/kernel/__dir___spec.rb reports the directory it ran in,
# which put the operator's home path into this file and kept it there across
# seven commits -- and `grep` did not show it, because a record with invalid
# UTF-8 bytes reads as binary. mspec/record_hygiene.sh is the check for both.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
specroot="${1:?usage: classify.sh <spec-root> [group ...]}"
shift
groups="$*"
if [ -z "$groups" ]; then
  groups="$(sed -n 's/^| \([a-z][a-z_/-]*\) |.*/\1/p' "$root/SPEC_STATUS.md" 2>/dev/null \
            | grep -v '^group$' | tr '\n' ' ')"
fi
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
lines="$here/DIFF_LINES.txt"
: > "$lines"
files=0
for g in $groups; do
  tag="$here/tags/$(printf '%s' "$g" | tr '/' '_').txt"
  [ -f "$tag" ] || continue
# The bucket has to be a DIFFERENCE, not a failure. This shim is not real
# mspec: it has no IOStub, no #should_receive, no mock_int, so plenty of
# examples raise NoMethodError on BOTH sides -- identically, so they are not
# what makes the file a DIFF. Recording only mere-ruby's side counted 399
# NoMethodErrors, and core/kernel/warn_spec's 24 of them were every one a
# missing facility in this file rather than a missing method in mere-ruby.
# Working that bucket would have changed no verdict at all.
#
# So each side's lines are collected and the RUBY side is subtracted. What is
# left is what mere-ruby fails and ruby does not.
raw_m="$(mktemp)"; raw_r="$(mktemp)"
trap 'rm -f "$raw_m" "$raw_r"' EXIT INT TERM
normalise() {
  grep -a '^FAILED:\|^ERROR:' \
    | sed -e "s|${HOME}[^ \"]*|HOME|g" \
          -e 's|/var/folders/[^ ]*|TMPDIR|g' \
          -e 's|{"[^}]*}|{...}|g' \
          -e 's|{"[^}]*$|{...|' \
          -e 's|0x[0-9a-f]*|0xADDR|g' \
    | awk -v n=300 '{ if (length($0) > n) print substr($0,1,n) " ...[clipped]"; else print $0 }'
}
bucket() {
  sed -e 's/^ERROR: .*: \([A-Za-z:]*Error\)$/ERROR\t\1/' \
      -e 's/^FAILED: raised \([A-Za-z:]*\), expected \([A-Za-z:]*\)$/RAISED\traised \1, expected \2/' \
      -e 's/^FAILED: .*: \(expected .*\)$/FAILED\t\1/' \
      -e 's/^FAILED: \(.*\)$/FAILED\t\1/' \
      -e 's/^ERROR: \(.*\)$/ERROR\t\1/'
}
for f in $(awk '$1 == "DIFF" || $1 == "CRASH" { print $2 }' "$tag"); do
    files=$((files+1))
    out="$("$here/run_spec.sh" "$specroot/$f" 2>&1)"
    printf '%s\n' "$out" | sed -n '/^--- mere-ruby:/,/^--- ruby:/p' | normalise | sort > "$raw_m"
    printf '%s\n' "$out" | sed -n '/^--- ruby:/,$p'                 | normalise | sort > "$raw_r"
    # -23: the lines only mere-ruby has. A line both sides print is the shim
    # failing the same way twice, which is not a finding about mere-ruby.
    comm -23 "$raw_m" "$raw_r" \
      | bucket \
      | while IFS= read -r rec; do printf '%s\t%s\t%s\n' "$g" "$f" "$rec" >> "$lines"; done
  done
done

# A cause is the record with its numbers and quoted contents left alone: the
# quotes ARE the difference in a wording bucket, so normalising them away would
# hide exactly what this script is for.
causes="$here/DIFF_CAUSES.txt"
{
  echo "# ranked causes of the DIFF/CRASH files: lines mere-ruby fails and ruby does NOT"
  echo "# (a line both sides print is this shim failing twice, and is subtracted)"
  echo "# $(awk 'END {print NR}' "$lines") failing examples across $files files"
  echo
  cut -f3,4 "$lines" | sort | uniq -c | sort -rn | head -60
  echo
  echo "# wording-only: expected/got that differ by ruby 3.2's \`x' against 3.4's 'x',"
  echo "# or by \"for x:C\" against \"for an instance of C\" -- a choice, not a gap"
  awk -F'\t' '$4 ~ /expected .*got /' "$lines" \
    | awk -F'\t' '{ e = $4; sub(/^expected /, "", e); n = index(e, ", got "); if (n == 0) next;
                    exp = substr(e, 1, n-1); got = substr(e, n+6);
                    ge = exp; gg = got;
                    gsub(/`/, "'"'"'", ge); gsub(/`/, "'"'"'", gg);
                    gsub(/'"'"'/, "", ge); gsub(/'"'"'/, "", gg);
                    gsub(/ for [^ ]*:[A-Za-z:]*/, " for an instance of C", ge);
                    gsub(/ for an instance of [A-Za-z:]*/, " for an instance of C", gg);
                    if (ge == gg) print "WORDING\t" $4; else print "REAL\t" $4 }' \
    | cut -f1 | sort | uniq -c | sort -rn
} > "$causes"
echo "wrote $causes and $lines"
tail -n +2 "$causes" | head -24
