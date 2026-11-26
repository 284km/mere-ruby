# Design: a VM frame without vm_exec's fail handler

A design for review, not a change. #307 took `vm_seg`'s handler off frames that cannot throw a jump. What is left between the evaluator and the VM on a raise is mostly `vm_exec`'s handler, one for each VM frame.
This record measures what it costs, says how a frame could do without it, and goes through the places where that is hard: Fibers, Threads, `Thread#raise` and `Thread#kill`, and the order of ensures.

## What the handler does

`vm_exec` takes an operand stack and registers from a pool (`vm_pool`, a free list in `vm_pool_free`), runs the frame in `try_or_msg`, and gives the slot back at the end. The handler gives it back when the frame is left by a failure, and raises the failure again. The pool matters to two things:

- **Reuse.** A slot holds a Vec for the stack and 16 registers; a frame that takes a used one costs no allocation.
- **The collector.** `gc_mark_roots` marks every value on the stack of every slot not in the free list, up to its depth. A slot that is held but whose frame has gone keeps its values alive.

## What it costs

Instructions, the median of three runs alternating main (94424798) and a build of it with the handler removed (measuring only; a frame left by a failure then never gives its slot back):

| program | main | no handler | |
|---|---|---|---|
| ten nested calls, 300,000 times, no raise | 45.30 G | 44.46 G | −1.9%, about 280 a call |
| app_fib | 227.74 G | 224.39 G | −1.5% |
| so_object | 189.79 G | 188.36 G | −0.75% |
| app_raise | 10.53 G | 10.38 G | −1.4% |
| a raise through ten frames, 300,000 times | 67.39 G | 179.61 G | the slots are never given back |

On calls, the handler is about 280 of the 2,300 instructions a VM call costs more than an evaluator call (the rest: `vm_step` ~570, `vm_exec` without the handler ~120, `vm_enter` ~250, `vm_loop` ~220, `vm_run_stmt` ~220, `vm_exec_run` ~180 a call).
On a raise, the VM spends about 1,100 instructions more than the evaluator for each frame the raise leaves, which is the handler's catch, its message formatted again, and its jump.

The last row is what happens without something to take the handler's place: three million slots held, and every collection marking all of them.

## Without the handler: who gives a slot back

A frame gives its slot back itself when it ends in order. When it is left by a failure, someone else must find out that the slot is no longer used. The evaluator catches failures in 269 places (`try_or` 182, `try_or_msg` 87), so giving slots back at every catch is not an option. What can be known without the catch:

- **Each Fiber has a band of call depths.** A Fiber's body starts at `idx * fb_band` (`fb_band` = 20,000; `fb_ctx_fresh`), and a Thread's root Fiber the same way. So the call depth a frame was entered at says which stack it is on: the band is `cd / fb_band`.
- **On one stack, frames end in order.** A frame entered after another one on the same stack has ended by the time that one ends, in order or not.

So: a stack of held slots for each band, each entry the slot and the call depth the frame was entered at. A slot leaves it:

1. **When its frame ends in order:** it is taken off the top, and every entry above it goes back to the free list. Those frames were entered after this one on this stack and have not ended in order: they were left by a failure.
2. **When a rescue region of a frame takes an exception** (`vm_region`, through `run_begin_f`): the same. The frame is running, and every entry above its own was left by the failure the region took.
3. **When a frame is entered at depth `d`**: every entry of the band deeper than `d` goes back. A frame deeper than one being entered on the same stack has ended.
4. **When a Fiber's or Thread's body ends** (`fb_run_body`), in order or by an exception: its whole band goes back.

What stays held until one of those happens is a frame left by a failure that an evaluator's catch took (a builtin that rescues what a block raised, `Integer()`'s conversions, `loop` and StopIteration) and that no VM frame below it has ended or caught since. While it stays held, its values stay alive.

### What has to be true, and how to know

Rule 3 gives back only entries strictly deeper than the frame being entered, so a rescue or an ensure sequence, which runs at its frame's own depth (`vm_region` → `vm_exec`, the call depth unchanged), leaves its frame's entry alone.
What it needs is that a frame is never entered at a depth below that of a frame still running on the same stack.

In main, the depth is moved in three ways: one deeper around a call (`cd_set (cd + 1)`, ten places) and back after it (`cd_set cd`); one deeper for a builtin's frames (`cd_set top`, `bi_frames_put`);
and to another band when a Fiber's stack is switched to (`fb_ctx_fresh`, `fb_ctx_restore`). None lowers it under a running frame of the same stack. A failure that skips a `cd_set cd` leaves the depth too high, not too low, and rule 3 then gives back less, not more.

Where a trap handler, a finalizer or `at_exit` runs Ruby code is to be checked for the same: run at the depth it interrupts or deeper, not reset to the bottom of the band.

The check: a mode (`MERE_RUBY_VM_POOLCHECK=1`) that keeps the handler and, when the handler runs, marks the slot as left by a failure. Whenever rules 1 to 4 give back a slot, the mode checks the mark and stops with the frame's program and depth if the slot was not given back by its handler.
Corpus, vm_check and the unit test files with Fibers and Threads (test_fiber, test_thread, test_thread_queue, test_exception, test_enumerator) run under it on the VM.

## The hard places

- **An exception that leaves a Fiber.** The body's coroutine catches it (`fb_run_body`) and hands it to the resumer on another stack. Rule 4 gives back the Fiber's band at that point, before the switch. The resumer's frames are in another band and are not touched.
- **A Fiber that is never resumed.** Today it is never unwound either: its frames' slots stay held, and their values alive, for as long as the program runs (the handler cannot help; nothing fails). With bands, the band can be given back when the Fiber is collected. This is a gain over today.
- **`Thread#kill`** raises `__ThreadPark` in the thread's stack, and **`Thread#raise`** delivers the exception at the thread's next poll. Both unwind by failing, as a raise does; the thread's frames are in its root Fiber's band. When the body ends, rule 4.
- **Ensures** run where they run now: nothing in rules 1 to 4 runs Ruby code. An ensure run while the failure is on its way out is in a frame below the ones left, so its own frames go above them in the band's stack;
when the ensure's frames end in order (rule 1), they also give back the left ones above them. One case to look at in the check: an ensure that enters at a depth equal to a left frame's (rule 3 gives back only deeper ones).
- **The collector** marks held slots as today. A slot held after its frame was left keeps its values for longer than today, until one of rules 1 to 4.
- **A Continuation** re-entered into a frame (`cont_rerun`) runs the frame's body again from a statement: a new `vm_exec` at the frame's depth, by rule 3 after the old one's deeper entries are given back.

## What it would give, and a recommendation

At most what the table shows: about 1.5% on call-heavy programs and about 1.4% on app_raise. More on a raise through many frames, where the handler's catch and jump are paid once per frame (about 1,100 instructions each); how much more cannot be measured without rules 1 to 4.

Against that: four ways to give a slot back where there is one now, one invariant about call depths, a check mode to keep, and values held for longer after a failure. My recommendation is not to do this now.
The rest of the VM's call cost (`vm_step`, `vm_enter`, `vm_loop` and `vm_run_stmt`, about 1,260 instructions a call) is a larger target with none of the risk. If the handler is taken on later, rules 1 to 4 with the check mode are the way.

## What was not done

No code: the build without the handler was for measuring and is gone. The depth that trap handlers, finalizers and `at_exit` blocks run at is not yet checked.
