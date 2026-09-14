#!/bin/sh
# Every write to the method table and its tombstones goes through set_meth /
# del_meth / set_undef / del_undef, which bump the lookup generation.
#
# ⚠ THIS GATE IS WHAT MAKES THE has_meth MEMO SAFE. `has_meth` caches the whole
# ancestor walk against that generation, so a `map_set meths ...` that skips
# the setter is a method the lookup will never see -- or worse, a stale `false`
# that makes a defined method raise NoMethodError. It is the quietest kind of
# bug this interpreter can have (see the note about a method-table entry hiding
# every other answer), and nothing else detects it: the build stays green, most
# programs stay green, and the one that breaks breaks for no visible reason.
#
#   ./tools/meth_writes_check.sh
#
# The method table reaches code under many names -- it is the first member of
# the `world` tuple and every function that destructures it picks its own -- so
# the names come from the destructuring itself rather than from a list here.
set -u
cd "$(dirname "$0")/.." || exit 2
# names bound to the world tuple's FIRST member, plus the global tombstone table
names=$(grep -ohE 'let \([a-z_0-9]+, [a-z_0-9]+, [a-z_0-9]+, [a-z_0-9]+\) = world' *.mere \
        | sed -E 's/let \(([a-z_0-9]+),.*/\1/' | sort -u | grep -v '^_$' | tr '\n' '|')
names="${names}undefs"
bad=$(grep -nE "map_(set|delete) ($names) " *.mere \
      | grep -vE '^m_state\.mere:[0-9]+:let (set|del)_(meth|undef) ' || true)
if [ -n "$bad" ]; then
  echo "meth writes: a write to the method table or its tombstones does not go through"
  echo "the setter, so it will not bump the generation the has_meth memo is keyed on:"
  printf '%s\n' "$bad" | sed 's/^/  /'
  echo "Use set_meth / del_meth / set_undef / del_undef (m_state.mere)."
  exit 1
fi
n=$(grep -cohE '\b(set_meth|del_meth|set_undef|del_undef) ' *.mere | awk -F: '{s+=$1} END {print s+0}')
# A gate whose subject vanished is not a gate that passed: these writes exist.
if [ "$n" -lt 40 ]; then
  echo "meth writes: only $n writes found through the setters -- expected dozens." >&2
  echo "Either the setters were renamed or this is looking at the wrong tree." >&2
  exit 1
fi
echo "meth writes: all $n go through the generation-bumping setters"
