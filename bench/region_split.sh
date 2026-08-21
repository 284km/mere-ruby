#!/bin/sh
# Splits one run's allocations into the two pools that have OPPOSITE fates:
#
#   def  = bytes bumped in the DEFAULT region -- never reclaimed by anything
#          today. Live guest objects, dead guest objects, and interpreter
#          permanents are all in here, undistinguished; this is the number any
#          collector design has to attack.
#   blk  = bytes bumped in BLOCK regions (statement regions and `region` blocks)
#          -- already reclaimed at each block's exit. The solved part.
#
# plus the malloc-level block accounting for each pool (cum / high-water), so
# "def grew to N" can be separated from "def BUMPED N" (blocks double, so the
# last block is half slack on average).
#
#   ./bench/region_split.sh workload.rb [more.rb ...]      (needs ./mr.c)
#
# The counters go INSIDE the generated C (byte splice -- mr.c embeds Ruby
# sources with NULs and 400KB lines; line tools corrupt it, see alloc_sites.sh).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="$root/mr.c"
[ -f "$src" ] || { echo "no $src (generate: mere -c main.mere > mr.c)"; exit 2; }
[ $# -ge 1 ] || { echo "usage: region_split.sh workload.rb ..."; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 - "$src" "$tmp/mr_split.c" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
b = open(src, "rb").read()

decl = (b"static unsigned long long __def_bump=0,__blk_bump=0,"
        b"__def_blk_cum=0,__blk_blk_cum=0,__blk_blk_live=0,__blk_blk_max=0;\n"
        b"static void __attribute__((destructor)) __split_report(void) {\n"
        b'  fprintf(stderr, "SPLIT def_bump=%llu blk_bump=%llu def_blocks=%llu '
        b'blk_blocks_cum=%llu blk_blocks_max=%llu\\n",\n'
        b"    __def_bump, __blk_bump, __def_blk_cum, __blk_blk_cum, __blk_blk_max);\n"
        b"}\n")

# counters live just before the first runtime fn that needs them
key = b"static void __lang_region_add_block("
i = b.index(key)
b = b[:i] + decl + b[i:]

# add_block: classify the malloc by which pool the region is. The default
# region's identity check needs its decl, which appears AFTER add_block in the
# emitted C -- so compare against a forward decl we inject here.
i = b.index(b'if (!b) __lang_fail_impl("out of memory");')
j = b.index(b"\n", i)
ins = (b"\n  { extern __lang_region __lang_default_region_fwd asm(\"___lang_default_region\");"
       b"\n    if (r == &__lang_default_region_fwd) __def_blk_cum += cap;"
       b"\n    else { __blk_blk_cum += cap; __blk_blk_live += cap;"
       b"\n           if (__blk_blk_live > __blk_blk_max) __blk_blk_max = __blk_blk_live; }"
       b"\n    b->pad = cap; }")
b = b[:j] + ins + b[j:]

# region_free: give back what the pad remembers (only block regions are freed)
i = b.index(b"static void __lang_region_free(")
j = b.index(b"free(b);", i)
b = b[:j] + b"__blk_blk_live -= b->pad;\n    " + b[j:]

# region_alloc: split the bump by pool ('shared' is already computed there)
i = b.index(b"size_t aligned = (n + 7) & ~((size_t)7);")
j = b.index(b"\n", i)
b = b[:j] + b"\n  if (shared) __def_bump += aligned; else __blk_bump += aligned;" + b[j:]

open(dst, "wb").write(b)
PYEOF

clang -O2 -Wl,-stack_size,0x20000000 "$tmp/mr_split.c" -o "$tmp/mr_split" 2> "$tmp/cc.err" \
  || { echo "build failed:"; head -5 "$tmp/cc.err"; exit 1; }

mib() { awk -v x="$1" 'BEGIN{printf "%.0f", x/1048576}'; }
printf "%-24s %-10s %-10s %-12s %-14s %s\n" "workload" "def MiB" "blk MiB" "def blocks" "blk cum/max" "(def = nothing reclaims it)"
for w in "$@"; do
  out=$("$tmp/mr_split" "$w" 2>&1 >/dev/null | grep "^SPLIT" | tail -1)
  db=$(printf '%s' "$out" | sed -n 's/.*def_bump=\([0-9]*\).*/\1/p')
  bb=$(printf '%s' "$out" | sed -n 's/.*blk_bump=\([0-9]*\).*/\1/p')
  dblk=$(printf '%s' "$out" | sed -n 's/.*def_blocks=\([0-9]*\).*/\1/p')
  bcum=$(printf '%s' "$out" | sed -n 's/.*blk_blocks_cum=\([0-9]*\).*/\1/p')
  bmax=$(printf '%s' "$out" | sed -n 's/.*blk_blocks_max=\([0-9]*\).*/\1/p')
  [ -n "$db" ] || { printf "%-24s (no SPLIT line)\n" "$(basename "$w")"; continue; }
  printf "%-24s %-10s %-10s %-12s %s/%s\n" "$(basename "$w")" "$(mib "$db")" "$(mib "$bb")" "$(mib "$dblk")" "$(mib "$bcum")" "$(mib "$bmax")"
done
