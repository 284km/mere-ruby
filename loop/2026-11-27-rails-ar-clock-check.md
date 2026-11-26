# The CLOCK_ constants read once, and Module#constants' tables given back

After #351, a probe in activerecord's tree (insert 16,384 citations with `insert_all`, then `Citation.preload(:reference_of).to_a`) still kept far more than ruby: 1,287 MB after the preload where ruby is near 100 MB.
A `--region-sites` build named two lines for 323 MB of the default region: `main.mere`'s `Module#constants` arm, `let tmp = map_new ()` and `let seen = map_new ()`.

## Who called constants

A build that printed the receiver and the Ruby line on every call of that arm: 12,770 calls of `Process.constants` from `<internal:prelude>`, for 4,096 rows.
The prelude's `Process.__clock_check` answered whether an Integer clock is valid with `Process.constants.any? { |k| k.start_with?("CLOCK_") && Process.const_get(k) == c }` -- on every `clock_gettime(Process::CLOCK_MONOTONIC)`.
ActiveSupport::Notifications reads the clock around every query.

`Module#constants` walks the whole constant table, and its two tables were made in the default region, which is never given back: every call left tables the size of what it read.
(TracePoint's `:c_call` does not fire for that arm, and `Module.prepend` of a `constants` that calls `super` fails with "no superclass method" for Process -- neither could be used to find the caller.)

## The change

- The prelude reads the CLOCK_ numbers once (`Process.__clock_ints`, a frozen Array in an instance variable, as `__clock_sym_res` already was).
- `Module#constants`' two tables live in `region CONSTS` and die with the call. What it answers -- an Array of Symbols -- is copied out of the region by `arr_new`, as any value stored into arr_store is.
- `tools/loop_rss_check.rb` gets both loops: `Process.constants` 20,000 times, `clock_gettime(Process::CLOCK_MONOTONIC)` 100,000 times.
- Corpus 1071: the clocks, an invalid one, a `#to_int` clock, and what `constants` answers kept across `GC.start` and later calls.

## Checked

Built with the Mere CI uses (9dec2ff6).

| | main | this |
|---|---|---|
| loop_rss `Module#constants` | 2.88 (FAIL) | 1.02 |
| loop_rss `clock_gettime with a CLOCK_ number` | 6.20 (FAIL) | 1.01 |
| 10,000 `clock_gettime(CLOCK_MONOTONIC)`, instructions | 7.34 G | 4.24 G |
| ...max RSS | 189 MB | 71 MB |
| the probe at 16,384 rows (with #351), RSS after the preload | 1,287 MB | 845 MB |

All 14 loop_rss cases pass. clock_gettime's answers and errors are unchanged; two messages differ from ruby on main and here alike (a Float clock is named truncated, nil is "NilClass").

What this does not change: eager_test's `test_preloading_too_many_ids`. Its peak footprint is 2.77 GB with #351 and 2.83 GB with this as well.
Its rows come from the citations fixture, and the fixture load is the peak: `Psych.unsafe_load` of the 65,536 rows takes 342 s of the load's 394 s, and after it and a `GC.start` the process holds 1.7 GB (ruby 202 MB).

## The corpus

On main 3fbe3921, with `MERE_RUBY_SHAPES_CHECK=1`: 994/994 on the evaluator and on the VM, the hash index on and off (1071 among them).
