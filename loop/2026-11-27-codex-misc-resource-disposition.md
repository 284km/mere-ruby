# A1/A2: resource-case disposition and shared parser cost

These observations keep the original test counts, assertions and budgets. A timeout is a
resource RED; it does not establish a memory leak. Each original selection runs one file
at a time with clean Ruby 4.0.10 through tools/ref_ruby.sh, MERE_RUBY_GC_TIGHT=1 and
--seed=1. Individual code PRs record their own full evaluator/VM corpus acceptance.

## Completed focused outcomes

| Case | Exact control | Observed result | Disposition |
| --- | --- | --- | --- |
| Hash replace | main 410c2314; Hash snapshot candidate | Reference and candidate both engines: 1 test / 3 assertions PASS; main times out. | The original 676 keys, 10000 warmup dups, 500000 dup/replace operations and 10-second budget are unchanged. This branch fixes the copy-storage cause. |
| Alias | main 410c2314; self-alias candidate | Original test still times out on main and candidate, both engines; reference 1 / 3 PASS. | PR #372 fixes source visibility and redundant self-alias metadata writes. The remaining complete definition/alias/removal throughput is open; the reduced benchmark is not an original-test pass. |
| IO select | detached integration on main 1f782f89 | Reference and integrated candidate both engines: 1 / 3 PASS. | PRs #366 and #367 are merged. The original 50000 interrupts and 60-second budget are unchanged. |
| Syntax invalid symbol | main 89ad241c | Reference and both main engines: 1 / 3 PASS. | The historical timeout no longer reproduces on that control. |

A separate Hash read-door gap appeared in the initial new-fixture sweeps: after an
Array key changes, MERE_RUBY_NO_HASH_INDEX=1 still finds that stored object. Both main
410c2314 and the copy-storage candidate behave identically on both engines; normal
indexed execution matches Ruby. This pre-existing index-off lookup difference remains
open. The copy-storage loop note retains the original reproduction and both failed full
attempts; its revised fixture explicitly rehashes both owners before checking independent
writes. Neither the original Hash resource test nor its assertions or budget changed.

## Ripper: unchanged original resource cases

Exact main 83bc573585b0e73c3266edd2f30fd7d80c2391eb and PR #365 integration candidate
3533171d use ordinary O2, compiler 9dec2ff6 and mgz 661a01d8. Candidate binary SHA-256
is 50624e880c2a3e9f35b24c75ed8b9110db53a78bbac6980df5e0166592d4c97b. All seven selected
resource tests retain their original workload and timeout.

| Original selection | Reference | Main evaluator/VM | Candidate evaluator/VM |
| --- | --- | --- | --- |
| ripper/test_lexer.rb | 1 tests, 3 assertions PASS | original timeout | original timeout |
| ripper/test_parser_events.rb | 2 tests, 9 assertions PASS | original timeout | original timeout |
| ripper/test_ripper.rb | 4 tests, 30 assertions PASS | original timeout | original timeout |

The Ripper no_memory_leak methods stop at their first timed-out two-million-empty-input
subcase. Their later one-million class/lambda subcases are not counted as executed or
passing by this recheck. The Lexer case retains 400000 parses; compile-error and warning
cases retain 100000 and 500000 parses; sexp retains one million parses.

The following RSS values measure the test driver, not the entire child-process family.
They are not independent proof of a leak.

| Driver max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ripper/test_lexer.rb | 22790144 | 217169920 | 217530368 | 217792512 | 218120192 |
| ripper/test_parser_events.rb | 24461312 | 219938816 | 220332032 | 224739328 | 225361920 |
| ripper/test_ripper.rb | 24051712 | 215728128 | 216006656 | 218103808 | 218497024 |

## Measured shared Prism/translation component

A separate diagnostic measures 0 and 1000 real calls in three alternating reference/main
evaluator/main VM runs, using the same tight-GC/seed settings and exact main 83bc5735.
Subtract the median startup/control instructions and divide by 1000. Each endpoint
includes its normal wrappers and Ruby loop calls, so the phases are not a disjoint or
additive decomposition. Startup-subtracted wall times are noisy under shared-machine
load and are not used for this attribution.

The warmed-load control calls Prism.parse once before measurement, enabling the existing
LoaderBytes native node decoder in lib/prism_ext.rb. A cold public Prism.load without
that setup has a different, slower path and is not attributed to the Ripper parse path.

| Diagnostic phase | Reference instructions/call | Main evaluator instructions/call | Main VM instructions/call |
| --- | ---: | ---: | ---: |
| Prism.dump | 5553 | 780177 | 782720 |
| Prism.load after native-adapter setup | 77142 | 3343302 | 3334989 |
| Prism.parse | 29627 | 4076927 | 4097334 |
| Ripper.parse | 15723 | 5566979 | 5591102 |
| Ripper.sexp | 17079 | 5788859 | 5781224 |

| Diagnostic max RSS bytes (maximum of three runs) | Reference | Main evaluator | Main VM |
| --- | ---: | ---: | ---: |
| Prism.dump | 27066368 | 186269696 | 188071936 |
| Prism.load after native-adapter setup | 29147136 | 186204160 | 187940864 |
| Prism.parse | 27738112 | 186400768 | 188121088 |
| Ripper.parse | 27934720 | 186286080 | 187940864 |
| Ripper.sexp | 28327936 | 186187776 | 187957248 |

The result-reconstruction and translation work remains substantial after native node
decoding is enabled. This identifies a shared Prism/AST and runtime performance
component for owner routing. The original Ripper resource REDs remain open; these
diagnostics do not replace their original workloads or claim a complete performance fix.
Functional Ripper scanner/parser corrections remain in their respective PRs.

The Alias workload also intersects the shared validity protocol introduced by stage10 PR
#321: mrec_get reads its record again whenever any method-table epoch changes, and
mro_bump_class uses the global MRO epoch for named owners. Repeatedly defining and
removing named methods therefore invalidates those shared proofs. This is a concrete
cache/record component for the stage10/runtime owner, supported by the existing
lookup/metadata samples; it is not claimed to be the complete cause of the original
timeout.

## Other recorded owner routing

The Addrinfo Marshal resource case has an AST-analysis component: native samples on main
ee9cf5dc show repeated deep_targets, stmt_targets and expr_pat_vars walks. The
source-level detail and actual measurements are posted on PR #243. Preserve the textual
declaration timing exercised by corpus 974; eagerly declaring all method locals would
change block assignment behavior. The complete original Addrinfo resource case remains
open.

The concrete TracePoint mismatch comes from the reference Ruby GC.start wrapper at
<internal:gc>. Mere has a native GC.start builtin and no corresponding Ruby body line.
This source-frame component is recorded for the GC/runtime owner. The three separate
TracePoint resource timeouts are not assigned to that same cause.

ruby/test_bignum.rb test_interrupt_during_to_s passes zero assertions on the clean
reference because Integer::GMP_VERSION triggers its actual early return. Mere decimal
storage returns from to_s before the queued Thread#raise, and its interrupt assertion
fails. Record this representation-dependent native Bignum/interrupt case with the C API
owner. It is not an exercised reference comparison.

The earlier exact-control results and max RSS for those cases are retained in
loop/2026-11-26-codex-misc-unowned-resource-recheck.md on main. No original assertion,
workload, timeout, skip rule or reference installation was changed.
