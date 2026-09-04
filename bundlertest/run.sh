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
# versions: ruby answers the bundler that ships with it (2.4.10) even with a
# newer bundler gem installed, because rubygems prefers the default gem for
# bundler; mere-ruby's activation picks the newest installed one (2.6.7). The
# other three steps agree, so the load path and resolution are right and only
# which bundler gets activated differs. Recorded in KNOWN_GAPS.md; the fix is
# in gem activation, not here.
DIVERGING="versions"

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
