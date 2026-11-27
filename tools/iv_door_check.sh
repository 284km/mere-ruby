#!/bin/sh
# An object's instance variables are read and written through the door in
# m_state.mere (iv_get / iv_get_or / iv_has / iv_set / iv_del and the rest),
# never by their table key "<id>@<name>". Since note 559 step 2b an object's
# variables are in its shape's slots, so a key read from the table finds
# nothing -- quietly: tools/native_probe/embedding_api.mere read an exit's
# __status and an exception's __exception_message that way and answered 1 and
# no message (#322's review). MERE_RUBY_SHAPES_CHECK=1 catches a write around
# the door at run time; a read leaves no trace, so this looks at the source.
#
#   ./tools/iv_door_check.sh
#
# What it looks for: an object key being built, `str_of_int X ++ "@`, anywhere
# but the door. Keys of other owners ("str:" ++ ..., "cls:" ++ ...) are not
# objects' and are left alone. The sites below are allowed, each for a reason.
#
# ⚠ It reads the spelling, not the meaning: `str_of_int <name> ++ "@` with the
# id a plain name. A key whose id is an expression (`str_of_int (f x) ++ "@`),
# or whose "@" is added later to a variable holding the id's text, passes
# unseen. Build a key through m_state's iv_key / iv_tkey, or not at all, and
# this stays the whole of it (#322's review).
set -u
cd "$(dirname "$0")/.." || exit 2
files=$(find . -name '*.mere' -not -path './.mere_modules/*' -not -path './vendor/*' -not -path './m_state.mere' | sort)
# shellcheck disable=SC2086
bad=$(grep -nE 'str_of_int [A-Za-z0-9_]+ \+\+ "@' $files \
  | grep -vE '"[a-z]+:" \+\+ str_of_int' \
  | grep -vF -e '  let pfx = str_of_int oid ++ "@" in' \
             -e '  | VObj id -> str_of_int id ++ "@" ++ name' \
             -e 'let sid = str_of_int id ++ "@" in' \
             -e 'str_of_int site ++ "@" ++ str_of_int (sch_me ())' \
             -e '"." ++ str_of_int k ++ "@" ++ str_of_int (sch_me ())' \
             -e 'str_of_int o ++ "@" ++ e' \
  || true)
# (allowed: ivar_names_of's index prefix, read only for an object in the
#  table; ivar_self_key's object arm, which every caller answers before it
#  gets there; the Prism loader's key for a node in the table; and three keys
#  that are no instance variable's -- a site's and a VM cache's per thread, the
#  ISeq export's text)
# A String's, an Array's and a Hash's are behind the door too since step 2b'
# (iv_k_get_or / iv_k_has / iv_k_set / iv_k_del with hiv_ok): their keys
# "str:<id>@...", "arr:...", "hsh:...", by hand or by hng_key, are looked for
# the same way. Allowed: ivar_self_key's arms for them, which ivs_has,
# ivs_get_or and ivs_set answer before they get there.
# shellcheck disable=SC2086
bad2=$(grep -nE '"(str|arr|hsh):" \+\+ str_of_int [A-Za-z0-9_]+ \+\+ "@|hng_key (\([^)]*\)|[a-z0-9_]+) \+\+ "@' $files \
  | grep -vE '  \| V(Arr|Hsh|Str) id -> "(arr|hsh|str):" \+\+ str_of_int id \+\+ "@" \+\+ name$' \
  || true)
# A record in obj_iv is written by iv_rec_put alone: it keys the record by the
# owner key (an object's id times 8), and keeps iv_hng, the collector's list of
# the Strings, Arrays and Hashes that have one. The VM's inline cache (#332)
# wrote an object's record under its bare id, which step 2b' made no key.
# shellcheck disable=SC2086
bad3=$(grep -nE 'map_set obj_iv' $files || true)
bad=$(printf '%s\n%s\n%s' "$bad" "$bad2" "$bad3" | sed '/^$/d')
if [ -n "$bad" ]; then
  echo "iv door: an object's instance variable is keyed by hand, around the door:"
  printf '%s\n' "$bad" | sed 's/^/  /'
  echo "Use iv_get_or / iv_has / iv_set / iv_del, or iv_k_* with hiv_ok, and iv_rec_put for a record (m_state.mere): the variable may be in a shape's slot."
  exit 1
fi
echo "iv door: no object, String, Array or Hash key is built outside the door"
