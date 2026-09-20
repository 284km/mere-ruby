#!/bin/sh
# Refuse to leave machine-identifying text in the checked-in records.
#
# These files are pushed to a PUBLIC repo. A spec that prints ENV puts the whole
# process environment into a failure message, and the first line of a diff is
# copied verbatim into the records -- that is how PATH, HOME, SSH_AUTH_SOCK, a
# session id and an internal package-index host got published in one commit.
# scoreboard.sh masks $HOME and clips the cause now; this is the check that says
# so, because a mask is a claim and only a check is evidence.
#
#   ./mspec/record_hygiene.sh [file ...]     # default: every tracked record
#
# TWO THINGS THIS GOT WRONG THE FIRST TIME, both of which made it quiet rather
# than wrong -- the worse failure for a detector:
#
#  1. `grep` without -a. A record that carries bytes which are not valid UTF-8
#     is treated as binary and grep says NOTHING. mspec/DIFF_LINES.txt is exactly
#     such a file and it holds three local paths; the first version of this check
#     passed it. The files most likely to have captured raw output are the files
#     most likely to be binary-ish, so -a is not optional here.
#  2. A hardcoded file list. It named tags/, CAUSES.md and SPEC_STATUS.md, and
#     the leak was also in DIFF_LINES.txt, which is a record too. The list now
#     comes from git, so a record added later is covered without editing this.
set -u
LC_ALL=C
export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
if [ "$#" -gt 0 ]; then
  files="$*"
else
  files=$(cd "$root" && git ls-files 'mspec/*.txt' 'CAUSES.md' 'EXAMPLES.md' 'SPEC_STATUS.md' 'bootstraptest/*.txt' 2>/dev/null | sed "s|^|$root/|")
fi
[ -n "$files" ] || { echo "no records to check" >&2; exit 2; }
rc=0
# Patterns that identify the machine or its operator rather than the interpreter.
# `/Users/` and `/home/` catch a home path even when $HOME is spelled some other
# way (a different user, a symlink, a sudo run): the masking cannot rely on the
# variable it happened to run with.
# `/var/folders/` is macOS's per-user tmpdir. It is on this list for two
# reasons at once: it names the machine, and the name inside it changes on every
# run, so a record carrying one differs from itself and can no longer show that
# something REAL moved. It sat unmasked in bootstraptest/ERRORS.txt while this
# check read that very file and reported it clean -- the detector only ever
# catches the leaks someone thought of.
# 'HOME/' catches a path the masker only half-took: replacing $HOME with the
# word HOME leaves `HOME/src/github.com/<user>/<repo>` behind, which is still
# this machine's layout and still in a public record -- and every pattern below
# it looks for the SPELLING BEFORE the mask, so it read as clean. Found on
# 2026-09-04, already pushed.
for pat in '/Users/' '/home/' 'HOME/' '/var/folders/' 'ruby-btest-' 'SSH_AUTH_SOCK' \
           'SECURITYSESSIONID' 'XPC_SERVICE_NAME' \
           'CLAUDE_CODE_SESSION_ID' 'LaunchInstanceID' '__CF_USER_TEXT_ENCODING' \
           'VSCODE_IPC_HOOK' 'GVM_PATH_BACKUP' 'LD_LIBRARY_PATH' 'SSH_AGENT_PID'; do
  hits=$(grep -al -- "$pat" $files 2>/dev/null)
  [ -n "$hits" ] && { echo "LEAK  $pat"; echo "$hits" | sed "s|$root/|        |"; rc=1; }
done
# ...and a STRUCTURAL check, because the list above is a list of leaks someone
# thought of. On 2026-09-05 a SESSION TOKEN went into a public commit WITH ITS
# VALUE, on four lines of mspec/DIFF_LINES.txt and one of mspec/tags/. Its
# variable sat in the same environment as CLAUDE_CODE_SESSION_ID, which IS on
# the list above -- and that is the whole point: naming variables one at a time
# cannot keep up with an environment.
#
# The signature of an environment dump is ruby's hash inspect with a SHOUTING
# key: `"SOME_NAME" => "value"`. That shape is never a legitimate cause here,
# whatever the name inside it happens to be.
# Four characters minimum: the KIND column masks a string to "S", and `"S" => "S"`
# is a masked row, not a dump.
# The generators COLLAPSE a string-keyed hash literal to `{...}`, so a record
# must never contain `{"` at all. Checking for the COLLAPSED-AWAY shape rather
# than for particular contents is the point: two earlier versions of the mask
# tried to keep the keys and rewrite the values, and each failed differently --
# one knew only ruby 3.4's spacing (the records span the 3.2 upgrade), the
# other ran off its quote boundaries and left half the text behind. There is
# no boundary to get wrong now, and nothing to enumerate.
envdump=$(grep -aln -F -- '{"' $files 2>/dev/null)
[ -n "$envdump" ] && { echo "LEAK  a string-keyed hash literal (an environment or object dump):"; echo "$envdump" | sed "s|$root/|        |"; rc=1; }
# A cause field long enough to hold an object dump is the mechanism, so bound it
# directly too: the longest line in a record should be a sentence, not a heap.
# The bound has to sit AT the generator's clip, not above it. classify.sh clips
# a cause at 300 characters, so a 400-char threshold could never fire on a
# clipped line -- and clipping is what let the token through while making the
# line small enough to look innocent. The clip made the leak quieter, not safer.
long=$(awk 'length($0) > 340 { print FILENAME": "length($0)" chars" }' $files 2>/dev/null | head -5)
[ -n "$long" ] && { echo "LONG  a recorded line is over 340 chars (an object dump, not a cause):"; echo "$long" | sed "s|$root/|        |"; rc=1; }
# ⚠ A record has to be TEXT. core/symbol/inspect's `quotes BINARY symbols`
# prints a raw 0xA4; it reached mspec/tags/core_symbol.txt and was pushed, and
# from that moment `grep` called that file binary and answered NOTHING without
# -a. A check that goes quiet is worse than one that fails, and this one went
# quiet about the record it was pointed at. mask.sh escapes such bytes now;
# this refuses them if they ever arrive by another route.
badenc=$(for f in $files; do
           perl -e 'local $/; my $b = <>; exit(utf8::decode($b) ? 0 : 1)' "$f" 2>/dev/null || echo "$f"
         done)
[ -n "$badenc" ] && { echo "BINARY  a record is not valid UTF-8 (grep goes silent on it):"; echo "$badenc" | sed "s|$root/|        |"; rc=1; }

# ...and finally, is each record COMPLETE? Everything above asks what a record
# CONTAINS. Nothing asked whether it contains all of it -- and on 2026-09-14 a
# truncated record was committed and pushed while every check here said clean.
# A scoreboard run that is killed part-way (two sweeps racing, a superseded
# binary) has already opened mspec/tags/<group>.txt and written the rows it got
# to. The file left behind is a VALID record of a shorter run: no leak, no long
# line, valid UTF-8. mspec/tags/language.txt kept 4 of its 22 DIFF rows that
# way, and the loss was invisible because SPEC_STATUS.md -- written last, in one
# go -- still said 22.
#
# That disagreement is the detector. SPEC_STATUS.md holds the COUNT per group
# and mspec/tags/ holds the ROWS, so the two records can be asked the same
# question and made to agree. A killed run cannot fake it: it dies before the
# summary, so either the summary is the old one (and the rows are short) or
# there is no summary at all.
#
# This is a check on the RECORDS, not on the interpreter -- it stays green while
# DIFF moves, and goes red only when the two files stop describing one run.
# Refused, not skipped, when the summary is absent: a check that quietly does
# nothing when its oracle is missing is the same green as a check that passed.
status="$root/SPEC_STATUS.md"
if [ ! -f "$status" ]; then
  echo "NO SUMMARY  SPEC_STATUS.md is missing, so the rows in mspec/tags/ cannot be"
  echo "            checked for completeness against anything."
  rc=1
else
  mismatch=$(awk -F'|' '
    # | group | MATCH | DIFF | CRASH | SKIP | SLOW | total |
    NF >= 8 {
      g = $2; gsub(/^ +| +$/, "", g)
      if (g == "group" || g ~ /^-+$/) next
      d = $4 + 0; c = $5 + 0; sk = $6 + 0; sl = $7 + 0
      f = g; gsub("/", "_", f)
      path = tags "/" f ".txt"
      want = d + c + sk + sl
      have = 0; hd = 0; hc = 0; hsk = 0; hsl = 0
      while ((getline line < path) > 0) {
        if (line == "") continue
        have++
        if (line ~ /^DIFF/)  hd++
        else if (line ~ /^CRASH/) hc++
        else if (line ~ /^SKIP/)  hsk++
        else if (line ~ /^SLOW/)  hsl++
      }
      close(path)
      if (have == 0 && want > 0)
        printf "        %s: SPEC_STATUS says %d rows, %s.txt is empty or missing\n", g, want, f
      else if (hd != d || hc != c || hsk != sk || hsl != sl)
        printf "        %s: SPEC_STATUS says %d/%d/%d/%d (diff/crash/skip/slow), %s.txt has %d/%d/%d/%d\n", \
               g, d, c, sk, sl, f, hd, hc, hsk, hsl
    }
  ' tags="$root/mspec/tags" "$status")
  if [ -n "$mismatch" ]; then
    echo "PARTIAL  a record disagrees with SPEC_STATUS.md (a killed sweep truncates the rows"
    echo "         it was mid-way through; the summary is written last and still reads full):"
    echo "$mismatch"
    rc=1
  fi
  # ...and the other direction: a tag file no row claims. A group renamed or
  # dropped from the sweep leaves its old rows behind, and they then read as
  # current findings about an interpreter that has not been asked in months.
  # ⚠ MAP THE ROW TO THE FILE, NOT THE FILE TO THE ROW. The tag basename is the
  # group with "/" turned into "_", and that direction is NOT reversible: from
  # "core_file_stat" you cannot tell whether the group was core/file/stat or
  # core/file_stat. The first version guessed by replacing the FIRST underscore,
  # which is right for "core_array" and wrong for every NESTED group -- so the
  # day 26 of them were added, all 26 were reported as orphan records while
  # their rows sat in the table. Deriving the expected basenames from the rows
  # has one answer per row and needs no guess.
  expected=$(sed -n 's/^| \([a-z][a-z_0-9/-]*\) |.*/\1/p' "$status" | tr '/' '_')
  orphan=$(for t in "$root"/mspec/tags/*.txt; do
             [ -e "$t" ] || continue
             b=$(basename "$t" .txt)
             printf '%s\n' "$expected" | grep -qxF "$b" || echo "        $b.txt"
           done)
  if [ -n "$orphan" ]; then
    echo "ORPHAN  a record in mspec/tags/ has no row in SPEC_STATUS.md:"
    echo "$orphan"
    rc=1
  fi
fi

[ "$rc" = 0 ] && echo "records clean ($(echo $files | wc -w | tr -d ' ') files)"
exit $rc
