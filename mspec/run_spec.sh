#!/bin/sh
# Run a real spec/ruby file through the minimal mspec shim, under BOTH
# mere-ruby and ruby, and diff the outputs. The spec tree (core/, language/,
# shared/, fixtures/) is cloned into a temp dir with the shim installed as
# spec_helper.rb, so every require_relative (../spec_helper,
# ../../spec_helper, sibling shared/, cross-directory shared/) resolves.
#
#   ./run_spec.sh <path/to/some_spec.rb> [--keep]
spec="$1"
[ -f "$spec" ] || { echo "usage: run_spec.sh <spec.rb>"; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
tmp="$(mktemp -d)"
specdir="$(cd "$(dirname "$spec")" && pwd)"
# subpath under spec/ruby (e.g. "language", "core/enumerator"); the spec root.
case "$specdir" in
  */spec/ruby/*)
    sub="${specdir#*/spec/ruby/}"
    specroot="${specdir%/$sub}"
    ;;
  *) sub="language"; specroot="" ;;
esac
if [ -n "$specroot" ]; then
  # clone the relevant trees (APFS copy-on-write when available).
  for d in core language shared fixtures; do
    [ -d "$specroot/$d" ] || continue
    cp -Rc "$specroot/$d" "$tmp/$d" 2>/dev/null || cp -R "$specroot/$d" "$tmp/$d"
  done
else
  mkdir -p "$tmp/$sub"
  cp "$spec" "$tmp/$sub/"
  [ -d "$specdir/fixtures" ] && cp -R "$specdir/fixtures" "$tmp/$sub/fixtures"
  [ -d "$specdir/shared" ] && cp -R "$specdir/shared" "$tmp/$sub/shared"
fi
# the shim replaces the real mspec spec_helper.
cp "$here/spec_helper.rb" "$tmp/spec_helper.rb"
base="$(basename "$spec" .rb)"
cat > "$tmp/driver.rb" <<EOF
require_relative "spec_helper"
require_relative "$sub/$base"
mspec_report
EOF
# Bound the mere-ruby run HERE, not only in the caller: scoreboard.sh's alarm
# kills this script, but the child would keep spinning (a runaway spec used to
# leave one behind per sweep, and they pile up until the machine is out of
# memory). SIGKILL after the deadline so nothing survives.
# ...and bound the BYTES, on both sides. A command substitution buffers the
# whole output in THIS shell, so a spec that prints without end grows the
# harness rather than the interpreter -- which is why rss_guard.sh, watching
# only processes whose args say mere-ruby, logged no kill on the two occasions
# a sweep took the machine down (2026-09-04). `head -c` stays in the pipe
# because closing it is what stops the producer (SIGPIPE); capturing to a file
# first would trade a bounded run for an unbounded one.
#
# The reference side had no bound at all -- no alarm, no cap. It is one ruby
# loop away from the same crash, and "the reference cannot run away" is an
# assumption, not a property.
#
# The exit status travels beside the output rather than through it: with
# `head -c` in the way, `$?` would be head's.
out_cap=2000000
out_m="$({ perl -e 'alarm 25; exec @ARGV' "$mr" "$tmp/driver.rb" 2>&1; echo "$?" > "$tmp/rc_m"; } | head -c "$out_cap")"
rc_m="$(cat "$tmp/rc_m" 2>/dev/null || echo 0)"
out_r="$({ perl -e 'alarm 25; exec @ARGV' ruby -W0 "$tmp/driver.rb" 2>&1; echo "$?" > "$tmp/rc_r"; } | head -c "$out_cap")"

# Say WHICH failure it was, in the section it belongs to, and let scoreboard.sh
# classify as it always has: with no `pass=` line in mere-ruby's section it
# records CRASH and takes the last line as the cause. A run the guard SIGKILLs
# and a run that aborts on its own both arrive here as no output, and the
# record then says "mere-ruby aborted" about a file that works and wants 15 GB.
# (Replacing the REFERENCE section instead makes it SKIP -- a claim about ruby.)
if [ "$rc_m" = "137" ] || [ "$rc_m" = "9" ]; then
  out_m="KILLED at the memory cap (SIGKILL; see mspec/rss_kills.log) -- it did not abort on its own"
fi
if [ "${#out_m}" -ge "$out_cap" ]; then
  out_m="RUNAWAY OUTPUT: passed $out_cap bytes and was cut off"
fi
if [ "${#out_r}" -ge "$out_cap" ]; then
  out_r="RUNAWAY OUTPUT on the reference side: passed $out_cap bytes and was cut off"
fi
echo "--- mere-ruby:"; echo "$out_m"
echo "--- ruby:";      echo "$out_r"
if [ "$out_m" = "$out_r" ]; then echo "MATCH"; else echo "DIFF"; fi
[ "$2" = "--keep" ] || rm -rf "$tmp"
