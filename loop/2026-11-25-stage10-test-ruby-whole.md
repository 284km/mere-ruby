# test/ruby whole on both executions, compared

The first comparison of all of test/ruby on the evaluator and on the ISeq VM (MERE_RUBY_VM=1) since the comparison became a script (`unittest/vm_compare.sh`, #265). The last by hand was on 2026-11-17 (note 552, section 15).

## The run

`sh unittest/vm_compare.sh <ruby 4.0.10 source> ruby` on main d5869476 (#279), built with Mere 9dec2ff6, against ruby 4.0.10, on a shared machine (other sessions' corpus runs beside it).

| pass | files | time |
|---|---|---|
| the evaluator | 167 | 76 min |
| the VM | 167 | 76 min |
| both again, over the 5 files that differed | 5 | 27 min |
| in all | | 179 min |

| | tests | MATCH | RED | BOTH | EXTRA |
|---|---|---|---|---|---|
| the evaluator | 9,814 | 8,821 | 897 | 86 | 10 |
| the VM | 9,814 | 8,819 | 900 | 85 | 10 |

Compared test by test: **VM_ONLY 2, EVAL_ONLY 1, VM_FILE 0**. No file the evaluator completes is left incomplete by the VM. The first pass had VM_ONLY 4; two (`TestArraySubclass#test_shared_marking`, `TestSetTraceFunc#test_tracepoints_not_disabled_by_ractor_gc`) did not differ the second time.

## The two that fail on the VM alone

**`TestIO#test_marshal_closed_io`.** The test undefines `closed?` in an IO's singleton class. On the VM, `undef_method :closed?` there raises NameError, "undefined method 'closed?'". The evaluator takes the same statement inside `class << r`, where its class-body walker reads it, and refuses it as the VM does when it is called (`r.singleton_class.send(:undef_method, :closed?)`, or `:close_write` in a second IO's singleton). The check asks whether the name is defined in the class or its ancestors, and IO's own methods are not where it looks:

- mere-ruby has no generated list of IO's own methods (`m_builtin_lists.mere`), and the prelude defines most of them on File;
- so `IO.instance_methods(false)` lacks 59 of ruby's (`closed?`, `read`, `write`, `close_write`, ...) and names 126 internal ones (`__fd_*` and others), and `File.instance_methods(false)` names 42 that are IO's in ruby;
- and `r.singleton_class.method_defined?(:closed?)` is false, where ruby's is true.

A defect of reflection on IO on both executions, which the VM shows in one more place. Recorded, for a round of its own: the fix is where IO's methods are defined, not the VM.

**`TestModule#test_complemented_method_entry_memory_leak`** stops at its time limit on the VM. It makes a class, a module refining it and a class using the refinement, 300,000 times. The VM runs it (no fallback), at about twice the evaluator's time: 10,000 rounds take 0.18 s on the evaluator, 0.33 s on the VM. The difference is a `def` inside a block: 20,000 `Class.new { def foo; end }` take 0.041 s on the evaluator and 0.086 s on the VM, where `Class.new { }` takes 0.05 s on each. Recorded, as the VM's speed.

**`TestParse#test_method_location_in_rescue`** fails on the evaluator alone, as in the 22 files' comparison of #265.

## #243's ten VM items

| file | test | now |
|---|---|---|
| test_rubyvm | `test_stat`, `test_stat_unknown` | pass on both (#279) |
| test_vm_dump | `test_darwin_invalid_access`, `test_darwin_invalid_call` | pass on both |
| test_vm_dump | `test_darwin_segv_in_syscall` | F on both |
| test_iseq | `test_invalid_source_no_memory_leak`, `test_loading_kwargs_memory_leak` | T on both |
| test_iseq | `test_iseq_builtin_to_a` | F on both |
| test_stack | `test_relative_stack_sizes`, `test_vm_stack_size` | E, F on both (a fiber's stack size, recorded in #279) |

Six remain, each the same on both executions.

## For CI's job unittest-vm

It runs the 22 files of `unittest/vm_compare_files.txt`. All of test/ruby took 152 minutes for the two first passes here, at a load of 5 or more: inside the job's 330 minutes, with the reruns. Whether the job takes all of test/ruby is the owner's decision.

CHECKED
