# Preserve the captured native Method entry

Follow-up to merged PR 340, bot inline 4710023790. The native Proc fast
path incorrectly looks up the saved Method object's public call, allowing
a singleton override to replace the captured computation. The class-wide
guard misses that singleton case. Clean Ruby 4.0.10 returns 3 for all four
entry names; the original candidate returns the replacement on both engines.
The reviewer independently reproduced the same issue on current integration.

Call the existing method_call_native entry directly, as EBoundCall does,
while retaining real callsite exception metadata. Public Method#call
replacements cannot affect this captured entry, so remove the obsolete
class-wide override guard. No source positions or frames are invented.

Corpus 1127 keeps its original 17 rows and adds capture-before/after override,
four Proc entry names, dup/clone, arity metadata, explicit block forwarding
and a class-wide override control. Both-engine reference comparisons,
original related-file selections versus exact pinned main, tight-GC fixed
seed RSS/cost, both full corpus sweeps, gates and completed record hygiene
are recorded below. Code and completed results are pushed together;
no record-only push or full unit/Rails suite.


## Completed focused acceptance and cost

Fresh exact-main and candidate ordinary O2 builds use compiler 9dec2ff6,
mgz 661a01d8 and base 3e84227e3f707e43f7603bf9c40a8db37fd232bd.
Candidate SHA-256 6c24e8f63fca7b6b10f69cdd129bbec458e4de76b73dc82c07e61d9a625ac908;
main fa7040ecdd84b4ed428fc861611a7bb3e752f31497031734e18f17c60d44e74b.
No runtime source changed during either build.

Corpus 1127 matches all 31 rows on both engines, stdout, stderr and status.
Original unchanged selections, fixed --seed=1, all pass on reference,
exact main and candidate, both engines: ErrorHighlight args_OP_ASGN1_aref_2
1 test / 8 assertions; Proc Method/dup/clone 5 / 25; Exception backtrace/cause
8 / 32. The old 17-row fixture remains covered by the expanded program.

| Tight-GC max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ErrorHighlight | 33193984 | 285261824 | 283607040 | 300220416 | 300367872 |
| Proc | 23953408 | 173621248 | 173309952 | 202244096 | 202784768 |
| Exception | 23461888 | 174047232 | 174997504 | 178683904 | 178290688 |

Three alternating main/candidate pairs, identical workload source,
MERE_RUBY_GC_TIGHT=1 and parsed --seed=1. Median hardware instructions;
RSS is the maximum of the three samples in bytes.

| Workload | Evaluator instruction change | VM instruction change | Main/candidate evaluator max RSS | Main/candidate VM max RSS |
| --- | ---: | ---: | --- | --- |
| Ordinary Proc | +0.015% | +0.001% | 74055680 / 74039296 | 75169792 / 75120640 |
| Ruby Method Proc | +0.084% | +0.048% | 87195648 / 87179264 | 93290496 / 93224960 |
| Native Method Proc | -14.930% | -14.489% | 74137600 / 74121216 | 75038720 / 74989568 |
| Native churn | -2.588% | -2.796% | 78626816 / 78626816 | 82558976 / 82542592 |

Ordinary/Ruby Proc medians remain within 0.084%; the native path uses about
14.5-14.9% fewer instructions than merged main. Native churn retains its
existing collection workload and does not retain dead native Proc flags.

## Completed publication acceptance

- sh run_corpus.sh --both: 986/986 PASS, hash index ON/OFF, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: 986/986 PASS, ON/OFF, exit 0.
- Both full sweeps use the same immutable candidate SHA-256 above.
- Eight source gates, generated-C bracket depth, iv_door, full/explicit
  completed record_hygiene and staged/unstaged whitespace checks pass.

Code, expanded regression and completed loop record are submitted together.
No full unit or Rails component suite, workflow change or reference gem
installation was performed.
