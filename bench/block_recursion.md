# Catch recursive block calls before exhausting the native stack

The CI run for #48 (`42459127323`) reaches its 2-GiB family RSS limit in
`ruby/test_exception.rb`, at `TestException#test_machine_stackoverflow`.
The unchanged test recursively calls a lambda stored in a Hash:

```ruby
h = {a: -> { h[:a].call }}
h[:a].call
```

`method_body_flow` already checks the per-fiber call depth, but `run_block0`
increments the same counter without checking it. A Proc or builtin yield can
therefore recurse without entering the method guard. Apply that guard before
installing the block's frame or changing its refinement/caller state. Methods
and blocks now use one named constant for the existing 15,000-frame budget.
The budget and the 512-MB native stack configuration are unchanged.

On the integrated pre-change O2 binary, the full upstream exception file stops
at test 16/98 after 3.484 seconds, with `MEMORY_LIMIT` and a sampled family peak
of 2,262,064 KiB. The initial guarded binary completes all 98 tests in 19.136
seconds at 1,103,264 KiB, with no resource limit. Its two failures and one timeout
are compatibility findings, not passing tests. Running those three tests on
the pre-change binary reproduces the same failures/timeout:

- `test_stackoverflow`: re-raised backtrace length differs.
- `test_method_missing_reason_clear`: exception class differs.
- `test_blocking_backtrace`: the test's internal timeout fires.

These measurements use the pinned Mere compiler
`991f299b20f18639713685fe3297e087ddc5b1d7` and the unchanged Ruby source
`3e93b23afcec3433f6aecc34b5d832799d754238`. They describe resource behavior,
not an end-to-end CI speedup or complete exception compatibility.

`corpus/524_recursive_block_depth.rb` compares Ruby's observable outcome for
recursive lambdas, Procs, builtin yields and a Fiber. It also checks recovery
of caller depth, a separately suspended Fiber, finite nested blocks, `next`
and `break`. Recursion depths themselves are implementation-dependent and
are not compared.
