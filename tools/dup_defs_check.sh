#!/bin/sh
# A top-level name defined twice in the SAME `let rec ... and ...` chain is a
# silent bug: every call resolves to the LATER definition and the earlier one
# is dead, with no warning and a green build. Editing the dead one does
# nothing, which is exactly what happens -- `val_member_w` was defined a
# second time (2026-09-14) beside the `==` version already there, every call
# went to the older function, and the fix looked like it had no effect.
#
#   ./tools/dup_defs_check.sh [main.mere]   exit 1 on a same-chain duplicate
#
# Duplicates in DIFFERENT chains are legal -- each is visible only in its own
# scope, and the file has several on purpose (a `str list` helper early and a
# `Val list` one later). Those are listed, not refused: the point of the gate
# is the case where one definition cannot be reached at all.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="${1:-$root/main.mere}"
[ -f "$src" ] || { echo "no $src"; exit 2; }

# chain id increments at every top-level binder that is NOT `and`; `and`
# continues the chain it follows. One (chain, name) pair may appear once.
awk '
  /^(and|let rec|let) [a-z_][a-z_0-9]* = fn/ {
    kind = $1
    name = ($1 == "let" && $2 == "rec") ? $3 : $2
    if (!(kind == "and")) chain++
    key = chain "\t" name
    if (key in seen) { dup[name] = seen[key] " " NR; same++ }
    else seen[key] = NR
    if (name in anywhere) other[name] = other[name] " " NR
    else anywhere[name] = NR
  }
  END {
    for (n in dup) printf "SAME-CHAIN  %-18s lines %s  (the first is dead)\n", n, dup[n]
    print "---same=" same > "/dev/stderr"
    for (n in other) if (!(n in dup)) printf "cross-chain %-18s lines %s %s\n", n, anywhere[n], other[n]
  }
' "$src" > "$root/.dup_defs.out" 2>"$root/.dup_defs.n"

same=$(sed -n 's/^---same=//p' "$root/.dup_defs.n")
[ -n "$same" ] || same=0
grep '^SAME-CHAIN' "$root/.dup_defs.out" | sort
grep '^cross-chain' "$root/.dup_defs.out" | sort
rm -f "$root/.dup_defs.out" "$root/.dup_defs.n"
if [ "$same" -gt 0 ]; then
  echo "dup defs: $same name(s) defined twice in one chain -- the earlier definition is unreachable"
  exit 1
fi
echo "dup defs: no name is defined twice in one chain"
exit 0
