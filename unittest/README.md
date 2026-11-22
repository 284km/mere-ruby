# CRuby test discovery and execution coverage

`run.sh` compares individual tests under CRuby and mere-ruby. File execution
coverage is recorded separately from MATCH / RED / BOTH / EXTRA, so a load
failure on both sides cannot disappear as a successful zero-test run.
The runner uses Python 3.9 or later (standard library only) to parse and
atomically save each interpreter's case results.

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
Both sides also include the source `test/` directory on their load paths, so
shared helpers such as `psych/helper` and `rubygems/simple_gem` can be loaded
from nested test directories.

`COVERAGE.tsv` has one row per selected file. Each side records the exit code,
the summary's test count and the number of distinct test names discovered.

| State | Meaning |
|---|---|
| COMPLETE | Nonzero summary count agrees with discovered names; exit agrees with failures + errors modulo 256 |
| ZERO | A summary was printed but reported zero tests |
| INCOMPLETE | No final test summary, including startup errors and timeouts |
| COUNT_MISMATCH | Summary count and discovered names disagree |
| EXIT_ERROR | Summary exists but its failures + errors do not explain the exit code |
| REPORT_MISMATCH | Failure/error/skip report counts do not agree with the summary |
| IDENTITY_AMBIGUOUS | Non-ASCII names lack runtime encoding metadata; no cases are confirmed passing |
| PARSE_LIMIT | Transcript or case-name/count budgets prevented complete parsing; issues are recorded |
| MISSING | The worker did not produce both its result and coverage row |

A file is complete even if some tests failed or were skipped; consult the
four verdict columns and raw logs for those results. As before, RED is a
measurement rather than a shell failure. The top-level command now exits 1
if any selected file has a state other than COMPLETE.
Neither an empty union of named tests nor a successful zero-test summary is
accepted as complete coverage. This also catches missing test-only extensions
that silently prevent a test class from being defined.

The existing wall-time and RSS controls still apply to full runs. Start with
small selections while developing; running the entire expanded selection is
a separate measurement from listing it.

## Tool tests

The separate [tool measurement](../tooltest/README.md) executes the 12
`tool/test` candidate bodies through their original runner, including their
CLI and parallel fixtures. CI publishes four `tool-shard-*` artifacts and a
`tool-report`; these cases are not added to the `test/` totals above.

## Checking the harness

```sh
python3 unittest/harness_check.py -v
python3 unittest/transcript_check.py -v
```

The check uses fixed fake-interpreter transcripts, temporary source trees and
a stub RSS guard. It covers selection, test framework preloading, load errors,
zero tests, interrupted output, count mismatches, exit codes, warning output,
both raw logs, record destinations and the existing verdict categories. It
does not build Mere or run CRuby's suites.

`transcript.py` recognizes the Symbol.inspect token at the start of each
verbose progress line, normalizes its quoted/escaped spelling, and resolves
failure reports against that same identity. Output printed by a test directly
after the token does not become part of its name. Control bytes and literal
backslashes have distinct single-line encodings. No transcript text is evaluated
as Ruby or Python code. Failure/error/skip report counts are also checked;
unrecognized reports, missing summaries and missing final exit statuses cannot
turn a case into MATCH.

## Full measurement in GitHub Actions

Pull requests, pushes to `main`, the weekly schedule and manual dispatch run
the full `test/` candidate inventory. For Ruby 4.0.9 this is 758 files: 757
matching the naming rules and the audited standalone body
`rubygems/bundler_test_gem.rb` in `extra_files.txt`. This includes the 16 files
excluded from the historical default and the encoding subdirectory. Recursive
directory selections include audited extra bodies in that directory; the
historical default stays unchanged. A missing audited body is an error.
Shared test modules are associated with their includers rather than executed
as independent zero-case bodies. The remaining helper candidates still need
that audit. Bootstrap, basic and RubySpec remain separate measurements.

The workflow pins the Mere compiler and Ruby source to full commit SHAs.
`workflow_dispatch` accepts `mere_ref`, a full published Mere commit SHA, to
measure a newer compiler without changing the default pin. The macOS jobs use
`macos-26` consistently. Linux still has its separate compilation smoke test.

The `build-macos` job builds mere-ruby once with `tools/build.sh` at O2 and uploads
the binary and its provenance. Corpus and native lifecycle checks run in the
separate `corpus` job, which restores that exact binary and verifies its SHA-256.
Its generated C, Prism archive and C API header are transferred in
`native-build-macos` rather than rebuilt. CRuby, bootstrap, basic and tool
measurements depend on the two builds and the plan, so they can start while
corpus verification is still running. Corpus failures still fail CI.

The shared `setup-mere` action caches only the native compiler executable,
keyed by the full Mere SHA, runner OS/architecture, image and Clang identity,
and the action definition. A hit skips OCaml/opam setup and compilation;
the compiler checkout and executable check still run. A miss retains the
existing OCaml setup retry. Both native platforms use the same action.

A separate job builds Ruby 4.0.9, its native test extensions and both JITs
(with Rust 1.85.0), installs a relocatable reference, and verifies the four
test extensions previously replaced by shims. The reference load path excludes
those shims entirely: Ruby can select a later .rb before an earlier native
extension. mere-ruby keeps its own Ruby implementations.

The reference runtime archive is cached by the Ruby source SHA, Ruby/Rust
versions, build/data/archive definitions, runner OS/architecture, image,
Clang/SDK identity and native dependency versions and prefixes. The definition
set lives in `reference_cache_key.py`; changes to shard scheduling or unrelated
workflow steps keep the cache. `package_reference.sh` defines the relocatable
archive layout and is included in its key. Cache hits still
check the Ruby version, both JITs, native test extensions, pinned test data,
the environment smoke tests and actual mkmf compilation. Provenance is
regenerated and the runtime is uploaded for the current run. The mere-ruby
binary is rebuilt for each run; test outcomes are always measured again.

Workers launch absolute test paths from each file's directory, preserving
the source assumptions about `__FILE__` and absolute backtrace locations.
Each side explicitly selects its running interpreter through `RUBY` and
passes its helper paths through `RUBYLIB` to children. Only the reference
receives the native extension directory; only mere-ruby receives the shims.
Missing native reference extensions stay visible instead of falling back.
The native reference retains its own standard/default-gem load path ordering;
those directories are not duplicated in its `RUBYLIB`. mere-ruby receives the
reference's pure-Ruby library directories explicitly. Adding native stdlib
directories to `RUBYLIB` bypasses default-gem activation and moves them ahead
of RubyGems' insertion marker, including in child processes. This distinction
is recorded as environment policy `per-side-path-ruby-v6`.
`child-bin/ruby` also routes PATH and `/usr/bin/env ruby` children to the
absolute interpreter selected for that side, including gem binstubs. An unset
selection is an error, rather than a fallback to a host Ruby. Explicit
`RUBY`/EnvUtil launches retain their selected absolute target. Tests that
deliberately replace PATH or hardcode another interpreter still require their
own context audit; this launcher does not rewrite those commands.
The real-Ruby regression compiles a small extension and checks competing
native/shim paths in the parent, an explicit subprocess, a PATH child and an
env-shebang child with a deliberately wrong host Ruby behind the launcher.

RubyGems tests load the pinned source `lib/` on both sides, including children,
so repository-specific checks such as `Gem.prefix` inspect the tested source.
`bootstrap.rb` explicitly preloads the prerequisites that selected files rely
on from earlier whole-suite tests (Tempfile, tmpdir, FileUtils, delegate or
socket). Only the named files receive those prerequisites, equally per side.
RubyGems files also receive test-unit 3's unqualified `assert_raise` contract:
some exception must be raised, while explicit expected classes retain their
checks and pending/skipped tests still propagate. The ruby-core assertion
contract is unchanged for core files. This avoids reporting a missing Fiddle
symbol as a failure merely because the two assertion frameworks disagree on
an empty expected-class list.
This does not change test definitions, assertions or feature guards.

The reference archive also preserves its original build Makefile and static
Ruby library. After extraction, `prepare_reference.rb` validates those files,
the source headers and generated config header, then creates a small rbconfig
wrapper at the current checkout location. For reference-side `mkmf/` tests,
the wrapper changes only the build `topdir`, keeping the installed prefix and
interpreter paths. Source `lib/` supplies mkmf's matching build-tree behavior.
The load paths propagate to `assert_separately` children; the extra context is
not applied to mere-ruby or other test groups. The reference build job checks
both actual C compilation/linking and a test that starts a separate Ruby.

`test_data.json` pins nine Unicode/Emoji inputs, their versioned official URLs,
exact sizes and SHA-256 hashes. `test_data.py` downloads at most the declared
size plus one byte per input and verifies every restored file before use.
The set includes UnicodeData, CaseFolding, SpecialCasing, NormalizationTest,
GraphemeBreakTest and the four Emoji 17.0 inputs used by the pinned tests.
The runtime archive carries the entire set; every shard checks it against
the reference build provenance. The data policy is recorded independently
from case identities, so partial or older input sets cannot be mixed in.

The pinned RubyGems Cargo tests still call the upstream `exe/gem` entry point,
whereas Ruby stores it in `bin/gem`. Preparation copies the exact pinned
entry point to `exe/gem`, records its hash and verifies it on restoration.
No test definitions or assertions are changed.

Each file receives a fresh `GEM_TEST_TMPDIR` outside the Ruby checkout, avoiding
accidental membership in Ruby's Cargo workspace. Its `CARGO_HOME` is also fresh.
The reference job and every shard install Rust 1.85.0 and select its actual
toolchain binaries using `UNITTEST_RUST_BIN`; these work with an empty HOME
without inheriting rustup configuration or Cargo credentials. Both interpreters
receive the same toolchain. Actual cargo/rustc versions and data hashes are
recorded, and collection rejects mixed inputs.

The packaged Rake entry point is invoked explicitly with each side's selected
Ruby and Rake library directory. RubyGems tests reset GEM_HOME/GEM_PATH; falling
back to a host `rake` shebang could otherwise start an unrelated Ruby with
incompatible native extensions. The RakeBuilder tests are the exception: they
install and select their own good/bad Rake fixtures, so the worker leaves the
`rake` override unset for that file. Native children keep their own installed
gem paths; mere-ruby children receive the pure-Ruby gem libraries explicitly.

`environment_smoke.py` uses the normal process-family supervisor, a 300-second
wall limit and 2 GiB family RSS limit. It requires casefold, comprehensive
case mapping, grapheme, emoji and normalization tests to execute assertions
without failures/skips. Data-dependent suites must define multiple cases.
Additional checks cover native iter semantics, absolute backtrace paths,
short UNIX socket paths, standalone delegate, native marshal helpers, source
RubyGems require behavior and all extension-builder cases. Four Cargo smoke cases cover an
extension build, an expected build failure, and two gem install/load paths.
Sanitized logs and summaries are retained as `reference-environment-smoke`.
The full measurement still runs all nine Cargo tests. In the pinned upstream
`refute_ffi_handle`, `assert_raise` has no exception class: CRuby's test runner
rejects the expected `Fiddle::DLError`. That reference failure remains visible
in the full measurement; the environment smoke uses the four functional paths.

`reference_conditions.tsv` classifies all 26 reference ZERO files from the
macOS baseline. They require Windows (five), DTrace/SystemTap (12), a Solaris/
Linux-only extension (one), development ABI checks (one), an alternate parser
(two), DBM (two), OpenSSL::Engine (one), SHAPE_DEBUG (one), or are an intentional
empty sentinel (one). The merged `files.tsv` includes the condition and needed
configuration; the summary lists counts and newly unclassified ZERO files.
These rows stay ZERO and never count as passing. Alternate-platform/build
measurements must retain their own provenance instead of mixing into macOS.

`unittest/ci.py` partitions the manifest into eight shards with no overlapping files.
CI supplies `--timings unittest/timings.json`: the planner assigns the longest
observed files first to the lightest shard, with deterministic tie breaking.
The complete discovered inventory remains in `files`; schema 2 plans also save
explicit `partitions`. Execution and collection validate that every file occurs
exactly once. Old schema 1 round-robin plans remain readable.

Timing estimates only control placement. New files receive a 60-second estimate,
removed files are ignored, and a different upstream Ruby SHA discards the old
weights. None of these cases skips a file or reuses a test verdict. Invalid
negative, zero or non-finite estimates fail planning. The plan records the timing
file hash, coverage and estimated shard durations.

The CRuby matrix runs at most four macOS jobs at once. Each file runs sequentially:
each interpreter has a 600-second wall limit, and the tracked process family
has an aggregate RSS cap of 2 GiB, polled every 0.1 seconds. A worker also has
an outer wall limit of twice the per-side limit plus 60 seconds. Polling can
overshoot the RSS cap; it is a measurement bound, not a reservation. These bounds
differ from historical local sweeps and are recorded with each result.

### CI scheduling measurements

The [2026-11-06 baseline](https://github.com/284km/mere-ruby/actions/runs/42165539038)
ran 758 files in 64 macOS jobs. Those jobs consumed 221.0 runner-minutes:
179.9 minutes in the measurement steps and 41.1 minutes outside them. The median
per-job setup/teardown cost was 38 seconds. The median delay from job creation
to start was 139.4 minutes; this includes the workflow's concurrency limit and
runner availability, so it is not a direct measurement of provider capacity.

Repartitioning those observed per-file times into eight jobs gives approximately
22.2 minutes of supervised execution per job. Keeping measurement work constant
and using the observed median overhead projects 185.0 runner-minutes, about 16%
below the baseline. This is a replay estimate, not a measured wall-clock speedup;
other workflows and available macOS capacity still affect elapsed time. Four
shards save little additional setup time and leave fewer scheduling units when
durations change; sixteen double the setup count for little estimated balance
benefit. Eight keeps two waves at the existing four-job concurrency limit.

The snapshot includes six mere-ruby WALL_LIMIT files (fiber/test_io.rb,
openssl/test_ossl.rb, resolv/test_dns.rb, ruby/test_io_timeout.rb,
socket/test_tcp.rb and zlib/test_zlib.rb), totaling about 60 minutes. Their
600-second limits and incomplete-result reporting are retained. Runtime fixes
are needed to remove that work without changing the measurement budget.
That earlier reduction targeted repeated-job overhead; the subsequent build
caches described above also remove fixed compiler/reference build work.

The checked-in estimates now come from the [full run on 2026-11-18](https://github.com/284km/mere-ruby/actions/runs/44205107484)
at measurement source `3e95d2844498aac009ba76b3a9025f5bc21feb0f`, with Mere
`2e3cc433d470842a07c79cc50bd217441c889dc0`. All 758 files were collected from
eight shards. The observed supervised execution totals ranged from 727.4 to
1,582.4 seconds per shard with the previous weights. Replaying the same
observations with refreshed weights gives 1,132.2–1,133.3 seconds per shard.
This excludes setup, queueing and future runtime variation and is not an
observed end-to-end speedup. The run took about 313 minutes overall, with the
last CRuby shard starting about 290 minutes after dispatch; build separation
does not itself remove contention with other workflows. The report retains
49 incomplete or zero-test files. Successful collection is not Ruby conformance.

Successful collection writes `timings.json` into `unittest-report`, using the
observed per-file supervisor durations and exact source/compiler/Ruby refs.
To refresh the checked-in estimates, inspect a completed full report, copy that
file to `unittest/timings.json`, and add its `run_url`. Keep the originating refs:
these identify the observation, not the sources of the next measurement.
Missing/infrastructure-failed collections do not produce timing estimates.
Replan against the full inventory after updating the snapshot; weights may age
as mere-ruby improves, but they never reduce coverage.

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

Each interpreter has separate stdout/stderr, a saved exit status and an atomic
private case snapshot. The reference snapshot is committed before mere-ruby
starts. If the worker reaches a memory/wall limit, the collector reuses that
snapshot and parses bounded partial output from the interrupted side. Finished
reference cases remain in the totals and RED tags instead of becoming null
counts. Reference skips/failures remain non-passing; an interrupted mere-ruby
summary without a saved exit status does not establish a pass. Monitor failures
can retain already known cases while still failing infrastructure collection
and aborting the shard. A hard stop of the collector/VM can still leave the
current file NOT_RUN; this is not a recovery mechanism for a lost VM.

Both interpreters preload `case_encodings.rb` after Test::Unit. Its start/result
callbacks record the bytes and encoding of non-ASCII suite/method names in a
private, bounded sidecar. Canonical identities include the encoding, so UTF-8,
ASCII-8BIT and legacy encodings with identical bytes remain distinct. Error
callbacks also identify the failing case when human-readable report headers
are identical. ASCII names keep their existing identities. Encoding suffixes
use a reserved escaped marker that cannot alias literal method-name text.
`Symbol.inspect` alone cannot distinguish every Ruby encoding: parsing older
non-ASCII logs without this sidecar yields IDENTITY_AMBIGUOUS, never MATCH.
Invalid/truncated metadata yields PARSE_LIMIT. Metadata is not uploaded.

The parser reads at most 64 MiB per side in 64 KiB line chunks. A single name
is capped at 16 KiB, and a side retains at most 100,000 names totaling 4 MiB.
Parsing also has a 10-second processing deadline, checked between bounded
line chunks. Encoding metadata is limited to 16 MiB, with the same line/name
and processing-time bounds. Private snapshots are limited to 16 MiB when read back. This bounds recovery
after the worker's monitor has stopped, including unterminated diagnostic lines.
Budget exhaustion is PARSE_LIMIT, with the reason retained in result.json.
The parser policy and budgets are recorded in the shard/report, and results
from different case policies cannot be merged. Per-side summaries retain
assertions, failures, errors and skips in shard JSON as well as case counts.

Artifacts are retained for seven days:

| Artifact | Contents |
|---|---|
| `unittest-plan` | Exact candidate list, pinned revisions, partitions and scheduling estimates |
| `mere-ruby-macos` | O2 binary, build mode and compiler/source provenance |
| `native-build-macos` | Generated C, Prism archive and generated C API header for corpus/native verification |
| `ruby-reference-macos` | Installed reference, native test extensions and provenance |
| `unittest-shard-N` | Per-file results, bounds, peak family RSS and sanitized diagnostic logs |
| `unittest-report` | `SUMMARY.md`, `summary.json`, every planned file in `files.tsv`, and successful-run `timings.json` |

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
HOME and TMPDIR per file. The owning temporary directory uses a short private
path under `/tmp`, so test-generated UNIX socket names fit macOS's 104-byte
limit; it is reclaimed with the measurement context. Only PATH, locale, explicit interpreter/extension paths,
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

The binary hash, actual source commits, reference hash, prepared test data and
Rust toolchain must agree across
shards. This prevents combining a partial run, another compiler build or another
Ruby version into one measurement. Result files are artifacts; CI does not
commit a partial sweep over the checked-in historical records.

```sh
python3 unittest/ci_check.py -v
python3 unittest/transcript_check.py -v
python3 unittest/test_data_check.py -v
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
The transcript checks also compare peak RSS while recovering from 8/128 MiB
unterminated input. Collection tests stop real workers after the reference has
finished, including a mere-ruby fixture that prints an early summary and then
stalls, to verify retained RED counts and the absence of false matches.

## Classified baseline gaps

The [completed baseline](https://github.com/284km/mere-ruby/actions/runs/41571293365)
measured all 757 candidates, including 53 files whose reference state was not
COMPLETE and 325 whose mere-ruby state was INCOMPLETE. These are file counts;
the named-case verdicts also include shared cases and unreached tests.

[reference_gaps.tsv](reference_gaps.tsv) retains all 53 reference rows with
their conditions and next actions. The 25 startup failures comprise 16 mkmf
files needing the build context and nine files needing the test-root load
path. A reference-only local probe reached 176 cases and 570 assertions across
those 25 files: zero failures/errors and four skips. Its Makefile CC_WRAPPER
field was reconstructed from the real reference RbConfig for this local smoke;
the library and generated headers came from that reference artifact. CI uses
the original build Makefile and verifies the packaged context independently.

The remaining 28 rows include 26 zero-case configurations and two counting
inconsistencies. They require Windows/TTY, trace privileges and providers,
optional DBM/Engine/Shape/test-extension APIs, parser or development-build
conditions, and explicit treatment of an empty chkbuild helper. The inspected
name and inline-diagnostic counting problems are addressed by transcript.py;
Unicode test data remains an environment task. Cargo also needs isolated fixture directories
and a usable Rust environment. No candidate is removed or reported as passing
because it defined no cases.

[incomplete_causes.tsv](incomplete_causes.tsv) classifies every one of the 325
mere-ruby incomplete files using the baseline logs. In particular, 150 stop at
unimplemented OpenSSL::Cipher (all 149 RubyGems files plus bundled-gem tests),
63 at missing prism/prism, 64 at missing test-only extension APIs, and 17 at
missing RbConfig APIs. Eight more share the corrected test-root load-path
problem. Six files had started tests before terminating; their symptoms are
recorded separately from load failures. These rows are a dated baseline,
not new execution results. Their API gaps remain implementation work; the
runner changes do not substitute fake crypto/parser/test-extension results.

The original casefold and Cargo logs now identify 58 and nine cases respectively,
retaining their actual skips/failures/errors. Replaying the previous String and
Ractor memory-limit artifacts retains all 460 reference cases (458 RED and two
BOTH), rather than losing their totals. These are parser/recovery checks on
saved evidence, not new interpreter-conformance results. A fresh reference Rand
run also verifies all 41 cases before diagnostic address masking, which can
collapse hexadecimal seeds in archived human-readable labels.

## Known noise: results that move without the change

What follows moves between runs of the SAME code. Before reading a one-test
difference between two runs as a regression, check it against this list, and
run the file on both builds with `unittest/try.sh` (a regression reproduces
there; these do not). Each entry was seen on main as well as on a branch.

**Order-dependent tests.** They lean on a library an earlier test happened to
load, so the seed decides them; run alone they fail on main too.

| file | test | why |
|---|---|---|
| ruby/test_syntax.rb | test_return_toplevel, test_eval_return_toplevel | use Tempfile without requiring it |
| ruby/test_settracefunc.rb | test_single_raise_inside_load | uses FileUtils without requiring it |
| ruby/test_settracefunc.rb | test_tp_ractor_local_untargeted | fails alone on main as well |
| ruby/test_syntax.rb | test_invalid_symbol_in_hash_memory_leak | intermittent on main |
| ruby/test_thread.rb | test_handle_interrupt_with_return_and_trap_handler | intermittent (±1 between runs) |

`ruby/test_object.rb` and `ruby/test_object_id.rb` have also moved by one test
between CI runs of the same code; locally both builds agree.

**Timing at the edge of a bound on CI runners.** The bounds stay; a slow
runner crosses them.

- build-linux's Module check: its three leak tests (iclass 3,000,000,
  complemented 300,000, clone 1,000,000 times) take 4.3-6.7 s each of their
  10 s (`upstream_leak_seconds`), the whole file 21.7-27.0 s. Some runners
  are slower at everything: main e40bb486's run and PR #95's took 39.7 and
  39.9 s for the file (test_prepend_gc 1.50 s against 0.79-0.95), and
  complemented went to 10.04 s, a Timeout. Builds before and after PR #89
  take the same time locally (4.6-6.5 s). Rerun the job. The clone test lost
  a third of its time when Module#clone stopped walking the whole constant
  table (`const_owners`); ruby 4.0.9 takes 1.7 s (complemented), 2.7 s
  (iclass) and 0.35 s (clone) on the same Mac. The same Timeout reaches
  `ruby/test_module.rb` in the unittest shards too (PR #101's run: 10.12 s,
  the file one test lower). Rerun its shard.
- ...and the same test in `ruby/test_module.rb` itself is an RSS ratio
  (after 300,000 more refinement classes against after 1,000) bounded by
  2.0: 1.74-1.82 locally on main 392bf810 and on PR #89's branch alike, and
  2.30 once on a macOS runner (78.6 MB -> 180.5 MB, PR #89's last run), the
  run before it passing. Rerun its shard.
- The reference side moves too: ruby 4.0.9 itself failed
  `ruby/test_method.rb`'s `test_kwarg_eval_memory_leak` once on a macOS
  runner (RSS ratio 1.23 against its 1.2, PR #101's run), which lowers the
  file's MATCH by one without mere-ruby's result changing (`ref_exit` 1,
  EXTRA 1). Rerun its shard.
- `ruby/enc/test_case_comprehensive.rb` takes 360-400 s of its 600; one run
  took 616 s (WALL_LIMIT, all 422 tests RED) while the run's median file was
  at 0.98 of main's. Rerun its shard.
- bootstraptest test_ractor #153 (1,000 ractors) and #99 sit at the runner's
  limit.
- `ruby/test_integer.rb`'s `test_pow` runs 17 expressions in child
  processes of 10 s each, and `crash03` (`-1111111**-1111*11 - -11**
  -1111111`) takes 8.2 s of it locally on main and on a branch alike. A
  loaded runner times it out (PR #88's run, twice).
- `ruby/test_ractor.rb`'s `test_shareable_proc_define_method_super_method_
  missing` (1,000,000 calls in a Ractor) takes 17-18 s of its 30 s
  locally; a loaded runner timed it out once (PR #88).
- `ruby/test_struct.rb`'s `test_named_structs_are_not_rooted` (run for
  TopStruct and for SubStruct) compares the process's RSS after 10,000 and
  after 60,000 named Structs and wants less than twice. Locally the ratio is
  1.25-1.37 on main and on a branch alike; one CI run gave 2.29 for one of
  the two while the other passed in the same file.
- `assert_no_memory_leak` gives a child 10 s: `-ext-/string/test_nofree.rb`
  (`test_no_memory_leak`) takes 7.1-7.3 s on this machine, on main's build
  and on a branch alike, and one CI run of a branch whose runners were
  crowded took 10.10 s. `ruby/test_object.rb`'s `test_copied_ivar_memory_leak`
  is the same kind of test, and the same run timed it out.
- `ruby/test_ractor.rb`'s `test_move_nested_hash_during_gc_with_yjit` runs a
  child with a 10 s bound and takes 9.3-10.1 s on the runners, on main as
  well: one run in a few is a Timeout and the file is one test lower.
- Two more children with a 10 s bound, both moving between runs of the
  same tree (main 3eb24fef's run against PR #101's): `ruby/test_class.rb`'s
  `test_classext_memory_leak` took 8.83 s and then 10.11 s (Timeout), and
  `ruby/test_weakkeymap.rb`'s `test_clear_bug_20691` 10.09 s and then 9.12 s,
  the Timeout falling on the other run. ruby 4.0.9 takes 1.48 s and 0.30 s.
- `test_time.rb` (the library's, not `ruby/test_time.rb`) peaks at 1.74-1.84
  GB of its 2 GiB on the macOS runners, on main and on a branch alike; once
  it reached 2,150,352 KB in `test_rfc2822_nonlinear`, right after
  `test_huge_precision`, and came back MEMORY_LIMIT with all 42 tests RED
  (PR #102's first run). Locally main and that branch both peak at
  1,081,6xx KB in five runs each, and the shard's rerun gave 42 / 42.
  Rerun its shard.

**Jobs that never ran.** A `macos-26` job can wait without a runner and be
cancelled after 15-30 min (the job has no `runner_name`). A shard that reaches
its job timeout is cancelled the same way, and every file it held comes back
MISSING_SHARD: the totals drop by thousands and the comparison is meaningless.
`gh run rerun <run> --failed` reruns the cancelled and failed jobs;
`gh run rerun <run> --job <job-id>` one of them. To find the shard that holds a
file, search the shard jobs' logs (`gh api --allow-escape-sequences
repos/<owner>/<repo>/actions/jobs/<id>/logs`).

**A local run that is not CI's.** These make a test fail locally that passes
in CI; `unittest/try.sh` sets all of them.

- rubygems/* need the ruby source tree's `lib/` first on RUBYLIB (`Gem.prefix`,
  the default gem specs).
- The binary must be named `mere-ruby`: a bin wrapper's shebang is read back
  only if it mentions "ruby".
- The corpus needs `LANG=en_US.UTF-8` (corpus/492 reads ENV keys under the
  locale's encoding).
