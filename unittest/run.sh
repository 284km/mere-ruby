#!/bin/sh
# CRuby's OWN tests, run under mere-ruby and under the reference ruby, test
# by test. ruby/spec is one yardstick; this is the second one.
#
#   ./unittest/run.sh <ruby-src> [path under test/ ...]
#
# <ruby-src> is a CRuby source tree AT THE REFERENCE'S RELEASE -- the ruby_4_0
# branch for 4.0.6 (tools/ref_ruby.sh). Only two of its directories are read:
# tool/lib, which holds the framework the tests are written against (its own
# test/unit, core_assertions, envutil -- NOT the test-unit gem), and test/.
# ⚠ A tree from another release is a different subject: master's test/json is
#   written against a newer json and fails four tests under 4.0.6 itself, which
#   would read as four defects in mere-ruby.
#
# Without paths it runs the list in unittest/files.txt. With paths, a
# directory means every *_test.rb and test_*.rb in it.
#
# Each file runs with `-v --show-skip` on both sides, under tool/lib's runner,
# which names every test it runs and then every one that did not pass:
#
#   [ 1/11] TestComparable#test_equal = 0.00 s
#     1) Failure:
#   TestComparable#test_clamp [.../test_comparable.rb:42]:
#
# A test is `.` when it ran and is in no report, F / E / S when it is under a
# Failure / Error / Skipped report. A test the reference runs and mere-ruby
# never names (the file stopped before it) is ABSENT. The columns:
#
#   MATCH   both sides passed it
#   RED     the reference passed it and mere-ruby did not (failed, errored,
#           omitted or never reached it) -- the number to work on
#   BOTH    neither side passed it (the reference's own failures: excluded)
#   EXTRA   mere-ruby passed it and the reference did not
#
# Both sides get the reference's stdlib and bundled gems on RUBYLIB (tests
# require them) and tool/lib first on -I, and both run in the test file's own
# directory, as `make test-all` does. mere-ruby's answer is its own
# (json, digest, zlib ... are the ones it ships or answers).
#
# Writes unittest/STATUS.md and unittest/tags/<file>.txt (the RED tests, one
# per line). Both are checked in: every line goes through mspec/mask.sh.
set -u
LC_ALL=C; export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="${1:?usage: unittest/run.sh <ruby-src> [path under test/ ...]}"
shift
src="$(cd "$src" && pwd)"
[ -d "$src/tool/lib" ] && [ -d "$src/test" ] || { echo "unittest: $src has no tool/lib and test/" >&2; exit 2; }
. "$root"/tools/ref_ruby.sh
. "$root"/mspec/mask.sh
mr="${MR_BIN:-$root/mere-ruby}"
[ -x "$mr" ] || { echo "unittest: no $mr" >&2; exit 2; }
ref="${REF_RUBY_BIN:-ruby}"
# the per-file bound, per side: a test file that hangs (a thread waiting on a
# pipe nobody writes) is KILLED, not signalled -- see bootstraptest/all.sh
wall="${UNITTEST_WALL:-300}"
stdlib="$("$ref" -e 'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))')"

if [ "$#" -eq 0 ]; then
  set -- $(grep -v '^#' "$here/files.txt" | grep -v '^$')
fi
list="$(mktemp)"; trap 'rm -f "$list"' EXIT
for p in "$@"; do
  if [ -d "$src/test/$p" ]; then
    (cd "$src/test" && find "$p" -maxdepth 1 \( -name '*_test.rb' -o -name 'test_*.rb' \) -type f | sort) >> "$list"
  elif [ -f "$src/test/$p" ]; then
    echo "$p" >> "$list"
  else
    echo "unittest: no test/$p in $src" >&2
  fi
done

runner='
  my ($wall, @cmd) = @ARGV;
  my $pid = fork();
  if (!defined $pid) { exit 127 }
  if (!$pid) { open(STDERR, ">&", \*STDOUT); exec(@cmd); exit 127 }
  $SIG{ALRM} = sub { kill "KILL", $pid; exit 142 };
  alarm $wall;
  waitpid($pid, 0);
  exit(($? & 127) ? 128 + ($? & 127) : ($? >> 8));
'
# one line per test: "Class#test_name<TAB>verdict"
verdicts() {
  awk '
    /^\[ *[0-9]+\/[0-9]+\] / { n = $0; sub(/^\[ *[0-9]+\/[0-9]+\] /, "", n); sub(/ = .*$/, "", n); ran[n] = 1; next }
    /^ *[0-9]+\) Failure:/ { want = "F"; next }
    /^ *[0-9]+\) Error:/   { want = "E"; next }
    /^ *[0-9]+\) Skipped:/ { want = "S"; next }
    want != "" { n = $1; sub(/:$/, "", n); bad[n] = want; ran[n] = 1; want = ""; next }
    END { for (n in ran) print n "\t" ((n in bad) ? bad[n] : ".") }' | sort -u
}

mkdir -p "$here/tags"
status="$here/STATUS.md.$$"
tm=0; tr=0; tb=0; tx=0; tt=0
{
  echo "# mere-ruby — CRuby's own tests"
  echo
  echo "CRuby's test/ files at the reference's release, run under mere-ruby and under"
  echo "ruby $REF_RUBY_VERSION test by test (\`unittest/run.sh\`). A second yardstick beside"
  echo "SPEC_STATUS.md: ruby/spec asks what the language and core classes do; these are the"
  echo "tests CRuby itself keeps, with the framework it keeps them in (tool/lib)."
  echo
  echo "- **MATCH** both passed · **RED** ruby passed, mere-ruby did not (failed, errored,"
  echo "  or never reached it) · **BOTH** neither passed (ruby's own failures here) ·"
  echo "  **EXTRA** only mere-ruby passed"
  echo
  echo "| file | tests | MATCH | RED | BOTH | EXTRA |"
  echo "|---|---|---|---|---|---|"
} > "$status"
while read -r rel; do
  dir="$src/test/$(dirname "$rel")"; base="$(basename "$rel")"
  ro="$(cd "$dir" && perl -e "$runner" "$wall" "$ref" -I "$src/tool/lib" "$base" -v --show-skip < /dev/null 2>&1 | verdicts)"
  mo="$(cd "$dir" && RUBYLIB="$stdlib" perl -e "$runner" "$wall" "$mr" -I "$src/tool/lib" "$base" -v --show-skip < /dev/null 2>&1 | verdicts)"
  rf="$(mktemp)"; mf="$(mktemp)"
  printf '%s\n' "$ro" | grep -v '^$' > "$rf"; printf '%s\n' "$mo" | grep -v '^$' > "$mf"
  tag="$here/tags/$(printf '%s' "$rel" | sed 's|/|_|g; s|\.rb$||').txt"
  counts="$(join -t "	" -a 1 -a 2 -e - -o 0,1.2,2.2 "$rf" "$mf" | awk -F'\t' -v tag="$tag" '
    BEGIN { m = r = b = x = n = 0; printf "" > tag }
    {
      n++
      rp = ($2 == "."); mp = ($3 == ".")
      if (rp && mp) m++
      else if (rp) { r++; print $1 "\t" ($3 == "-" ? "ABSENT" : $3) >> tag }
      else if (mp) x++
      else b++
    }
    END { print n, m, r, b, x }')"
  rm -f "$rf" "$mf"
  set -- $counts
  [ -s "$tag" ] || rm -f "$tag"
  [ -f "$tag" ] && { strip_noise < "$tag" > "$tag.m" && mv "$tag.m" "$tag"; }
  printf '| %s | %s | %s | %s | %s | %s |\n' "$rel" "$1" "$2" "$3" "$4" "$5" >> "$status"
  printf '%-48s %4s tests  MATCH %4s  RED %4s  BOTH %3s  EXTRA %3s\n' "$rel" "$1" "$2" "$3" "$4" "$5"
  tt=$((tt + $1)); tm=$((tm + $2)); tr=$((tr + $3)); tb=$((tb + $4)); tx=$((tx + $5))
done < "$list"
{
  printf '| **total** | %s | %s | %s | %s | %s |\n' "$tt" "$tm" "$tr" "$tb" "$tx"
  echo
  echo "_Generated by \`unittest/run.sh\` against ruby $REF_RUBY_VERSION's test/ and tool/lib._"
} >> "$status"
mv "$status" "$here/STATUS.md"
echo "total: $tt tests, MATCH $tm, RED $tr, BOTH $tb, EXTRA $tx"
