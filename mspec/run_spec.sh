#!/bin/sh
# Run a real spec/ruby file through the minimal mspec shim, under BOTH
# mere-ruby and ruby, and diff the outputs. The spec file is copied into a
# temp layout (language/x_spec.rb + spec_helper.rb) so that its
# `require_relative '../spec_helper'` resolves to the shim.
#
#   ./run_spec.sh <path/to/some_spec.rb> [--keep]
spec="$1"
[ -f "$spec" ] || { echo "usage: run_spec.sh <spec.rb>"; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
mr="$here/../mere-ruby"
tmp="$(mktemp -d)"
mkdir -p "$tmp/language"
cp "$spec" "$tmp/language/"
# fixture files the spec may require_relative
specdir="$(cd "$(dirname "$spec")" && pwd)"
[ -d "$specdir/fixtures" ] && cp -R "$specdir/fixtures" "$tmp/language/fixtures"
[ -d "$specdir/../fixtures" ] && cp -R "$specdir/../fixtures" "$tmp/fixtures"
[ -d "$specdir/shared" ] && cp -R "$specdir/shared" "$tmp/language/shared"
cp "$here/spec_helper.rb" "$tmp/spec_helper.rb"
base="$(basename "$spec" .rb)"
cat > "$tmp/driver.rb" <<EOF
require_relative "spec_helper"
require_relative "language/$base"
mspec_report
EOF
out_m="$("$mr" "$tmp/driver.rb" 2>&1)"
out_r="$(ruby -W0 "$tmp/driver.rb" 2>&1)"
echo "--- mere-ruby:"; echo "$out_m"
echo "--- ruby:";      echo "$out_r"
if [ "$out_m" = "$out_r" ]; then echo "MATCH"; else echo "DIFF"; fi
[ "$2" = "--keep" ] || rm -rf "$tmp"
