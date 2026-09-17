#!/bin/sh
# name_set takes a tag and looks the spec up in name_spec. A tag with no arm
# would build an empty table -- a predicate that answers false about every
# name, which is a wrong answer and not a crash. Refuse the tree instead.
set -u
cd "$(dirname "$0")/.." || exit 2
# ⚠ TWO SPELLINGS ASK FOR A TAG: `name_set "t"` builds the membership table and
# `name_spec "t"` reads the raw string (which is how a list whose ORDER matters
# is iterated -- the set is a hash). Counting only the first reported a live
# arm as dead.
# ⚠ ...and the tag is not always a LITERAL at the call: a list whose choice
# depends on the question is asked as `name_spec (if want_priv then "modpriv"
# else "modpub")`, and matching only `name_spec "..."` reported both arms as
# dead. The "no arm for a tag" direction (the one that builds an empty table
# and answers false about every name) still reads the calls; the "arm nobody
# asks for" direction reads every quoted string, which is where a tag chosen
# in an expression appears.
used=$(grep -hoE '(name_set|name_spec) "[a-z_0-9]*"' ./*.mere | sed 's/.*"\(.*\)"/\1/' | sort -u)
# ⚠ ...MINUS the arm's own `str_eq tag "t"`, which every arm contains. Counting
# that made this direction vacuous: a poisoned tree with an arm nobody asks for
# passed, because the arm mentioned itself.
mentioned=$(sed 's/str_eq tag "[a-z_0-9]*"//g' ./*.mere | grep -hoE '"[a-z_0-9]+"' | tr -d '"' | sort -u)
have=$(sed -n '/^let name_spec = /,/^let /p' m_state.mere \
       | grep -o 'str_eq tag "[a-z_0-9]*"' | sed 's/.*"\(.*\)"/\1/' | sort -u)
[ -n "$used" ] || { echo "name_spec: found no name_set call at all -- the pattern moved"; exit 1; }
[ -n "$have" ] || { echo "name_spec: found no arm at all -- the chain moved"; exit 1; }
miss=$(comm -23 "$(printf %s "$used" > /tmp/ns_u.$$; echo /tmp/ns_u.$$)" \
                "$(printf %s "$have" > /tmp/ns_h.$$; echo /tmp/ns_h.$$)")
printf %s "$mentioned" > /tmp/ns_m.$$
extra=$(comm -13 /tmp/ns_m.$$ /tmp/ns_h.$$)
rm -f /tmp/ns_m.$$
rm -f /tmp/ns_u.$$ /tmp/ns_h.$$
rc=0
[ -n "$miss" ]  && { echo "name_spec: no arm for tag(s):"; echo "$miss" | sed 's/^/    /'; rc=1; }
[ -n "$extra" ] && { echo "name_spec: arm(s) no name_set asks for:"; echo "$extra" | sed 's/^/    /'; rc=1; }
[ "$rc" = 0 ] && echo "name_spec: all $(echo "$used" | wc -l | tr -d ' ') tags have an arm"
exit $rc
