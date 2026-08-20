#!/bin/sh
# What can be given back, and what cannot. Nothing in mere-ruby is ever
# reclaimed, and before designing a collector it is worth knowing which of the
# two layers the memory is in -- the language's, or this interpreter's.
#
#   MERE=/path/to/mere ./bench/reclaim.sh
#
# Part 1 asks the LANGUAGE, in Mere, whether any of its containers give memory
# back. Part 2 asks THIS interpreter where the entries accumulate (it needs a
# build with the store census: MERE_RUBY_STORE_STATS=1). Part 3 runs identical
# work under ruby and mere-ruby, so the live set is the same on both sides and
# the difference is only what is never released.
#
# Every number in KNOWN_GAPS.md's reclamation section comes from here.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
mere="${MERE:-mere}"
mr="$root/mere-ruby"
d="$here/reclaim"
tmp="${TMPDIR:-/tmp}/mrb_reclaim.$$"
mkdir -p "$tmp"

# Peak RSS in MiB -- as a RANGE over three runs, because it is not a
# deterministic number here. The program allocates the same bytes every time,
# but once a run holds several GB the OS starts compressing pages, and what
# "maximum resident set size" then reports moves by a factor of two between
# runs of the same binary (measured: 6227, 10614, 13346, 15664, 15803 MiB for
# the same program). A single figure would be a fiction. For deterministic
# per-call numbers -- allocations and bytes requested -- see alloc_sites.sh,
# which counts inside the region allocator instead of asking the OS.
peak() {
  lo=""; hi=""
  for _ in 1 2 3; do
    v=$(/usr/bin/time -l "$@" 2>&1 >/dev/null | awk '/maximum resident/ {printf "%.0f", $1/1048576}')
    [ -n "$v" ] || continue
    [ -n "$lo" ] || lo=$v
    [ -n "$hi" ] || hi=$v
    [ "$v" -lt "$lo" ] && lo=$v
    [ "$v" -gt "$hi" ] && hi=$v
  done
  if [ "$lo" = "$hi" ]; then echo "$lo"; else echo "$lo-$hi"; fi
}

# The region runtime, counted from inside. Peak RSS cannot answer "was this
# reclaimed?" on its own: a region block in a recursive function's body stops
# clang from turning the self-call into a loop, so the stack grows ~250 bytes an
# iteration and swamps a heap that is being handed back correctly. Reading the
# generated C's own counters separates the two, and this is the measurement that
# corrected an earlier conclusion here (see KNOWN_GAPS).
region_accounting() {  # $1 = .mere file -> "init=N bytes=N acquire=N release=N"
  "$mere" -c "$1" > "$tmp/acct.c" 2> "$tmp/acct.err" || { echo "(compile failed)"; return; }
  python3 - "$tmp/acct.c" "$tmp/acct_i.c" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
s = s.replace("static void __lang_region_init(",
  "static unsigned long long __ri_b=0,__ri_c=0,__acq=0,__rel=0;\nstatic void __lang_region_init(", 1)
for fn, stmt in (("static void __lang_region_init(", "__ri_b += (unsigned long long)cap; __ri_c++;"),
                 ("static __lang_region* __lang_region_block_acquire(void) {", "__acq++;"),
                 ("static void __lang_region_block_release(__lang_region* r) {", "__rel++;")):
    i = s.index(fn); j = s.index("{", i)
    s = s[:j+1] + "\n  " + stmt + "\n" + s[j+1:]
k = s.rindex("return 0;")
s = s[:k] + 'fprintf(stderr, "init=%llu bytes=%llu acquire=%llu release=%llu\\n", __ri_c, __ri_b, __acq, __rel);\n  ' + s[k:]
open(dst, "w", encoding="utf-8").write(s)
PYEOF
  clang -O2 "$tmp/acct_i.c" -o "$tmp/acct.bin" 2>/dev/null || { echo "(build failed)"; return; }
  "$tmp/acct.bin" 2>&1 >/dev/null | tr -d '\n'
}

echo "== 0. is a Map created inside a region block reclaimed? (1M blocks)"
printf "%-34s %s\n" "$(basename "$d/p6_map_in_region_accounted.mere")" "$(region_accounting "$d/p6_map_in_region_accounted.mere")"
echo "   acquire == release and a handful of inits means yes: the region is reused,"
echo "   and the map, its keys and its values go with it."
echo

echo "== 1. does the language give a container's memory back? (1M iterations each)"
printf "%-20s %-11s %s\n" "probe" "peak MiB" "what it asks"
for p in p8_pure_recursion p3_baseline p1_delete p2_overwrite p7_strings_no_region p5_map_per_call p4_map_in_region; do
  case $p in
    p8_pure_recursion)     q="a recursion that allocates NOTHING (the floor)";;
    p3_baseline)           q="build 1M strings, store none";;
    p1_delete)             q="map_set then map_delete each time";;
    p2_overwrite)          q="map_set the same key each time";;
    p7_strings_no_region)  q="1M strings, no region block";;
    p5_map_per_call)       q="a fresh Map per iteration";;
    p4_map_in_region)      q="... the same, inside region R { } (see part 0)";;
  esac
  "$mere" -c "$d/$p.mere" > "$tmp/$p.c" 2> "$tmp/$p.err" \
    && clang -O2 "$tmp/$p.c" -o "$tmp/$p.bin" 2>/dev/null
  if [ -x "$tmp/$p.bin" ]; then
    printf "%-20s %-11s %s\n" "$p" "$(peak "$tmp/$p.bin")" "$q"
  else
    printf "%-20s %-11s %s\n" "$p" "BUILD" "$(head -1 "$tmp/$p.err")"
  fi
done

echo
echo "== 2. where do THIS interpreter's entries accumulate? (200k iterations each)"
if [ -x "$mr" ]; then
  printf "%-18s %-11s %s\n" "workload" "peak MiB" "stores that grew"
  for w in w1_temp_strings w2_objects w3_calls; do
    census=$(MERE_RUBY_STORE_STATS=1 "$mr" "$d/$w.rb" 2>&1 >/dev/null)
    stats=$(printf '%s\n' "$census" | awk -F'\t' '$2+0 > 1000 {printf "%s=%s ", $1, $2}')
    # "no store grew" and "this build has no census" are different answers, and
    # only one of them is about the interpreter.
    if [ -z "$census" ]; then stats="(this build has no census: MERE_RUBY_STORE_STATS does nothing)"
    elif [ -z "$stats" ]; then stats="(no store over 1000 -- it is all temporaries)"
    fi
    printf "%-18s %-11s %s\n" "$w" "$(peak "$mr" "$d/$w.rb")" "$stats"
  done
else
  echo "skipping: no $mr"
fi

echo
echo "== 3. the same work, both interpreters (same live set, same answer)"
if [ -x "$mr" ] && command -v ruby > /dev/null; then
  printf "%-12s %s MiB\n" "ruby" "$(peak ruby "$d/w4_ruby_compare.rb")"
  printf "%-12s %s MiB\n" "mere-ruby" "$(peak "$mr" "$d/w4_ruby_compare.rb")"
else
  echo "skipping: needs ruby and $mr"
fi
rm -rf "$tmp"
