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
# e.g. .../lib/ruby/3.2.0 and .../lib/ruby/gems/3.2.0
#
# One step is expected NOT to agree: `setup` reaches bundler's vendored thor,
# which reads `caller[1]`, and mere-ruby keeps no call stack (KNOWN_GAPS.md).
# That is recorded here as DIVERGE rather than dropped, and this gate fails if
# it ever starts agreeing -- a boundary that has moved has to be noticed.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
stdlib="${1:?usage: run.sh <stdlib-dir> <gem-home>}"
gem_home="${2:?usage: run.sh <stdlib-dir> <gem-home>}"
[ -f "$stdlib/rubygems.rb" ] || { echo "no rubygems.rb under $stdlib"; exit 2; }
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"
export RUBYOPT
DIVERGING=setup

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
      echo "DIVERGE $step  ruby[$a]  mere-ruby[$b]  (no call stack; KNOWN_GAPS.md)"
    fi
  elif [ "$a" = "$b" ] && [ -n "$a" ]; then
    echo "MATCH   $step  [$a]"
  else
    echo "FAIL    $step  ruby[$a]  mere-ruby[$b]"
    fail=1
  fi
done
exit $fail
