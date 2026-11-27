# A1: original resource cases on a pinned main control

These are focused reproductions of the archived RED inventory, not fixes or
whole-file passes. Main is 89ad241c, ordinary O2 with Mere 9dec2ff6 and mgz
661a01d8. Its binary SHA-256 is
c163ca7b882964e3010f4d7ca619914fc3e338524043c85531bebb117587be27.
Reference is clean Ruby 4.0.10 via tools/ref_ruby.sh. Every original case
keeps its original workload and timeout, uses MERE_RUBY_GC_TIGHT=1 and
--seed=1, and runs one file at a time. A timeout does not establish a leak.

| Original selection | Reference tests/assertions | Main evaluator and VM | Disposition |
| --- | --- | --- | --- |
| ruby/test_alias.rb test_alias_memory_leak | 1/3 PASS | 1/0, original 10-second child timeout | Still a resource RED; inspect actual repeated method/alias work before assigning a leak cause. |
| ruby/test_hash.rb test_replace_memory_leak | 1/3 PASS | 1/0, original 10-second child timeout | Still a resource RED; repeated dup/replace creates and drops native indexes and pair storage. Source reading is not a measured cost attribution. |
| ruby/test_io.rb test_select_memory_leak | 1/3 PASS | 1/0, original 60-second child timeout | Still a resource RED; blocking/interrupt behavior requires separate diagnosis. |
| ruby/test_syntax.rb test_invalid_symbol_in_hash_memory_leak | 1/3 PASS | 1/3 PASS on both engines | Historical timeout no longer reproduces on this main control. |
| socket/test_addrinfo.rb test_marshal_memory_leak | 1/3 PASS | 1/0, original 10-second child timeout | Still a resource RED; do not infer a Marshal leak from the timeout. |
| ruby/test_settracefunc.rb four related cases | 4/15 PASS | 4/2, one failure and three original child timeouts | Keep the concrete GC frame mismatch separate from resource errors. |
| ruby/test_bignum.rb test_interrupt_during_to_s | 1/0 PASS by native GMP early return | 1/1, one failure on both engines | Representation-dependent test; the reference never exercises its interrupt assertion. |

TracePoint selections are lots_of_enabled_tracepoints_ractor_gc,
tp_ractor_local_untargeted, tracepoint_bmethod_memory_leak and
tracepoint_memory_leak. The concrete failure is the expected single line
event from the reference's actual Ruby GC.start wrapper, <internal:gc>.
Mere executes GC.start as a native builtin, with no Ruby body line to emit.
Its existing TracePoint dispatcher already checks the creating Ractor.
Do not fabricate a line event or a source location to satisfy this test.
The native GC wrapper/source-frame cause is recorded for the GC/runtime
owner; the three timeouts are not claimed to have that same cause.

The genuine isolated Integer test extension was supplied on each side for
the Bignum selection. The first attempt loaded no tests and was rejected.
The actual reference defines Integer::GMP_VERSION and immediately returns
from this test, completing zero assertions. Mere stores this large value
in decimal form and returns from to_s before the queued Thread#raise;
its assertion expects RuntimeError and fails. This is not an exercised
reference comparison or evidence of a memory leak. Record the native
Bignum representation/interrupt test with the C API owner; never add a
fake GMP_VERSION, an artificial delay or a test-specific exception.

Maximum resident set size bytes from /usr/bin/time -l, with the same tight
GC and seed settings. Child-spawning timeout rows report the measured test
driver process only; they are not a complete process-family leak measure.

| Selection | Reference | Main evaluator | Main VM |
| --- | ---: | ---: | ---: |
| Alias | 22200320 | 228917248 | 250789888 |
| Hash replace | 86130688 | 170442752 | 185778176 |
| IO select | 27066368 | 191365120 | 433586176 |
| Syntax invalid symbol | 23412736 | 174014464 | 189480960 |
| Addrinfo marshal | 22757376 | 169476096 | 179535872 |
| TracePoint selections | 24412160 | 215711744 | 224526336 |
| Bignum interrupt | 22478848 | 176357376 | 179027968 |

No assertion, workload size, timeout, skip rule or reference installation
was changed. Full unit and Rails component suites were not run.


## Follow-up attribution on exact main ee9cf5dc

An independent verified O2 snapshot, compiler 9dec2ff6 and mgz 661a01d8,
uses SHA-256 94dd4c3e662ca569d5c5c7d5b5320cdf81e1263f4ac626f73ab199fb09fbbe89.
Separate scaled diagnostic workloads retain keyword self-alias operations,
676-key Hash dup/replace and real Addrinfo Marshal loading. They do not
replace the original tests, change their counts or extend their budgets.
Every output checksum matches clean Ruby, on both engines. Each timing
is a single observation including startup, not an alternating-pair
performance claim or evidence of a leak. Tight GC and parsed --seed=1.

| Diagnostic workload | Count | Reference seconds | Main evaluator seconds | Main VM seconds | Main evaluator/VM max RSS bytes |
| --- | ---: | ---: | ---: | ---: | --- |
| alias | 1000 | 0.0613 | 0.3020 | 0.3284 | 117702656 / 120979456 |
| alias | 10000 | 0.0795 | 0.5577 | 0.6122 | 117587968 / 121028608 |
| hash_dup | 100 | 0.0684 | 0.3497 | 0.2980 | 123666432 / 124895232 |
| hash_dup | 1000 | 0.0669 | 0.3927 | 0.3765 | 139362304 / 139788288 |
| hash_replace | 100 | 0.0720 | 0.2959 | 0.2946 | 132120576 / 132612096 |
| hash_replace | 1000 | 0.0674 | 0.4296 | 0.3958 | 131956736 / 132694016 |
| addrinfo | 1000 | 0.1019 | 2.1929 | 2.2055 | 169295872 / 167657472 |
| addrinfo | 5000 | 0.0816 | 9.6538 | 9.6758 | 201605120 / 200638464 |

Native samples use separate evaluator runs, never mixed into timing data.
They show allocation/value copying and collection in Hash dup/replace,
method lookup and metadata work in aliasing, and repeated deep_targets,
stmt_targets and expr_pat_vars walks during Addrinfo Marshal decoding.
The samples include waiting helper threads; their ulock_wait entries are
not attributed to application-thread blocking, and recursive stack counts
are not percentages.

The Addrinfo workload identifies an AST-analysis performance component.
run_if intentionally declares skipped-branch targets in textual order:
predeclaring all method locals early can change which variable a block
assignment updates (the existing ActiveRecord/corpus 974 case). Static
per-branch target metadata must preserve that timing and actual scope,
rather than replacing scans with an eager whole-scope declaration. Record
that component for the AST stream. The complete original resource failure
remains open until an unchanged original test passes; other costs are not
assigned or claimed fixed by this sample.

A separate deterministic IO probe finds that even a ready zero-timeout
IO.select must be a real blocking interrupt boundary: reference catches
the queued on_blocking exception at select, while both main engines return
from select and deliver it later. This is now under an independent runtime
fix and corpus 1134. Its independent pending-Thread-interrupt queue cause
is covered by corpus 1135. A later detached integration on main 1f782f89
passes the unchanged original test_select_memory_leak on both engines:
1 test / 3 assertions with tight GC and --seed=1, the original 50,000 raises
and 60-second limit. Reference also passes; main times out on both engines.
The IO-only head still times out because it lacks the queue correction.
Queue and IO-boundary fixes have separate PRs and head-specific corpus
acceptance. A timeout is not counted as evidence of a leak.
