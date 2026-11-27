# A method store compaction a pin refused is done again at the next top-level statement boundary

main's CI failed `test_complemented_method_entry_memory_leak` (test/ruby/test_module.rb) once: an RSS ratio of 2.12 against a limit of 2.0. Later runs passed. The test makes a class, a module refining it and a class using the refinement, 300,000 times, and compares the RSS after a `GC.start` with the RSS before the loop.

The ratio is not a regression of a recent change. It varies from run to run of one binary: on Linux (arm64, docker), main gives 1.18 to 1.53 on the evaluator and 1.88 to 2.21 on the VM.

## Where the variation comes from

- Without the collector's conservative scan of the stack for class names (`fb_scan_names`), two runs give the same GC log, line for line. With it they part: the scan keeps a different handful of dead classes each run, depending on the addresses the words on the stack happen to hold. The scan cannot be dropped: corpus 559, 561 and 583 depend on it.
- What the RSS follows is the method store's arena (`meths_g`). It is compacted when it has doubled, and every collection runs off the stack it interrupts, which the runtime pins for: any word on it that looks like a pointer into the arena refuses the compaction. A store past Mere's small-map rule then waits under the pin until it has doubled again (Mere v0.1.651). The test ended with this arena at 8, 16 or 33 MB, depending on the run, and its ratio went with it.

## The change

A compaction of the method store a pin refused is noted (`method_store_refused`). It is done again at the next boundary between two of the main program's top-level statements (`compact_method_store_at_top`, from `run_until_gc_n`). There no call is in flight, and the stack running there is not a suspended one the runtime pins for, so the compaction happens the same way in every run.

The check is one `vec_get` per top-level statement.

I also tried doing it once more after the program's last statement, before the at_exit handlers, which the VM would meet. It made no difference to the numbers below, so it is not in this change.

## Numbers

The ratio is the leak test's child, as `assert_no_memory_leak` runs it (`-r memory_status -v -`, START after the 1,000-turn prepare, FINAL in the END block after the 300,000 turns and `GC.start`). It ran in a Linux arm64 docker container (ubuntu 24.04, clang 18, `ulimit -s 524288`), and on macOS with ps's RSS. Each cell gives min / median / max.

| | runs | evaluator | VM | VM runs at 2.0 or above |
|---|---|---|---|---|
| Linux, main (3fbe3921) | 10 | 1.182 / 1.335 / 1.527 | 1.883 / 1.937 / 2.207 | 3 of 10 |
| Linux, here | 20 / 40 | 1.143 / 1.208 / 1.517 | 1.844 / 1.879 / 2.344 | 3 of 40 |
| macOS, main | 10 | 1.084 / 1.245 / 1.251 | 1.624 / 1.649 / 1.709 | 0 |
| macOS, here | 10 | 1.078 / 1.179 / 1.241 | 1.671 / 1.725 / 1.765 | 0 |

The VM's 40 runs here, sorted: 1.844 1.853 1.856 1.856 1.857 1.858 1.858 1.861 1.864 1.865 1.867 1.867 1.867 1.868 1.868 1.870 1.871 1.872 1.874 1.879 1.880 1.882 1.884 1.889 1.890 1.891 1.892 1.893 1.895 1.898 1.898 1.901 1.908 1.909 1.911 1.916 1.933 2.150 2.273 2.344.

On macOS the VM's median went up (1.649 to 1.725). macOS keeps the memory it was given back, so the compaction's copy stays in the RSS there.

Instructions (main and here, median of three alternating runs, Mere 9dec2ff6): the leak loop at 60,000 turns is 12.765 G against 12.798 G on the evaluator, and 17.440 G against 17.469 G on the VM. A self call 300,000 times is 7.859 G against 7.847 G, and 7.865 G against 7.862 G.

## Not solved

A few VM runs still end at 2.15 to 2.34, on main and here alike. In those runs the number of collections, every store's size at the last collection and the classes the scan kept are the same as in the others. Only the virtual size is about 60 MB larger: a large anonymous mapping outside the interpreter's stores is still there at the end.

It is not glibc's per-thread arenas: with `MALLOC_ARENA_MAX=1` the VM still had 2 of 40 runs at 2.0 or above (2.014, 2.325). The process has two threads, also for `-e`.

The class names the scan keeps are left as they are too. A watermark for classes would keep the in-flight ones of corpus 559 and 561 without the scan, but not 583's (a class taken out of an Array mid-statement), so the scan stays. That is a separate change.

## Checked

On 410c2314:

- `run_corpus.sh`: 994/994.
- `vm_corpus.sh`: all 994 programs on the VM, 0 fallback, 0 FAIL.
- vm_check: 246/246.
- The collector's root check.
- `tools/loop_rss_check.sh`: all 12 loops within their bounds.

CHECKED
