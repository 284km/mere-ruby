# A1: retain pending Thread interrupts in order

Base current origin/main 1f782f89a2083dacea899ef15c4b31438daf4610.
Reference is clean Ruby 4.0.10 through tools/ref_ruby.sh.

| Cause | Reference | Main, both engines |
| --- | --- | --- |
| A single pending slot overwrites earlier raises and drops a subsequent kill | Queues exception values, selects the first eligible one, and retains later termination | Later raise replaces the first; kill behind a deferred exception is discarded. |

A deterministic Queue handshake holds StandardError under :never, queues
an exception and then requests kill. Ruby finishes the thread; main and
the independent IO-boundary candidate remain alive until explicit cleanup.
A scaled IO reproduction reaches the final kill and then fails to join;
the original select resource test times out at 60 seconds. The IO readiness
boundary is a separate cause and will have its own PR.

Retain the single-value fast path. For multiple interrupts, use an internal
Array rooted by the Thread, preserve order, skip masked entries and release
consumed values. Track the live count/head and compact holes by live count,
including holes behind a permanently masked front. Collapse back to a
single value when only one remains. Thread.pending_interrupt? inspects all
entries. A real kill clears the queue as native Ruby does.

Do not clear remaining interrupts merely because an ordinary exception
ends the thread: an independent reference probe shows pending_interrupt?
still true for the remaining exception. Corpus 1135 covers ordering,
kill after deferral, masked entry selection, compaction with explicit GC,
and that finished-thread query. No forced timing, location or fake memory
counter is used.

## Completed focused and cost checks

Corpus 1135 matches all five output rows, stderr and exit status on
reference and both candidate engines; main differs on both. The unchanged
ruby/test_thread.rb selection passes 8 tests / 20 assertions and the
IO select_timeout control passes 1 / 10 on reference, main and both
candidate engines. No queue-only original resource-test pass is claimed.

Unchanged original selections, one file at a time, MERE_RUBY_GC_TIGHT=1
and fixed --seed=1. Maximum RSS from /usr/bin/time -l:

| Original file / selection | Phase | Engine | Max RSS bytes | Outcome |
| --- | --- | --- | ---: | --- |
| ruby/test_thread.rb / 0 | ref | reference | 23019520 | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 0 | main | evaluator | 168624128 | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 0 | main | VM | 176160768 | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 0 | candidate | evaluator | 167165952 | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 0 | candidate | VM | 174260224 | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 1 | ref | reference | 27164672 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 1 | main | evaluator | 194019328 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 1 | main | VM | 229163008 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 1 | candidate | evaluator | 190431232 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 1 | candidate | VM | 231260160 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |

A detached integration of the separate IO-boundary and pending-queue fixes
uses exact main 1f782f89, without changing the original CRuby resource test.
Corpus 1134 and 1135 match reference stdout/stderr/status on both engines.
The original ruby/test_io.rb test_select_memory_leak retains its 50,000
raises and 60-second limit: reference and integration evaluator/VM each pass
1 test / 3 assertions. Main times out on both engines, 1 test / 0 assertions.
This integration is a focused dependency check, not either PR head's full
corpus result. No timeout or assertion is weakened and no timeout is counted
as a memory leak. Integration O2 SHA-256: 7f8075f526c28e7d6cd7eff0e12145127f963d391536082a5e16863bbd3a7a06.

Unchanged integration resource selection, tight GC and --seed=1:

| Original file / selection | Phase | Engine | Max RSS bytes | Outcome |
| --- | --- | --- | ---: | --- |
| ruby/test_io.rb / 0 | ref | reference | 27328512 | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 0 | main | evaluator | 192086016 | 1 tests, 0 assertions, 0 failures, 1 errors, 0 skips |
| ruby/test_io.rb / 0 | main | VM | 465108992 | 1 tests, 0 assertions, 0 failures, 1 errors, 0 skips |
| ruby/test_io.rb / 0 | candidate | evaluator | 190922752 | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 0 | candidate | VM | 231407616 | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips |

Three alternating ordinary O2 main/candidate pairs, tight GC and parsed
--seed=1. Instructions and seconds are medians; RSS is the maximum
of three samples. Wall times are shared-machine observations.

| Workload | Engine | Main instructions | Candidate instructions | Change | Main seconds | Candidate seconds | Main RSS bytes | Candidate RSS bytes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| plain | evaluator | 1902158228 | 1900116992 | -0.107% | 0.160035 | 0.181439 | 74137600 | 74203136 |
| single | evaluator | 1208986496 | 1208976343 | -0.001% | 0.120547 | 0.127994 | 80904192 | 80871424 |
| burst | evaluator | 1044345640 | 1732497535 | +65.893% | 0.109409 | 0.156292 | 73662464 | 81444864 |
| plain | VM | 1977516796 | 1977652186 | +0.007% | 0.168366 | 0.164276 | 75268096 | 75333632 |
| single | VM | 1242908056 | 1243124621 | +0.017% | 0.125520 | 0.124506 | 87605248 | 87703552 |
| burst | VM | 1054330973 | 1788519865 | +69.636% | 0.114363 | 0.152856 | 77053952 | 91095040 |

| Workload | Engine | Main instruction range | Candidate instruction range |
| --- | --- | ---: | ---: |
| plain | evaluator | 1897774169–1905468494 | 1894245498–1942052786 |
| single | evaluator | 1208552741–1209457854 | 1206671853–1209490111 |
| burst | evaluator | 1039079709–1049157486 | 1728147943–1738715520 |
| plain | VM | 1977021281–1978448090 | 1973626058–1983925318 |
| single | VM | 1242718555–1243803603 | 1242773499–1243183862 |
| burst | VM | 1053710587–1056631180 | 1786953026–1796730929 |

Plain executes 100,000 iterations and single handles 500 interrupts on both
binaries. Burst queues 1,000 interrupts: main incorrectly handles only one,
while the candidate handles all 1,000. Its +65.893% evaluator / +69.636%
VM instruction change therefore includes additional required work; it is
not a comparison of equally correct burst processing. Plain/single medians
and all ranges above are reported without a zero-overhead claim.

Fresh ordinary O2 candidate SHA-256: d0038a173ba6214cb8ed588751f34126ce519d94f9f1aecee2c2df7821f0e6b4.
Pinned compiler 9dec2ff6 and mgz 661a01d8. Build input hashes and immutable
full-sweep binary proofs are retained. Reference: clean Ruby 4.0.10 via
tools/ref_ruby.sh. No full unit/Rails suite, workflow change or reference
gem installation. Each cause has its own PR and full-sweep acceptance.

## Completed publication acceptance

`sh run_corpus.sh --both` and `MERE_RUBY_VM=1 sh run_corpus.sh --both`
each pass 991/991 programs, hash index ON/OFF, exit 0. Both binary proofs
match the immutable O2 SHA recorded above. Eight source gates, generated-C
bracket depth, full/explicit completed record_hygiene and staged/unstaged
whitespace checks pass. Code and completed record are pushed together.
