#!/bin/sh
# Use the same reference pure-Ruby store library with both interpreters.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$here/ref_ruby.sh"
mr="${MR_BIN:-$root/mere-ruby}"
stdlib="$("$REF_RUBY_BIN" -e 'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))')"
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/yaml_store_check.XXXXXX")"
trap 'rm -rf "$task_tmp"' EXIT HUP INT TERM
RUBYLIB="$stdlib" "$REF_RUBY_BIN" "$root/unittest/repro/yaml_store_indentation.rb" > "$task_tmp/reference"
RUBYLIB="$stdlib" "$mr" "$root/unittest/repro/yaml_store_indentation.rb" > "$task_tmp/candidate"
diff -u "$task_tmp/reference" "$task_tmp/candidate"
echo "YAML::Store indentation round trips match the reference"
