# The Module.new/Class.new loop starts its caller's interval again at each turn

#377 gave class identities statement intervals, as objects have. After that, CI's upstream Module test timed out: `TestModule#test_iclass_memory_leak` (Bug #19550) took 10.1 s against its bound of 10 s. Before #377 it took 6.6 s.

## What kept the classes

The test's body is a loop that makes a module and a class that includes it, turn after turn:

    100_000.times { mod = Module.new; Class.new { include mod } }

This body does not run as a block. #78 gave it a loop of its own, `range_metadata_each`, that builds the module, the class and the inclusion edge directly. Each turn sets the caller's call-in mark (`fb_wm_call (depth - 1)`) and the turn's own statement start, as a block's yield does.

The caller here is `times`' own frame. A builtin runs no statement of its own, so nothing moves the start of its interval. `run_block0x` starts that interval again at each yield when the caller is a builtin, which has no env at its depth. `range_metadata_each` did not. The interval of `times`' frame therefore ran from where `times` was entered to the latest turn.

For objects this made no difference here: the body makes no Array, String or Hash, so their counters did not move. For classes, the interval covered every class and module the loop had made. Each collection in the middle of the loop kept all of them: 184,258 classes and 92,154 modules at the last one, where main before #377 kept 24.

## The change

`range_metadata_each` starts the caller's interval again at each turn when the caller has no env, as `run_block0x` does.

## Numbers

Collections in the middle of the loop, `100_000.times { mod = Module.new; Class.new { include mod } }`, evaluator:

| | classes live at the last one | peak memory footprint |
|---|---|---|
| main | 184,258 | 220 MB |
| this branch | 24 | 114 MB |

Instructions retired for that line alone, in billions, the median of three runs taken alternately. Both sides are built with the same Mere.

| | evaluator | VM |
|---|---|---|
| main (`6d2cb190`) | 3.319 | 3.177 |
| this branch | 2.584 | 2.450 |
| before #377 (`7850d078`) | 2.553 | 2.433 |
| this branch, in the same runs | 2.568 | 2.462 |

`tools/class_module_check.py` (CI's "Check complete upstream Module tests and memory limits"), twice each, in turn:

| | `test_iclass_memory_leak` | the file |
|---|---|---|
| main | 10.16 s, 10.13 s | 1 error (that test) |
| before #377 | 6.04 s, 6.52 s | 195/195 |
| this branch | 5.78 s, 6.67 s | 195/195 |

## Why #377's numbers did not show it

#377 measured `Class.new` loops and `Module.new` loops apart. Neither goes through `range_metadata_each`, which takes only this body: a module made into a local, and a class that includes it.

## tools/loop_rss_check.rb

A new case runs the body 300,000 times. Its ratio of RSS after to RSS before:

| | evaluator | VM |
|---|---|---|
| main | 1.80 (FAIL) | 1.75 (FAIL) |
| this branch | 1.03 to 1.09 | 1.02 to 1.09 |

At 100,000 turns main passed (1.28 and 1.45); at 200,000 the evaluator still passed (1.54). This branch was run four times on each engine.

## Checked

On 3c9fb7fe:

- `run_corpus.sh`: 1028/1028.
- `vm_corpus.sh`: all 1028 programs on the VM, 0 fallback, 0 FAIL.
- vm_check: 246/246.
- The collector's root check.
- `tools/loop_rss_check.sh`: all 15 loops within their bounds, the new one at 1.03.
- `tools/class_watermark_check.sh`: 559, 561 and 839 pass on both engines without the class-name scan, and 559 still loses its class with neither the scan nor the watermarks.
