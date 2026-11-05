# Bootstrap measurement

CI's bootstrap report runs every `bootstraptest/test_*.rb` from the pinned Ruby
source through that source's original bootstrap runner. The driver is the
exact native reference Ruby; its `--ruby` target is either that reference or
the O2 mere-ruby measurement binary. The upstream assertion methods evaluate
equality, matching, syntax, exit and finish conditions. No assertion kind is
replaced by a no-op.

`audit_runner.rb` adds discovery, start and finish records around the native
runner. Its child wrapper records an explicit `BT_Skip` without changing the
original result text or line count. An expected skip message remains SKIP.
Case identities use source location and occurrence, so loops that generate
multiple assertions on one line remain distinct. A digest of generated code
is also recorded; driver PIDs or paths inside it do not create false test-name
differences. Both native drivers use the same source-discovery random seed.

Each side is bounded to 600 seconds per source file and a 2 GiB process family.
The upstream assertion-specific timeout also applies. A missing final event,
malformed ledger, interrupted file or inconsistent count never promotes
progress into passing cases. Ledgers are bounded to 100,000 assertions and
16 MiB. Diagnostic logs use the existing bounded sanitizer.

The plan, reference commit, compiler commit, O2 binary digests, harness digests
and limits travel with each shard. Collection checks all planned files and
shards, duplicate rows, unchanged provenance and missing reference results.
Behavior differences are measurement results. Missing inputs, infrastructure
errors and reference gaps fail collection.

Artifacts:

- `unittest-plan/bootstrap.json`: complete bootstrap source manifest and shards.
- `unittest-plan/suites.json`: static inventory of the broader Ruby suites,
  helper candidates and pending measurement entry points. File counts are not
  executed case counts.
- `bootstrap-shard-*`: native and Mere case ledgers, sanitized diagnostics,
  completion states and case comparison counts.
- `bootstrap-report`: collected JSON and Markdown report. MATCH/RED/BOTH/EXTRA
  have the same meaning as the unittest report; skips are never passes.

`all.sh`, `extract.rb`, `run.sh` and `triage.sh` retain the older `assert_equal`
pair workflow for existing investigations. It is a subset and its totals must
not be used as a complete bootstrap measurement. The native-runner path does
not depend on successful extraction and cannot silently discard a failed load.

Run the collector locally using the same plan and binary provenance artifacts
as CI:

```sh
python3 bootstraptest/measure.py run --ruby-src .ruby-tests \
  --plan measurement-plan/bootstrap.json --build-info build-info.json \
  --reference-info reference-build.json --binary mere-ruby \
  --reference .reference-ruby/bin/ruby --shard 0 --output bootstrap-measurement/shard-0
python3 bootstraptest/measure.py merge --plan measurement-plan/bootstrap.json \
  --input bootstrap-measurement --output bootstrap-report
```
