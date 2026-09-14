#!/bin/sh
# A top-level function nobody calls is dead weight that reads as live code.
# The compiler does not say so -- it emits it, or quietly drops it, and either
# way the source keeps a definition that can be maintained, corrected and
# argued about for years without ever running. 28 of them had accumulated
# (2026-09-14): `register_class_sng` superseded by `register_class_sng_in`,
# `rx_split` by `rx_split_lim`, `md_insp_groups_unused` saying so in its own
# name, and a dozen one-line wrappers whose only caller had been rewritten.
#
#   ./tools/dead_defs_check.sh [file.mere ...]   exit 1 on an uncalled function
#
# A name is called if it appears anywhere in the CODE of any .mere in the
# project other than on its own definition line -- being passed as a value
# counts, since that is still the name. Comments do not count: a function
# mentioned only in prose is exactly the case this is looking for.
#
# ⚠ tools/dead_defs_allow.txt holds the ones kept ON PURPOSE, each with its
# reason. An entry there is a decision, not a silence.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
if [ "$#" -gt 0 ]; then srcs="$*"; else srcs="$(echo "$root"/*.mere)"; fi
for s in $srcs; do [ -f "$s" ] || { echo "no $s"; exit 2; }; done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# every top-level function name, with where it is defined
LC_ALL=C awk '/^(and|let rec|let) [a-z_][a-z_0-9]* = fn/ {
    name = ($1 == "let" && $2 == "rec") ? $3 : $2
    if (!(name in seen)) { seen[name] = 1; print name "\t" FILENAME ":" FNR }
  }' $srcs | sed "s#$root/##" > "$tmp/defs"
# every identifier occurrence in code (comments stripped)
LC_ALL=C sed 's://.*::' $srcs | LC_ALL=C grep -oE '[a-z_][a-z_0-9]*' | sort | uniq -c \
  | awk '{print $2 "\t" $1}' > "$tmp/uses"
sed -n 's/^\([a-z_][a-z_0-9]*\)[[:space:]].*/\1/p' "$here/dead_defs_allow.txt" 2>/dev/null \
  | sort -u > "$tmp/allow"

n=0
while IFS="$(printf '\t')" read -r name where; do
  c=$(LC_ALL=C awk -v n="$name" -F"\t" '$1==n {print $2; found=1} END{if(!found) print 0}' "$tmp/uses")
  [ "$c" -le 1 ] || continue
  grep -qx "$name" "$tmp/allow" && continue
  printf 'UNCALLED  %-26s %s\n' "$name" "$where"
  n=$((n+1))
done < "$tmp/defs"

if [ "$n" -gt 0 ]; then
  echo "dead defs: $n top-level function(s) nobody calls -- delete, or name in tools/dead_defs_allow.txt with the reason"
  exit 1
fi
echo "dead defs: every top-level function is called"
exit 0
