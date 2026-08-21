#!/bin/sh
# Does the memory of a GROWN region come back in a form the next region can use?
# This is the load-bearing property for any world-compaction ("swap") loop: each
# cycle copies the live set into a fresh region and releases the old one, so
# total footprint is bounded ~2x live ONLY if released chains are actually
# reusable. reclaim.sh part 0 answered this for regions that never grow (struct
# cache, no free); this asks about the free()+re-seed path a compaction would
# always take.
#
#   MERE=/path/to/mere ./bench/region_reuse.sh
#
# Two independent answers per probe:
#   blocks: cum=<all block bytes ever malloc'd>  max=<live high-water>  end=<still held at exit>
#     counted INSIDE the runtime (deterministic; the block header's pad field
#     carries each block's size so free can subtract it).
#   peak RSS as a range over 3 runs (the OS's answer; quantized and noisy, see
#     reclaim.sh for why it cannot stand alone).
# Reuse works at the allocator level iff x8's max is ~x1's max while cum is ~8x.
# The no_region control must show max ~= cum (nothing ever comes back), or the
# harness itself is broken.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mere="${MERE:-mere}"
d="$here/reclaim"
tmp="${TMPDIR:-/tmp}/mrb_reuse.$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

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
  if [ "$lo" = "$hi" ]; then echo "${lo}"; else echo "${lo}-${hi}"; fi
}

instrument() {  # $1 = src.c  $2 = out.c
  python3 - "$1" "$2" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
# counters, declared before the first runtime function
key = "static void __lang_region_add_block("
s = s.replace(key,
  "static unsigned long long __bk_cum=0,__bk_live=0,__bk_max=0;\n" + key, 1)
# add_block: count the malloc, remember the size in the (otherwise unused) pad
i = s.index('if (!b) __lang_fail_impl("out of memory");')
j = s.index("\n", i)
s = s[:j] + ("\n  __bk_cum += (unsigned long long)cap; __bk_live += (unsigned long long)cap;"
             "\n  if (__bk_live > __bk_max) __bk_max = __bk_live;"
             "\n  b->pad = cap;") + s[j:]
# region_free: subtract what free() hands back
i = s.index("static void __lang_region_free(")
j = s.index("free(b);", i)
s = s[:j] + "__bk_live -= b->pad;\n    " + s[j:]
k = s.rindex("return 0;")
s = s[:k] + ('fprintf(stderr, "blocks: cum=%llu max=%llu end=%llu\\n",'
             ' __bk_cum, __bk_max, __bk_live);\n  ') + s[k:]
open(dst, "w", encoding="utf-8").write(s)
PYEOF
}

mib() { awk -v b="$1" 'BEGIN{printf "%.0f", b/1048576}'; }

printf "%-26s %-30s %s\n" "probe" "blocks (MiB)" "peak RSS MiB (3 runs)"
for p in p9_grown_region_x1 p9_grown_region_x8 p9_grown_no_region_x8; do
  "$mere" -c "$d/$p.mere" > "$tmp/$p.c" 2> "$tmp/$p.err" || { printf "%-26s EMIT FAIL: %s\n" "$p" "$(head -1 "$tmp/$p.err")"; continue; }
  instrument "$tmp/$p.c" "$tmp/${p}_i.c"
  clang -O2 "$tmp/${p}_i.c" -o "$tmp/$p.bin" 2> "$tmp/$p.cerr" || { printf "%-26s BUILD FAIL: %s\n" "$p" "$(head -1 "$tmp/$p.cerr")"; continue; }
  acct=$("$tmp/$p.bin" 2>&1 >/dev/null)
  cum=$(printf '%s' "$acct" | sed -n 's/.*cum=\([0-9]*\).*/\1/p')
  max=$(printf '%s' "$acct" | sed -n 's/.*max=\([0-9]*\).*/\1/p')
  end=$(printf '%s' "$acct" | sed -n 's/.*end=\([0-9]*\).*/\1/p')
  printf "%-26s cum=%-6s max=%-6s end=%-6s %s\n" "$p" "$(mib "$cum")" "$(mib "$max")" "$(mib "$end")" "$(peak "$tmp/$p.bin")"
done
