#!/bin/sh
# Run a rubygems test file (from a rubygems checkout) under BOTH ruby and
# mere-ruby with the minitest-lite shim in rgtest/helper.rb, and diff the
# tallies. Like mspec/run_spec.sh, the verdict is a byte comparison against
# CRuby, not a self-assessment.
#
#   ./run.sh <path/to/rubygems> [test_file ...]
#
# With no test files it runs the pure-Ruby core: version, requirement,
# dependency — the classes that drive gem activation.
set -u
# The reference ruby's own output depends on its default external encoding:
# with the locale unset (or not UTF-8) `p "にち"` escapes to "\u306B\u3061",
# while mere-ruby has one behaviour and prints the bytes. That made corpus/118
# fail on a machine where LANG is not set -- the interpreter measuring the same
# as ever, the environment answering differently. -Eutf-8 pins the reference
# instead of trusting the shell (a locale name would need that locale to exist;
# this option does not).
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
root="${1:?usage: run.sh <path/to/rubygems> [test_file ...]}"
shift
files="$*"
[ -n "$files" ] || files="test_gem_version.rb test_gem_requirement.rb test_gem_dependency.rb"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp "$here/helper.rb" "$tmp/helper.rb"

status=0
for f in $files; do
  src="$root/test/rubygems/$f"
  [ -f "$src" ] || { echo "skip $f (not found)"; continue; }
  # Same test body for both, differing only in how the checkout's RubyGems gets
  # loaded: ruby takes -I (it has its own RubyGems preloaded, and -I is what
  # makes the checkout win), mere-ruby has no -I flag and nothing preloaded, so
  # it unshifts $LOAD_PATH and requires rubygems in the source. Both sides then
  # enter the test with the same RubyGems in memory, which is what makes the
  # tallies comparable.
  { cat "$src"; echo; echo 'Gem::TestCase.run_all'; } > "$tmp/$f"
  { echo "\$LOAD_PATH.unshift(\"$root/lib\")"; echo 'require "rubygems"'; cat "$tmp/$f"; } > "$tmp/mr_$f"
  rb="$(cd "$tmp" && RUBYOPT= ruby -I"$root/lib" "$f" 2>&1 | tail -1)"
  mrout="$(cd "$tmp" && perl -e 'alarm 120; exec @ARGV' "$mr" "mr_$f" 2>&1 | tail -1)"
  if [ "$rb" = "$mrout" ]; then
    echo "MATCH $f  [$rb]"
  else
    echo "DIFF  $f  ruby[$rb]  mere-ruby[$mrout]"
    status=1
  fi
done
exit $status
