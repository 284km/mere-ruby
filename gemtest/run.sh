#!/bin/sh
# Load every gem in gems.txt under mere-ruby and print the tally.
#
#   ./gemtest/run.sh <gem-home> <rubygems-checkout> [stdlib-dir]
#
# With a stdlib directory, mere-ruby is pointed at a CRuby installation's
# pure-Ruby stdlib with -I; without one it runs on what it ships.
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
gem_home="$1"
rubygems="$2"
stdlib="$3"
[ -d "$gem_home" ] || { echo "usage: run.sh <gem-home> <rubygems-checkout> [stdlib-dir]"; exit 2; }
[ -d "$rubygems/lib" ] || { echo "usage: run.sh <gem-home> <rubygems-checkout> [stdlib-dir]"; exit 2; }
inc=""
[ -n "$stdlib" ] && inc="-I$stdlib"
GEM_HOME="$gem_home" GEM_PATH="$gem_home" RUBYGEMS_LIB="$rubygems/lib" \
  "$mr" $inc "$here/load_gems.rb"
