# A class made in the middle of a statement is kept by a watermark

An anonymous class made in the middle of a statement, and held only by that statement's half-evaluated arguments, has no root a collection can see:

    first_of(Class.new { def v = 1 }, GC.start).new.v

Only a C variable of the evaluator holds it while `GC.start` runs. Until now the collector kept it through its conservative scan of the stack for class names (`fb_scan_names`, #78). That scan matches names by content, through whatever the words on the stack point at. Its answer depends on the addresses those words happen to hold, and it differs from run to run (#368).

Objects have a deterministic answer for this already: the statement watermarks (`fb_wm`). Every allocation takes its id from a counter that only grows, so "built by this frame's statement so far" is an interval of ids for each frame on a stack. Classes now have the same.

## The change

- `fb_wm_put` writes the count of generated class identities (`scope_ids` 0, which names `AnonClass_N`, `AnonModule_N` and `Struct_N`) beside its four counters. It does so where a statement begins and where its frame calls in (`fb_cw_put`, slot `b / 4` of the same `b`).
- `fb_stack_wm_iv` hands over that interval as a fifth kind (4).
- `gc_mark_wm_merged` marks every generated class whose number falls in one of those intervals. It walks the generated classes, which are few, rather than the intervals.
- `MERE_RUBY_GC_DBG` bit 8 leaves the class-name scan out. Like the other bits, it is an unsound diagnostic.

## What the scan still keeps

A class made before the statement and held only by a C variable since is outside every interval. That is corpus 583's `native_class_argument(queue.pop, GC.start)`: the class went into the queue before the statement, and `pop` took it out of the queue's Array. The scan still keeps that one; the change leaves the scan in place. Without the scan (bit 8), 583 loses that class on the evaluator. On the VM it happens to survive, held on the VM's operand stack.

## tools/class_watermark_check.sh (CI, corpus job)

The check runs corpus 559, 561 and 839 with the class-name scan left out, on both engines, against ruby. All of them pass.

It also has a control: with the watermarks left out as well (bits 8 and 2), 559 must lose its class on the evaluator. Otherwise the check could not see a missing watermark.

With the scan in place, a missing watermark would not show: the scan kept those classes on most runs.

## Corpus 839

Each of these holds a class made in the middle of a statement, only by that statement's arguments, across a `GC.start` in it:

- `Class.new`, `Module.new`, `Struct.new` and `Data.define` as an argument;
- an element of an Array literal;
- inside a method;
- in a block run twice;
- the superclass of a `Class.new` that is itself an argument;
- a Fiber suspended in such a statement, across three collections.

It matches ruby on both engines, with the scan and without it.

## Numbers

Instructions retired for the whole program, in billions, the median of three runs taken alternately. Both sides are built with the same Mere; the old side is main at `b9ca06d6`, the base of this branch.

| program | evaluator old | new | | VM old | new | |
|---|---|---|---|---|---|---|
| self call (`f` 300k times in a `while`) | 7.905 | 7.933 | +0.35% | 7.905 | 7.937 | +0.40% |
| `app_fib` | 201.598 | 202.083 | +0.24% | 192.393 | 193.064 | +0.35% |
| `so_object` | 149.597 | 149.910 | +0.21% | 161.733 | 162.094 | +0.22% |
| `20_000.times { Class.new }` | 1.441 | 1.443 | +0.14% | 1.493 | 1.498 | +0.33% |
| `20_000.times { Class.new { def foo; end } }` | 1.504 | 1.510 | +0.40% | 1.799 | 1.809 | +0.56% |
| `20_000.times { Class.new { def foo; end; def bar; end } }` | 2.083 | 2.082 | -0.05% | 2.577 | 2.587 | +0.39% |
| `i += 1` 300k times in a `while` | 2.322 | 2.325 | +0.13% | 1.654 | 1.664 | +0.60% |

The cost is the one more counter written where a statement begins and where a frame calls in. Collections pay for the fifth interval too, but they are rare in these programs.

The first version wrote it through its own function and grew its own array, and cost +0.5% to +0.9% on the same programs. This one writes the slot inside `fb_wm_put`, beside the four counters, and `fb_wm_grow` grows both arrays together.

## Checked

- `tools/class_watermark_check.sh`: 559, 561 and 839 match ruby without the class-name scan on both engines, and the control (no scan and no watermarks) loses 559's class.
- 583 without the scan (bit 8) loses its class on the evaluator, as above. With the scan, as in every ordinary run, it passes.
- `run_corpus.sh`: 1014/1014.
- `tools/iseq/vm_corpus.sh`: 1014 on the VM, 0 fell back, 0 FAIL.
- `tools/iseq/vm_check.sh`: 246/246.
- `tools/gc_roots_check.sh` and `tools/loop_rss_check.sh`: pass.
