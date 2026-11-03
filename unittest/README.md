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

## Full measurement in GitHub Actions

Pull requests, pushes to `main`, the weekly schedule and manual dispatch run
the full `test/` candidate inventory. For Ruby 4.0.9 this is 757 files, including
the 16 files excluded from the historical default and the encoding subdirectory.
Bootstrap tests, basic tests and RubySpec remain separate suites.

The workflow pins the Mere compiler and Ruby source to full commit SHAs.
`workflow_dispatch` accepts `mere_ref`, a full published Mere commit SHA, to
measure a newer compiler without changing the default pin. The macOS jobs use
`macos-26` consistently. Linux still has its separate compilation smoke test.

The corpus job builds mere-ruby once with `tools/build.sh` at O2 and uploads the
binary before running the corpus. A separate job builds Ruby 4.0.9 and its native
test extensions and both JITs (with Rust 1.85.0), installs a relocatable
reference, and verifies the four test
extensions previously replaced by shims. Reference-only extension paths take
precedence over those shims; mere-ruby keeps its own Ruby implementations.

`unittest/ci.py` partitions the manifest into 64 shards with no overlapping files.
At most four macOS measurement jobs run at once. Each file runs sequentially:
each interpreter has a 600-second wall limit, and the tracked process family
has an aggregate RSS cap of 2 GiB, polled every 0.1 seconds. A worker also has
an outer wall limit of twice the per-side limit plus 60 seconds. Polling can
overshoot the RSS cap; it is a measurement bound, not a reservation. These bounds
differ from historical local sweeps and are recorded with each result.

The CI supervisor starts a new session per file and tracks PID/start-time
identities, parent ancestry, process groups and a per-file inherited marker.
This includes children that create another session or daemonize before the
next sample. Launch environments provide the marker after ordinary unsetenv;
ancestry and recorded birth identities also follow children with empty exec
environments. Cleanup stops parents, rescans for racing forks, then kills the
verified descendants. It does not select processes by interpreter name.
Process inspection is checked before launching tests, and a supervision error
aborts the shard so later files do not use an uncertain runner. Limits,
zero-test results, startup failures and unattempted files are separate states.
Each completed file atomically updates `result.json`, so a job that stops early
leaves its remaining files marked `NOT_RUN`. Missing shard artifacts are expanded
back to the manifest's full file list as `MISSING_SHARD` by the collection job.

Artifacts are retained for seven days:

| Artifact | Contents |
|---|---|
| `unittest-plan` | Exact candidate list, pinned revisions and shard count |
| `mere-ruby-macos` | O2 binary, build mode and compiler/source provenance |
| `ruby-reference-macos` | Installed reference, native test extensions and provenance |
| `unittest-shard-N` | Per-file results, bounds, peak family RSS and sanitized diagnostic logs |
| `unittest-report` | `SUMMARY.md`, `summary.json` and every planned file in `files.tsv` |

Diagnostic logs pass through the repository's existing masking rules before
upload. Each mask receives at most the first 2 MiB of raw input, bounding even
sed/perl's buffering of a single unterminated line. Filtered output is drained
in 64 KiB chunks, retaining at most 2 MiB plus a truncation marker. The marker
identifies whether input, output, or both reached their limits. A capped prefix
does not end with a partial UTF-8 code point. Private raw logs are not uploaded.
Interrupted workers also retain masked partial stdout/stderr when available.

The fixed mask pipeline has a 10-second wall limit and its own process group,
which is reclaimed on timeout. Failed or timed-out masking publishes no new
log and fails collection as an infrastructure error. Input/output byte limits
and the mask wall limit are recorded with the measurement bounds. These limits
also apply to driver logs, partial output and RED tags.

Both interpreters run with a small environment allowlist and a fresh temporary
HOME and TMPDIR per file. Only PATH, locale, explicit interpreter/extension paths,
the generated process-family identifier and the harness settings are passed;
parent credentials and GitHub session variables
are not inherited. This is important for whole Test::Unit failure reports:
multiline hashes and arrays can expose environment values that a line-oriented
mask cannot remove reliably. The environment policy is recorded in each shard
and mixed policies are rejected during collection. A real Ruby 4.0.9 Test::Unit
fixture exercises both renderings through the artifact publication path.

The Actions summary reports the named-test totals and incomplete-file count.
Known RED, BOTH, EXTRA and measured dependency/resource failures do not fail
the collection job by themselves: its status means results were collected,
not that Ruby conformance was achieved. Missing/unattempted files, inconsistent
revisions, binaries, bounds or counts, and infrastructure errors fail collection.
Read `files.tsv` as well as the four verdict totals before comparing runs.

The binary hash, actual source commits and reference hash must agree across
shards. This prevents combining a partial run, another compiler build or another
Ruby version into one measurement. Result files are artifacts; CI does not
commit a partial sweep over the checked-in historical records.

```sh
python3 unittest/ci_check.py -v
python3 unittest/process_family_check.py -v
```

This checks partitioning, collection, missing and partial shards, provenance,
resource cleanup and diagnostic masking with small controlled fixtures.
The process-family checks use real processes, including new sessions/groups,
empty exec environments, fast double-forks and multiline argv. They require
permission to inspect processes with ps. The CI harness job also runs a real
Ruby 4.0.9 Test::Unit fixture for multiline environment diagnostics.
The collection checks compare parent and mask-process peak RSS for 8 MiB and
64 MiB logs without newlines, exercise output expansion and UTF-8 truncation,
and check both silent and continuously noisy mask timeouts.
