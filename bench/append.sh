#!/bin/sh
# Is String#<< linear? A Mere `str` is immutable, and appending was a copy of
# the whole receiver per call -- `N.times { s << 'ab' }` went 0.40 s at 20k,
# 1.71 s at 80k and 25 s at 300k, where ruby is 0.09 s at 80k. The shapes:
#
#   append N      s << 'ab', N times, read once at the end (the build)
#   concat N      s.concat('ab') -- the method path, not the operator
#   binary N      String.new (BINARY) << 'ab' (UTF-8): negotiates every time
#   int N         s << 97 (a codepoint)
#   mixed N       s << 'ab'; s.size -- a read after every append
#   sio N         StringIO#write at the end of the stream
#
#   ./bench/append.sh [mere-ruby ...]     each binary, then ruby; best of REPS (3)
#
# Each binary is timed on every shape in turn, alternating, so a slow moment
# of the machine lands on both sides rather than on one.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../tools/ref_ruby.sh"
[ $# -gt 0 ] || set -- "$here/../mere-ruby"
reps="${REPS:-3}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

prog() {  # shape n -> a program that prints a checksum
  case "$1" in
    append) echo "s = +''; $2.times { s << 'ab' }; p s.size" ;;
    concat) echo "s = +''; $2.times { s.concat('ab') }; p s.size" ;;
    binary) echo "s = String.new; $2.times { s << 'ab' }; p [s.size, s.encoding]" ;;
    int)    echo "s = +''; $2.times { s << 97 }; p s.size" ;;
    mixed)  echo "s = +''; t = 0; $2.times { s << 'ab'; t += s.size }; p t" ;;
    sio)    echo "require 'stringio'; io = StringIO.new(+''); $2.times { io.write('ab') }; p io.string.size" ;;
  esac
}
# one run: "<wall seconds> <output>"
run1() {  # bin file
  perl -MTime::HiRes=time -e '
    my $t0 = time; my $out = `"$ARGV[0]" "$ARGV[1]" 2>&1`; chomp $out;
    printf "%.3f %s", time - $t0, $out' "$1" "$2"
}

printf '%-14s' "shape"
for b in "$@"; do printf '%14s' "$(basename "$b")"; done
printf '%14s\n' "ruby"
for spec in "append 20000" "append 80000" "append 300000" "concat 80000" "binary 80000" \
            "int 80000" "mixed 20000" "mixed 80000" "sio 20000"; do
  sh=${spec% *}; n=${spec#* }
  prog "$sh" "$n" > "$tmp/p.rb"
  printf '%-14s' "$sh $n"
  # rep-major, so the binaries alternate; the best of each is kept
  rm -f "$tmp"/best.*
  rep=0
  while [ "$rep" -lt "$reps" ]; do
    k=0
    for b in "$@" "$REF_RUBY_BIN"; do
      r=$(run1 "$b" "$tmp/p.rb")
      t=${r%% *}
      if [ ! -f "$tmp/best.$k" ] || [ "$(echo "$t < $(cat "$tmp/best.$k")" | bc)" = 1 ]; then
        printf '%s' "$t" > "$tmp/best.$k"
      fi
      printf '%s' "${r#* }" > "$tmp/out.$k"
      k=$((k + 1))
    done
    rep=$((rep + 1))
  done
  k=0
  for b in "$@" "$REF_RUBY_BIN"; do
    # a different checksum is a different amount of work: say so, not a time
    if cmp -s "$tmp/out.$k" "$tmp/out.$#"; then printf '%13ss' "$(cat "$tmp/best.$k")"
    else printf '%14s' "DIFF"; fi
    k=$((k + 1))
  done
  echo
done
