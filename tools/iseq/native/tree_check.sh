#!/bin/sh
# tools/iseq/native/tree_check.sh -- the native compiler's reading of Prism's
# serialized tree against Prism's own, a file at a time (note 552 §11).
#   MERE=<mere.exe> sh tools/iseq/native/tree_check.sh corpus/*.rb     (ref ruby on PATH)
here="$(cd "$(dirname "$0")" && pwd)"
tmp="${TMPDIR:-/tmp}/ic_tree.$$"
mkdir -p "$tmp"
# (MERE may be relative to where this was started: made absolute before the
#  compile, which runs from this directory)
case "${MERE:?MERE names the Mere compiler}" in
  /*) ;;
  */*) MERE="$(cd "$(dirname "$MERE")" && pwd)/$(basename "$MERE")" ;;
esac
(cd "$here" && "$MERE" -c tree_dump.mere > "$tmp/tree_dump.c") && clang -O1 -w "$tmp/tree_dump.c" -o "$tmp/tree_dump" || { echo "tree_check: build failed"; exit 2; }
ok=0; bad=0
for f in "$@"; do
  ruby "$here/tree_expect.rb" "$f" "$tmp/t.pm" > "$tmp/t.exp" 2>/dev/null
  "$tmp/tree_dump" "$tmp/t.pm" "$f" > "$tmp/t.got" 2>&1
  if cmp -s "$tmp/t.exp" "$tmp/t.got"; then ok=$((ok+1)); else bad=$((bad+1)); [ $bad -le 5 ] && { echo "DIFF $f"; diff "$tmp/t.exp" "$tmp/t.got" | head -4; }; fi
done
rm -rf "$tmp"
echo "tree_check: $ok the same, $bad different"
[ $bad -eq 0 ]
