#!/bin/sh
# The generated tables include frozen US-ASCII literals with Unicode escapes.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$here/ref_ruby.sh"
mr="${MR_BIN:-$root/mere-ruby}"
stdlib="$("$REF_RUBY_BIN" -rrbconfig -e 'print RbConfig::CONFIG.fetch("rubylibdir")')"
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/unicode_normalize_check.XXXXXX")"
trap 'rm -rf "$task_tmp"' EXIT HUP INT TERM
RUBYLIB="$stdlib" "$REF_RUBY_BIN" "$root/unittest/repro/unicode_normalize_tables.rb" > "$task_tmp/reference"
RUBYLIB="$stdlib" "$mr" "$root/unittest/repro/unicode_normalize_tables.rb" > "$task_tmp/candidate"
diff -u "$task_tmp/reference" "$task_tmp/candidate"
echo "UnicodeNormalize's generated tables load with the reference encodings"
