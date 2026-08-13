#!/bin/sh
# Load every gem in gems.txt under mere-ruby AND under the reference ruby, and
# compare. The reference run is the point: two gems in the list (action_tracer,
# letter_opener_web) cannot be required outside a Rails application, and CRuby
# fails them with `uninitialized constant Rails` exactly as mere-ruby does.
# Counting those against the interpreter overstated the gap by two.
#
#   ./gemtest/run.sh <gem-home> <rubygems-checkout> [stdlib-dir]
#
# With a stdlib directory, mere-ruby is pointed at a CRuby installation's
# pure-Ruby stdlib with -I; without one it runs on what it ships.
#
# One gem per process. It costs a startup each, and it buys a gate that keeps
# reporting when a gem crashes the interpreter outright: a native signal in a
# single batch process used to take every gem after it down with it, and the
# tally silently shrank.
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
gem_home="$1"
rubygems="$2"
stdlib="$3"
[ -d "$gem_home" ] || { echo "usage: run.sh <gem-home> <rubygems-checkout> [stdlib-dir]"; exit 2; }
[ -d "$rubygems/lib" ] || { echo "usage: run.sh <gem-home> <rubygems-checkout> [stdlib-dir]"; exit 2; }
inc=""
[ -n "$stdlib" ] && inc="-I$stdlib"
list="${GEMLIST:-$here/gems.txt}"
ok=0; bad=0; skip=0
while IFS= read -r line; do
  g=$(printf '%s' "$line" | tr -d '\r' | sed 's/^ *//;s/ *$//')
  [ -z "$g" ] && continue
  case "$g" in \#*) continue;; esac
  # what the reference ruby makes of it, in the same gem home
  rout=$(GEM_HOME="$gem_home" GEM_PATH="$gem_home" \
         ruby "$here/load_one.rb" "$g" 2>/dev/null)
  out=$(GEM_HOME="$gem_home" GEM_PATH="$gem_home" RUBYGEMS_LIB="$rubygems/lib" \
        "$mr" $inc "$here/load_one.rb" "$g" 2>/dev/null)
  code=$?
  if [ $code -ne 0 ]; then
    # a native signal: the interpreter died rather than raising
    echo "CRASH $g  (exit $code)"
    bad=$((bad + 1))
    continue
  fi
  case "$rout" in
    OK*)
      echo "$out"
      case "$out" in OK*) ok=$((ok + 1));; *) bad=$((bad + 1));; esac
      ;;
    *)
      # ruby cannot load it here either — not a statement about mere-ruby
      echo "SKIP $g  (ruby: ${rout#FAIL* })"
      skip=$((skip + 1))
      ;;
  esac
done < "$list"
echo "TOTAL ok=$ok fail=$bad skip=$skip (of $((ok + bad)) gems ruby itself loads)"
