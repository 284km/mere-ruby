#!/bin/sh
# Run a real spec/ruby file through the minimal mspec shim, under BOTH
# mere-ruby and ruby, and diff the outputs. The spec tree (core/, language/,
# shared/, fixtures/) is cloned into a temp dir with the shim installed as
# spec_helper.rb, so every require_relative (../spec_helper,
# ../../spec_helper, sibling shared/, cross-directory shared/) resolves.
#
#   ./run_spec.sh <path/to/some_spec.rb> [--keep]
spec="$1"
[ -f "$spec" ] || { echo "usage: run_spec.sh <spec.rb>"; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
tmp="$(mktemp -d)"
specdir="$(cd "$(dirname "$spec")" && pwd)"
# subpath under spec/ruby (e.g. "language", "core/enumerator"); the spec root.
case "$specdir" in
  */spec/ruby/*)
    sub="${specdir#*/spec/ruby/}"
    specroot="${specdir%/$sub}"
    ;;
  *) sub="language"; specroot="" ;;
esac
if [ -n "$specroot" ]; then
  # clone the relevant trees (APFS copy-on-write when available).
  for d in core language shared fixtures; do
    [ -d "$specroot/$d" ] || continue
    cp -Rc "$specroot/$d" "$tmp/$d" 2>/dev/null || cp -R "$specroot/$d" "$tmp/$d"
  done
else
  mkdir -p "$tmp/$sub"
  cp "$spec" "$tmp/$sub/"
  [ -d "$specdir/fixtures" ] && cp -R "$specdir/fixtures" "$tmp/$sub/fixtures"
  [ -d "$specdir/shared" ] && cp -R "$specdir/shared" "$tmp/$sub/shared"
fi
# the shim replaces the real mspec spec_helper.
cp "$here/spec_helper.rb" "$tmp/spec_helper.rb"
base="$(basename "$spec" .rb)"
cat > "$tmp/driver.rb" <<EOF
require_relative "spec_helper"
require_relative "$sub/$base"
mspec_report
EOF
out_m="$("$mr" "$tmp/driver.rb" 2>&1)"
out_r="$(ruby -W0 "$tmp/driver.rb" 2>&1)"
echo "--- mere-ruby:"; echo "$out_m"
echo "--- ruby:";      echo "$out_r"
if [ "$out_m" = "$out_r" ]; then echo "MATCH"; else echo "DIFF"; fi
[ "$2" = "--keep" ] || rm -rf "$tmp"
