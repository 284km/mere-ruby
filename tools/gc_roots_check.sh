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
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. maps whose value type carries Val (the value type is the C struct suffix)
LC_ALL=C grep -a -o 'static mere_map_str_[A-Za-z_]*\* mu_[a-z_0-9]*;' "$src" \
  | sed 's/static mere_map_str_//; s/\* mu_/ /; s/;//' \
  | awk '$1 ~ /Val/ && $1 !~ /^Map___heap_str_Val$/ {print $2, $1}' | sort -u > "$tmp/valmaps"
# (Map___heap_str_Val values are env maps -- containers of Vals -- and lv_up,
#  which holds them, is a root; the rest are frame-shaped scratch handled by
#  the pool. They are checked by hand, not here.)

# 2. the roots: every `map_iter X mk` inside gc_mark_roots
a=$(LC_ALL=C grep -n '^let gc_mark_roots = fn' "$root/main.mere" | head -1 | cut -d: -f1)
b=$(LC_ALL=C awk -v s="$a" 'NR>s && /^(let|and) [a-z_]+ = /{print NR; exit}' "$root/main.mere")
[ -n "$a" ] && [ -n "$b" ] || { echo "cannot find gc_mark_roots in main.mere"; exit 2; }
sed -n "${a},${b}p" "$root/main.mere" | LC_ALL=C grep -o 'map_iter [a-z_0-9]*' | awk '{print $2}' | sort -u > "$tmp/roots"

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
  grep -q "^$nm " "$tmp/valmaps" || { echo "STALE allowlist entry $nm: no such Val-valued map"; fail=1; }
done < "$tmp/allow"
[ $fail = 0 ] && echo "gc roots: every Val-valued global map is accounted for" || echo "gc roots: UNACCOUNTED maps above"
exit $fail
