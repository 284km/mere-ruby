# A2: implicit missing calls on primitive self

Branch starts from current main 94424798. The actual-frame probe on main
8f412f51 reproduces NoMethodError for nil/String instance_eval bare calls
where clean Ruby 4.0.10 raises NameError; Object already matches. Both
engines have this difference. The unchanged error_highlight cases are
VCALL_2 and spoofed_filename. This table precedes implementation.

| Cause | Current route | Required behavior |
| --- | --- | --- |
| Bare primitive self loses vcall context | prim_self_send reaches explicit native missing-method dispatch | Preserve vcall only for the terminal missing call; explicit foo()/self.foo stay NoMethodError. |

Reuse the existing class/module native vcall guard rather than changing
exception classes after arbitrary calls. A valid builtin's nested failure
must retain its own receiver/name/type; custom method_missing and super
must preserve normal dispatch. No invented parser position is involved.
Reference/candidate matrix, original upstream selections, tight GC fixed
seed max RSS, both complete corpus sweeps and all gates remain pending.


## First candidate and user method_missing control

The first O2 candidate matches 79 of 80 fixture rows, but loses vcall
context when a primitive's user-defined method_missing calls super. It
correctly fixes the ordinary bare calls and retains parenthesized-call
NoMethodError. This failed candidate is not acceptance. The primitive
method_missing dispatch must pass the already consumed native call context
through mm_priv, exactly as the class/module path does. Rebuild a separate
r2 binary and repeat every fixture/control before any full acceptance.

Revision 2 matches all 80 corpus rows, including method_missing super, but
the unchanged upstream selection still has two failures. VCALL_2 reveals
that undef_call_exc's nil sentinel loses the actual receiver and message;
revision 3 preserves nil as the real receiver at this native raise site.
The spoofed-filename case is a separate existing backtrace/source identity
problem: main fails both cases, and the new NameError exposes its spurious
highlight. It remains recorded, not counted as a vcall pass.

Revision 3 also exposed an unchanged Object#method_missing control failure:
main and candidate both left the preceding bare name's reason in mm_priv,
so Array#flatten's unrelated to_ary conversion raised NameError. Revision 4
clears that reason at the terminal native bare-name raise, after its trace
callbacks. An added conversion-after-rescue corpus row checks isolation.

For the newly exposed spoofed filename error, the backtrace helper now
requires a recorded callee to match a real Prism call/name node. A file's
unrelated constant is never a fallback for a known missing method. This
narrows existing matching and adds no guessed location or node choice.

## Completed revision 4 focused acceptance and cost

Corpus 1124 matches all 82 rows, stderr and exit status on both engines.
The unchanged error_highlight VCALL_2, spoofed_filename and FCALL_1/2
selection passes 4 tests / 26 assertions on reference and both candidate
engines. The unchanged Object method_missing control passes 1 / 5 on all
candidate/reference runs. Main fails both VCALL/spoofed cases and the
conversion-after-rescue Object control; the earlier unresolved-failure
notes above describe rejected revisions, not revision 4.

Candidate ordinary O2 SHA-256:
`78dba04489b6d8cd020c66c281e69d6c9bc46f236d758e2f1e50f9cb8ad6b7b9`.
Matching main 68fee417 has exactly the native runtime source of branch base
94424798 (the intervening change is a loop design note). The repeated
related-file runs and cost measurements below use that matching build.
Tight GC and fixed --seed=1; maximum RSS in bytes:

| Original file | Phase | Engine | Max RSS | Outcome |
| --- | --- | --- | ---: | --- |
| `error_highlight/test_error_highlight.rb` | main | evaluator | 377847808 | 4 tests, 20 assertions, 2 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | main | VM | 365395968 | 4 tests, 20 assertions, 2 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | evaluator | 351272960 | 4 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | VM | 376733696 | 4 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_object.rb` | main | evaluator | 169525248 | 1 tests, 5 assertions, 1 failures, 0 errors, 0 skips |
| `ruby/test_object.rb` | main | VM | 172277760 | 1 tests, 5 assertions, 1 failures, 0 errors, 0 skips |
| `ruby/test_object.rb` | candidate | evaluator | 168116224 | 1 tests, 5 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_object.rb` | candidate | VM | 174997504 | 1 tests, 5 assertions, 0 failures, 0 errors, 0 skips |

Three alternating pairs per workload/engine, the same benchmark source,
ordinary binaries, MERE_RUBY_GC_TIGHT=1 and fixed --seed=1. Instruction
changes use medians, elapsed observations use medians, RSS uses maxima:

| Workload | Engine | Main instructions | Candidate instructions | Delta | Main sec | Candidate sec | Main RSS | Candidate RSS |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| integer | evaluator | 8913139271 | 8915311052 | +0.024% | 0.720 | 0.720 | 107282432 | 107364352 |
| integer | VM | 4994545713 | 4996452268 | +0.038% | 0.372 | 0.375 | 112263168 | 112246784 |
| float | evaluator | 11058975295 | 11086056003 | +0.245% | 0.785 | 0.884 | 107249664 | 107331584 |
| float | VM | 5956774455 | 5947471624 | -0.156% | 0.415 | 0.420 | 112459776 | 112476160 |
| string | evaluator | 5129621105 | 5145377586 | +0.307% | 0.450 | 0.477 | 93077504 | 93093888 |
| string | VM | 4280378421 | 4293898080 | +0.316% | 0.312 | 0.383 | 93437952 | 93487104 |
| array | evaluator | 5199705773 | 5196154663 | -0.068% | 0.411 | 0.429 | 107233280 | 107266048 |
| array | VM | 3775156777 | 3771269837 | -0.103% | 0.270 | 0.280 | 103940096 | 103858176 |
| encoding | evaluator | 2588002229 | 2589825673 | +0.070% | 0.214 | 0.226 | 81772544 | 81788928 |
| encoding | VM | 2341446561 | 2332861939 | -0.367% | 0.210 | 0.219 | 82591744 | 82608128 |

## Completed publication acceptance

- `sh run_corpus.sh --both`: 964/964 PASS, hash index ON/OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 964/964 PASS, ON/OFF, exit 0.
- Both immutable binary proofs match the final R4 SHA-256 above.
- Eight source gates, generated-C bracket depth, full and explicit completed
  record_hygiene and staged/unstaged whitespace checks pass.

Code, fixture, benchmark and completed record are pushed together after
local acceptance. No full unit/Rails suite, workflow change or reference
gem installation. These checks do not claim integration acceptance for
later main runtime revisions.


## R5 current-main integration

PR343 exposed a prospective conflict with main
 ee9cf5dc7044092e97f6e86aca0ec58fa5b1d741. Preserve main's real
arg_splat_scoped entry wrapper and apply the primitive bare-call context
handling inside invoke_val_c0_raw. Both corrections are needed; no argument
scope or missing-call metadata is dropped. R4's completed 964 sweeps remain
historical acceptance. Fresh R5 build, matching-main original selections,
cost/RSS, full corpus and gates are required before the next code push.


### Completed R5 focused and cost checks

A missing bare call on primitive self now raises NameError with the actual receiver
and vcall context; explicit and parenthesized calls retain NoMethodError. User
method_missing/super dispatch remains effective, and a consumed missing-call reason
cannot leak into a later conversion. Known callees must match a real Prism call/name
node, fixing the spoofed-filename highlight without choosing an unrelated constant.

The integration preserves main's arg_splat_scoped entry wrapper and applies the
bare-call handling inside invoke_val_c0_raw. Corpus 1124 matches all 82 rows, stderr
and exit status on both engines. Unchanged original error_highlight VCALL_2,
spoofed_filename and FCALL_1/2 selections pass 4 tests / 26 assertions on reference
and candidate; ruby/test_object.rb method_missing passes 1 / 5. Exact main ee9cf5dc
has two ErrorHighlight failures and one Object failure, on both engines. One file at a
time, fixed --seed=1.

Maximum RSS bytes, original unchanged file selections, MERE_RUBY_GC_TIGHT=1 and --seed=1:

| Selection | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ErrorHighlight | 34062336 | 350781440 | 322355200 | 341966848 | 393216000 |
| Object | 22085632 | 165052416 | 165724160 | 167936000 | 169951232 |

Three alternating matching-main/candidate ordinary O2 pairs, same benchmark source,
MERE_RUBY_GC_TIGHT=1 and parsed --seed=1. Hardware instructions and seconds are
medians; RSS is the maximum of three samples:

| Workload | Engine | Main instructions | Candidate instructions | Change | Main seconds | Candidate seconds | Main RSS bytes | Candidate RSS bytes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| integer | evaluator | 8939077620 | 8930098197 | -0.100% | 0.662 | 0.668 | 108068864 | 107970560 |
| integer | VM | 4998110961 | 4994668132 | -0.069% | 0.346 | 0.336 | 113115136 | 113000448 |
| float | evaluator | 11089777175 | 11091823882 | +0.018% | 0.768 | 0.775 | 108068864 | 107954176 |
| float | VM | 5959931092 | 5958957107 | -0.016% | 0.386 | 0.385 | 130121728 | 113246208 |
| string | evaluator | 5167572451 | 5198807169 | +0.604% | 0.421 | 0.427 | 93208576 | 93224960 |
| string | VM | 4281429462 | 4296426513 | +0.350% | 0.322 | 0.322 | 94175232 | 94191616 |
| array | evaluator | 5240514380 | 5237270887 | -0.062% | 0.388 | 0.391 | 108019712 | 107905024 |
| array | VM | 3803355226 | 3802854019 | -0.013% | 0.270 | 0.261 | 104693760 | 104710144 |
| encoding | evaluator | 2630478465 | 2627717578 | -0.105% | 0.213 | 0.219 | 82378752 | 82264064 |
| encoding | VM | 2335125857 | 2342224804 | +0.304% | 0.181 | 0.189 | 83263488 | 83263488 |

All instruction medians are reported. In particular, String is +0.604% on the
evaluator and +0.350% on the VM; these are measured overhead, without a claim of zero
cost. Shared-machine wall times are observations.

Candidate O2 SHA-256 a7b8ece15f818296b385f6c893f98209afdb1feb5ccf430652b2db2146147dcb;
matching main SHA-256
94dd4c3e662ca569d5c5c7d5b5320cdf81e1263f4ac626f73ab199fb09fbbe89. The candidate was
freshly built after integration with exact main
ee9cf5dc7044092e97f6e86aca0ec58fa5b1d741. The matching-main executable was reused only
after verifying all 2706 tracked regular source files against that commit before and
after its immutable snapshot, the mgz inputs, original successful O2 build record,
compiler 9dec2ff6 and executable SHA. This is a verified build reuse, not a new main
build. Both full sweeps use the same candidate binary.

### Completed R5 publication acceptance

- `sh run_corpus.sh --both`: 989/989 PASS, hash index ON/OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 989/989 PASS, ON/OFF, exit 0.
- Both immutable binary proofs match the R5 SHA-256 recorded above.
- Eight source gates, generated-C bracket depth, embedded Ruby regeneration,
  full/explicit completed record_hygiene and whitespace checks pass.

The integration code and completed record are pushed together. These results
validate the pinned ee9cf5dc integration; R4 results remain historical.
