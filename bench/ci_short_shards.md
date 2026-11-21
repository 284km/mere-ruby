# Fewer short macOS measurement jobs

Measured on 2026-11-08 using the complete `bootstrap-report`, `tool-report`
and job metadata from [CI run 42444684594](https://github.com/284km/mere-ruby/actions/runs/42444684594).
The report source is `87551c3de8f2df7f82dffb7af79b7ea8e2fbb205`, with
Mere `991f299b20f18639713685fe3297e087ddc5b1d7` and Ruby
`3e93b23afcec3433f6aecc34b5d832799d754238`.

Short measurements still need a runner allocation, checkout, artifact downloads,
runtime extraction and artifact upload. In this run, the eight bootstrap jobs
took 54–289 seconds each and the four tool jobs took 28–68 seconds each, excluding
queue time. Across all files, the recorded reference-plus-candidate execution
times sum to 886.148 seconds for bootstrap and 72.424 seconds for tool tests.

| Work | Previous jobs | New jobs | Inputs retained |
|---|---:|---:|---:|
| Bootstrap | 8 | 4 | 35 files, including comment-only KNOWNBUGS.rb |
| Tool | 4 | 1 | 12 files |
| Complete workflow | 29 | 22 | Same test inventory |
| macOS portion | 23 | 16 | Same test inventory |

The existing deterministic file partitioning and report collectors are unchanged.
Bootstrap still permits two concurrent shards. The eight longer CRuby shards
retain their existing partitioning and concurrency.

Repartitioning the recorded per-file execution times gives bootstrap totals of
200.462, 142.126, 260.241 and 283.319 seconds. The single tool partition totals
72.424 seconds. These are projections from an earlier run, not measurements of
the new jobs. Runner contention and queue ordering prevent a reliable prediction
of end-to-end elapsed time; CI must establish that separately. The immediate
reduction is seven runner allocations and seven copies of the setup/upload work.

Each reference and candidate file retains its 600-second wall limit and 2 GiB
process-family memory limit. Outer job deadlines become 210 minutes for bootstrap
and 270 minutes for tool tests: respectively 9 or 12 files × 2 sides × 10 minutes,
plus 30 minutes for setup and upload. This lets the collectors retain per-file
limit findings even when several files reach their bounds. These are failure
ceilings, not expected runtimes, and will need revisiting if the pinned inventory
grows. Compatibility failures and incomplete files remain visible.

## Validation

- A fresh four-shard plan from the pinned Ruby source preserves all 35 input
  paths, source digests and the comment-only KNOWNBUGS sentinel.
- Replaying the real report rows through the existing collectors with four
  bootstrap shards and one tool shard preserves every row and verdict: bootstrap
  2,044 counted cases (1,921 MATCH, 117 RED, 5 BOTH, 1 EXTRA); tool 205 counted
  cases (189 MATCH, 5 RED, 11 BOTH, 0 EXTRA). This checks collection and does not
  claim those compatibility failures are fixed or that tests were re-executed.
- Removing a shard makes collection fail for both suites.
- The existing bootstrap harness checks (14 tests) and tool harness checks
  (7 tests) pass, including the real pinned upstream runners, with no skips.
- Workflow YAML parses successfully and its matrices match the selected counts.

To inspect the source measurements, download `bootstrap-report` and `tool-report`
from the linked run. In each `summary.json`, use the manifest's file order
(`manifest.files` for bootstrap, `files` for tool), take every Nth file for each
partition, and sum `rows[*].reference.execution.seconds` plus
`rows[*].mere.execution.seconds`. Report row order is not the partition order.

## Bootstrap placement refresh, 2026-11-18

The [complete report from run 44205107484](https://github.com/284km/mere-ruby/actions/runs/44205107484)
contains the same 35 bootstrap inputs and four shards. Its measured source is
`3e95d2844498aac009ba76b3a9025f5bc21feb0f`, with Mere
`2e3cc433d470842a07c79cc50bd217441c889dc0` and the same Ruby source SHA above.

| Partition | Previous execution seconds | Weighted replay seconds | Files after replay |
|---|---:|---:|---:|
| 0 | 134.1 | 365.9 | 9 |
| 1 | 202.1 | 365.8 | 9 |
| 2 | 518.4 | 365.2 | 8 |
| 3 | 606.3 | 364.0 | 9 |

Longest-first placement retains at most nine files per shard, so the original
210-minute job deadline still accommodates both 600-second interpreter sides
per file plus setup/upload. Jobs and concurrency remain four and two.
These are sums of previous observations, excluding queueing and setup; the
roughly 40% reduction in the longest partition is not an end-to-end CI result.

A fresh weighted plan against the pinned Ruby checkout preserves all input
paths, source hashes and the comment-only sentinel. Replaying the original
rows through the updated collector preserves all 2,044 counted cases:
2,014 MATCH, 24 RED, 5 BOTH and 1 EXTRA. No test was re-executed by that replay.
Schema 1 plans still use round-robin placement; schema 2 workers and collectors
share the same validated explicit partitions. Successful collection emits new
placement estimates with exact revision provenance.

## Enumerator profile, 2026-11-18

In that CI run, the gap between the preceding corpus completion and
`214_an_enumerator_stepped_one_element_at_a_time.rb` was 326.7 seconds on macOS
and 193.5 seconds on Linux. Each interval includes the reference and both
hash-index modes of mere-ruby. The whole macOS corpus step took about 14 minutes.

The downloaded macOS O2 artifact has SHA-256
`c32a4c6c7ec90d787347b491ae14d240559544ad6528c34d7c3d6d0e35aa5643`
and the measured source/compiler revisions above. On a local arm64 macOS 26.7.1
host, one complete execution of corpus/214 took 99.998 seconds and its output
matched Ruby 4.0.9 byte for byte. A three-second `sample` during its final
9,000-generator loop found captured-environment return/compaction on 512 of
529 active-thread samples. The paths went through `blk_env_put`,
`mere_map_str_Val_compact`, `__lang_coro_pins` and `__lang_pin_gather`, with
stack-word traversal and live-allocation span rebuilding/sorting underneath.
This short sample describes that phase, not a whole-run percentage.

`bench/enumerator_steps.rb` isolates that loop and verifies that a retained
generator survives across it. One fresh process per count, including startup:

| Generators | Ruby 4.0.9 seconds | Pinned O2 mere-ruby seconds |
|---:|---:|---:|
| 1,000 | 0.098 | 1.006 |
| 2,000 | 0.067 | 4.553 |
| 4,000 | 0.079 | 17.802 |

Every process printed the requested count between `:kept1` and `:kept2`.
Doubling this workload roughly quadruples the measured interpreter time,
consistent with growing pin/compaction work. These are single local observations,
not repeated benchmark medians. They identify the next optimization target;
this change preserves the runtime's reachability and pinning checks.

To reproduce with the same artifact, download `mere-ruby-macos` from the linked
run, verify its binary hash against `build-info.json`, restore its execute bit,
and run the benchmark with each count under that binary and Ruby 4.0.9. For
the complete test, compare corpus/214's stdout byte for byte, then use
`sample <pid> 3 5 -file <profile>` while its generator loop is running. The
relevant compaction call is in `m_state.mere`; the pin and allocation-span
implementation is emitted by Mere's pinned `lib/codegen_c.ml`.
