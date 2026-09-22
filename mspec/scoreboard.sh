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
#   CRASH  - mere-ruby aborts ON ITS OWN where ruby does not (missing feature)
#   SKIP   - ruby itself errors/does not run (unmeasurable here)
#   SLOW   - one of this harness's bounds stopped it (CPU seconds, wall clock or
#            bytes). Not the interpreter aborting: the row names which bound.
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
# ...and the same question about the subject's NAME. spec_subject above reads
# the root's git checkout, and a root that is not one -- an unpacked tarball, a
# `git archive` of the pinned revision, a copy -- makes it "unknown@unknown".
# That string then REPLACES the revision the table was measured against, so the
# record stops naming its subject and the next reader cannot tell whether a
# moved number is the interpreter or the suite. Losing the name is the same
# failure the count check above exists to prevent, so it is refused the same
# way and for two seconds rather than after the sweep.
#
# SPEC_SUBJECT_OK=1 sweeps anyway, for a root that genuinely has no revision to
# name.
sb_rec_subject="$(sed -n 's/^_Measured against ruby\/spec `\(.*\)`\._$/\1/p' "$status_final" 2>/dev/null | tail -1)"
if [ "$spec_subject" = "unknown@unknown" ] && [ -n "$sb_rec_subject" ] \
   && [ "$sb_rec_subject" != "unknown@unknown" ] && [ "${SPEC_SUBJECT_OK:-0}" != 1 ]; then
  echo "scoreboard.sh: REFUSING to sweep -- '$root' is not a git checkout, so this run" >&2
  echo "cannot name the suite it measured, and would replace '$sb_rec_subject' with" >&2
  echo "'unknown@unknown'. Point it at a checkout of that revision (git worktree add" >&2
  echo "--no-checkout --detach <dir> <rev> && git -C <dir> sparse-checkout set spec)," >&2
  echo "or set SPEC_SUBJECT_OK=1 if the root really has no revision to name." >&2
  exit 2
fi

# ...and the same question about the BINARY. tools/build.sh has a --fast mode
# that compiles at -O0: 30s instead of 112s, and 1.7x slower to run. That is a
# good trade while a change is being shaped and a bad one here, because every
# verdict in this table is bounded in CPU seconds -- a file that burns 20 of
# them under -O2 burns about 34 under -O0 and crosses a budget it has never
# crossed, so the record would report a regression that is a compiler flag.
# Which build made the binary is not visible in the binary; build.sh writes it
# down, and this is what reads it. Silent when there is no stamp, because a
# hand-built binary is still the normal case.
sb_build_mode="$(cat "$here/../.build_mode" 2>/dev/null || echo)"
if [ "$sb_build_mode" = "O0" ] && [ "${SPEC_BUILD_OK:-0}" != 1 ]; then
  echo "scoreboard.sh: REFUSING to sweep -- .build_mode says this mere-ruby was built" >&2
  echo "with tools/build.sh --fast (-O0), which runs about 1.7x slower. Every verdict" >&2
  echo "here is bounded in CPU seconds, so the table would move for a reason that is" >&2
  echo "not the interpreter. Rebuild with ./tools/build.sh, or set SPEC_BUILD_OK=1." >&2
  exit 2
fi

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

# ⚠ THE OUTER BOUND IS DERIVED, NOT CHOSEN. It used to be a number here (60s)
# while run_spec.sh had a number of its own (25s per side), and the two answered
# the same question -- "does this finish" -- in two places. When the sweep went
# parallel and the answers moved, the first fix scaled THIS one, which changed
# nothing, because the files were hitting the other. mspec/bounds.sh now owns
# both, and this one is computed from the inner wall bound so that it covers
# two sides plus the driver and can never be the one that fires first. Its job
# is to catch run_spec.sh ITSELF wedging, not to judge a spec.
. "$here"/bounds.sh
TIMEOUT="$sb_outer"
# ...and prove the CPU bound is available BEFORE measuring 2,498 files with it,
# once for the whole sweep rather than once per file. run_spec.sh reads this and
# skips its own probe.
if sb_cpu_works; then
  SPEC_CPU_OK=1
else
  SPEC_CPU_OK=0
  echo "scoreboard.sh: this shell cannot set RLIMIT_CPU -- the sweep falls back to a" >&2
  echo "${sb_cpu}s WALL bound per side, so verdicts will depend on the machine's load." >&2
fi
export SPEC_CPU_OK
# The sweep can be parallel now that "does this finish" is measured in CPU
# seconds: a file that burns 25 of them burns 25 whether one worker runs or six.
# ⚠ It still defaults to 1, because the RECORD is the product here and a record
# is checked by re-measuring it. The flag is how a working session buys the 3x;
# see LOOP.md for the numbers and for what was checked.
sb_jobs="${SPEC_JOBS:-1}"
case "$sb_jobs" in ''|*[!0-9]*) sb_jobs=1 ;; esac
[ "$sb_jobs" -ge 1 ] || sb_jobs=1
# what a recorded line may say -- masking and the length bound, shared with
# examples.sh so the two records cannot drift apart.
. "$here"/mask.sh

run_one() {  # $1 = spec file -> echoes VERDICT<TAB>CAUSE
  # Through a FILE, not a pipe: the alarm's status has to be perl's, and `$?`
  # after a pipeline is the last stage's (`tr` always succeeds). Read off an
  # empty output, a killed run is indistinguishable from an abort. (`pipefail`
  # would do it too, but it is a bashism and these harnesses also run under dash.)
  raw="$(mktemp)"
  # ⚠ `</dev/null`, because the loops below read the GROUP LIST on stdin and the
  # child inherits it. Two things follow from leaving it: a spec that reads
  # $stdin reads the harness's own work list -- so the record would depend on
  # WHICH groups the sweep was asked for -- and whatever it consumed is a line
  # the `while read` loop never sees, which loses groups in silence. Neither had
  # bitten yet (core/argf's stdin specs redirect a fixture into a child rather
  # than reading ours), and both are one redirection away from doing so.
  perl -e "alarm $TIMEOUT; exec @ARGV" sh "$here/run_spec.sh" "$1" > "$raw" 2>/dev/null </dev/null
  rc=$?
  # LC_ALL=C on the `tr`: a spec whose output carries bytes that are not valid
  # UTF-8 (core/string's chars, chr, grapheme_clusters, ...) makes `tr` FAIL under
  # a UTF-8 locale, which empties the output and turns the verdict into SKIP or
  # CRASH. The number then depended on the locale of whoever ran the sweep:
  # measured in ja_JP.UTF-8, core/string reported 12 SKIPs and 5 extra CRASHes
  # that are not there in C.
  out="$(LC_ALL=C tr -d '\0' < "$raw")"
  rm -f "$raw"
  case $rc in 142|14) printf 'TIMEOUT\tthe outer %ss bound fired -- run_spec.sh itself did not return\n' "$TIMEOUT"; return;; esac
  # The verdict line is VERDICT or VERDICT<TAB>CAUSE.
  vline="$(printf '%s' "$out" | tail -1)"
  verdict="${vline%%	*}"
  if [ "$vline" = "$verdict" ]; then vcause="-"; else vcause="${vline#*	}"; fi
  if [ "$verdict" = "MATCH" ]; then printf 'MATCH\t-\n'; return; fi
  # run_spec.sh says SLOW when one of ITS bounds fired: the file works and was
  # stopped, which is not the same finding as aborting. Its cause says WHICH --
  # over the CPU budget (a fact about the file) or stuck with the budget unspent
  # (a fact about the harness or the environment) -- and the record keeps that,
  # because a SLOW row that does not name the bound cannot be acted on.
  if [ "$verdict" = "SLOW" ]; then printf 'TIMEOUT\t%s\n' "$(clip_cause "$vcause")"; return; fi
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
  echo "- **CRASH** mere-ruby aborts ON ITS OWN where ruby does not (missing feature)"
  echo "- **SKIP** ruby itself does not run it here (mock/subprocess/platform — unmeasurable)"
  echo "- **SLOW** stopped by one of this harness's bounds — CPU seconds, wall clock or bytes —"
  echo "  and so working, not aborting. The row in \`mspec/tags/\` names which bound answered."
  echo
  echo "Measured against **ruby $REF_RUBY_VERSION** (tools/ref_ruby.sh). The reference is part"
  echo "of the subject: a row measured against another release is not comparable with the"
  echo "ones around it, and the difference reads as movement in mere-ruby."
  echo "| group | MATCH | DIFF | CRASH | SKIP | SLOW | total |"
  echo "|---|---|---|---|---|---|---|"
} > "$status"

# ⚠ ONE TREE FOR THE WHOLE SWEEP. run_spec.sh used to clone core, language,
# library, shared and fixtures -- 4,333 files -- for EVERY spec file, which is
# ten million clones and about an hour of syscall time per sweep, and it is
# what drives fseventsd to 100%+ for hours afterwards. Measured 2026-09-22: of
# one file's 2.71s, 1.46s was the clone and 0.1s the two interpreters.
#
# The tree is read-only to a spec except for what the spec itself writes, which
# it also cleans up; the driver.rb this rewrites per file is the only thing
# that changes. Validated by sweeping groups both ways and requiring the rows
# to be identical -- if a spec ever leaves something behind, that check is
# where it shows.
sb_mktree() {  # $1 = where to build it
  for sb_d0 in core language library shared fixtures; do
    [ -d "$root/$sb_d0" ] || continue
    cp -Rc "$root/$sb_d0" "$1/$sb_d0" 2>/dev/null || cp -R "$root/$sb_d0" "$1/$sb_d0"
  done
  cp "$here/spec_helper.rb" "$1/spec_helper.rb"
}

# ⚠ THE SWEEP LEAVES ITS OWN LITTER, and it is the litter that makes the NEXT
# sweep slow. mspec/spec_helper.rb gives each process a scratch directory --
# `rubyspec_temp/<pid>`, under the cwd -- and removes it on the last line of a
# normal exit. A run killed by either bound never reaches that line, so every
# SLOW file leaves one behind: 1,605 of them had accumulated by 2026-09-22, and
# they are exactly what fseventsd is indexing between sweeps (see LOOP.md).
#
# Removing them is the sweep's job because they are the sweep's own droppings.
# ⚠ A directory is removed only when NO PROCESS HOLDS ITS PID: a concurrent
# sweep's scratch must survive this one's exit, and `kill -0` is the question
# that distinguishes them. A recycled pid keeps a dead directory one sweep
# longer, which is the harmless direction.
sb_sweep_litter() {
  sb_lit="$sb_cwd/rubyspec_temp"
  [ -d "$sb_lit" ] || return 0
  for sb_p in "$sb_lit"/*; do
    [ -d "$sb_p" ] || continue
    sb_b="${sb_p##*/}"
    case "$sb_b" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$sb_b" 2>/dev/null && continue
    rm -rf "$sb_p"
  done
  rmdir "$sb_lit" 2>/dev/null
  return 0
}
sb_cwd="$PWD"
# before, so a sweep does not run on top of the last one's droppings...
sb_sweep_litter

# ⚠ THE MEMORY BOUND WAS A STEP IN THE README, WHICH IS NOT A BOUND. The
# third limit on a spec run is bytes, and mspec/rss_guard.sh is what enforces
# it -- by polling, because macOS has no `ulimit -v`. It was started by hand
# ("./mspec/rss_guard.sh &" in the README) and it dies with the shell that
# started it, so whether a runaway file is recorded as CRASH or takes the
# machine down depended on whether someone remembered. On 2026-09-22 it was
# down for half a day without anything saying so, and the four CRASH rows the
# parallel experiment produced the same morning came from a run where it was
# UP -- the same sweep, two answers, decided by a process nobody could see.
#
# So the sweep starts its own and takes it down on the way out. An operator's
# guard is left alone if one is already up, because two pollers would both
# report the same kill.
sb_guard_pid=""
if pgrep -f 'rss_guard\.sh' >/dev/null 2>&1; then
  echo "scoreboard.sh: an rss_guard.sh is already running; leaving it to it" >&2
else
  sh "$here/rss_guard.sh" "$sb_rss_cap" "$here/rss_kills.log" 1 &
  sb_guard_pid=$!
fi

# the rows measured THIS run; the table is merged rather than rewritten (below)
rows="$(mktemp)"
# ⚠ ...and one FILE per row, named by the group's position, because the workers
# below finish out of order and the table's row order has to come out the same
# as a sequential sweep's.
rowsdir="$(mktemp -d)"
sb_trees="$(mktemp -d)"
trap '[ -n "$sb_guard_pid" ] && kill "$sb_guard_pid" 2>/dev/null; rm -rf "$rowsdir" "$sb_trees"; sb_sweep_litter' EXIT INT TERM

# one group, measured by whichever worker drew it. The tag file is named by the
# group, so two workers never write the same one; the row goes to its own file
# in $rowsdir under the group's position.
run_group() {  # $1 = group dir, $2 = its position in $dirs
  d="$1"
  group="$(printf '%s' "$d" | tr '/' '_')"
  files="$(ls "$root/$d"/*_spec.rb 2>/dev/null)"
  [ -n "$files" ] || return 0
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
      TIMEOUT) to=$((to+1)); printf 'SLOW  %s\t%s\n' "$rel" "$cause" >> "$tagdir/$group.txt" ;;
    esac
  done
  echo "| $d | $m | $df | $cr | $sk | $to | $tot |" > "$rowsdir/$2"
  echo "$d: $m/$tot MATCH ($df diff, $cr crash, $sk skip, $to slow)"
}

# ⚠ ONE TREE PER WORKER, never one shared by all of them. A spec that writes
# into the tree merely FOLLOWS another spec when the sweep is sequential; with
# workers sharing a tree it would RACE one, which is a different and much worse
# failure. Six clones instead of 2,498 keeps the win and adds the parallelism.
# SPEC_TEMP_DIR is already per-process (see mspec/spec_helper.rb), so the specs'
# own scratch does not collide either.
sb_work="$(mktemp)"
sb_i=0
for d in $dirs; do
  sb_i=$((sb_i + 1))
  printf '%s %s\n' "$sb_i" "$d"
done > "$sb_work"

if [ "$sb_jobs" -le 1 ]; then
  sb_t0="$sb_trees/0"; mkdir -p "$sb_t0"; sb_mktree "$sb_t0"
  SPEC_TREE="$sb_t0"; export SPEC_TREE
  while read -r sb_n sb_d; do run_group "$sb_d" "$sb_n"; done < "$sb_work"
else
  sb_w=0
  sb_wpids=""
  while [ "$sb_w" -lt "$sb_jobs" ]; do
    (
      sb_t="$sb_trees/$sb_w"
      mkdir -p "$sb_t"
      sb_mktree "$sb_t"
      SPEC_TREE="$sb_t"
      export SPEC_TREE
      while read -r sb_n sb_d; do
        [ $(( (sb_n - 1) % sb_jobs )) -eq "$sb_w" ] || continue
        run_group "$sb_d" "$sb_n"
      done < "$sb_work"
    ) &
    sb_wpids="$sb_wpids $!"
    sb_w=$((sb_w + 1))
  done
  # ⚠ WAIT FOR THE WORKERS, NOT FOR EVERY BACKGROUND CHILD. A bare `wait` also
  # waits for the memory guard this script starts, and the guard is a `while :`
  # poller that never exits -- so the sweep measured all eight groups, wrote
  # every tag file, and then sat there forever with no child process running.
  # It looked exactly like a hung sweep and it was a finished one. The
  # sequential path has no `wait`, which is why only the parallel path wedged.
  for sb_p in $sb_wpids; do wait "$sb_p"; done
fi
rm -f "$sb_work"
# the rows, back in the order a sequential sweep would have written them
for sb_r in $(ls "$rowsdir" 2>/dev/null | sort -n); do cat "$rowsdir/$sb_r"; done > "$rows"

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
