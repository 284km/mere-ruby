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
if [ -n "$bad" ]; then
  echo "iv door: an object's instance variable is keyed by hand, around the door:"
  printf '%s\n' "$bad" | sed 's/^/  /'
  echo "Use iv_get_or / iv_has / iv_set / iv_del (m_state.mere): the variable may be in a shape's slot."
  exit 1
fi
echo "iv door: no object key is built outside the door"
