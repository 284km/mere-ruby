#!/bin/sh
# Run every corpus program under the reference ruby and under ./mere-ruby,
# and diff the outputs. Exits non-zero on the first mismatch.
set -e
# The reference ruby's own output depends on its default external encoding:
# with the locale unset (or not UTF-8) `p "にち"` escapes to "\u306B\u3061",
# while mere-ruby has one behaviour and prints the bytes. That made corpus/118
# fail on a machine where LANG is not set -- the interpreter measuring the same
# as ever, the environment answering differently. -Eutf-8 pins the reference
# instead of trusting the shell (a locale name would need that locale to exist;
# this option does not).
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
# One interpreter self-check first: an Errno class registered with no strerror
# text loses its message prefix SILENTLY (`raise Errno::EXYZ, "m"` would read "m"
# where ruby reads "<text> - m"), so the class list and the text table are asked
# about each other rather than trusted to stay in step.
errno_out="$(MERE_RUBY_ERRNO_CHECK=1 ./mere-ruby corpus/01_arith.rb 2>&1 >/dev/null || true)"
case "$errno_out" in
  *MISSING*) echo "$errno_out"
             echo "an Errno class has no strerror text -- see errno_desc in main.mere"
             exit 1;;
esac
# A second self-check: every global map that holds object handles is a GC root
# (or is named, with its reason, in tools/gc_roots_allow.txt). The table that
# was missing from the roots on 2026-09-03 cost `require "bundler"` two weeks.
./tools/gc_roots_check.sh > /dev/null || { ./tools/gc_roots_check.sh | grep -v " root$"; exit 1; }

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
  ./mere-ruby "$f" > "$got"
  if ! diff -u "$exp" "$got" > "$dif"; then
    echo "FAIL $f"
    cat "$dif"
    exit 1
  fi
  pass=$((pass + 1))
  echo "ok   $f"
done
echo "$pass/$pass corpus programs match ruby"
