#!/bin/sh
# Does bundler work here? Run the same steps under the reference ruby and under
# mere-ruby, with the SAME rubygems and bundler -- the ones in the ruby
# installation's stdlib, which ship together and therefore agree with each
# other. (A rubygems checkout paired with a separate bundler checkout does not:
# rubygems 4.1.0.dev has no Gem::Platform.match, which bundler 2.2.0.dev calls,
# so ruby itself fails there and the comparison says nothing.)
#
#   ./bundlertest/run.sh <stdlib-dir> <gem-home>
#
# e.g. .../lib/ruby/4.0.0 and .../lib/ruby/gems/4.0.0
#
# Every step agrees now, `setup` included -- it is the last one to have. It went
# thor's caller[1], then comparison through a user <=>, then module_function's
# scope, then an exception that kept neither class nor message, then `rescue *[]`
# swallowing everything, then an ensure body that consumed the exception it ran
# under, and finally File.open refusing the Pathname bundler writes the lockfile
# through. Each was recorded here as a DIVERGE while it lasted, and each retired
# because this gate fails when a recorded divergence starts agreeing. Set
# DIVERGING to a step name again when the next boundary appears.
set -u
. "$(cd "$(dirname "$0")" && pwd)"/../tools/ref_ruby.sh
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
stdlib="${1:?usage: run.sh <stdlib-dir> <gem-home>}"
gem_home="${2:?usage: run.sh <stdlib-dir> <gem-home>}"
[ -f "$stdlib/rubygems.rb" ] || { echo "no rubygems.rb under $stdlib"; exit 2; }
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
# NOTHING is expected to diverge here as of 2026-09-05: every step -- reading
# the Gemfile, resolving it, building the definition, and setting up the load
# paths -- answers what ruby answers, with the reference's own rubygems 4.0.16
# and bundler 4.0.16 on both sides. Set DIVERGING to a step name when the next
# boundary appears; the gate fails either way (a recorded divergence that
# starts agreeing is reported as RETIRE, so the record cannot go stale).
#
# `setup` was the last to go, and the move to ruby 4.0.6 cost it three
# separate causes in one day: rubygems 4's vendored uri defines a constant in
# a `class << self` body and reads it from a method defined there (the def
# recorded the enclosing class as its scope); bundler's materialization sorts
# candidates with `sort_by.with_index`, which answered [spec, index] pairs
# because with_index materialised and re-ran instead of wrapping the block;
# and bundled_gems.rb reads `RbConfig::CONFIG["rubylibdir"]`, a key this
# interpreter's stand-in RbConfig did not have, and adds "/" to nil.
#
# `versions` RETIRED on 2026-09-04: with the reference's own rubygems and
# bundler on both sides they answer the same pair. The gate said so itself
# rather than being asked.
DIVERGING=""

run() {  # $1 = interpreter command line
  GEM_HOME="$gem_home" GEM_PATH="$gem_home" \
    perl -e 'alarm 300; exec @ARGV' $1 -I"$stdlib" "$here/probe.rb" 2>/dev/null
}
rb="$(run "ruby --disable-gems")"
mr="$(run "$root/mere-ruby")"

fail=0
for step in versions dsl definition setup; do
  a="$(printf '%s\n' "$rb" | sed -n "s/^$step=//p")"
  b="$(printf '%s\n' "$mr" | sed -n "s/^$step=//p")"
  if [ "$step" = "$DIVERGING" ]; then
    if [ "$a" = "$b" ]; then
      echo "RETIRE  $step  both say [$a] -- the recorded divergence is gone, update run.sh and KNOWN_GAPS.md"
      fail=1
    else
      echo "DIVERGE $step  ruby[$a]  mere-ruby[$b]  (see KNOWN_GAPS.md)"
    fi
  elif [ "$a" = "$b" ] && [ -n "$a" ]; then
    echo "MATCH   $step  [$a]"
  else
    echo "FAIL    $step  ruby[$a]  mere-ruby[$b]"
    fail=1
  fi
done
exit $fail
