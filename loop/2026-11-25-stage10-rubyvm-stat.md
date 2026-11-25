# RubyVM.stat, and two of the VM's unit-test items recorded

#243 recorded ten unit-test items of test/ruby as the VM stream's: three of test_iseq, two of test_rubyvm, two of test_stack and three of test_vm_dump. On main 0cd831f0, with ruby 4.0.10, `unittest/vm_compare.sh` over test_rubyvm.rb and test_stack.rb finds the four of those two files RED on **both** executions, the same on each: none is the VM's alone.

## RubyVM.stat

`TestRubyVM#test_stat` and `#test_stat_unknown` asked for a method mere-ruby did not have. ruby's `vm_stat` answers with five counters of its own: its inline constant caches (`constant_cache_invalidations`, `constant_cache_misses`), its class variable state (`global_cvar_state`) and its object shapes (`next_shape_id`, `shape_cache_size`).

- `RubyVM.stat` is a new Hash of the five; `RubyVM.stat(hash)` fills the Hash given and returns it, a frozen one raising FrozenError; `RubyVM.stat(:name)` is one counter.
- An unknown name is an ArgumentError, "unknown key: name"; any other argument a TypeError, "non-hash or symbol given"; a second argument is the arity's ArgumentError (0..1). The arity is -1, as ruby's.

This interpreter keeps none of the five, and counts 0 for each. The values are each implementation's own, so corpus 824 compares the names, the class of each value, the Hash filled in place and the errors.

## Recorded: a Fiber's stack size

`TestStack#test_vm_stack_size` and `#test_relative_stack_sizes` ask that a fiber recurse less deep under a smaller `RUBY_FIBER_VM_STACK_SIZE` and deeper under a larger one, and that `RubyVM::DEFAULT_PARAMS` report the fiber sizes. Here a fiber's recursion budget is the thread's (15,000 calls at the default), whatever the variable says, and `DEFAULT_PARAMS` has the two thread sizes only. ruby's default fiber VM stack is 128 KB against the thread's 1 MB, so following it would make every fiber recurse about an eighth as deep as it does here now: a change to what programs can do, left for a round of its own.

## Numbers

Corpus 824 matches ruby on both executions, and runs on the VM; on main it fails on both (NoMethodError). `test_rubyvm.rb` passes on both executions: 3 tests, 0 failures, 0 errors, and the one omission ruby makes too (`test_keep_script_lines`, under Prism). An uncaught error's backtrace is ruby's, `in 'RubyVM.stat'` on top.

CHECKED
