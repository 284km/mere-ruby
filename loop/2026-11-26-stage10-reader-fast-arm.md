# A reader written as a method takes attr_reader's arm

`def x = @x` and `def x; @x; end` read one instance variable and answer it, as `attr_reader :x` does. attr_reader's method has a fast arm in `run_meth_result`: no frame, the variable read straight from the object. A reader written as a method did not take it, because its body is not attr_reader's (`[SReturn (EIVar x)]`):

- the evaluator's body is the parser's, `[SLineQ; SFile; SExpr (EIVar x)]`;
- the VM's body is `[SLineQ; SFile; SVm (id, gen)]`.

So it made a frame of its own: about 21,900 instructions a call on the evaluator and 23,200 on the VM, against attr_reader's 2,000 and 3,700.

## The change

`triv_reader_iv body` answers the variable a body only reads and answers, or "" if the body does anything else. It accepts:

- attr_reader's body, `[SReturn (EIVar x)]`;
- `[SExpr (EIVar x)]` after any number of line and file marks (`SLine`, `SLineQ`, `SFile`);
- a VM program of two instructions, `getinstancevariable x; leave`, that is still loaded (its generation matches) and is a method's (kind 2).

For a VM program it reads the cheap facts first: the length from `vm_code`, then the two opcodes. The tree and the 14-field metadata record are read only for a two-instruction program.

The arm's conditions are attr_reader's arm's, in a new order: no arguments, an object receiver, the body a reader, then no block, no tracing, no Coverage, no Ractor. A call that is not a reader fails at the body check, before the tracing, Coverage and Ractor checks run.

## The two checks asked for in review

**Line marks.** The fast arm makes no frame and passes no line or file mark. The caller's `cur_line` and `cur_file` stay what they were before the call, which is what the full path restores on return.

Corpus 834 checks this. It raises on the line after a reader, and on the same line as one (`l.w; raise`). It compares `backtrace_locations.first.lineno` and `path`, `__LINE__` and `caller_locations` there. All match ruby on both engines.

**Tracing.** The conditions are attr_reader's arm's, unchanged:

- `hook_tp_on ()` covers TracePoint and `set_trace_func`;
- `cov_st 0 != 2` covers Coverage while it runs (lines and methods);
- `ractor_thr` must be empty.

ObjectSpace's allocation trace is not a condition. A reader allocates nothing, and the allocation after a reader call must record the caller's line and method. Checked against ruby on both engines, with an Array literal made in two places:

- inside a method, after `a; b; c` (the three kinds of reader);
- at the top of a `trace_object_allocations` block, after `o.a`.

Both give the same `allocation_sourceline`, `allocation_method_id` and `allocation_sourcefile` as ruby.

## Why the answer is not kept in the method's record (#335's review)

The review asked whether to decide "is this body a reader" once per definition, as a field of the method's record (`mrec_build` / `mrec_top_build`). Then a call that is not a reader would pay one comparison, and a reader would not walk its body again. Tried; kept as it is, for two reasons.

- **The record cannot say "a reader".** The record is keyed by `Class#name` and describes the method defined under that name now. A Method or UnboundMethod keeps the body it was taken from. Redefine `x` as a reader after `mm = o.method(:x)`, and the record says "reader" while `mm.call` must run the old body. That body sets `@y` (corpus 834's last case, which matches ruby on both engines today). So the record could only say "not a reader": a filter, with the body still checked when it lets a call through.
- **As a filter, the cost moves rather than goes.** To filter, a call must fetch the record before the frameless arms. Today those arms (this one, `triv_or_init`, `triv_store`) fetch none, and only the full path does, further down (`defcls ++ "#" ++ name`, then a map lookup). Fetching earlier means every call to a frameless method pays a key build and a lookup. A key built at run time costs about 190 instructions to hash (step 1 of note 560 B measured this: `loop/2026-11-26-stage10-frame-head-doors.md`). A reader is about 2,000. The saving on a call that is not a reader is 30 to 95.

Also tried: checking the shapes a reader can have inline in the guard, without calling `triv_reader_iv`. The loops did not move: a self call +0.18% / +0.23%, against +0.1% / +0.23% as it stands. That is within run-to-run noise, so it is not taken.

## Also here: the VM ivar cache and a moved self (#332's review)

`vm_ivar_ok`'s comment now covers a method still running on an object that `Ractor#send(move: true)` took, once every Ractor has ended.

In ruby, the next call on that self raises `Ractor::MovedError`. In mere-ruby, `moved_guard` refuses only a call on a moved receiver named explicitly. A method still running on a moved self reads and writes its instance variables:

- on the evaluator;
- on main's VM.

The cache is off while any Ractor runs, and after that it does what the evaluator does, so it adds no gap of its own. The gap itself is older than the cache and is not closed here.

## Numbers

Instructions: the median of three runs alternating main (7a733b48) and this branch, both built with Mere 9dec2ff6 (CI's). Each reader program makes 300,000 calls on one object in a `while` loop. The per-call figure is (the program − the same loop with no call) / 300,000.

Instructions a call:

| reader | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| `attr_reader :x` | 2,040 | 2,067 | 3,687 | 3,677 |
| `def x = @x` | 21,900 | 2,037 | 23,243 | 3,707 |
| `def x; @x; end` | 21,947 | 2,033 | 23,263 | 3,717 |

Whole programs, which are not readers (a call that is not a reader now runs the body check):

| program | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| a self call, 300,000 times | 7.818 G | 7.826 G | 7.820 G | 7.838 G |
| a method calling another object's method, 300,000 times | 9.470 G | 9.495 G | 9.091 G | 9.119 G |
| a top-level method, 300,000 times | 5.804 G | 5.807 G | 5.664 G | 5.658 G |
| app_fib | 200.9 G | 201.1 G | 191.7 G | 191.8 G |
| so_object | 149.3 G | 149.3 G | 161.2 G | 161.2 G |
| Rails 8.1's warm boot (`bin/rails runner`) | 49.1 G | 49.1 G | 48.3 G | 48.3 G |

A zero-argument call on an object that is not a reader pays about 30 to 95 instructions for the body check: +0.1% to +0.3% on the two call loops. app_fib and so_object change by 0.06% or less.

An earlier version did the check after the tracing conditions and read the whole program record first. It cost the self call +0.3% on the evaluator and +0.45% on the VM.

Rails's warm boot under `MERE_RUBY_GC_TIGHT=1`, the median of three alternating runs:

| engine | max RSS: main | here | instructions: main | here |
|---|---|---|---|---|
| evaluator | 647 MB | 643 MB | 54.8 G | 55.6 G |
| VM | 740 MB | 702 MB | 55.7 G | 54.9 G |

Under the tight collector, instructions follow when collections fall. Without it they are equal (the table above).

## Checked

- `run_corpus.sh`: 981/981, both plain and with `MERE_RUBY_ATTR_IC_CHECK=1`.
- `vm_corpus.sh`: all 981 programs run on the VM, 0 fallback, 0 FAIL.
- vm_check: 246/246.
- The collector's root check.
- Corpus 834 matches ruby on both engines, with and without the attr_ic check.

CHECKED
