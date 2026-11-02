# CRuby test discovery and execution coverage

`run.sh` compares individual tests under CRuby and mere-ruby. File execution
coverage is recorded separately from MATCH / RED / BOTH / EXTRA, so a load
failure on both sides cannot disappear as a successful zero-test run.

## Selecting files

```sh
# List files without a built mere-ruby or an installed reference Ruby.
sh unittest/run.sh /path/to/ruby --list
sh unittest/run.sh /path/to/ruby --list --all
sh unittest/run.sh /path/to/ruby --list ruby/enc

# Measure a directory recursively, or a file excluded from the default record.
sh unittest/run.sh /path/to/ruby ruby/enc
sh unittest/run.sh /path/to/ruby ruby/test_iseq.rb
```

With no paths, `files.txt` retains the historical selection: its directories
are searched directly, and its negative entries apply. Explicit directories
are recursive and explicit selections do not apply those negative entries.
`--all` recursively selects `test_*.rb` and `*_test.rb` throughout `test/`,
except `test_helper.rb`. Overlapping selections are deduplicated. Missing
paths, incompatible arguments and an empty execution selection exit 2.

This lists candidate files, not all dynamically defined test cases. Bootstrap
tests, basic tests, RubySpec and tests outside this naming convention need
their own runners and inventories. `--all` adds CRuby implementation tests;
their dependencies and runtime behavior may require substantial work.

## Records and diagnostics

```sh
UNITTEST_RECORD_DIR=/path/to/run/records \
UNITTEST_KEEP=/path/to/run/raw \
  sh unittest/run.sh /path/to/ruby ruby/enc
```

`UNITTEST_RECORD_DIR` defaults to `unittest/`. It holds `STATUS.md`, `tags/`
and `COVERAGE.tsv`. Use a separate destination for exploratory subsets so
they do not replace the full record. `UNITTEST_KEEP` retains both sides:
`ruby_test_example.reference.out` and the existing `ruby_test_example.out`
name for mere-ruby. Each diagnostic log contains stdout followed by stderr;
their chronological interleaving is not preserved. Verdicts are parsed from
stdout so warnings cannot be mistaken for part of a verbose test name.

Both sides preload CRuby's `tool/lib/test/unit` before loading a file, including
files that normally rely on the shared runner to define `Test::Unit`.

`COVERAGE.tsv` has one row per selected file. Each side records the exit code,
the summary's test count and the number of distinct test names discovered.

| State | Meaning |
|---|---|
| COMPLETE | Nonzero summary count agrees with discovered names; exit agrees with failures + errors modulo 256 |
| ZERO | A summary was printed but reported zero tests |
| INCOMPLETE | No final test summary, including startup errors and timeouts |
| COUNT_MISMATCH | Summary count and discovered names disagree |
| EXIT_ERROR | Summary exists but its failures + errors do not explain the exit code |
| MISSING | The worker did not produce both its result and coverage row |

A file is complete even if some tests failed or were skipped; consult the
four verdict columns and raw logs for those results. As before, RED is a
measurement rather than a shell failure. The top-level command now exits 1
if any selected file is ZERO, INCOMPLETE, COUNT_MISMATCH, EXIT_ERROR or MISSING.
Neither an empty union of named tests nor a successful zero-test summary is
accepted as complete coverage. This also catches missing test-only extensions
that silently prevent a test class from being defined.

The existing wall-time and RSS controls still apply to full runs. Start with
small selections while developing; running the entire expanded selection is
a separate measurement from listing it.

## Checking the harness

```sh
python3 unittest/harness_check.py -v
```

The check uses fixed fake-interpreter transcripts, temporary source trees and
a stub RSS guard. It covers selection, test framework preloading, load errors,
zero tests, interrupted output, count mismatches, exit codes, warning output,
both raw logs, record destinations and the existing verdict categories. It
does not build Mere or run CRuby's suites.
