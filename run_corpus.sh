#!/bin/sh
# Run every corpus program under the reference ruby and under ./mere-ruby,
# and diff the outputs. Exits non-zero on the first mismatch.
set -e
. "$(cd "$(dirname "$0")" && pwd)"/tools/ref_ruby.sh
# The reference ruby's own output depends on its default external encoding:
# with the locale unset (or not UTF-8) `p "にち"` escapes to "\u306B\u3061",
# while mere-ruby has one behaviour and prints the bytes. That made corpus/118
# fail on a machine where LANG is not set -- the interpreter measuring the same
# as ever, the environment answering differently. -Eutf-8 pins the reference
# instead of trusting the shell (a locale name would need that locale to exist;
# this option does not).
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
# The interpreter under test. A candidate build has to be gated BEFORE it is
# moved onto ./mere-ruby, because a sweep in flight owns that path -- writing
# it mid-measurement tests a half-written binary and invents a regression.
MR_BIN="${MR_BIN:-./mere-ruby}"
# One interpreter self-check first: an Errno class registered with no strerror
# text loses its message prefix SILENTLY (`raise Errno::EXYZ, "m"` would read "m"
# where ruby reads "<text> - m"), so the class list and the text table are asked
# about each other rather than trusted to stay in step.
errno_out="$(MERE_RUBY_ERRNO_CHECK=1 "$MR_BIN" corpus/01_arith.rb 2>&1 >/dev/null || true)"
case "$errno_out" in
  *MISSING*) echo "$errno_out"
             echo "an Errno class has no strerror text -- see errno_desc in main.mere"
             exit 1;;
esac
# A second self-check: every global map that holds object handles is a GC root
# (or is named, with its reason, in tools/gc_roots_allow.txt). The table that
# was missing from the roots on 2026-09-03 cost `require "bundler"` two weeks.
# MR_C, when the caller has just emitted one, so this reads the tree it is
# testing rather than a checked-in mr.c that nothing regenerates (it was five
# days stale on 2026-09-15 and the check reported on it every run).
./tools/gc_roots_check.sh ${MR_C:+"$MR_C"} > /dev/null \
  || { ./tools/gc_roots_check.sh ${MR_C:+"$MR_C"} | grep -v " root$"; exit 1; }
# A third: no top-level name is defined twice in one `let rec ... and ...`
# chain. The later definition wins for every caller and the earlier one is
# dead, silently, on a green build -- six of them had accumulated, and one was
# added the same day the gate was written.
./tools/dup_defs_check.sh > /dev/null || { ./tools/dup_defs_check.sh | grep -a SAME-CHAIN; exit 1; }
# ...and a fourth: no top-level function is defined and never called. Twenty-
# eight had accumulated, superseded by rewrites nobody finished; the compiler
# does not say so, and a definition that never runs still gets maintained.
./tools/dead_defs_check.sh > /dev/null || { ./tools/dead_defs_check.sh | grep -a UNCALLED; exit 1; }
# ...and a fifth, on the RECORDS rather than the interpreter: no leaked machine
# text, and no record left half-written. This lived only in CI until 2026-09-14,
# when a sweep killed mid-file left mspec/tags/language.txt holding 4 of its 22
# rows and it was committed and pushed -- CI would have said so days later. The
# check belongs on the path walked before a commit, which is this one.
./mspec/record_hygiene.sh > /dev/null || { ./mspec/record_hygiene.sh; exit 1; }
# ...and a sixth: every write to the method table goes through the setter that
# bumps the lookup generation. `has_meth` memoises the whole ancestor walk on
# that generation, so a write that skips the setter is a method the lookup will
# never see -- green build, green corpus, and one program that fails for no
# visible reason.
./tools/meth_writes_check.sh > /dev/null || { ./tools/meth_writes_check.sh; exit 1; }
# ...a seventh: every `name_set "tag"` has an arm in name_spec. A tag with no
# arm builds an EMPTY table, which is a predicate answering false about every
# name -- a wrong answer, not a crash.
./tools/name_spec_check.sh > /dev/null || { ./tools/name_spec_check.sh; exit 1; }
# ...and an eighth: every write to a regex capture slot goes through
# rx_cap_set, which keeps the high-water mark rx_clear_caps reaches to. A write
# that goes around it leaves a capture behind, and the NEXT match answers with
# a group belonging to the one before it.
./tools/rx_caps_check.sh > /dev/null || { ./tools/rx_caps_check.sh; exit 1; }
# ...and a ninth: each single-namespace arm of the class dispatcher (File /
# FileTest, IO, Dir, Math) is guarded by a name list, and the SAME list answers
# respond_to?. If the arm grows a name the list does not carry, the call is
# refused for a method that is right there; if the list carries one the arm
# never implements, respond_to? claims a method that is not. Both doors, one
# list -- this is what caught File.foreach, which the entry condition let in
# and the body never answered.
./tools/ns_names_check.sh > /dev/null || { ./tools/ns_names_check.sh; exit 1; }
# ...and a tenth: every dispatch arm's length test matches its own literal.
# A guard whose N is not the literal's length makes the arm UNREACHABLE, with
# no build error and no crash -- the method simply answers "undefined" forever.
# Two arms were written that way (append_features as 16, prepend_features as
# 17) and both were invisible until someone called the method.
./tools/name_len_check.sh > /dev/null || { ./tools/name_len_check.sh; exit 1; }

# Per-run temp files. These were three fixed /tmp names, so two runs of this
# gate at once overwrote each other's expected and actual output and reported a
# FAIL for a program that passes -- measured, by running it twice concurrently.
# A gate that can be made to lie by running it again is not one.
tmpd="$(mktemp -d "${TMPDIR:-/tmp}/mere_ruby_corpus.XXXXXX")"
trap 'rm -rf "$tmpd"' EXIT
exp="$tmpd/exp.txt"; got="$tmpd/got.txt"; dif="$tmpd/diff.txt"

pass=0
for f in corpus/*.rb; do
  ruby "$f" > "$exp" 2>/dev/null
  "$MR_BIN" "$f" > "$got"
  if ! diff -u "$exp" "$got" > "$dif"; then
    echo "FAIL $f"
    cat "$dif"
    exit 1
  fi
  pass=$((pass + 1))
  echo "ok   $f"
done
echo "$pass/$pass corpus programs match ruby"
