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
pass=0
for f in corpus/*.rb; do
  ruby "$f" > /tmp/mere_ruby_exp.txt 2>/dev/null
  ./mere-ruby "$f" > /tmp/mere_ruby_got.txt
  if ! diff -u /tmp/mere_ruby_exp.txt /tmp/mere_ruby_got.txt > /tmp/mere_ruby_diff.txt; then
    echo "FAIL $f"
    cat /tmp/mere_ruby_diff.txt
    exit 1
  fi
  pass=$((pass + 1))
  echo "ok   $f"
done
echo "$pass/$pass corpus programs match ruby"
