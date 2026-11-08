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
