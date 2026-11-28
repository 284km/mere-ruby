# The Method-copy check compares the second half with the first

`tools/method_copy_memory_check.py` makes 1,000 classes in each batch, gives each of them 20 Method copies, lets them go, collects, and samples RSS. It held max(every batch) / batch 0 to 2.0, core_assertions.rb's leak bound.

On Linux in CI that ratio varied from 1.61 to 2.14 with no leak:

- main: 1.77 to 1.84;
- other branches: 1.61 to 2.14;
- #373: failed at 2.005 (its previous run was 1.80);
- rails-ar-slab-compact: failed at 2.139.

## Why it varied

Every sample of five runs on Linux (arm64, in docker, main 491cc5ca), in MB. All ten runs had the same shape:

    evaluator  92 108 102 112 123 134 141 149 159 174 142 149 164 139 143 150 159 137 144 150 169
    VM         74  88  92  99 109 119 123 135 140 119 132 124 131 139 148 119 126 132 143 120 126
    ruby       14  14  14  14  14  14  14  14  14  14  14  14  14  14  14  14  14  14  14  14  14

- RSS climbs for about eight batches and then saws between 120 and 175 MB, without growing.
- Batch 0 is taken after one warm-up batch, below that climb. So the ratio counted the climb and wherever the highest tooth fell: 1.64 to 1.75 on the evaluator, and 1.90 to 2.42 on the VM.

`MERE_RUBY_GC_TIGHT=1` did not steady it. It lowered batch 0 from 95 MB to 80 MB, and the ratio rose to 1.97 to 2.07. The program draws no random numbers, so there is no seed to fix.

## The change

- 30 batches.
- The peak of batches 21 to 30 is divided by the peak of batches 6 to 15. A leak grows from one half to the other, while the climb and the sawing do not.
- The median of three runs is taken.
- The limit is 1.3, where it was 2.0. The limit is on a different ratio now, and 1.3 is where the numbers below put it.
- `--leak-every N` keeps every Nth class in a global Array. It is a negative control: the check must fail with it. It does not run in CI.

One run of the check, both sides, takes 25 s on Linux, where it took about 6. The wall limit is per run, so the worst case is six runs of 600 s each.

### The check as it was, kept (review, Major)

Other tools read the old program and the old result:

- `rss_native_probe.py` imports `PROGRAM` and pins its SHA-256 and its 21 samples.
- `method_copy_retention.py` imports it and asks for one `20.times do |batch|`.
- `cache_compiler_compare.py` runs the check and prints each side's `post_gc_peak_to_initial`. The Cache compiler RSS comparison workflow runs it when this file changes.
- `iclass_resource_replay.py` reads the same field. `iclass_resource_assess.py` reads `samples_kb`, `execution` and the old bounds.

So `PROGRAM` is the 20-batch program, byte for byte: its SHA-256 is still 9bb9dd80…, which `rss_native_probe.py` pins. The new one is `HALVES_PROGRAM`, and its result has new fields (`runs`, `median`, `second_half_peak_to_first`).

`--legacy` runs `PROGRAM` once and writes the old result, judged by max / batch 0 against 2.0. `cache_compiler_compare.py` asks for it. `iclass_resource_replay.py` asks for it where the root's check has it; a root from before had it as its only mode. A legacy ratio is the old metric, and is not read as the new one.

## Numbers

Linux (arm64, docker), main 491cc5ca, the check itself:

| | mere: three runs | mere: median | growth per batch | ruby: median |
|---|---|---|---|---|
| no leak | 1.022, 1.153, 1.035 | 1.035 (passes) | 1.1 to 1.2 MB | 1.000 |
| `--leak-every 10` | 1.345, 1.337, 1.339 | 1.339 (fails) | 3.2 to 3.3 MB | 1.267 |
| `--leak-every 5` | 1.465, 1.411, 1.462 | 1.462 (fails) | 5.3 to 5.4 MB | 1.342 |

So a leak of 3.2 MB a batch fails it, close to the limit. One of 5.3 MB fails it with room to spare.

With no leak, mere's RSS still grows by 1.1 to 1.2 MB a batch, from batch 1 to batch 30, where ruby's is flat. The second half's peak stays at the first half's, so the check reads it as the climb of the first batches. It may also be a small retention of mere's own that the halves do not see. It is left for later, with the VM's case below.

Before the change, with the same program over 30 batches and no leak, three runs on each engine gave the ratio of halves:

- evaluator: 0.989, 0.996, 1.012;
- VM: 0.953, 0.966, 1.030.

## The VM

CI runs this check on the evaluator only, and it still does.

On the VM the new ratio was 0.95 to 1.03 with no leak, and 1.33 to 1.49 with a leak. Its earlier five runs over 20 batches gave a ratio of halves (16-20 / 6-10) of 1.02 to 1.26.

**The VM's Method copies, left for later.** The VM's RSS over these batches is below the evaluator's, but it saws further. By the old ratio it is over 2.0 on main as well: 2.13 to 2.42 over five runs. Nothing here says that it leaks. Its ratio of halves over 30 batches is about 1.0. But one run of five reached 175 MB at batch 16 from 148 at batch 13. Looking at that is not part of this change.

## Checked

- `--legacy` on an O2 build (macOS): `method_copy.rb` is the pinned program, 21 samples, and `post_gc_peak_to_initial` is there for `cache_compiler_compare.py`'s print (reference 1.08, mere 1.90).
- `rss_native_probe.py` and `method_copy_retention.py` import, and the pin of `PROGRAM` holds. A build that is not O2 is still refused with exit 2 and "an O2 build is required", in both modes, as `clone_rss_heap.py` and `rss_native_probe.py` ask.
- `tools/cache_compiler_compare_check.py` (16), `tools/iclass_resource_replay_check.py` (18), `tools/clone_rss_heap_check.py`, `tools/rss_native_probe_check.py` and `tools/rss_page_probe_check.py`: OK.
- The default mode on macOS: a median of 1.013, which passes.
- The full collector, with its pinned compilers and runtimes, runs in the Cache compiler RSS comparison workflow, which this change starts.

- The check and its two negative controls on Linux, as above.
- `--leak-every 5` and `--leak-every 10` exit 1. No leak exits 0.
