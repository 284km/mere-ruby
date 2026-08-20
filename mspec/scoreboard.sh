#!/bin/sh
# Sweep ruby/spec directories and record what mere-ruby does and does NOT
# pass, so the gap is visible from outside. This is mere-ruby's equivalent of
# the tags/filter files the other alternative implementations keep: the point
# is an honest, checked-in record of known-not-passing specs, not a green CI.
#
# For each spec file it runs the mspec shim under BOTH mere-ruby and ruby and
# compares byte-for-byte (see run_spec.sh). A file is one of:
#   MATCH  - identical output on both
#   DIFF   - runs on both, output differs (feature fidelity gap)
#   CRASH  - mere-ruby aborts where ruby does not (missing feature / bug)
#   SKIP   - ruby itself errors/does not run (unmeasurable here)
#
# Usage:
#   ./scoreboard.sh <spec-root> [dir ...]     # e.g. .../spec/ruby language core/array
#   ./scoreboard.sh <spec-root>               # default: re-sweep every group the
#                                             # recorded table already has a row for
#
# The default used to read "language core", which measured language ALONE: there
# are no *_spec.rb directly under core/, so that word was skipped in silence
# while the table kept its core rows from an older run -- a refresh that looked
# whole and was not. The default now comes from the record itself, so the
# invitation at the bottom of SPEC_STATUS.md ("re-run to refresh") is true, and a
# group added to the table is swept from then on without editing this script.
# Writes SPEC_STATUS.md (summary table) and mspec/tags/<group>.txt (the
# per-file DIFF/CRASH records — the "known not passing" list).
set -u
# Pin the reference's encoding, as run_corpus.sh and bootstraptest do: with the
# locale unset, ruby's default external encoding is US-ASCII and `inspect`
# escapes every non-ASCII byte, while mere-ruby prints the bytes -- core/string
# is full of specs where that decides the verdict. The table below was measured
# WITHOUT this, so pinning it and re-sweeping have to happen together.
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:?usage: scoreboard.sh <spec-root> [dir ...]}"
shift
dirs="$*"
if [ -z "$dirs" ]; then
  # column 1 of the recorded table, minus the header rows
  # ... and not the header, whose first cell reads "group"
  dirs="$(sed -n 's/^| \([a-z][a-z_/-]*\) |.*/\1/p' "$here/../SPEC_STATUS.md" 2>/dev/null | grep -v '^group$' | tr '\n' ' ')"
  [ -n "$dirs" ] || dirs="language"
fi
tagdir="$here/tags"
mkdir -p "$tagdir"
# write to a per-pid temp and move into place at the end, so two runs never
# interleave their writes into SPEC_STATUS.md (they would produce a garbled,
# doubled table otherwise).
status="$here/../SPEC_STATUS.md.$$"
status_final="$here/../SPEC_STATUS.md"

# 60s, not 30: the heaviest file here (core/string/modulo_spec.rb) spends ~26s of
# CPU on its own, so 30 left almost no margin under the load of a sweep -- and a
# file the alarm kills is not the same finding as a file that aborts, which is
# what TIMEOUT below is for. (modulo_spec does abort, for its own reasons: its
# mere-ruby side stops before it prints a tally, under this build and under the
# build before it.)
TIMEOUT=60
run_one() {  # $1 = spec file -> echoes MATCH/DIFF/CRASH/SKIP/TIMEOUT
  # Through a FILE, not a pipe: the alarm's status has to be perl's, and `$?`
  # after a pipeline is the last stage's (`tr` always succeeds). Read off an
  # empty output, a killed run is indistinguishable from an abort. (`pipefail`
  # would do it too, but it is a bashism and these harnesses also run under dash.)
  raw="$(mktemp)"
  perl -e "alarm $TIMEOUT; exec @ARGV" sh "$here/run_spec.sh" "$1" > "$raw" 2>/dev/null
  rc=$?
  # LC_ALL=C on the `tr`: a spec whose output carries bytes that are not valid
  # UTF-8 (core/string's chars, chr, grapheme_clusters, ...) makes `tr` FAIL under
  # a UTF-8 locale, which empties the output and turns the verdict into SKIP or
  # CRASH. The number then depended on the locale of whoever ran the sweep:
  # measured in ja_JP.UTF-8, core/string reported 12 SKIPs and 5 extra CRASHes
  # that are not there in C.
  out="$(LC_ALL=C tr -d '\0' < "$raw")"
  rm -f "$raw"
  case $rc in 142|14) echo TIMEOUT; return;; esac
  verdict="$(printf '%s' "$out" | tail -1)"
  if [ "$verdict" = "MATCH" ]; then echo MATCH; return; fi
  # ruby side empty tally => unmeasurable (ruby itself didn't run the examples)
  rb="$(printf '%s' "$out" | sed -n '/--- ruby:/,$p' | grep -a 'pass=' | tail -1)"
  mr="$(printf '%s' "$out" | sed -n '/--- mere-ruby:/,/--- ruby:/p' | grep -a 'pass=' | tail -1)"
  if [ -z "$rb" ]; then echo SKIP; return; fi
  if [ -z "$mr" ]; then echo CRASH; return; fi
  echo DIFF
}

# expand each requested dir to the group name + its spec files
{
  echo "# mere-ruby — ruby/spec status"
  echo
  echo "Byte-exact conformance against ruby/spec (the de-facto Ruby suite), swept by"
  echo "\`mspec/scoreboard.sh\`. Not a pass/fail gate — a checked-in record of where"
  echo "mere-ruby matches CRuby and where it does not, like the other alternative"
  echo "implementations' tags files. Per-file DIFF/CRASH lists live in \`mspec/tags/\`."
  echo
  echo "- **MATCH** identical output under mere-ruby and ruby"
  echo "- **DIFF** runs on both, output differs (fidelity gap — often an error message or a frozen check)"
  echo "- **CRASH** mere-ruby aborts where ruby does not (missing feature)"
  echo "- **SKIP** ruby itself does not run it here (mock/subprocess/platform — unmeasurable)"
  echo "- **SLOW** ran past this harness's per-file limit — working, not aborting"
  echo
  echo "| group | MATCH | DIFF | CRASH | SKIP | SLOW | total |"
  echo "|---|---|---|---|---|---|---|"
} > "$status"

# the rows measured THIS run; the table is merged rather than rewritten (below)
rows="$(mktemp)"

for d in $dirs; do
  group="$(printf '%s' "$d" | tr '/' '_')"
  files="$(ls "$root/$d"/*_spec.rb 2>/dev/null)"
  [ -n "$files" ] || continue
  m=0; df=0; cr=0; sk=0; to=0; tot=0
  : > "$tagdir/$group.txt"
  for f in $files; do
    tot=$((tot+1))
    v="$(run_one "$f")"
    rel="${f#$root/}"
    case "$v" in
      MATCH) m=$((m+1)) ;;
      DIFF)  df=$((df+1)); echo "DIFF  $rel"  >> "$tagdir/$group.txt" ;;
      CRASH) cr=$((cr+1)); echo "CRASH $rel"  >> "$tagdir/$group.txt" ;;
      SKIP)  sk=$((sk+1)); echo "SKIP  $rel"  >> "$tagdir/$group.txt" ;;
      TIMEOUT) to=$((to+1)); echo "SLOW  $rel"  >> "$tagdir/$group.txt" ;;
    esac
  done
  echo "| $d | $m | $df | $cr | $sk | $to | $tot |" >> "$rows"
  echo "$d: $m/$tot MATCH ($df diff, $cr crash, $sk skip, $to slow)"
done

# Merge the measured rows into the table instead of rewriting it. Rewriting meant
# a sweep of ONE group silently dropped every row it had not measured: the
# numbers for the other groups vanished, and the only defence was remembering to
# restore them by hand. Sweeping one group at a time is also how a long sweep
# survives being interrupted. A row in the older 6-column format keeps its
# numbers and gets "-" for SLOW -- "not measured in this format", not a zero.
old_rows="$(mktemp)"
if [ -f "$status_final" ]; then
  awk -F'|' '/^\| / && $0 !~ /^\| group / && $0 !~ /^\|---/ {
    for (i = 2; i < NF; i++) { gsub(/^ +| +$/, "", $i) }
    n = NF - 2
    if (n == 6) printf("| %s | %s | %s | %s | %s | - | %s |\n", $2, $3, $4, $5, $6, $7)
    else if (n == 7) printf("| %s | %s | %s | %s | %s | %s | %s |\n", $2, $3, $4, $5, $6, $7, $8)
  }' "$status_final" > "$old_rows"
fi
{
  cat "$status"
  # rows that already had a place keep it, with this run's numbers
  awk -F'|' -v rf="$rows" '
    function grp(l,  f, k) { split(l, f, "|"); k = f[2]; gsub(/^ +| +$/, "", k); return k }
    BEGIN { while ((getline l < rf) > 0) nr[grp(l)] = l }
    { k = grp($0); if (k in nr) print nr[k]; else print }
  ' "$old_rows"
  # ... and a group measured for the first time is appended
  awk -F'|' '
    function grp(l,  f, k) { split(l, f, "|"); k = f[2]; gsub(/^ +| +$/, "", k); return k }
    NR == FNR { had[grp($0)] = 1; next }
    !(grp($0) in had) { print }
  ' "$old_rows" "$rows"
  echo
  echo "_Generated by \`mspec/scoreboard.sh\`; re-run to refresh._"
} > "$status.merged"
rm -f "$status" "$rows" "$old_rows"
mv "$status.merged" "$status_final"
echo "wrote $status_final and $tagdir/*.txt"
