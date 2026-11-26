# A method's record: what a call reads of its definition, read once

Note 560, A (the first of three, in the order decided: A, C, then B after note 559's 2b and 2c).

## What a call read

A call of a method on an object (`run_meth_result`) built the key `"Class#name"` and looked it up in about fourteen tables, all of them about the method's definition and almost never written after it:

- `alias_origin`, `alias_srcname`: the class it was defined in and the name it was defined as;
- `meth_cref`, `meth_cvcls`: its cref and its class-variable class, with the nesting packed from the cref;
- `meth_params`: its parameters' Array;
- `meth_cfn`, `dm_methods`: whether C runs it, whether define_method made it;
- `meth_src`, twice: its first and last line.

It also turned four of those into the frame's texts (`frame_text`). Then `method_body_flow_result` read two of them back from the frame and joined them again, `"Class#name"`, for the frame's label. A top-level method (`call_method`) did the same under its bare name.

Measured on main, a self call on the evaluator was about 22,000 instructions, and `run_meth_result` alone a third of them: the lookups and the joining about 12%, the frame texts 4%.

## The change

- **The record** (`mrec_get`, `mrec_build`): those answers, the frame texts and the label, kept by `"Class#name"` (`mrec_tab`). A top-level method has its own (`mrec_top_get`, `mrec_ttab`), under its name. The frame is given exactly what it was given before.
- **When it holds**: while no method table has moved since it was read. `mro_gen`'s slot 2 is an epoch that every change of a method table moves, global or one class's. The record's epoch is kept apart (`mrec_gen`), so a moved epoch with the same answers writes one int, not the record.
- **The tables are written through wrappers that move the epoch** (`mrec_set_ss` and its kin, 63 writes, and `meth_source_set` and the two direct writes of `meth_src`).
  Most of those writes come with a method table's change anyway. Not all: a Method that holds its definition (note 354) puts its rows back without one. The check below found five corpus programs where that happens.
- **The label** is handed to the body's run (`method_body_flow_lbl`); `method_body_flow_result` without one reads the frame as before.
- `ruby2_keywords`'s table is asked only while it has an entry.
- **The collector** marks the records' values (`mrec_tab`, `mrec_ttab` in `gc_mark_roots`): the same handles `frame_str_ids` and `meth_params` keep, until a redefinition drops those rows and the record is read again.
- **The check**: `MERE_RUBY_MREC_CHECK=1` reads the tables at every call too, compares the record field by field, and stops naming the method and the field that differs.

A define_method method still reads its closure's rows at each call, as before.

## Numbers

Instructions, the median of three runs alternating main and this branch, both built with Mere 9dec2ff6 (CI's), main at 0c89c8a3. The micro programs are per call, with the same loop without the call taken off.

| program | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| a self call in a method (per call) | 21,900 | 19,390 (-11.5%) | 24,230 | 21,620 (-10.8%) |
| a method calling another object's method (per call) | 27,760 | 25,230 (-9.1%) | 28,720 | 26,230 (-8.7%) |
| a top-level method (per call) | 13,730 | 12,160 (-11.5%) | 15,710 | 14,130 (-10.0%) |
| app_fib | 236.1 G | 215.6 G (-8.7%) | 227.7 G | 207.3 G (-9.0%) |
| app_tak | 406.2 G | 377.9 G (-7.0%) | 366.7 G | 338.4 G (-7.7%) |
| so_object | 176.0 G | 171.1 G (-2.7%) | 189.8 G | 185.1 G (-2.5%) |
| Rails 8.1's warm boot (`bin/rails runner`) | 54.3 G | 53.7 G (-1.1%) | 53.6 G | 52.9 G (-1.3%) |

The boot gains less: it defines more than it calls, and each definition moves the epoch, so records are read again often there. Its maximum RSS under `MERE_RUBY_GC_TIGHT=1` is the same (the VM's median 755 MB on both).

## Checked

- Corpus with `MERE_RUBY_MREC_CHECK=1` on both executions, `run_corpus.sh` without it, vm_check, and the collector's root check (`tools/gc_roots_check.sh`): see the PR for the counts on the final build.
- The check found five corpus programs (330, 591, 604, 620, 776) where a Method that holds its definition puts its rows back without a method table moving; the wrappers above are for that.
- Ten unit files on both executions against main, the new build under the check: test_method, test_proc, test_backtrace, test_exception, test_fiber, test_thread, test_settracefunc, test_refinement, test_alias, test_module. The same failures as main.
- Two things the unit files found on the way:
  - **A record for every anonymous class.** `test_complemented_method_entry_memory_leak` defines methods on `Class.new` in a loop and grew to 3.7 times its memory: the records were never let go.
    A class whose name `mro_local_name` knows (an anonymous class or module, a Struct's, a refinement's, a singleton class) has no record kept; its call reads the tables, as before.
  - **A gap it showed, not made.** `test_tracepoints_not_disabled_by_ractor_gc` counts the `:raise` events: 7 when the dead Ractor was collected (the RangeError `ObjectSpace._id2ref` raises then), 6 when not.
    A build of this round collected the Ractor where main does not, and the RangeError, raised in the prelude, is not reported to a TracePoint on either build (ruby reports a raise in a C method with its `method_id`).
    The final build does not collect it either, and the test reads as main. Recorded: a raise in the prelude is no `:raise` event.

## #321's review

- **A record written again was not given back.** A record replaced by one with other contents stayed in the table's arena: a named class's method redefined and called in a loop grew by about 220 bytes a turn (a class that comes and goes keeps no record, so the earlier fix did not reach it).
  The rewrites are counted (`mrec_dirty`), and the collector compacts the record tables when 256 have piled up (`gc_sweep_classes`), where the stack it interrupted keeps what it borrowed. A compaction anywhere else would free the strings a running call holds of its record. Maximum RSS under `MERE_RUBY_GC_TIGHT=1`, main and here:

  | loop | evaluator: main | here | VM: main | here |
  |---|---|---|---|---|
  | `K.define_method(:m) { \|x\| x }` and `o.m(i)`, 180,000 turns | 146.1 MB | 148.2 MB | 135.9 MB | 142.0 MB |
  | the same, 360,000 turns | 185.3 MB | 188.5 MB | 163.0 MB | 165.3 MB |
  | `K.class_eval("def m = 1", "x.rb", i + 1)` and `o.m`, 120,000 turns | 166.5 MB | 169.5 MB | 167.0 MB | 174.2 MB |
  | the same, 240,000 turns | 241.5 MB | 242.1 MB | 239.1 MB | 245.3 MB |

  Main's own grows with the turns; the difference does not.
- **The parameters' memo moved the epoch.** `mrec_build` wrote it through the wrapper, so the first call of each method with parameters dropped every record, its own too. It is a memo of the Array the record keeps; written as before.
- **The class tables' sweep** takes `mrec_tab` and `mrec_gen` too: a dead class's records go with its other rows.

## Witnesses

Corpus 831: a method first called, then aliased, redefined, held as a Method across a redefinition, made a module function, marked ruby2_keywords, refined, removed;
a top-level method aliased and redefined; a class variable; a define_method method; backtrace labels through a method and its alias; a recursive method's `__method__`.

CHECKED
