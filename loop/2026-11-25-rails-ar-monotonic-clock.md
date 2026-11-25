# Rails-2: CLOCK_MONOTONIC is a monotonic clock, not the wall clock

Rails-2 round 4 (activerecord, sqlite3 adapter) lost all 93 MATCH of migration/compatibility_test, which round 3 had.
The file passed on mere-ruby. But one of its lines read:

```
LegacyPrimaryKeyTest::V4_2#test_add_column_with_legacy_primary_key_should_be_integer = -3.35 s = .
```

The runner's pattern does not take a negative time, so the line was not read.
The file then counted 94 tests against a summary of 95 (COUNT_MISMATCH), and every pass in it became UNCONFIRMED.

## The cause

minitest times a test with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`.
mere-ruby's `clock_gettime` read `time()`, the wall clock, for every clock id except the process CPU clock.
The wall clock goes back when the system time is set (NTP), and a monotonic clock never does. The time went back by more than 3 seconds during that test.

## The change

- `tools/process_glue.c` gets `mr_clock_read(kind)`. It reads this platform's own clock for each kind: realtime, monotonic, monotonic raw, uptime raw, thread CPU time, and the two approximate darwin clocks.
  A kind the platform has no clock for falls back to the monotonic clock, never to the wall clock.
- mere-ruby's `CLOCK_` constants are darwin's numbers on every platform (CLOCK_MONOTONIC is 6, where linux's is 1), so the prelude passes the kind, not the number. `Process.__clock_kind` maps the ids and the symbol clocks to it.
- `CLOCK_THREAD_CPUTIME_ID` read the wall clock as well, and now reads the thread's CPU time. The symbol clocks named `*_CLOCK_PROCESS_CPUTIME_ID` read the process CPU clock, as `CLOCK_PROCESS_CPUTIME_ID` already did.
- `:TIME_BASED_CLOCK_REALTIME` is time(2), so it gives whole seconds. `:TIMES_BASED_CLOCK_MONOTONIC` is a monotonic reading cut to hundredths, as times(2) gives on linux.
  (ruby on darwin answers the wall clock there, in hundredths. A monotonic clock is what the name promises.)

## Checked

- corpus/1060 (new): the monotonic clocks are far below the epoch and do not go back; the CPU clocks; the units; the two symbol realtime clocks; EINVAL for an unknown id.
  It names the clocks rather than printing their numbers, and checks the darwin-only clocks only where they exist, so linux's ruby prints the same.
  The result matches ruby on both engines. main fails it: every monotonic clock there is the wall clock.
- `./run_corpus.sh --both`: 946/946, plain and with `MERE_RUBY_VM=1`.
- Gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth, loop_rss.
- migration/compatibility_test run alone in round 4's tree: 95 runs, 213 assertions, 0 failures, 2 skips, all 95 lines read. A clock that goes back cannot be made to happen on demand, so this is the file's health, not the bug.

## Left

- `Process.clock_getres` still answers one microsecond for every numeric clock, as before.
