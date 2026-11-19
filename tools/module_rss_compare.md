# Original Module memory-test comparison

This investigation compares locked main `3b05689f` and PR #90 `949e4638`,
both built normally with the same pinned CI compiler `01f5ad73`. It addresses
`TestModule#test_complemented_method_entry_memory_leak`, not the separate
Method-copy workload.

Build both checkouts before measuring; use separate checkouts for the driver
and the two locked sources. Then run:

```sh
LANG=en_US.UTF-8 python3 tools/module_rss_compare.py \
  --baseline /path/to/main/mere-ruby \
  --candidate /path/to/pr90/mere-ruby \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --ruby-src /path/to/ruby-source-3e93b23 \
  --compiler-root /path/to/mere-01f5ad73 \
  --output /path/to/cache/module-rss-comparison
```

The runner first executes the complete original 195-test file on reference,
main and PR #90, sequentially. It then selects the original complemented-entry
test on each side, adding a parent-only observer. The observer copies the
child input and reports the child's original START/FINAL measurements without
changing the input, arguments, return value or upstream ten-second timeout.
Only the random upstream PID/time/hex tokens are normalized when comparing
input hashes; raw input and logs remain intact.

All six measurements retain their raw logs, exit/limit state, case dictionaries,
source/binary hashes and actual statuses. Each main/candidate dictionary must
match the reference within its mode; missing/extra cases and differing verdicts
are recorded and fail acceptance even when aggregate counts agree. They must
complete with no failures,
errors or skips: 195 tests / 1,240 assertions for each full file, and one test /
three assertions for each selected case. Missing child measurements, different
canonical inputs, or a ratio not strictly below 2.0 fail the comparison. Each
execution keeps the existing 600-second / 2-GiB process-family bound.

The Linux workflow builds both sources and uses the same runner for all sides;
it is a separate job and extends no existing job. Failed observations are kept.
An original selected case is diagnostic evidence, not a substitute for the full
file. A successful local observation does not waive a hosted failure, establish
its root cause, or prove a memory repair. The unrelated Method-copy control and
GC/allocator release policy are unchanged.

`python3 tools/module_rss_compare_check.py -v` replays captured reference
transcripts through the real CLI parser and acceptance path. Its controls
substitute a case identity while retaining COMPLETE state and all aggregate
counts, in both full-file and selected-case modes. Source/build checks and
process execution are fixtures; these replays are not runtime measurements.
