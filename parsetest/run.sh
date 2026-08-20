#!/bin/sh
# Can mere-ruby READ the Ruby that exists? A parse error is the one failure
# that takes a whole file with it -- no example runs, no method is missing,
# the file simply does not load -- so it is worth asking in isolation, over
# thousands of files, without executing any of them.
#
#   ./parsetest/run.sh <dir> [dir ...]
#
# The tree the recorded FAILURES.txt is measured over is a ruby checkout's
# whole spec/ (ruby-spec, plus the bundler and mspec suites vendored under it)
# and a rubygems checkout's lib/ -- about 5400 files ruby -c accepts. Sweeping
# a NARROWER tree gives a smaller number that is not comparable with it.
#
# The reference is `ruby -c`: a file CRuby itself rejects (newer syntax than
# the reference ruby, or a fixture that is deliberately broken) is SKIPped, so
# the number counts only syntax that ruby accepts and mere-ruby does not.
#
# Writes parsetest/FAILURES.txt -- ONE record, so two sweeps at once produce a
# file that is neither of them: a narrower sweep running alongside a full one
# left 8 of its lines in a full sweep's record here, and the tally printed at
# the end (39) no longer matched the file (47). Run one sweep at a time.
# One line per file, with the parse error and
# the line it names, sorted so the same construct groups together.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
[ $# -gt 0 ] || { echo "usage: run.sh <dir> [dir ...]"; exit 2; }
out="$here/FAILURES.txt"
: > "$out"

ok=0; bad=0; skip=0
for dir in "$@"; do
  [ -d "$dir" ] || { echo "skip $dir (not a directory)"; continue; }
  # the recorded list names each file relative to the swept tree's parent
  # (spec/ruby/core/array/... ), never by the absolute path it happened to
  # live at on one machine: where the checkout sits is not part of the finding.
  root="$(cd "$dir/.." && pwd)/"
  # find is the only way to enumerate a tree here, and -print0 would need xargs
  # to survive spaces; the corpora in question have none.
  for f in $(find "$dir" -name '*.rb' -type f | sort); do
    if ! ruby -c "$f" >/dev/null 2>&1; then
      skip=$((skip + 1))
      continue
    fi
    # 20s: a pathological file should be reported, not wedge the sweep
    msg=$(perl -e 'alarm 20; exec @ARGV' "$mr" --parse-only "$f" 2>&1)
    if [ $? -eq 0 ]; then
      ok=$((ok + 1))
    else
      bad=$((bad + 1))
      # strip the absolute path: the message repeats it, and the list is
      # easier to group by construct without it
      printf '%s\t%s\n' "$(printf '%s' "$msg" | sed "s#$f##g" | tr '\n' ' ')" \
        "$(printf '%s' "$f" | sed "s#^$root##")" >> "$out"
    fi
  done
done

sort "$out" -o "$out"
echo "parsed=$ok failed=$bad skipped=$skip (of $((ok + bad)) files ruby -c accepts)"
[ "$bad" -gt 0 ] && echo "see $out"
exit 0
