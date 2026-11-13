#!/bin/sh
# ONE test file, ONE side, as unittest/run.sh runs it -- for working on a
# file, not for measuring it. Nothing is recorded (STATUS.md and tags/ are
# run.sh's), and the runner's own options go through:
#
#   ./unittest/try.sh <ruby-src> rubygems/test_require.rb
#   ./unittest/try.sh <ruby-src> ruby/test_io.rb -n /test_pipe/
#   ./unittest/try.sh <ruby-src> --ref ruby/test_io.rb -n /test_pipe/
#
# The side is mere-ruby ($MR_BIN, else ./mere-ruby) or, with --ref, the
# reference ($REF_RUBY_BIN, else ruby -- tools/ref_ruby.sh). The environment
# is run.sh's for that side, and it is NOT optional detail -- a hand-made
# command line reads differently:
#   - rubygems/* need the source tree's lib/ FIRST on RUBYLIB: its rubygems
#     is the one under test (Gem.prefix, the default gem specs).
#   - mere-ruby gets the reference's standard library and bundled gem libs
#     on RUBYLIB, and unittest/shim.
#   - the binary is reached by an absolute path, and should be NAMED
#     mere-ruby: rubygems writes it into a bin wrapper's shebang and later
#     reads the wrapper back only if the shebang mentions "ruby"
#     (Gem::Installer#check_executable_overwrite).
#   - the seed is run.sh's (1) unless one is given: a file that dies part-way
#     reaches a different set of tests under another seed.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="${1:?usage: unittest/try.sh <ruby-src> [--ref] <path under test/> [runner args ...]}"
shift
src="$(cd "$src" && pwd)"
side=mere
if [ "${1:-}" = "--ref" ]; then side=ref; shift; fi
rel="${1:?usage: unittest/try.sh <ruby-src> [--ref] <path under test/> [runner args ...]}"
shift
file="$src/test/$rel"
[ -f "$file" ] || { echo "unittest: no $file" >&2; exit 2; }
case "$rel" in
  */*) dir="$src/test/${rel%/*}" ;;
  *) dir="$src/test" ;;
esac
. "$root"/tools/ref_ruby.sh >/dev/null
mr="${MR_BIN:-$root/mere-ruby}"
ref="${REF_RUBY_BIN:-ruby}"
ref="$(command -v "$ref")" || exit 2
case "$mr" in /*) ;; *) mr="$(cd "$(dirname "$mr")" && pwd)/$(basename "$mr")" ;; esac
case "$ref" in /*) ;; *) ref="$(cd "$(dirname "$ref")" && pwd)/$(basename "$ref")" ;; esac
[ -x "$mr" ] || [ "$side" = ref ] || { echo "unittest: no $mr" >&2; exit 2; }
shim="$here/shim"
stdlib="$("$ref" -e 'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))')"
rake_source="$("$ref" -e 'begin; print Gem.bin_path("rake", "rake"); rescue Gem::Exception; end')"
# (run.sh's select_rake, for the file in hand)
if [ "$rel" != "rubygems/test_gem_ext_rake_builder.rb" ] && [ -n "$rake_source" ]; then
  if [ "$side" = ref ]; then bin="$ref"; else bin="$mr"; fi
  rake="$("$ref" -rshellwords -e 'print Shellwords.join(ARGV)' "$bin" "-I${rake_source%/*}/../lib" "$rake_source")" || exit 2
  export rake
else
  unset rake
fi
ref_lib="$src/tool/lib:$src/test"
if [ -n "${UNITTEST_REF_EXT_PATH:-}" ]; then
  ref_lib="$UNITTEST_REF_EXT_PATH:$ref_lib"
fi
mere_lib="$src/tool/lib:$src/test:$shim:$stdlib"
set -- "$@"
extra=""
case "$rel" in
  mkmf/*)
    if [ -f "$src/.unittest-reference/rbconfig.rb" ]; then
      extra="-I $src/.unittest-reference -I $src/lib"
      ref_lib="$src/.unittest-reference:$src/lib:$ref_lib"
    fi ;;
  rubygems/*)
    ref_lib="$src/lib:$ref_lib"
    mere_lib="$src/lib:$mere_lib" ;;
esac
seed="--seed=${UNITTEST_SEED:-1}"
for a in "$@"; do case "$a" in --seed*) seed="" ;; esac; done
cd "$dir" || exit 2
if [ "$side" = ref ]; then
  # shellcheck disable=SC2086
  PATH="$here/child-bin:$PATH" UNITTEST_CHILD_RUBY="$ref" RUBY="$ref" RUBYLIB="$ref_lib" UNITTEST_TEST_FILE="$rel" \
    exec "$ref" $extra -I "$src/tool/lib" -I "$src/test" -r test/unit -r "$here/bootstrap.rb" "$file" -v --show-skip $seed "$@"
else
  # shellcheck disable=SC2086
  PATH="$here/child-bin:$PATH" UNITTEST_CHILD_RUBY="$mr" RUBY="$mr" RUBYLIB="$mere_lib" UNITTEST_TEST_FILE="$rel" \
    exec "$mr" -I "$src/tool/lib" -I "$src/test" -I "$shim" -r test/unit -r "$here/bootstrap.rb" "$file" -v --show-skip $seed "$@"
fi
