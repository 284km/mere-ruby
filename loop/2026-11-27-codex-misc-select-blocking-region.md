# A1: ready IO.select retains its native blocking boundary

Base current origin/main 817c3f5839369511f8fc9f6d3e1e86c0538f5639.
Reference is clean Ruby 4.0.10 through tools/ref_ruby.sh.

| Cause | Reference evidence | Main reproduction |
| --- | --- | --- |
| A ready IO.select skips the blocking boundary | io.c uses rb_thread_fd_select and BLOCKING_REGION even for ready descriptors and zero timeout. | A queued :on_blocking exception is delivered after select, on both engines. |

A deterministic Queue handshake puts the real pending exception in place
before entering :on_blocking. Reference reports caught_at_select; exact
ee9cf5dc main reports returned_from_select then delivered_late on both
engines. Current branch base has the same relevant select/poll path.

The original test_io select resource case repeatedly waits for the worker
to enter that blocking operation before raising into it. It remains a
resource RED until an unchanged original run demonstrates otherwise.
No leak claim follows from its timeout. Verify actual wait observability,
mask behavior and unrelated nonblocking operations before treating the
missing boundary as its complete cause.

Plan: preserve the actual IO.select polling boundary in the cooperative
scheduler, check its pending blocking interrupts, and restore wait state
on normal return and exception. Keep ordinary nonblocking readiness probes
on their existing path. No fake sleep duration or test-specific exception.

## Completed focused and cost checks

Corpus 1134 matches all seven rows, stderr and exit status on both engines.
Unchanged IO select_timeout passes 1 / 10 and Thread select/interrupt
controls pass 5 / 14 on reference, main and candidate. The IO-only head
still times out on the unchanged select_memory_leak case on both engines;
it needs the independent pending-queue fix as demonstrated below.

Unchanged original selections, one file at a time, MERE_RUBY_GC_TIGHT=1
and fixed --seed=1. Maximum RSS from /usr/bin/time -l:

| Original file / selection | Phase | Engine | Max RSS bytes | Outcome |
| --- | --- | --- | ---: | --- |
| ruby/test_io.rb / 0 | ref | reference | 26820608 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 0 | main | evaluator | 190791680 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 0 | main | VM | 229720064 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 0 | candidate | evaluator | 192888832 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 0 | candidate | VM | 231243776 | 1 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 1 | ref | reference | 22888448 | 5 tests, 14 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 1 | main | evaluator | 168001536 | 5 tests, 14 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 1 | main | VM | 176488448 | 5 tests, 14 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 1 | candidate | evaluator | 167723008 | 5 tests, 14 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_thread.rb / 1 | candidate | VM | 178225152 | 5 tests, 14 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 2 | ref | reference | 27115520 | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_io.rb / 2 | main | evaluator | 190627840 | 1 tests, 0 assertions, 0 failures, 1 errors, 0 skips |
| ruby/test_io.rb / 2 | main | VM | 290471936 | 1 tests, 0 assertions, 0 failures, 1 errors, 0 skips |
| ruby/test_io.rb / 2 | candidate | evaluator | 189857792 | 1 tests, 0 assertions, 0 failures, 1 errors, 0 skips |
| ruby/test_io.rb / 2 | candidate | VM | 265453568 | 1 tests, 0 assertions, 0 failures, 1 errors, 0 skips |

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
| ready | evaluator | 2022966617 | 2028858920 | +0.291% | 0.213584 | 0.216254 | 78594048 | 78479360 |
| thread_ready | evaluator | 2113439273 | 2122780242 | +0.442% | 0.219491 | 0.224242 | 80297984 | 80232448 |
| nonblock | evaluator | 1874907318 | 1870820557 | -0.218% | 0.199833 | 0.186761 | 74088448 | 74022912 |
| ready | VM | 2001379806 | 2014096592 | +0.635% | 0.198383 | 0.216652 | 79495168 | 79462400 |
| thread_ready | VM | 2110160541 | 2115700132 | +0.263% | 0.240362 | 0.224177 | 81018880 | 80936960 |
| nonblock | VM | 1870282859 | 1868780582 | -0.080% | 0.189965 | 0.179643 | 74743808 | 74629120 |

| Workload | Engine | Main instruction range | Candidate instruction range |
| --- | --- | ---: | ---: |
| ready | evaluator | 2022297558–2069455416 | 2026589998–2028865566 |
| thread_ready | evaluator | 2113249707–2115408458 | 2121745613–2127647449 |
| nonblock | evaluator | 1873792373–1881090148 | 1869893707–1877444423 |
| ready | VM | 1997396388–2013166683 | 2008316926–2017967705 |
| thread_ready | VM | 2107278440–2117556620 | 2112731441–2133400129 |
| nonblock | VM | 1867165639–1872885218 | 1867167210–1869509312 |

The ready and thread_ready workloads each perform 1,000 selects; nonblock
performs 1,000 ordinary readiness operations. The measured ready-select
instruction overhead is +0.291% evaluator / +0.635% VM, with the ranges
shown above. Nonblocking operations retain their original polling path.

Fresh ordinary O2 candidate SHA-256: 39c88f758753f6488e511c29cb7ab13139208b88490e2c506d08b3af4f58e9e0.
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
