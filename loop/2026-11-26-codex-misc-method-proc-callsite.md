# A2: native Method Proc call sites

Start from current main fc646ea7. The prior unchanged semantic probe on
main 8f412f51 shows native method(:raise).to_proc[] adds a synthetic block
frame and loses the real [] callee, so error_highlight cannot select the
index operator write. A Ruby-defined method's own raise frame is already
correct and must remain the innermost frame.

| Cause | Main evaluator and VM | Ruby 4.0.10 |
| --- | --- | --- |
| Native Method proc executes synthetic Ruby forwarder | Duplicate caller frame; missing native call-site callee | Native method enters directly; real caller instruction owns the call. |

Dispatch native Method-backed procs through the existing bound Method call
path. Preserve the actual Proc entry name only for an ArgumentError whose
recorded innermost frame is the current caller, never replacing a Ruby
method's own frame. Do not guess a Prism node or source position. Check
metadata replacement, Ruby bodies, aliases and ordinary/block calls before
full corpus, gates, record hygiene and tight-GC fixed-seed RSS acceptance.

The first build matches all eight direct-call/source-frame corpus rows but
still fails the original argument highlight. A native raise can remain a
class/message pair until a Ruby rescue binds it: the pair accessor cannot
read the currently held frames before that binding. Revision 2 pins the
actual pending exception and its recorded frames before checking the
innermost caller and applying the actual Proc entry name. Revision 1 is not
accepted as a fix for the upstream failure.

Revision 2 passes the unchanged ErrorHighlight args_OP_ASGN1_aref_2 case
(1 test / 8 assertions) and all three selected Proc controls (3 / 13), on
both engines against the clean reference and matching main. Revision 3
keeps that dispatch but reads the native/Ruby provenance already recorded
by Method#to_proc. It removes a source_location Array allocation from each
invocation, including invocations of Ruby-defined Method procs. The empty
filename case remains distinct because a Ruby body's source line still
exists. These intermediate revisions are superseded by the final candidate below.

Revision 3's real three-pair cost run gives a 30-31% instruction reduction
for native Method procs, but adds 1.15-1.28% to ordinary procs and 2.24-2.34%
to Ruby Method procs. Revision 4 rejects those common Ruby-body cases
through their existing cached source line before building/checking the
Method key or inspecting call names. With no arity metadata, a single
empty-table check rejects the new path. Re-measure before acceptance;
these earlier regressions are not silently described as unchanged.

## Current focused acceptance and cost

The final candidate uses an integer-keyed native Method Proc set, populated
only when the retained actual Method has native provenance. Dup/clone copy
the flag; existing Proc collection drops and compacts it. Ordinary and Ruby
Method procs avoid string keys, source-location allocation and Method scans.

Expanded repeated-raise controls found value-equal exception pairs retaining
an earlier raise's frames. Fresh raise_exc now records its own pair frames
after preserving explicit re-raise frames; builtin fixup updates the shared
frame slot only when it still references those same frames. A separately
replaced custom backtrace stays separate. No guessed source location or
Prism node ID is introduced.

All 17 corpus 1127 rows match stdout, stderr and status on evaluator and VM,
including dup/clone, GC, repeated equal messages, retained custom backtraces
and explicit re-raise. Original unchanged file selections, --seed=1:

| Original selection | Reference | Main fc646ea7, both | Candidate, both |
| --- | --- | --- | --- |
| error_highlight args_OP_ASGN1_aref_2 | 1 test / 8 assertions PASS | 1 / 2, one failure | 1 / 8 PASS |
| Proc Method/dup/clone controls | 5 / 25 PASS | 5 / 25 PASS | 5 / 25 PASS |
| Exception backtrace/cause controls | 8 / 32 PASS | 8 / 32 PASS | 8 / 32 PASS |

Three alternating ordinary O2 pairs, tight GC, --seed=1, hardware
instruction median and maximum RSS across all three runs:

| Engine | Workload | Instruction change | Main max RSS bytes | Candidate max RSS bytes |
| --- | --- | ---: | ---: | ---: |
| Evaluator | ordinary | -0.035% | 73252864 | 73269248 |
| VM | ordinary | -0.102% | 74399744 | 74383360 |
| Evaluator | ruby | -0.049% | 87015424 | 87031808 |
| VM | ruby | +0.012% | 89014272 | 88915968 |
| Evaluator | native | -31.723% | 93093888 | 73367552 |
| VM | native | -30.906% | 85737472 | 74268672 |
| Evaluator | native_churn | -7.329% | 78249984 | 78102528 |
| VM | native_churn | -7.330% | 82001920 | 81952768 |

The churn control repeatedly creates native Method procs with explicit GC;
its native-flag set does not retain dead Procs. Original Exception selection
RSS: reference 23216128, main evaluator/VM 176963584/180011008, candidate
179519488/179945472 bytes. The ErrorHighlight and Proc selection maxima
are retained alongside the raw cost measurements.

Current binary SHA-256
8847d9a74fd0ed7e41bc8d16a21020a532f24cde003dc5852e709fbfc0ba9b01.
Compiler 9dec2ff6, mgz 661a01d8. Both complete corpus sweeps pass
967/967 with hash indexing ON and OFF, exit 0, using this same binary.
No intermediate failed revision is counted as accepted.

Additional block-forwarding control: direct native Method Proc call, a
Proc-prepended call wrapper forwarding through super, and plain sqrt all
match reference, matching main and candidate on both engines. No regression
was established and no speculative block-dispatch change was made. The
completed evaluator and VM sweeps both remain valid.


## Completed acceptance

- `sh run_corpus.sh --both`: 967/967 PASS, hash index ON and OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 967/967 PASS, ON/OFF, exit 0.
- Both immutable-binary proofs match the SHA-256 above.
- Eight source gates, generated-C bracket depth, full and explicit loop
  record_hygiene, and staged/unstaged whitespace checks pass.
- Original related-file selections and fixed-seed tight-GC cost/RSS are
  recorded above. No full unit or Rails component suite was run.

Code, fixture, benchmark and this completed record are submitted together
in one push after local acceptance. No workflow change.
