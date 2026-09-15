#!/bin/sh
# name_set takes a tag and looks the spec up in name_spec. A tag with no arm
# would build an empty table -- a predicate that answers false about every
# name, which is a wrong answer and not a crash. Refuse the tree instead.
set -u
cd "$(dirname "$0")/.." || exit 2
used=$(grep -ho 'name_set "[a-z_0-9]*"' ./*.mere | sed 's/.*"\(.*\)"/\1/' | sort -u)
have=$(sed -n '/^let name_spec = /,/^let /p' m_state.mere \
       | grep -o 'str_eq tag "[a-z_0-9]*"' | sed 's/.*"\(.*\)"/\1/' | sort -u)
[ -n "$used" ] || { echo "name_spec: found no name_set call at all -- the pattern moved"; exit 1; }
[ -n "$have" ] || { echo "name_spec: found no arm at all -- the chain moved"; exit 1; }
miss=$(comm -23 "$(printf %s "$used" > /tmp/ns_u.$$; echo /tmp/ns_u.$$)" \
                "$(printf %s "$have" > /tmp/ns_h.$$; echo /tmp/ns_h.$$)")
extra=$(comm -13 /tmp/ns_u.$$ /tmp/ns_h.$$)
rm -f /tmp/ns_u.$$ /tmp/ns_h.$$
rc=0
[ -n "$miss" ]  && { echo "name_spec: no arm for tag(s):"; echo "$miss" | sed 's/^/    /'; rc=1; }
[ -n "$extra" ] && { echo "name_spec: arm(s) no name_set asks for:"; echo "$extra" | sed 's/^/    /'; rc=1; }
[ "$rc" = 0 ] && echo "name_spec: all $(echo "$used" | wc -l | tr -d ' ') tags have an arm"
exit $rc
