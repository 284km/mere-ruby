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

- The check and its two negative controls on Linux, as above.
- `--leak-every 5` and `--leak-every 10` exit 1. No leak exits 0.
