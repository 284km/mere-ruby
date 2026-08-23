#!/bin/sh
# WHICH MAP took the writes? def_sites.sh answers with call sites, and for a
# SHARED map runtime that is not enough: `mere_map_str_Val_set` is the same
# code for every str->Val map in the program, so a symbol offset names the
# runtime, not the container. This harness attributes by map IDENTITY: it wraps
# each map runtime's set(), charges the bytes that call added to the DEFAULT
# region, and names the map by joining against the interpreter's global maps.
#
#   ./bench/def_maps.sh workload.rb            (needs ./mr.c; env passes through)
#
# The name table is GENERATED FROM THE DEFINITION SIDE -- every
# `let <name> = map_new ()` in main.mere -- so a map cannot be missed by not
# having been thought of. Maps that are not globals (frame envs, scratch maps)
# appear as "<not a global map>" with their share, which is the honest answer
# for them.
#
# The bytes come from the region's own cumulative counter (mere v0.1.307's
# alloc_total), so a block boundary inside the call cannot corrupt the reading
# the way a bump-pointer delta would. Only DEFAULT-region bytes are counted:
# they are the ones nothing gives back. A map that has been compacted owns a
# private arena and drops out of this table by design -- that is what a fix
# looks like here.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="$root/mr.c"
[ -f "$src" ] || { echo "no $src (generate: mere -c main.mere > mr.c)"; exit 2; }
[ $# -ge 1 ] || { echo "usage: def_maps.sh workload.rb"; exit 2; }
command -v clang >/dev/null || { echo "needs clang"; exit 2; }
LC_ALL=C grep -q -F "alloc_total" "$src" || {
  echo "this mr.c predates mere v0.1.307 (no region alloc_total) — regenerate it"; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- the name table, from the definition side --------------------------------
LC_ALL=C sed -n 's/^let \([a-z_][a-z_0-9]*\) = map_new ().*/\1/p' "$root/main.mere" \
  | sort -u > "$tmp/names"
[ -s "$tmp/names" ] || { echo "no global maps found in main.mere — has the form changed?"; exit 1; }
: > "$tmp/names_ok"
while read -r nm; do
  LC_ALL=C grep -q -F "* mu_$nm;" "$src" && echo "$nm" >> "$tmp/names_ok"
done < "$tmp/names"
n_ok=$(wc -l < "$tmp/names_ok" | tr -d ' ')

python3 - "$src" "$tmp/names_ok" "$tmp/mr_dm.c" <<'PYEOF'
import re, sys
src, names_path, dst = sys.argv[1], sys.argv[2], sys.argv[3]
b = open(src, "rb").read()
names = [l.strip() for l in open(names_path) if l.strip()]

TABLE = rb'''
#define __DM_N 8192
static struct { void* m; unsigned long long c, b; } __dm[__DM_N];
static void __dm_note(void* m, unsigned long long n) {
  unsigned long long h = ((unsigned long long)m) >> 4;
  h = (h ^ (h >> 16)) & (__DM_N - 1);
  for (unsigned long long i = 0; i < __DM_N; i++) {
    unsigned long long k = (h + i) & (__DM_N - 1);
    if (__dm[k].m == m) { __dm[k].c++; __dm[k].b += n; return; }
    if (__dm[k].m == 0) { __dm[k].m = m; __dm[k].c = 1; __dm[k].b = n; return; }
  }
}
'''
i = b.index(b"static void __lang_region_add_block(")
b = b[:i] + TABLE + b[i:]

# Wrap every map runtime's set(). The impl is renamed and the wrapper takes the
# original name, so every existing call site binds to the wrapper without any
# forward declaration games. The wrapper is inserted immediately after the
# impl's closing brace -- found as a `}` at column 0, which in this generated C
# only ever ends a top-level definition.
sig = re.compile(rb"static int (mere_map_[A-Za-z0-9_]+)_set\((mere_map_[A-Za-z0-9_]+)\* m, ([^\)]*)\) \{")
pieces, pos, wrapped = [], 0, 0
for mo in sig.finditer(b):
    fn, ty, params = mo.group(1), mo.group(2), mo.group(3)
    end = b.index(b"\n}\n", mo.end())
    # forward the parameters by name: the last identifier of each declarator
    argv = []
    for part in params.split(b","):
        ids = re.findall(rb"[A-Za-z_][A-Za-z0-9_]*", part)
        argv.append(ids[-1])
    wrapper = (b"\nstatic int " + fn + b"_set(" + ty + b"* m, " + params + b") {\n"
               b"  extern __lang_region __lang_default_region_fwd3 asm(\"___lang_default_region\");\n"
               b"  int __dm_def = (m->region == &__lang_default_region_fwd3);\n"
               b"  unsigned long long __dm_b0 = __dm_def ? m->region->alloc_total : 0;\n"
               b"  int __dm_r = " + fn + b"_set_impl(m, " + b", ".join(argv) + b");\n"
               b"  if (__dm_def) __dm_note(m, m->region->alloc_total - __dm_b0);\n"
               b"  return __dm_r;\n}\n")
    pieces.append(b[pos:mo.start()])
    pieces.append(b[mo.start():mo.end()].replace(fn + b"_set(", fn + b"_set_impl(", 1))
    pieces.append(b[mo.end():end + 3])
    pieces.append(wrapper)
    pos = end + 3
    wrapped += 1
pieces.append(b[pos:])
b = b"".join(pieces)
assert wrapped > 0, "no map set() found -- has the runtime's shape changed?"

report = [b"\nstatic void __attribute__((destructor)) __dm_report(void) {\n",
          b'  fprintf(stderr, "DEFMAPS\\n");\n']
for nm in names:
    report.append(b'  fprintf(stderr, "MAPNAME %s %p\\n", "' + nm.encode() +
                  b'", (void*)mu_' + nm.encode() + b");\n")
report.append(b"  for (int i = 0; i < __DM_N; i++)\n"
              b"    if (__dm[i].m) fprintf(stderr, \"MAPBYTES %p %llu %llu\\n\","
              b" __dm[i].m, __dm[i].c, __dm[i].b);\n}\n")
b = b + b"".join(report)
open(dst, "wb").write(b)
print("wrapped %d map runtimes, %d names" % (wrapped, len(names)), file=sys.stderr)
PYEOF

clang -O2 -Wl,-stack_size,0x20000000 "$tmp/mr_dm.c" -o "$tmp/mr" 2> "$tmp/cc.err" \
  || { echo "build failed:"; head -8 "$tmp/cc.err"; exit 1; }

"$tmp/mr" "$1" > /dev/null 2> "$tmp/err" || true
grep -E '^(MAPNAME|MAPBYTES)' "$tmp/err" > "$tmp/raw" || {
  echo "no DEFMAPS output — did the workload crash?"; tail -5 "$tmp/err"; exit 1; }

awk -v known="$n_ok" '
  /^MAPNAME/  { name[$3] = $2; next }
  /^MAPBYTES/ { calls[$2] += $3; bytes[$2] += $4; next }
  END {
    for (p in bytes) tot += bytes[p]
    for (p in bytes) {
      nm = (p in name) ? name[p] : "<not a global map>"
      printf "%12.1f %-28s %14d %6.1f%%\n", bytes[p]/1048576, nm, calls[p], 100*bytes[p]/tot
    }
    printf "%12.1f %s\n", tot/1048576, "== TOTAL (default-region bytes charged to map set) =="
    printf "%12s %s\n", "", "(" known " global map names known)"
  }' "$tmp/raw" | sort -g -r | head -28
