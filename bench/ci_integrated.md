# Combined CI validation

This validation branch combines three proposed changes from GitHub main
`12ca1df237aacb24f1bb516b848762e2a4a6110a`:

| PR | Exact imported head | Change |
|---|---|---|
| [#105](https://github.com/284km/mere-ruby/pull/105) | `e7574297d8a0ac7e51356167173a7f399c2c193b` | Publish the O2 build before verification, compiler/reference caches, two embedding builds, CRuby timing weights |
| [#106](https://github.com/284km/mere-ruby/pull/106) | `244ca028f18bc5e3b1d9ba143078081a262c20fb` | Weighted bootstrap placement and Enumerator workload |
| [#108](https://github.com/284km/mere-ruby/pull/108) | `dc1c4f2c91e10e0edd01b5dd3bd212f6d56558f5` | Published compiler `01f5ad738748cc570cc04e3000f50b8c6965543f` and coroutine scan improvements |

Merge conflicts were confined to additions in `bench/README.md`; both the
embedding and Enumerator explanations are retained. Interpreter and C API
sources are identical to #108. This branch is an integration experiment,
not a measured end-to-end speedup claim.

## Timing collection

`CI timing report` waits for every other job and runs even after failures.
It needs only `actions: read` and `contents: read`. It records raw API data,
JSON summaries and Markdown under the `ci-timing-<attempt>` artifact and in
the job summary. The reporter itself is excluded from work-job totals.

The report separates three timestamps:

- Run creation → job creation: includes dependencies and planning.
- Job creation → actual start: includes matrix/concurrency throttling and
  runner availability; it cannot attribute all delay to runner capacity alone.
- Actual start → completion: execution wall time, including setup and cleanup.

Queued jobs can have a placeholder `started_at` equal to `created_at`; the
collector never treats that as execution. Cancelled-before-start and skipped
jobs also do not acquire invented execution time. Active-job durations are
marked as elapsed observations. Missing timestamps remain unknown; negative
intervals and incomplete pagination fail the report with an error artifact.
An exception is a completed execution carried forward into a later rerun:
GitHub can create its new record after its original completion. The report
keeps the raw timestamps and attempt, marks start delay unavailable with
`execution_precedes_rerun_record`, and retains the real execution duration.
Run attempts are explicitly pinned, so a later rerun cannot replace the
current reporter's measurements.

Parallel job durations and waits overlap: their sums are not workflow elapsed
time. Job boundaries, source/compiler revisions and cache state also differ
between the baseline and candidate. Failed/incomplete runs remain visible;
they cannot establish an overall speedup.

For an immediate local snapshot:

```sh
python3 tools/ci_timing.py --repository 284km/mere-ruby \
  --run-id RUN_ID --run-attempt ATTEMPT --baseline-run-id 44239745755 \
  --output /tmp/mere-ci-timing
```

The validation workflow defaults its baseline to the existing main run
[44239745755](https://github.com/284km/mere-ruby/actions/runs/44239745755).
`workflow_dispatch` can override it with `timing_baseline_run_id`.

## Baseline observation

A real API snapshot at `2026-11-18T11:22:15Z` shows:

| Job | Creation → start/observation | Execution |
|---|---:|---:|
| basic-measurement | 184.12 min | 44 sec |
| CRuby tests / shard 0 | 324.75 min, still queued | Not started |

The baseline was incomplete and already contained a failed Linux job. This
establishes substantial scheduling delay, not a complete before/after ratio.
The selected rows are preserved in [ci_timing_baseline.json](ci_timing_baseline.json).

## Local validation

- All 162 existing CI harness checks and the 15 timing checks pass with pinned
  Ruby 4.0.9 runners, with no skips.
- A real plan preserves 758 CRuby files exactly once across eight shards and
  35 bootstrap inputs exactly once across four shards (9/9/8/9 files).
- Placement projections remain 1,132–1,133 seconds per CRuby shard and
  364–366 seconds per bootstrap shard. These are historical replay weights,
  not hosted measurements of this integration.
- Workflow actionlint, composite-action YAML and `git diff --check` pass.
- With the final compiler, the real normal and combined-fault O2 embedding
  builds pass all lifecycle and ownership cases. Their header bytes/recipe
  identities match; the fault build emits no second header. Retained-state
  and allocation checks, archive creation and both packaged-consumer modes
  pass. The normal C/archive contain no injection selector and packaging
  the actual fault fixture is refused.

Actual hosted cache hits, build/verification timing and measurement-job
completion are recorded by the integration run. Linux execution and the
full macOS measurement suite still require the hosted run.
