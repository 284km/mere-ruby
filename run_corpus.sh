#!/bin/sh
# Run every corpus program under the reference ruby and under ./mere-ruby,
# and diff the outputs. Exits non-zero on the first mismatch.
set -e
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
