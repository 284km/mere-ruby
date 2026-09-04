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
# LC_ALL=C for the WHOLE script, not just the `tr` below. Pinning one tool was
# half the fix: `run_one` also puts the captured output through `sed` and `grep`,
# and a spec whose output carries bytes that are not valid UTF-8 (core/string's
# chars, chr, grapheme_clusters) makes BSD sed exit "illegal byte sequence" too.
# An empty `rb` is read as "ruby did not run this file" -- SKIP -- so the verdict
# became a fact about the operator's locale. Measured on core/string with one and
# the same binary: ja_JP.UTF-8 gave 32/69/1 with 12 SKIP, LC_ALL=C gave 30/79/1
# with 4. The 2026-08-19 fix named `tr` because `tr` was what had failed that day;
# the exposure was never tool-specific.
LC_ALL=C
export LC_ALL
# Pin the reference's encoding, as run_corpus.sh and bootstraptest do: with the
# locale unset, ruby's default external encoding is US-ASCII and `inspect`
# escapes every non-ASCII byte, while mere-ruby prints the bytes -- core/string
# is full of specs where that decides the verdict. The table below was measured
# WITHOUT this, so pinning it and re-sweeping have to happen together.
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT

. "$(cd "$(dirname "$0")" && pwd)"/../tools/ref_ruby.sh
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:?usage: scoreboard.sh <spec-root> [dir ...]}"
shift
dirs="$*"
# Which checkout this is, for the footer: the remote and the revision, so the
# next reader can tell whether a moved number is the interpreter or the suite.
spec_subject="$( (cd "$root" 2>/dev/null && printf '%s@%s' \
  "$(basename "$(git config --get remote.origin.url 2>/dev/null || echo unknown)" .git)" \
  "$(git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)") 2>/dev/null || echo unknown )"
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

# The spec root is passed in on the command line and was recorded NOWHERE, so a
# sweep against a DIFFERENT ruby/spec checkout produced rows that read as
# regressions in groups nothing had touched -- core/string 114 -> 112, core/array
# 102 -> 98 -- and the only thing that gave it away was the `total` column
# moving. That column is the number of spec FILES the group had when its row was
# written, and no change to the interpreter can move it.
#
# So it is the detector. Counting files is instant; the sweep it guards is an
# hour. Checked BEFORE measuring, a wrong root costs two seconds instead of being
# read out of the diff afterwards -- and read out of the diff afterwards is how
# it was actually caught, once, by luck.
#
# SPEC_TOTALS_OK=1 sweeps anyway. That is the honest override for a deliberate
# suite UPGRADE, where the counts are supposed to move and the whole table has to
# be re-measured together.
sb_mismatch=""
for sb_d in $dirs; do
  sb_n="$(ls "$root/$sb_d"/*_spec.rb 2>/dev/null | wc -l | tr -d ' ')"
  sb_rec="$(awk -F'|' -v g=" $sb_d " '$2 == g { t = $(NF-1); gsub(/ /, "", t); print t; exit }' "$status_final" 2>/dev/null)"
  [ -n "$sb_rec" ] || continue
  [ "$sb_n" = "$sb_rec" ] && continue
  sb_mismatch="$sb_mismatch  $sb_d: this root has $sb_n spec files, the recorded row counted $sb_rec
"
done
if [ -n "$sb_mismatch" ]; then
  if [ "${SPEC_TOTALS_OK:-0}" = 1 ]; then
    printf 'scoreboard.sh: spec-file counts differ from the record; SPEC_TOTALS_OK=1, sweeping anyway:\n%s' "$sb_mismatch" >&2
  else
    printf "scoreboard.sh: REFUSING to sweep -- '%s' is not the checkout this table was measured against.\n%s" "$root" "$sb_mismatch" >&2
    echo "The 'total' column counts spec FILES, so a different count is a different suite, and" >&2
    echo "this run's MATCH numbers would not be comparable with the rows they replace." >&2
    echo "Point it at the recorded root, or set SPEC_TOTALS_OK=1 for a deliberate upgrade." >&2
    exit 2
  fi
fi

# 60s, not 30: the heaviest file here (core/string/modulo_spec.rb) spends ~26s of
# CPU on its own, so 30 left almost no margin under the load of a sweep -- and a
# file the alarm kills is not the same finding as a file that aborts, which is
# what TIMEOUT below is for. (modulo_spec does abort, for its own reasons: its
# mere-ruby side stops before it prints a tally, under this build and under the
# build before it.)
TIMEOUT=60
# A verdict alone does not say WHERE to work. The sweep used to compute one and
# throw the output away (`rm -f "$raw"` below), so 603 DIFFs were 603 unknowns:
# the tags files named the files and nothing else. Classifying by message first
# is the difference between fixing one name and guessing among hundreds -- on
# this codebase a batch of 346 errors turned out to be 194 instances of ONE name.
#
# So run_one now echoes "VERDICT<TAB>CAUSE":
#   CRASH -> the abort message from the mere-ruby side
#   DIFF  -> the first line where the two sides disagree
# Only the leading "path:line:" is stripped. The message itself is kept whole,
# quoted identifiers included: normalising it further merges causes that are
# genuinely different, and a bucket that mixes them cannot be acted on.
strip_noise() {  # stdin -> stdout, a line usable as a bucket key
  # $HOME goes the way of the tmpdir and the address: a recorded line is checked
  # into a PUBLIC repo, and the operator's home path is neither a property of the
  # interpreter nor something to publish. This is the same masking rule the other
  # two already are, applied to the third thing that identifies the machine.
  sed -e 's|^[^ ]*\.rb:[0-9]*: |*.rb:N: |' \
      -e 's|/[^ ]*/mrb_[A-Za-z0-9]*|TMPDIR|g' \
      -e 's|/var/folders/[^ ]*|TMPDIR|g' \
      -e "s|${HOME}[^ \"]*|HOME|g" \
      -e 's|0x[0-9a-f]*|0xADDR|g'
}

# A cause is a SUMMARY -- the one line the two sides first disagree on, kept so
# the failures can be grouped and one of them reproduced. It is not the output.
#
# Nothing enforced that until core/env taught it: those specs print ENV, so once
# `ENV.filter` became reflectable here the first differing line was a Method whose
# inspect carries the entire process environment. An 11KB "cause" went into
# mspec/tags/ and CAUSES.md and was pushed -- PATH, HOME, SSH_AUTH_SOCK, session
# ids and an internal package-index host, in a public repo, inside a field whose
# whole job is to be a short label.
#
# The cap is the fix rather than a mask for ENV specifically: the field's contract
# is "short enough to read in a table", and any object with a large inspect --
# a big hash, a long array, a deep struct -- reaches it the same way.
CAUSE_MAX=${CAUSE_MAX:-240}
clip_cause() {  # $1 = cause -> echoes it, bounded
  printf '%s' "$1" | awk -v n="$CAUSE_MAX" '{ if (length($0) > n) print substr($0,1,n) " ...[clipped]"; else print $0 }'
}

run_one() {  # $1 = spec file -> echoes VERDICT<TAB>CAUSE
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
  case $rc in 142|14) printf 'TIMEOUT\t-\n'; return;; esac
  verdict="$(printf '%s' "$out" | tail -1)"
  if [ "$verdict" = "MATCH" ]; then printf 'MATCH\t-\n'; return; fi
  # ruby side empty tally => unmeasurable (ruby itself didn't run the examples)
  rb="$(printf '%s' "$out" | sed -n '/--- ruby:/,$p' | grep -a 'pass=' | tail -1)"
  mr="$(printf '%s' "$out" | sed -n '/--- mere-ruby:/,/--- ruby:/p' | grep -a 'pass=' | tail -1)"
  if [ -z "$rb" ]; then printf 'SKIP\t-\n'; return; fi

  # Split the two sides. `--- ruby:` also ends the mere-ruby side, and the very
  # last line is run_spec.sh's own verdict, which belongs to neither.
  mr_f="$(mktemp)"; rb_f="$(mktemp)"
  printf '%s\n' "$out" | sed -n '/^--- mere-ruby:/,/^--- ruby:/p' \
    | sed '1d;$d' | strip_noise > "$mr_f"
  printf '%s\n' "$out" | sed -n '/^--- ruby:/,$p' \
    | sed '1d;$d' | strip_noise > "$rb_f"

  if [ -z "$mr" ]; then
    # CRASH: the cause is why it stopped -- the last thing it said. An empty
    # mere-ruby side means it died before printing anything at all, which is a
    # different finding and worth its own bucket rather than a blank.
    cause="$(clip_cause "$(grep -av '^$' "$mr_f" | tail -1)")"
    [ -n "$cause" ] || cause="(no output before aborting)"
    rm -f "$mr_f" "$rb_f"
    printf 'CRASH\t%s\n' "$cause"
    return
  fi

  # DIFF: the first line the two sides disagree on. Not the tally -- the tally
  # says how many examples differ, never which behaviour is wrong.
  cause="$(clip_cause "$(diff "$mr_f" "$rb_f" 2>/dev/null | grep -a '^<' | head -1 | cut -c3-)")"
  [ -n "$cause" ] || cause="$(clip_cause "$(diff "$mr_f" "$rb_f" 2>/dev/null | grep -a '^>' | head -1 | cut -c3-)")"
  [ -n "$cause" ] || cause="(tallies differ, lines identical)"
  rm -f "$mr_f" "$rb_f"
  printf 'DIFF\t%s\n' "$cause"
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
  echo "Measured against **ruby $REF_RUBY_VERSION** (tools/ref_ruby.sh). The reference is part"
  echo "of the subject: a row measured against another release is not comparable with the"
  echo "ones around it, and the difference reads as movement in mere-ruby."
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
    vc="$(run_one "$f")"
    v="${vc%%	*}"       # before the tab
    cause="${vc#*	}"    # after it
    rel="${f#$root/}"
    # The cause is the third field, tab-separated, so the first two stay
    # readable as before and a cause containing spaces survives whole.
    case "$v" in
      MATCH) m=$((m+1)) ;;
      DIFF)  df=$((df+1)); printf 'DIFF  %s\t%s\n'  "$rel" "$cause" >> "$tagdir/$group.txt" ;;
      CRASH) cr=$((cr+1)); printf 'CRASH %s\t%s\n'  "$rel" "$cause" >> "$tagdir/$group.txt" ;;
      SKIP)  sk=$((sk+1)); printf 'SKIP  %s\n'       "$rel" >> "$tagdir/$group.txt" ;;
      TIMEOUT) to=$((to+1)); printf 'SLOW  %s\n'     "$rel" >> "$tagdir/$group.txt" ;;
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
  echo
  # ...and name the subject. A conformance number without the suite it was
  # measured against is not comparable with the next one.
  echo "_Measured against ruby/spec \`$spec_subject\`._"
} > "$status.merged"
rm -f "$status" "$rows" "$old_rows"
mv "$status.merged" "$status_final"
echo "wrote $status_final and $tagdir/*.txt"
