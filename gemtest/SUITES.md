# Original upstream gem tests

`suites.py` runs each locked upstream test file under Ruby 4.0.9 and an O2
mere-ruby build. It does not modify the original tests or helpers. The first
five suites are minitest 5.25.5, rack 3.2.0, rack-test 2.2.0, public_suffix
6.0.2 and base64 0.2.0 (62 files). These are independent of the load-only
snapshot in `snapshot.lock.json`.

`suites_additional.lock.json` adds Matrix 0.4.3 and Logger 1.6.0 separately:
seven original files and 169 reference tests. It pins their release commits
and the actual pure Ruby test-unit 3.7.8, test-unit-ruby-core 1.0.16 and
power_assert 3.1.0 archives. It uses the same restore/measure commands with
`--lock gemtest/suites_additional.lock.json` and a separate external cache.
Keep the original 62-file lock and both original OS baselines unchanged.
The first audited macOS record is 6 MATCH / 1 RED, preserved in
`suites_additional_initial.json`; `suites_additional_latest.json` is its
strict macOS baseline. Hosted Linux run 44269323039 also reports 6 MATCH /
1 RED, with all seven reference files healthy and both sides audited.
`suites_additional_linux_initial.json` preserves that first observation;
`suites_additional_linux.json` is the strict Linux baseline. The separate
additional CI jobs now enforce their own OS's baseline under the same caps.

`suites_rake.lock.json` adds Rake 13.2.1 at release commit
`d84f6ef7f3540a1d0e95fabe451ea3a16157791b`: all 46 original test files,
597 reference tests and 1,459 assertions. Its four pure Ruby dependencies
are the three Test::Unit packages above and Minitest 5.25.5, which Rake's
functional tests require in generated child tests. Use a third external cache
with the same commands and `--lock gemtest/suites_rake.lock.json`.
The first complete macOS observation is `suites_rake_initial.json` (verbose);
`suites_rake_latest.json` is a strict repeat with normal output. Both report
46 MATCH with both sides' physical source audits complete. Preparatory 40/6
and 45/1 measurements had incomplete child environments and are explicitly
not baselines; their reasons remain in `suites_rake_preparation.json`.
Hosted Linux run 44288206768 also gives 46 MATCH with all 92 source audits
complete. `suites_rake_linux_initial.json` preserves that first observation;
`suites_rake_linux.json` is the strict Linux baseline. The independent Rake
workflow requires the matching OS baseline on every PR/main/dispatch run.
The same first hosted run completes macOS at 46 MATCH too; the latest macOS
snapshot retains this normal-output observation and its zero-regression
comparison with the preceding complete local baseline.

These gems use their unmodified helper and actual Test::Unit framework,
with alphabetical order instead of a Minitest seed. Preserve tests,
assertions, failures, errors, pendings, omissions and notifications; pending
plus omitted tests count as skips when rejecting an all-skipped summary.
Every summary field must match. Each side routes bare `ruby` children through
the existing child-bin selector to the selected interpreter and propagates
the locked libraries. A real child-process control rejects a shadow Ruby
on PATH, a missing locked child library or a missing child stdlib fallback.
Child RUBYLIB retains each selected runtime's actual own paths before the
pinned Ruby-source fallback, after the locked gem libraries. Ten controls pass.

The additional jobs also run `tools/method_copy_memory_check.py`: actual
UnboundMethod definitions on 21,000 transient classes, with three collections
after each batch. It records real process RSS and applies the pinned upstream
leak assertion's default 2x bound to every collected prefix. Its outer family
limits stay 600 seconds / 2 GiB. Separate `method-copy-memory-*` artifacts
preserve the samples and execution records. The source, clone/import and
native-boundary warning controls are in corpus 701/702.
`method_copy_lifetime_latest.json` retains the subsequent strict Linux failure
and paired measurements of publishing each copied metadata row once. The
check, workload and limits are unchanged; local Linux/aarch64 is identified
separately from hosted x86-64. Final hosted validation of that change is pending.

`suites.lock.json` records each release tag's full commit, repository URL,
source tree SHA256, every test file, load paths and command. Development
dependencies have exact versions, archive URLs and SHA256s, and extracted
tree SHA256s. Restoring validates the entire runtime dependency closure and
rejects native extensions. Sources and installed dependencies belong outside
this repository. Nothing is resolved against the user's installed gems.

```sh
python3 gemtest/suites.py restore --cache /path/to/suite-cache \
  --reference /path/to/ruby-4.0.9/bin/ruby
python3 gemtest/suites.py measure --cache /path/to/suite-cache \
  --reference /path/to/ruby-4.0.9/bin/ruby --binary ./mere-ruby \
  --ruby-src /path/to/ruby-source-3e93b23 --output /tmp/gem-suites-new \
  --baseline gemtest/suites_latest.json
```

Only `restore` retrieves sources. `measure` uses the verified cache offline,
checks it before and after the run, and refuses a changed binary or lock.
The pinned Ruby source provides RubyGems and standard-library fallbacks; its
`tool/lib` also supplies base64's original Test::Unit framework. Both sides
use seed 1, an isolated gem home and the same explicit library paths. Each
file and side gets a separate temporary source copy, so tests can write their
fixtures without influencing the other interpreter or subsequent files.

`suite_bootstrap.rb` appends the Ruby-source fallback after the interpreter's
own standard library. Locked gem libraries remain first. After the upstream
autorunner finishes, it records the physical files loaded from that gem's
locked `lib` directory in `<side>.source.txt`. The measurement retains these
relative names and requires a nonempty audit as well as successful tests.
An early `exit!` cannot bypass the audit and produce MATCH.

The source audit corrected an earlier provenance gap: Mere had selected its
bundled Base64 implementation before the explicitly supplied release source.
The old result established that the release tests passed, but did not verify
the release library. `suites_before_source_audit.json` preserves that result;
`suites_source_audit_transition.json` records the explicit protocol transition.
Only command descriptions change in the lock; source SHAs, dependency digests,
test inventory and limits are unchanged. The full new run is compared with the
old snapshot using the ordinary per-file comparison, with zero regressions.
The CLI still rejects a baseline whose lock digest differs. Subsequent runs
use the audited `suites_latest.json` and the new lock normally.

The existing CI process-family supervisor applies **600 seconds and 2 GiB
per side per file**, including descendants. No command-line option relaxes
these limits. Raw stdout and stderr are separate, with exit status, limit,
peak family RSS, elapsed time and original test summary in `results.json`.
Logs live under `<gem>/<test-file>/<reference|mere>.stdout` and `.stderr`.
Use a fresh output directory. `--gem NAME` and `--file PATH` select individual
files for diagnosis; baseline comparisons require the full file inventory.
Add `--verbose` to record the upstream runner's individual test names while
diagnosing a resource limit; the default seed, bounds and verdicts stay the same.

| Verdict | Meaning |
|---|---|
| MATCH | Both exit successfully, execute non-skipped tests and assertions, and have identical test summaries. |
| RED | The reference is healthy; mere-ruby fails, stops early, or reports a different summary. |
| BOTH | The reference fails or has no usable nonempty summary. Both sides are still measured. |
| TIMEOUT | Either process family reaches 600 seconds. |
| MEMORY | Either process family exceeds 2 GiB. |

These are **file verdicts**, not individual test-case verdicts. Assertion
counts are retained and compared: rack-test's UploadedFile file passes on both
interpreters but reports different assertion counts because it enumerates
Tempfile's public methods. It remains RED as a visible reflection difference.
Zero tests, all skips and exit 0 without a summary never become MATCH.
Resource limits take precedence over BOTH; each side's record identifies
which limit fired. The complete raw logs remain authoritative when diagnosing
an early exit or a missing summary.

CI runs in separate Linux and macOS jobs without extending existing jobs.
Linux uses Ubuntu 24.04, the successful main baseline's reference environment.
Ubuntu 26.04's GCC-built Ruby fuses Float#step multiply/add operations; the
current x86-64 implementation evaluates them separately. That numeric
portability gap remains open, rather than weakening the bit-parity check.
`actions/cache` stores the exact locked sources and dependencies, which are
verified even on cache hits. A baseline rejects missing files, lost MATCH
files, changed reference counts and a newly unhealthy reference. The CLI
rejects a baseline from another OS. Linux uses `suites_linux.json`; macOS
uses `suites_latest.json`. The two interpreters must agree within each run.
CI artifacts preserve
the complete measurements and logs. `suites_check.py` includes negative
controls for zero tests, early exits, missing files, reference failures,
resource classification, and source mutation or shadow files.
The seventh control runs real Ruby to reject a healthy-looking summary from
the wrong source tree and a process that bypasses the audit with `exit!`.
The eighth rejects wrong-platform and wrong-lock baselines and verifies that
a previously matching file reaching the RSS cap is still a regression.

The Linux baseline comes from hosted run 44248949546, with 52 MATCH /
9 RED / 1 MEMORY. Its ordinary per-file comparison with this PR's earlier
Linux run 43989409595 has no regressions. Both runs exceed 2 GiB in Rack's
multipart file. `suites_linux_before_source_audit.json` preserves the earlier
result; `suites_linux_transition.json` records the unchanged source/dependency
inventory, command-only audit transition and exact comparison. The original
gate error against macOS's 53-MATCH snapshot is preserved in the new Linux
record. No file verdict, test count or limit is changed. The macOS baseline
retains all 53 MATCH files, including multipart; a later macOS loss must fail.

Kramdown 2.5.1 was measured before choosing this set. Its large conversion
file needs an external tidy executable plus optional Rouge and stringex; the
reference had 19 failures and 11 errors. Its source and reason are recorded
under `exclusions` in the lock. It is deferred rather than patching its tests
or silently dropping conversion cases. TZInfo and i18n were inspected as
possible next suites; both need a separately locked Bundler environment.

Remaining runtime differences and their ownership are in
[SUITES_GAPS.md](SUITES_GAPS.md). The interpreter changes for the first batch
are limited to `pct_strict_value` and `cls_meth_own`, with corpus witnesses
667 and 668. No VM, AST tree, C API or collector implementation is changed.

Follow-up rounds 4-5 fix gzip output replay after a destination raises and
StringIO backing state leaking into Ruby-visible ivars and YAML. With the
same 62 files and lock, the latest record is 50 MATCH / 11 RED / 1 MEMORY,
up from 48 MATCH / 13 RED / 1 MEMORY in the first PR. The original initial
record stays unchanged. These changes are in the Ruby libraries and their
generated embedded copies, with witnesses 671 and 672; the full CRuby zlib
and StringIO tests report 96/96 and 103/103 MATCH respectively.

Rounds 6-7 respect block-bearing File overrides and defer Chain grouping
until iteration. The same inventory now gives 51 MATCH / 10 RED / 1 MEMORY;
minitest's original reporter becomes MATCH (22 tests / 52 assertions).
Witnesses 676 and 677 cover restoring native File aliases, keyword/block
forwarding, deferred predicates and early termination of infinite inputs.
Only `invoke_with_block0` and `core_prelude_b` change in these rounds.

Rounds 8-9 match rescue candidates in order and retain a Hash subclass's
default block passed to super. Rack's original utils file becomes MATCH
(63 tests / 285 assertions). The unchanged 62-file inventory now gives
52 MATCH / 9 RED / 1 MEMORY, with no BOTH, TIMEOUT or baseline regression.
Witnesses 678 and 679 cover candidate evaluation/conversion, Module#===,
Proc identity, lambda arity, preserved entries, argument errors and freezing.
Corpus reports 699/699 MATCH; bracket depth remains 895/1024.

Rounds 10-11 honor singleton undef on primitive values and let name overrides
reach Module#name through super. Rack Lint becomes MATCH (37 tests / 763
assertions). Minitest spec and Rack headers now reach summaries with visible
remaining failures. Request's newly reached 16 MiB NUL case crosses the
unchanged 2 GiB cap. The same inventory gives **53 MATCH / 7 RED / 2 MEMORY**,
zero BOTH/TIMEOUT and no lost MATCH. Round 10 alone was 53 / 8 / 1; the RED
to MEMORY transition is not counted as an improvement. Witnesses 681/682 and
all 701 corpus programs match Ruby. Bracket depth is 892/1024 after the incoming
main C API merge. Paired CRuby Method and Module controls equal latest main:
97 MATCH / 1 RED and 195/195 MATCH respectively.

The round 10-11 review follow-up retains native Method/UnboundMethod and alias
definitions across singleton undef, without leaking the one-dispatch bypass
into Ruby callbacks, coercion defaults or string eval. Module#name super now
requires the native Module entry to remain ahead of the actual method origin.
Expanded witnesses 681/682 match normally and under GC.stress. Fresh O2 source
a3ad911a keeps **53 MATCH / 7 RED / 2 MEMORY**, zero regressions and corpus
**701/701**. Method, Module, TracePoint, Proc, Super and Yield retain their
paired baseline MATCH counts. The initial snapshot and resource bounds stay
unchanged; hosted per-file merge checks remain pending.

Rounds 12-13 dispatch genuinely missing primitive names to their singleton's
Ruby method_missing and leave do...end on the outer command when its argument
is another dotted command. Minitest spec's errors fall from four to zero and
Minitest test's from one to zero; both files retain their other failures.
Fresh O2 source 61d57736 keeps the full-file totals at **53 MATCH / 7 RED /
2 MEMORY**, zero BOTH/TIMEOUT/regressions. Corpus is **703/703**. Witnesses
683/684 match normally and under GC.stress, and related Method/Super/Yield/
Parse/Syntax controls retain their baseline counts. Original files, sources,
dependencies, the initial snapshot and all resource bounds stay unchanged.
