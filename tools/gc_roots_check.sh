#!/bin/sh
# Every global map whose VALUES are object handles must be a GC root -- or be
# named here with the reason it need not be. A table added without its root
# is how `require "bundler"` came to raise `Illformed requirement [""]`
# (2026-09-03): the interned-string table was not marked, a collection during
# the rubygems preload blanked its strings, and the next `"lit".freeze`
# returned an empty one.
#
#   ./tools/gc_roots_check.sh [mr.c]        exit 1 on an unaccounted map
#
# The candidates come from the TYPES in the generated C (a map whose value
# type mentions Val holds handles by construction), not from reading the
# writes -- a `map_set t k cv` where cv is a variable names no constructor and
# would slip past a grep. The roots come from gc_mark_roots in main.mere. The
# allowlist (tools/gc_roots_allow.txt) holds the maps that hold Vals which are
# never handles (VInt / VBool / VNil / VSym / VClass only), each with its reason.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="${1:-$root/mr.c}"
[ -f "$src" ] || { echo "no $src (generate: mere -c main.mere > mr.c)"; exit 2; }
# ⚠ AND IT MUST DESCRIBE THIS TREE. The default subject is a file in the repo
# and nothing regenerates it: locally it was FIVE DAYS OLD while this check
# reported on it every run. CI writes it immediately before, which is why the
# staleness never showed there. A gate that caches its subject is not a gate.
newest=$(ls -t "$root"/*.mere 2>/dev/null | head -1)
if [ -n "$newest" ] && [ "$newest" -nt "$src" ]; then
  echo "gc roots: $src is older than $(basename "$newest") -- it does not describe this tree." >&2
  echo "Regenerate it (mere -c main.mere > mr.c) or pass the C you just built:" >&2
  echo "  ./tools/gc_roots_check.sh /path/to/fresh.c" >&2
  exit 2
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. maps whose value type carries Val (the value type is the C struct suffix)
# ⚠ BOTH KEY TYPES. This read `mere_map_str_` only, and on 2026-09-15 a batch
# of tables moved from string keys to int keys for speed -- at which point
# arr_store, arr_pending and lv_up, all of which hold Vals, became INVISIBLE
# here. A gate that silently stops covering something is worse than one that
# never covered it: the green stayed green. (What said so was the allowlist's
# own staleness check -- "no such Val-valued map" for a table that plainly
# exists -- which is why that check earns its place.)
LC_ALL=C grep -a -o -e 'static mere_map_str_[A-Za-z_]*\* mu_[a-z_0-9]*;' -e 'static mere_map_int_[A-Za-z_]*\* mu_[a-z_0-9]*;' "$src" \
  | sed 's/static mere_map_str_//; s/static mere_map_int_//; s/\* mu_/ /; s/;//' \
  | awk '$1 ~ /Val/ && $1 !~ /^Map___heap_str_Val$/ {print $2, $1}' | sort -u > "$tmp/valmaps"
# ...and the names this excluded, so an allowlist entry for one of them is not
# reported as stale (see the note above).
LC_ALL=C grep -a -o -e 'static mere_map_str_[A-Za-z_]*\* mu_[a-z_0-9]*;' -e 'static mere_map_int_[A-Za-z_]*\* mu_[a-z_0-9]*;' "$src" \
  | sed 's/static mere_map_str_//; s/static mere_map_int_//; s/\* mu_/ /; s/;//' \
  | awk '$1 == "Map___heap_str_Val" {print $2}' | sort -u > "$tmp/excluded"
# (Map___heap_str_Val values are env maps -- containers of Vals -- and lv_up,
#  which holds them, is a root; the rest are frame-shaped scratch handled by
#  the pool. They are checked by hand, not here.)
# ⚠ a map of MAPS lands in that excluded class too, and not every one of them
#   is an env map: num_names_memo (numeric kind -> a set of method names) has
#   been on BOTH sides of this line -- `Map_str_Val` in one build (so the gate
#   said UNACCOUNTED and it was allowlisted) and `Map___heap_str_Val` in
#   another (so the same entry read STALE and the gate went red again). Which
#   one it gets is a monomorphisation coincidence, not a change in the map.
#   Two sessions then "fixed" the gate in OPPOSITE directions on the same day.
#   So an allowlist entry naming a map that is currently in the excluded class
#   is not stale -- it is an entry waiting for the type to swing back.

# 2. the roots: every `map_iter X mk` inside gc_mark_roots.
# ⚠ The definition may live in ANY of the program's .mere files -- main.mere
# is one module among several, and looking only there would find nothing and
# report every map as unrooted (or, worse, find a stale copy). The source
# files are asked in turn for the one that defines it.
srcfile=""
for f in "$root"/*.mere; do
  LC_ALL=C grep -q '^let gc_mark_roots = fn' "$f" && { srcfile="$f"; break; }
done
[ -n "$srcfile" ] || { echo "cannot find gc_mark_roots in any .mere under $root"; exit 2; }
a=$(LC_ALL=C grep -n '^let gc_mark_roots = fn' "$srcfile" | head -1 | cut -d: -f1)
b=$(LC_ALL=C awk -v s="$a" 'NR>s && /^(let|and) [a-z_]+ = /{print NR; exit}' "$srcfile")
[ -n "$a" ] && [ -n "$b" ] || { echo "cannot delimit gc_mark_roots in $srcfile"; exit 2; }
sed -n "${a},${b}p" "$srcfile" | LC_ALL=C grep -o 'map_iter [a-z_0-9]*' | awk '{print $2}' | sort -u > "$tmp/roots"

# 3. the allowlist: "name  reason"
sed -n 's/^\([a-z_][a-z_0-9]*\)[[:space:]].*/\1/p' "$here/gc_roots_allow.txt" 2>/dev/null | sort -u > "$tmp/allow"

fail=0
printf '%-26s %-34s %s\n' map value-type status
while read -r nm ty; do
  if grep -qx "$nm" "$tmp/roots"; then st="root"
  elif grep -qx "$nm" "$tmp/allow"; then st="allowlisted: $(grep "^$nm[[:space:]]" "$here/gc_roots_allow.txt" | sed 's/^[a-z_0-9]*[[:space:]]*//')"
  else st="UNACCOUNTED -- root it in gc_mark_roots, or name it in tools/gc_roots_allow.txt with the reason"; fail=1
  fi
  printf '%-26s %-34s %s\n' "$nm" "$ty" "$st"
done < "$tmp/valmaps"
# an allowlist entry that has become a root (or vanished) is stale
while read -r nm; do
  grep -qx "$nm" "$tmp/roots" && { echo "STALE allowlist entry $nm: it is a root now"; fail=1; }
  grep -q "^$nm " "$tmp/valmaps" || grep -qx "$nm" "$tmp/excluded" \
    || { echo "STALE allowlist entry $nm: no such Val-valued map"; fail=1; }
done < "$tmp/allow"
[ $fail = 0 ] && echo "gc roots: every Val-valued global map is accounted for" || echo "gc roots: UNACCOUNTED maps above"
exit $fail
