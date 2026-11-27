# CI network contracts: clocks called from non-main Ractors

Base: current origin/main ad289755a37de94e5faddf61763d49edda849c03.
Reference: clean Ruby 4.0.10 through tools/ref_ruby.sh.

| Original CI failure | Observed cause component | Required behavior |
| --- | --- | --- |
| net/http/test_http.rb TestNetHTTPInRactor#test_get | clock_gettime calls a private cache implemented by an ordinary captured Proc. Ractor isolation rejects it. | Clock operations work in non-main Ractors, with no public cache state. |
| net/http/test_https.rb TestNetHTTPS#test_ractor | The same clock-cache refusal occurs while opening the connection. | Preserve the original HTTPS assertions. |
| test_timeout.rb TestTimeout#test_ractor | The timeout watcher reaches the same clock cache. | Preserve the original timeout and Ractor assertions. |

The failed network-Linux artifact from PR 376 records all 450 discovered tests,
with these three REDs. Its Ractor::RemoteError later fails to marshal the Ractor;
the first substantive exception is the clock-cache isolation refusal. This is
not evidence that Ractor exceptions should become generally marshalable.

Construct the frozen private clock tables once during core bootstrap and capture
them with Ractor.shareable_proc. Keep ordinary user Proc isolation checks intact.
Corpus 1138 covers numeric/symbolic clocks, repeated non-main Ractors, GC and
reflection, plus a user closure that must remain rejected.

## Completed acceptance

Clock operations in a non-main Ractor failed after the private clock caches became
captured ordinary Procs. Build the hidden frozen tables once during bootstrap and
capture them with Ractor.shareable_proc; ordinary user closures retain their isolation
checks. This fixes the first error in the three network CI failures rather than making
Ractor objects marshalable to hide the secondary harness error.

Clean Ruby 4.0.10 through `tools/ref_ruby.sh`; matching main
`ad289755a37de94e5faddf61763d49edda849c03`. Corpus 1138 matches stdout, stderr and exit
status in all four engine/index configurations, including ordinary user Proc rejection
and clock argument errors.

- `sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.

Both sweeps use the same O2 candidate and compare hash indexing ON and OFF.

The following original CRuby files were each run in full, one file at a time, unchanged,
with parsed `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. No full unit or Rails component suite
was run.

| Original full file | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| net/http/test_http.rb | 85 / 467 PASS | 85 / 465, 1 failure | 85 / 467 PASS | 85 / 465, 1 failure | 85 / 467 PASS |
| net/http/test_https.rb | 17 / 42 PASS | 17 / 40, 1 failure | 17 / 42 PASS | 17 / 40, 1 failure | 17 / 42 PASS |
| test_timeout.rb | 35 / 90 PASS | 35 / 87, 1 failure | 35 / 90 PASS | 35 / 87, 1 failure | 35 / 90 PASS |

RSS is the measured test-driver maximum from `/usr/bin/time -l`, in bytes. Main stops
assertions in one failing Ractor case in each file; candidate/reference complete those
assertions. The HTTP driver RSS increase is reported rather than presented as an
equal-work memory improvement.

| Driver max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| net/http/test_http.rb | 171540480 | 876380160 | 955678720 | 991772672 | 829063168 |
| net/http/test_https.rb | 38060032 | 538968064 | 546521088 | 557989888 | 564559872 |
| test_timeout.rb | 23232512 | 156286976 | 156286976 | 156205056 | 156073984 |

Ordinary clock hot-path cost: three alternating matching-main/candidate pairs, 10000
clock_gettime calls per invocation, O2, tight GC and parsed --seed=1. Instructions and
elapsed seconds are medians; RSS is the maximum of three. Wall time is diagnostic on the
shared machine.

| Engine | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator | -0.443% | 0.471069 / 0.410326 | 75448320 / 75677696 |
| VM | -0.139% | 0.461144 / 0.434549 | 76660736 / 76808192 |

Candidate O2 SHA-256:
`557e113c8ed35600fc79a1afa20cdc1667642172a31fc007e83fcae1bc182db8`. Compiler 9dec2ff6;
mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and this completed loop
record are pushed together. No workflow change or reference gem installation.
