#!/bin/sh
# WHAT is the memory of one Ruby method call made of? alloc_per_call.sh answers
# how much (peak RSS); this answers how many allocations and how big, by building
# a copy of the generated C with a counter inside the region allocator.
#
#   ./bench/alloc_sites.sh [path/to/mr.c]
#
# The answer as of 2026-08-20: an EMPTY method call is ~240 allocations totalling
# ~7.4 KB, of which 19 in 24 are 32 bytes or less. Not one big thing -- hundreds
# of small ones. That is what any reclamation work has to move.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
src="${1:-$here/../mr.c}"
[ -f "$src" ] || { echo "usage: alloc_sites.sh [mr.c]  (generate it with: mere -c main.mere > mr.c)"; exit 2; }
command -v clang > /dev/null || { echo "needs clang"; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# a counter and a size histogram in front of the bump allocator. The C goes in a
# file rather than inside awk's print statements: escaping a C string through awk
# escaping is how the first version of this produced C that would not compile.
cat > "$tmp/pre.c" <<'PRE'
static unsigned long long __pa = 0, __pb = 0, __ph[8] = {0};
static void __attribute__((destructor)) __pr(void) {
  const char* n[8] = {"<=32","<=64","<=128","<=256","<=1K","<=4K","<=64K",">64K"};
  fprintf(stderr, "ALLOCS %llu BYTES %llu", __pa, __pb);
  for (int i = 0; i < 8; i++) fprintf(stderr, " %s=%llu", n[i], __ph[i]);
  fprintf(stderr, "\n");
}
PRE
cat > "$tmp/body.c" <<'BODY'
  __pa++; __pb += n;
  __ph[n <= 32 ? 0 : n <= 64 ? 1 : n <= 128 ? 2 : n <= 256 ? 3 : n <= 1024 ? 4 : n <= 4096 ? 5 : n <= 65536 ? 6 : 7]++;
BODY
# The splice is done with BYTE tools, not line tools. The generated C is not
# text: `awk \'{print}\'` over it loses 11 bytes (mere-ruby embeds Ruby sources
# with bytes that are not valid UTF-8, and awk strings stop at a NUL), so the
# copy stopped compiling at a line nowhere near the patch. LC_ALL=C does not fix
# that -- only not reading it as lines does. Its longest line is 397386 bytes,
# which is another reason to leave it alone.
sig='static void* __lang_region_alloc(__lang_region* r, size_t n) {'
off=$(LC_ALL=C grep -b -m1 -F "$sig" "$src" | cut -d: -f1)
[ -n "${off:-}" ] || { echo "could not find the region allocator in $src"; exit 1; }
siglen=$(LC_ALL=C grep -m1 -F "$sig" "$src" | wc -c | tr -d ' ')

head -c "$off" "$src"                                        >  "$tmp/probe.c"
cat "$tmp/pre.c"                                             >> "$tmp/probe.c"
tail -c "+$((off + 1))" "$src" | head -c "$siglen"           >> "$tmp/probe.c"
cat "$tmp/body.c"                                            >> "$tmp/probe.c"
tail -c "+$((off + siglen + 1))" "$src"                      >> "$tmp/probe.c"

clang -O2 -Wl,-stack_size,0x20000000 "$tmp/probe.c" -o "$tmp/mr" 2> "$tmp/build.err" || {
  echo "build failed:"; tail -5 "$tmp/build.err"; exit 1; }

n=100000
printf 'def f; end\n%d.times { f }\n' "$n" > "$tmp/call.rb"
printf '%d.times { }\n' "$n" > "$tmp/block.rb"
printf 'def f(a); a + 1; end\n%d.times {|i| f(i) }\n' "$n" > "$tmp/args.rb"

printf '%-22s %-12s %-14s %s\n' program allocs/call bytes/call histogram
for prog in call block args; do
  line="$("$tmp/mr" "$tmp/$prog.rb" 2>&1 >/dev/null | grep -a '^ALLOCS' || true)"
  a=$(printf '%s' "$line" | awk '{print $2}')
  b=$(printf '%s' "$line" | awk '{print $4}')
  h=$(printf '%s' "$line" | cut -d' ' -f5-)
  printf '%-22s %-12s %-14s %s\n' "$prog.rb" \
    "$(echo "$a $n" | awk '{printf "%.0f", $1/$2}')" \
    "$(echo "$b $n" | awk '{printf "%.0f", $1/$2}')" "$h"
done
