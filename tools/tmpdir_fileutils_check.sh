#!/bin/sh
# Check both library load orders using the reference's real FileUtils source.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$here/ref_ruby.sh"
mr="${MR_BIN:-$root/mere-ruby}"
stdlib="$("$REF_RUBY_BIN" -e 'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))')"
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/tmpdir_fileutils_check.XXXXXX")"
trap 'rm -rf "$task_tmp"' EXIT HUP INT TERM
for name in fileutils_before_tmpdir tmpdir_before_fileutils; do
  RUBYLIB="$stdlib" "$REF_RUBY_BIN" "$root/unittest/repro/$name.rb" > "$task_tmp/reference"
  RUBYLIB="$stdlib" "$mr" "$root/unittest/repro/$name.rb" > "$task_tmp/candidate"
  diff -u "$task_tmp/reference" "$task_tmp/candidate"
done
"$mr" "$root/unittest/repro/tmpdir_without_fileutils.rb"
echo "tmpdir and FileUtils load orders match the reference"
