#!/bin/sh
# Run a real spec/ruby file through the minimal mspec shim, under BOTH
# mere-ruby and ruby, and diff the outputs. The spec file is copied into a
# temp layout that mirrors its depth under spec/ruby (language/x_spec.rb,
# core/encoding/x_spec.rb, ...) so that its `require_relative '../spec_helper'`
# or '../../spec_helper' resolves to the shim.
#
#   ./run_spec.sh <path/to/some_spec.rb> [--keep]
spec="$1"
[ -f "$spec" ] || { echo "usage: run_spec.sh <spec.rb>"; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
tmp="$(mktemp -d)"
specdir="$(cd "$(dirname "$spec")" && pwd)"
# subpath under spec/ruby (e.g. "language", "core/encoding"); default language.
case "$specdir" in
  */spec/ruby/*) sub="${specdir#*/spec/ruby/}" ;;
  *) sub="language" ;;
esac
mkdir -p "$tmp/$sub"
cp "$spec" "$tmp/$sub/"
# fixture files the spec may require_relative
[ -d "$specdir/fixtures" ] && cp -R "$specdir/fixtures" "$tmp/$sub/fixtures"
[ -d "$specdir/shared" ] && cp -R "$specdir/shared" "$tmp/$sub/shared"
parent="$(dirname "$sub")"
[ "$parent" = "." ] && parent=""
[ -d "$specdir/../fixtures" ] && mkdir -p "$tmp/$parent" && cp -R "$specdir/../fixtures" "$tmp/${parent:+$parent/}fixtures"
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
