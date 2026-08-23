#!/bin/sh
# WHO bumps the default region? region_split.sh answers how the bump divides
# between the default region and block regions; this answers which EMITTING
# SITES the default-region bytes come from, by recording the return address of
# every default-region allocation and symbolizing the top sites with atos.
#
#   ./bench/def_sites.sh workload.rb            (needs ./mr.c; env passes through)
#
# The output is a table of "function  calls  MiB  %", biggest first. This is
# the decomposition step of any collection design: before building a collector
# for the default region, ask which sites fill it -- guest-object stores,
# string data, cons cells, closure envs and copy-outs all have different
# owners and different collection stories.
#
# The splice is done with BYTE tools (grep -b / head -c / tail -c), not line
# tools: mr.c embeds Ruby sources with NULs and 397 KB lines; awk over it loses
# bytes and the copy stops compiling nowhere near the patch (see alloc_sites.sh).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="$root/mr.c"
[ -f "$src" ] || { echo "no $src (generate: mere -c main.mere > mr.c)"; exit 2; }
[ $# -ge 1 ] || { echo "usage: def_sites.sh workload.rb"; exit 2; }
command -v clang >/dev/null || { echo "needs clang"; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- the instrumented copy --------------------------------------------------
cat > "$tmp/pre.c" <<'PRE'
#include <dlfcn.h>
#define __DS_N 65536
/* two tables: keyed by the direct caller of region_alloc, and by that
   caller's caller — the second names WHICH map a shared map runtime is
   filling, which the first cannot. ra(1) is safe here because the build
   keeps frame pointers (-fno-omit-frame-pointer below). */
static struct { void* a; unsigned long long c, b; } __ds0[__DS_N], __ds1[__DS_N];
static void __ds_note_in(void* ra, unsigned long long n,
                         struct { void* a; unsigned long long c, b; } * t) {
  unsigned long long h = ((unsigned long long)ra) >> 2;
  h = (h ^ (h >> 16)) & (__DS_N - 1);
  for (unsigned long long i = 0; i < __DS_N; i++) {
    unsigned long long k = (h + i) & (__DS_N - 1);
    if (t[k].a == ra) { t[k].c++; t[k].b += n; return; }
    if (t[k].a == 0)  { t[k].a = ra; t[k].c = 1; t[k].b = n; return; }
  }
}
static void __ds_note(void* ra0, void* ra1, unsigned long long n) {
  __ds_note_in(ra0, n, __ds0);
  __ds_note_in(ra1, n, __ds1);
}
static void __ds_dump(const char* tag,
                      struct { void* a; unsigned long long c, b; } * t) {
  for (int rank = 0; rank < 60; rank++) {
    unsigned long long best = 0; int bi = -1;
    for (int i = 0; i < __DS_N; i++)
      if (t[i].a && t[i].b > best) { best = t[i].b; bi = i; }
    if (bi < 0) break;
    fprintf(stderr, "%s %p %llu %llu\n", tag, t[bi].a, t[bi].c, t[bi].b);
    t[bi].a = 0; t[bi].b = 0;
  }
}
static void __attribute__((destructor)) __ds_report(void) {
  Dl_info di;
  void* base = 0;
  if (dladdr((void*)&__ds_dump, &di)) base = di.dli_fbase;
  fprintf(stderr, "DEFSITES base=%p\n", base);
  __ds_dump("SITE", __ds0);
  __ds_dump("UPSITE", __ds1);
}
PRE

python3 - "$src" "$tmp/pre.c" "$tmp/mr_ds.c" <<'PYEOF'
import sys
src, pre, dst = sys.argv[1], sys.argv[2], sys.argv[3]
b = open(src, "rb").read()
p = open(pre, "rb").read()

# counters + table just before the first runtime fn (same anchor as region_split)
key = b"static void __lang_region_add_block("
i = b.index(key)
b = b[:i] + p + b[i:]

# keep the allocator out of line so the return address names its caller
sig = b"static void* __lang_region_alloc(__lang_region* r, size_t n) {"
b = b.replace(sig,
  b"static void* __attribute__((noinline)) __lang_region_alloc(__lang_region* r, size_t n) {", 1)

# record every default-region allocation ('shared' is computed right above)
anchor = b"size_t aligned = (n + 7) & ~((size_t)7);"
i = b.index(anchor)
j = b.index(b"\n", i)
b = b[:j] + (b"\n  if (shared) __ds_note(__builtin_return_address(0),"
             b" __builtin_return_address(1), aligned);") + b[j:]

open(dst, "wb").write(b)
PYEOF

# -fno-omit-frame-pointer so __builtin_return_address(1) walks a real frame
# chain; -no_deduplicate so the linker does not fold same-bodied functions
# into one <deduplicated_symbol> that atos cannot name.
clang -O2 -fno-omit-frame-pointer -Wl,-no_deduplicate -Wl,-stack_size,0x20000000 \
  "$tmp/mr_ds.c" -o "$tmp/mr" 2> "$tmp/cc.err" \
  || { echo "build failed:"; head -5 "$tmp/cc.err"; exit 1; }

# --- run and symbolize --------------------------------------------------------
"$tmp/mr" "$1" > /dev/null 2> "$tmp/err" || true
grep -E '^(DEFSITES|SITE|UPSITE)' "$tmp/err" > "$tmp/sites" || {
  echo "no DEFSITES output — did the workload crash?"; tail -5 "$tmp/err"; exit 1; }

base=$(sed -n 's/^DEFSITES base=\(.*\)/\1/p' "$tmp/sites")
mib() { awk -v x="$1" 'BEGIN{printf "%.1f", x/1048576}'; }

show_table() { # $1 = SITE|UPSITE, $2 = heading
  tag="$1"; heading="$2"
  total=$(awk -v t="$tag" '$1 == t { s += $4 } END { print s }' "$tmp/sites")
  awk -v t="$tag" '$1 == t { print $2 }' "$tmp/sites" > "$tmp/addrs"
  : > "$tmp/names"
  if command -v atos >/dev/null && [ -n "$base" ] && [ "$base" != "0x0" ] && [ -s "$tmp/addrs" ]; then
    atos -o "$tmp/mr" -l "$base" $(cat "$tmp/addrs") > "$tmp/names" 2>/dev/null || :
  fi
  [ -s "$tmp/names" ] || cp "$tmp/addrs" "$tmp/names"
  printf '\n%-60s %12s %10s %6s\n' "$heading" calls MiB "%"
  awk -v t="$tag" '$1 == t { print $3, $4 }' "$tmp/sites" > "$tmp/nums"
  paste "$tmp/nums" "$tmp/names" | \
  while read -r calls bytes name; do
    pct=$(awk -v b="$bytes" -v t="$total" 'BEGIN{printf "%.1f", 100*b/t}')
    printf '%-60.60s %12s %10s %6s\n' "$name" "$calls" "$(mib "$bytes")" "$pct"
  done
  printf 'default-region total: %s MiB across the listed %s rows\n' "$(mib "$total")" "$tag"
}

show_table SITE   "site (caller of region_alloc)"
show_table UPSITE "one level up (caller's caller)"
