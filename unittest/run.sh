#!/bin/sh
# CRuby's OWN tests, run under mere-ruby and under the reference ruby, test
# by test. ruby/spec is one yardstick; this is the second one.
#
#   ./unittest/run.sh <ruby-src> [--list] [--all | path under test/ ...]
#
# <ruby-src> is a CRuby source tree AT THE REFERENCE'S RELEASE -- the ruby_4_0
# branch for 4.0.9 (tools/ref_ruby.sh). Only two of its directories are read:
# tool/lib, which holds the framework the tests are written against (its own
# test/unit, core_assertions, envutil -- NOT the test-unit gem), and test/.
# ⚠ A tree from another release is a different subject: master's test/json is
#   written against a newer json and fails four tests under 4.0.x itself, which
#   would read as four defects in mere-ruby.
#
# Without paths it runs the historical selection in unittest/files.txt.
# Explicit directories are recursive; explicit paths and --all include default
# exclusions. --list prints the selection without requiring either interpreter.
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
# never names (the file stopped before it) is ABSENT.
# ⚠ "IN NO REPORT" MEANS NOTHING WHEN THERE IS NO REPORT. The reports come
#   after the last test, so a file killed on its last test (test_exception ran
#   into the 6 GB guard there) named all 98 and reported none, and read as
#   98 MATCH; finished, it is 49. A test that ran in a file that never printed
#   its "N tests, M assertions" line is X, not `.`. The columns:
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
# UNITTEST_RECORD_DIR changes the record destination for an exploratory run.
# COVERAGE.tsv records each side's exit status, summary and discovered tests;
# missing summaries and zero tests make the run exit 1, even with zero RED.
set -u
LC_ALL=C; export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="${1:?usage: unittest/run.sh <ruby-src> [path under test/ ...]}"
shift
src="$(cd "$src" && pwd)"
[ -d "$src/tool/lib" ] && [ -d "$src/test" ] || { echo "unittest: $src has no tool/lib and test/" >&2; exit 2; }
if [ "${1:-}" = "--list" ]; then
  shift
  exec sh "$here/list.sh" "$src" "$@"
fi
if [ "${1:-}" != "--one" ]; then
  list="$(mktemp)"
  trap 'rm -f "$list"' EXIT
  sh "$here/list.sh" "$src" "$@" > "$list" || exit 2
  [ -s "$list" ] || { echo "unittest: empty selection" >&2; exit 2; }
fi
records="${UNITTEST_RECORD_DIR:-$here}"
mkdir -p "$records/tags" || exit 2
records="$(cd "$records" && pwd)"
UNITTEST_RECORD_DIR="$records"; export UNITTEST_RECORD_DIR
[ -z "${UNITTEST_KEEP:-}" ] || mkdir -p "$UNITTEST_KEEP" || exit 2
# ⚠ THE TEST EXTENSIONS AN INSTALLED RUBY DOES NOT CARRY. test_file,
#   test_file_exhaustive and test_dir_m17n require -test-/file, test_call
#   -test-/iter, test_keyword -test-/rb_call_super_kw -- C extensions built
#   only inside a CRuby build tree -- and the reference ruby fails to load them
#   as surely as mere-ruby does: about 400 tests measured on NEITHER side.
#   unittest/shim/-test-/ has a Ruby stand-in for each, and BOTH sides get it
#   on the load path (and pass it to the children assert_separately starts,
#   which inherit $:), so it is part of the instrument as mspec's shim is. A
#   stand-in that answered differently from the extension would show as the
#   reference's own failure (BOTH), not as a verdict on mere-ruby.
shim="$here/shim"
. "$root"/tools/ref_ruby.sh
. "$root"/mspec/mask.sh
mr="${MR_BIN:-$root/mere-ruby}"
[ -x "$mr" ] || { echo "unittest: no $mr" >&2; exit 2; }
ref="${REF_RUBY_BIN:-ruby}"
# the per-file bound, per side: a test file that hangs (a thread waiting on a
# pipe nobody writes) is KILLED, not signalled -- see bootstraptest/all.sh
# ⚠ 600, not 300: test_io takes about 270 s alone (one test, a child writing
#   to a closed pipe, runs 94 s -- note 269), so two files at once put it
#   past 300 and every one of its 249 tests read as X (no report). A file
#   that really hangs costs the wall either way.
wall="${UNITTEST_WALL:-600}"
# ⚠ ONE SEED FOR BOTH SIDES AND EVERY RUN. tool/lib's runner shuffles the
#   tests with a random seed, so a file that hangs or dies part-way reached a
#   different set of tests each run: test_enumerator read 47 MATCH on one run
#   and 5 on the next with the same interpreter, because the hanging test
#   (42.upto(Float::INFINITY).size) came first the second time.
seed="${UNITTEST_SEED:-1}"
stdlib="$("$ref" -e 'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))')"

runner='
  my ($wall, @cmd) = @ARGV;
  my $pid = fork();
  if (!defined $pid) { exit 127 }
  if (!$pid) { exec(@cmd); exit 127 }
  $SIG{ALRM} = sub { kill "KILL", $pid; exit 142 };
  alarm $wall;
  waitpid($pid, 0);
  exit(($? & 127) ? 128 + ($? & 127) : ($? >> 8));
'
# ONE FILE, both sides -- the unit the loop below hands out, as
# `run.sh <src> --one <work> <n> <rel>`. It writes the file's tag and a row,
# <work>/<n>.row ("tests match red both extra"); the table is assembled from
# the rows in list order, so how many files ran at once does not show in it.
if [ "${1:-}" = "--one" ]; then
  work="$2"; n="$3"; rel="$4"
  # -ext-/... is a real part of CRuby's test tree. Passing it directly to
  # dirname/basename treats the leading hyphen as an option on macOS.
  base="${rel##*/}"
  case "$rel" in
    */*) dir="$src/test/${rel%/*}" ;;
    *) dir="$src/test" ;;
  esac
  case "$base" in -*) base="./$base" ;; esac
  # ⚠ INTO A FILE, then read: a pipe is not done until every process holding
  #   its write end is gone, and a test can leave one behind. test_process's
  #   fifo tests start `cat < fifo` from a ruby they interrupt; under
  #   mere-ruby that cat outlived it, blocked opening the fifo, holding the
  #   inherited stderr -- and `| verdicts` waited on it for 2 h 40 m, the
  #   whole sweep stopped behind one file, whose verdicts then came out empty
  #   (MATCH 57 -> 0). An orphan holding a file holds nothing up.
  out1="$work/$n.ref.stdout"; err1="$work/$n.ref.stderr"
  printf 'ref\n' > "$work/$n.phase.new"
  mv "$work/$n.phase.new" "$work/$n.phase"
  # mkmf's own tests require Ruby's build Makefile and source headers. The
  # restored context reuses the installed config, rebinding only topdir;
  # children inherit these -I entries through assert_separately.
  set --
  case "$rel" in
    mkmf/*)
      if [ -f "$src/.unittest-reference/rbconfig.rb" ]; then
        set -- -I "$src/.unittest-reference" -I "$src/lib"
      fi ;;
  esac
  # Verbose names are printed before a test runs, without a newline. A warning
  # on stderr can otherwise join the name and create a different test identity.
  # Parse stdout, then append stderr to the saved diagnostic log.
  (cd "$dir" && UNITTEST_CASE_ENCODINGS="$work/$n.ref.encodings" perl -e "$runner" "$wall" "$ref" "$@" -I "$src/tool/lib" -I "$src/test" -I "${UNITTEST_REF_EXT_PATH:-$shim}" -I "$shim" -r test/unit -r "$here/case_encodings.rb" "$base" -v --show-skip --seed="$seed" < /dev/null > "$out1" 2> "$err1")
  ref_code=$?
  printf '%s\n' "$ref_code" > "$work/$n.ref.exit.new"
  mv "$work/$n.ref.exit.new" "$work/$n.ref.exit"
  python3 "$here/transcript.py" parse "$out1" "$ref_code" "$work/$n.ref.json" --encodings "$work/$n.ref.encodings" || exit 1
  [ -z "${UNITTEST_KEEP:-}" ] || cat "$out1" "$err1" > "$UNITTEST_KEEP/$(printf '%s' "$rel" | sed 's|/|_|g; s|\.rb$||').reference.out"
  # Separate files prevent a kill between the phase switch and redirection
  # from reinterpreting reference stdout as mere-ruby stdout.
  out1="$work/$n.mere.stdout"; err1="$work/$n.mere.stderr"
  printf 'mere\n' > "$work/$n.phase.new"
  mv "$work/$n.phase.new" "$work/$n.phase"
  (cd "$dir" && UNITTEST_CASE_ENCODINGS="$work/$n.mere.encodings" RUBYLIB="$stdlib" perl -e "$runner" "$wall" "$mr" -I "$src/tool/lib" -I "$src/test" -I "$shim" -r test/unit -r "$here/case_encodings.rb" "$base" -v --show-skip --seed="$seed" < /dev/null > "$out1" 2> "$err1")
  mr_code=$?
  printf '%s\n' "$mr_code" > "$work/$n.mere.exit.new"
  mv "$work/$n.mere.exit.new" "$work/$n.mere.exit"
  python3 "$here/transcript.py" parse "$out1" "$mr_code" "$work/$n.mere.json" --encodings "$work/$n.mere.encodings" || exit 1
  # Preserve the old mere-ruby log name and add the reference side beside it.
  [ -n "${UNITTEST_KEEP:-}" ] && cat "$out1" "$err1" > "$UNITTEST_KEEP/$(printf '%s' "$rel" | sed 's|/|_|g; s|\.rb$||').out"
  tag="$records/tags/$(printf '%s' "$rel" | sed 's|/|_|g; s|\.rb$||').txt"
  python3 "$here/transcript.py" compare "$work/$n.ref.json" "$work/$n.mere.json" \
    --file="$rel" "$work/$n" "$tag" || exit 1
  [ -s "$tag" ] || rm -f "$tag"
  [ -f "$tag" ] && { strip_noise < "$tag" > "$tag.m" && mv "$tag.m" "$tag"; }
  exit 0
fi

# ⚠ UNITTEST_JOBS files at once (default 1). Each file is two processes,
#   and a mere-ruby run can take a few GB, so this is a number for the machine
#   and not for the record: the verdicts are per test and do not depend on it.
jobs="${UNITTEST_JOBS:-1}"
# ⚠ ...AND THE BYTES ARE BOUNDED HERE, as the sweep bounds them: the first run
#   of this list four files at a time had no guard, and the machine went down
#   part-way. mspec/rss_guard.sh kills any mere-ruby (or reference) past the
#   cap, one at a time; a killed file reads as ABSENT tests, so check
#   mspec/rss_kills.log before believing a file that stopped. An operator's
#   guard already up is left to it, as scoreboard.sh does.
ut_guard=""
if pgrep -f 'rss_guard\.sh' >/dev/null 2>&1; then
  echo "unittest: an rss_guard.sh is already running; leaving it to it" >&2
else
  sh "$root/mspec/rss_guard.sh" "${SPEC_RSS_KB:-6291456}" "$root/mspec/rss_kills.log" 1 &
  ut_guard=$!
fi
work="$(mktemp -d)"; trap '[ -n "$ut_guard" ] && kill "$ut_guard" 2>/dev/null; rm -f "$list"; rm -rf "$work"' EXIT INT TERM
awk '{ print NR " " $0 }' "$list" | xargs -n 2 -P "$jobs" sh "$0" "$src" --one "$work"
status="$records/STATUS.md.$$"
coverage_file="$records/COVERAGE.tsv.$$"
printf 'file\tref_state\tref_exit\tref_summary_tests\tref_discovered_tests\tmere_state\tmere_exit\tmere_summary_tests\tmere_discovered_tests\n' > "$coverage_file"
incomplete=0
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
i=0
while read -r rel; do
  i=$((i + 1))
  if [ ! -f "$work/$i.row" ] || [ ! -f "$work/$i.coverage" ]; then
    echo "unittest: no result for $rel" >&2
    printf '%s\tMISSING\t-\t-\t-\tMISSING\t-\t-\t-\n' "$rel" >> "$coverage_file"
    incomplete=$((incomplete + 1))
    continue
  fi
  cat "$work/$i.coverage" >> "$coverage_file"
  if ! awk -F '\t' '$2 == "COMPLETE" && $6 == "COMPLETE" {ok=1} END {exit !ok}' "$work/$i.coverage"; then
    incomplete=$((incomplete + 1))
  fi
  set -- $(cat "$work/$i.row")
  printf '| %s | %s | %s | %s | %s | %s |\n' "$rel" "$1" "$2" "$3" "$4" "$5" >> "$status"
  printf '%-48s %4s tests  MATCH %4s  RED %4s  BOTH %3s  EXTRA %3s\n' "$rel" "$1" "$2" "$3" "$4" "$5"
  tt=$((tt + $1)); tm=$((tm + $2)); tr=$((tr + $3)); tb=$((tb + $4)); tx=$((tx + $5))
done < "$list"
{
  printf '| **total** | %s | %s | %s | %s | %s |\n' "$tt" "$tm" "$tr" "$tb" "$tx"
  echo
  printf 'File coverage: %s incomplete or zero-test files. See `COVERAGE.tsv`.\n' "$incomplete"
  echo
  echo "_Generated by \`unittest/run.sh\` against ruby $REF_RUBY_VERSION's test/ and tool/lib._"
} >> "$status"
mv "$status" "$records/STATUS.md"
mv "$coverage_file" "$records/COVERAGE.tsv"
[ "$incomplete" -eq 0 ] || echo "unittest: $incomplete files incomplete or zero-test; see $records/COVERAGE.tsv" >&2
echo "total: $tt tests, MATCH $tm, RED $tr, BOTH $tb, EXTRA $tx"
[ "$incomplete" -eq 0 ]
