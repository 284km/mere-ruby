#!/bin/sh
# Can this interpreter run a real gem, and what does it cost? ruby/csv is a
# good subject: pure Ruby, no C extension, and it leans on StringScanner,
# Enumerator, StringIO and ARGF -- four things an interpreter is easy to get
# almost right. Six bugs stood between `require "csv"` and this table.
#
#   ./bench/csv.sh [path/to/mere-ruby]
#
# ROWS (default 400) and REPS (default 3, best-of) come from the environment.
#
# The csv gem is NOT vendored here; it is located by asking the reference ruby
# where it loaded csv.rb from, so the two sides run byte-identical library
# code and the only difference left is the interpreter.
#
# Read the count column, not just the seconds. Two sides that produced
# different numbers of rows did different amounts of work, and the way this
# arc started was CSV.parse quietly returning every other row -- which without
# the counts looks like a 2x speedup.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="${1:-$here/../mere-ruby}"
. "$here/../tools/ref_ruby.sh"

lib=$("$REF_RUBY_BIN" -e 'require "csv"; f = $LOADED_FEATURES.grep(%r{/csv\.rb$})[0]; abort "no csv" unless f; print File.dirname(f)') || exit 1

echo "csv from: $("$REF_RUBY_BIN" -I"$lib" -e 'require "csv"; print CSV::VERSION')   ruby $REF_RUBY_VERSION   rows=${ROWS:-400} best-of=${REPS:-3}"
echo
echo "--- ruby"
"$REF_RUBY_BIN" -I"$lib" "$here/csv_bench.rb" || exit 1
echo
echo "--- mere-ruby"
"$mr" -I"$lib" "$here/csv_bench.rb" || exit 1
