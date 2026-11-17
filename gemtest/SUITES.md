# Original upstream gem tests

`suites.py` runs each locked upstream test file under Ruby 4.0.9 and an O2
mere-ruby build. It does not modify the original tests or helpers. The first
five suites are minitest 5.25.5, rack 3.2.0, rack-test 2.2.0, public_suffix
6.0.2 and base64 0.2.0 (62 files). These are independent of the load-only
snapshot in `snapshot.lock.json`.

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
The pinned Ruby source provides RubyGems and the standard library; its
`tool/lib` also supplies base64's original Test::Unit framework. Both sides
use seed 1, an isolated gem home and the same explicit library paths. Each
file and side gets a separate temporary source copy, so tests can write their
fixtures without influencing the other interpreter or subsequent files.

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
files and a newly unhealthy reference. On the same OS it also rejects changed
reference counts. Across operating systems platform guards may differ, while
the two interpreters must still agree within that run. CI artifacts preserve
the complete measurements and logs. `suites_check.py` includes negative
controls for zero tests, early exits, missing files, reference failures,
resource classification, and source mutation or shadow files.

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
