#!/bin/sh
# Compare actual supplied pure Ruby Psych protocols with native Psych.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$here/ref_ruby.sh"
mr="${MR_BIN:-$root/mere-ruby}"
stdlib="$("$REF_RUBY_BIN" -e 'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))')"
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/psych_scalar_check.XXXXXX")"
trap 'rm -rf "$task_tmp"' EXIT HUP INT TERM
for mode in --autoload --direct; do
  "$REF_RUBY_BIN" "$root/unittest/repro/psych_scalar_protocols.rb" "$mode" > "$task_tmp/reference"
  RUBYLIB="$stdlib" "$mr" "$root/unittest/repro/psych_scalar_protocols.rb" "$mode" > "$task_tmp/candidate"
  diff -u "$task_tmp/reference" "$task_tmp/candidate"
done
cat "$task_tmp/candidate"
