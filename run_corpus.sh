#!/bin/sh
# Run every corpus program under the reference ruby and under ./mere-ruby,
# and diff stdout/status. Optional stderr comparisons use the same executions.
# Stdout/status retain first-failure behavior; stderr is compared in one batch.
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
# Stderr is opt-in while the measured baseline differences are corrected.
# Both modes retain ordering and duplicates; "all" also checks non-warning text.
sb_stderr="${CORPUS_STDERR:-off}"
case "$sb_stderr" in
  off|warnings|all) ;;
  *) echo "CORPUS_STDERR must be off, warnings or all" >&2; exit 2 ;;
esac
# A caller may supply reference stdlib paths through RUBYLIB. They are fallbacks
# for Mere, whose C-backed libraries (including monitor) are shipped internally.
# Do not reorder the reference side or override paths a program adds with -I
# or $LOAD_PATH.unshift. Ask only once, before any Mere invocation.
mere_rubylib="${RUBYLIB:-}"
if [ -n "$mere_rubylib" ]; then
  mere_load_path="$(sh "$(dirname "$0")/tools/runtime_load_path.sh" "$MR_BIN")"
  mere_rubylib="$mere_load_path:$mere_rubylib"
fi
# One interpreter self-check first: an Errno class registered with no strerror
# text loses its message prefix SILENTLY (`raise Errno::EXYZ, "m"` would read "m"
# where ruby reads "<text> - m"), so the class list and the text table are asked
# about each other rather than trusted to stay in step.
errno_out="$(MERE_RUBY_ERRNO_CHECK=1 env ${mere_rubylib:+RUBYLIB="$mere_rubylib"} "$MR_BIN" corpus/01_arith.rb 2>&1 >/dev/null || true)"
case "$errno_out" in
  *MISSING*) echo "$errno_out"
             echo "an Errno class has no strerror text -- see errno_desc in main.mere"
             exit 1;;
esac
# A class's counts beside the shapes (sh_cls_var, sh_cls_cap) are kept by its
# name and nothing bounds them but the collector: 3,000 classes made and
# dropped, each with objects of two shapes, and an object's singleton class
# each turn, must leave a few hundred keys at most. Before the sweep dropped
# them (note 559 step 2b, #322's review) every class left its keys for good.
shape_out="$(MERE_RUBY_STORE_STATS=1 env ${mere_rubylib:+RUBYLIB="$mere_rubylib"} "$MR_BIN" tools/shape_class_tables_check.rb 2>&1 >/dev/null || true)"
for row in sh_cls_var sh_cls_cap; do
  n="$(printf '%s\n' "$shape_out" | awk -v r="$row" '$1 == r { print $2 }')"
  if [ -z "$n" ] || [ "$n" -gt 300 ]; then
    echo "$row holds ${n:-no row} keys after 3,000 dropped classes (tools/shape_class_tables_check.rb): a dead class's keys are not swept"
    exit 1
  fi
done
# Another self-check: every global map that holds object handles is a GC root
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
# ...and: no object's instance variable is read or written by its table key
# "<id>@<name>" outside the door (m_state's iv_*). Since note 559 step 2b the
# variable is in a shape's slot, and such a read finds nothing, quietly.
./tools/iv_door_check.sh > /dev/null || { ./tools/iv_door_check.sh; exit 1; }
# ...and every StrBuf is made inside a region block (or allowed, with the reason
# it may stay): one made outside is the default region's, which nothing gives
# back, and its buffer -- the size of what it built -- stays for the rest of the
# run, every call.
python3 ./tools/strbuf_region_check.py > /dev/null || { python3 ./tools/strbuf_region_check.py; exit 1; }
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
stderr_manifest="$tmpd/stderr.tsv"
if [ "$sb_stderr" != off ]; then
  mkdir "$tmpd/stderr"
  : > "$stderr_manifest"
fi

# ⚠ `--both` RUNS THE REFERENCE ONCE, NOT TWICE. Every change is swept with the
# hash index ON and again with it OFF, which used to be two whole invocations of
# this script -- and the second one re-ran `ruby` over all 213 programs to
# reproduce output it had already produced.
#
# It is the same output: measured 2026-09-22, all 213 programs give a
# byte-identical reference result with and without MERE_RUBY_NO_HASH_INDEX in
# the environment (the flag is this interpreter's, and the three corpus programs
# that enumerate ENV compare sizes against themselves rather than absolutely).
# So the reference side of the second pass was pure repetition.
#
# Two runs of this script may go at once, even in one tree. A corpus program
# that writes a file names it with the process id (`/tmp/mr277_#{$$}.txt`,
# `corpus/zzz_to_path_#{$$}.txt`) or under Dir.tmpdir with the id, and one that
# listens asks for port 0. They used to write fixed paths (`/tmp/mrb_al_source.rb`,
# `corpus/531_object_root_constants.rb.autoload.rb`) and listen on a fixed port
# (53791), so two runs at once deleted each other's files and refused each
# other's listener, and the FAIL looked exactly like an interpreter bug. A new
# program keeps to this: no fixed path it writes, no fixed port it listens on,
# and nothing it prints that depends on the id. Measured 2026-11-28 by running
# every program under the reference ruby with writes denied outside a private
# TMPDIR and outside paths that carry a process id: none wrote anywhere else.
sb_both=0
if [ "${1:-}" = "--both" ]; then
  sb_both=1
  # A caller may already have disabled indexing. The first pass must still
  # exercise ON; the second pass below explicitly selects OFF.
  unset MERE_RUBY_NO_HASH_INDEX
fi

# CI can collect every platform difference in one run, still failing the gate.
# Default callers retain the first-failure behavior.
sb_keep="${CORPUS_KEEP_GOING:-0}"
pass=0
failed=0
total=0
for f in corpus/*.rb; do
  rrc=0
  mrc=0
  if [ "$sb_stderr" = off ]; then
    "$REF_RUBY_BIN" "$f" > "$exp" 2>/dev/null || rrc=$?
    env ${mere_rubylib:+RUBYLIB="$mere_rubylib"} "$MR_BIN" "$f" > "$got" || mrc=$?
  else
    stderr_name="${f##*/}"
    stderr_reference="$tmpd/stderr/$stderr_name.ref"
    stderr_on="$tmpd/stderr/$stderr_name.on"
    stderr_off="-"
    "$REF_RUBY_BIN" "$f" > "$exp" 2> "$stderr_reference" || rrc=$?
    env ${mere_rubylib:+RUBYLIB="$mere_rubylib"} "$MR_BIN" "$f" > "$got" 2> "$stderr_on" || mrc=$?
  fi
  total=$((total + 1))
  bad=0
  if ! diff -u "$exp" "$got" > "$dif"; then
    echo "FAIL $f"
    cat "$dif"
    bad=1
  fi
  if [ "$rrc" != "$mrc" ]; then
    echo "FAIL $f (ruby exited $rrc and mere-ruby $mrc)"
    bad=1
  fi
  if [ "$bad" = 1 ] && [ "$sb_keep" != 1 ]; then exit 1; fi
  if [ "$sb_both" = 1 ]; then
    mrc=0
    if [ "$sb_stderr" = off ]; then
      MERE_RUBY_NO_HASH_INDEX=1 env ${mere_rubylib:+RUBYLIB="$mere_rubylib"} "$MR_BIN" "$f" > "$got" || mrc=$?
    else
      stderr_off="$tmpd/stderr/$stderr_name.off"
      MERE_RUBY_NO_HASH_INDEX=1 env ${mere_rubylib:+RUBYLIB="$mere_rubylib"} "$MR_BIN" "$f" > "$got" 2> "$stderr_off" || mrc=$?
    fi
    if ! diff -u "$exp" "$got" > "$dif" || [ "$rrc" != "$mrc" ]; then
      echo "FAIL $f (with MERE_RUBY_NO_HASH_INDEX=1; ruby exited $rrc, mere-ruby $mrc)"
      cat "$dif"
      bad=1
    fi
  fi
  if [ "$sb_stderr" != off ]; then
    printf '%s\t%s\t%s\t%s\n' "$f" "$stderr_reference" "$stderr_on" "$stderr_off" >> "$stderr_manifest"
  fi
  if [ "$bad" = 1 ]; then
    failed=$((failed + 1))
    if [ "$sb_keep" != 1 ]; then exit 1; fi
  else
    pass=$((pass + 1))
    echo "ok   $f"
  fi
done
stderr_status=0
if [ "$sb_stderr" != off ]; then
  "$REF_RUBY_BIN" tools/corpus_stderr_check.rb "$sb_stderr" "$stderr_manifest" \
    "$REF_RUBY_BIN" "$MR_BIN" "$PWD" "$tmpd" "${CORPUS_STDERR_REPORT:-}" || stderr_status=$?
fi
if [ "$failed" != 0 ]; then
  echo "$failed/$total corpus programs differ from ruby ($pass match)"
  exit 1
fi
if [ "$sb_both" = 1 ]; then
  echo "$pass/$pass corpus programs match ruby, with the hash index ON and OFF"
else
  echo "$pass/$pass corpus programs match ruby"
fi
if [ "$stderr_status" != 0 ]; then
  exit "$stderr_status"
fi
