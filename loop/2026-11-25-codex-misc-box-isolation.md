# B13: independent class identities in Ruby boxes

Boxes that define the same displayed class name shared its internal
identity. Every newly defined box-owned class/module now receives its own
internal identity. Qualified lookups follow the box's constant binding,
including aliases, reopening and the VM include path. Outside boxes, a
removed constant starts a fresh identity; ordinary reopening remains the
same class. Registering the new class's lexical scope through the common
path also fixes Timeout::State::GET_TIME when a box requires Timeout.

## Review integration completed

The review of head cd8e47f8 required integration after #262, #285 and #288
changed the class-definition/singleton paths. This revision merges main
f4303e14 and validates the resulting tree with a fresh ordinary O2 build.
Older r6 sweeps are superseded by the following actual r7 results:

- `sh run_corpus.sh --both`: 965/965, hash index ON and OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 965/965, ON and OFF, exit 0.
- Eight source gates, generated-C bracket depth, full and explicit loop
  record_hygiene and staged/unstaged whitespace checks: PASS.

Binary SHA-256:
`7a62b41a2efccd196b46f01c854eebff888ed73ac1e7ca260c110bf0670809a7`.
Compiler 9dec2ff6; mgz 661a01d8. Reference is clean Ruby 4.0.10 selected by
`tools/ref_ruby.sh`. Matching main control is a fresh f4303e14 O2 build.

Requested targeted corpus comparisons match stdout, stderr and status on
both engines: 1112 (14 rows), 1057 (72), 1061 (44), and 1062 (22).
Corpus 1112 also matches on both engines with RUBY_BOX=1; only the exact
reference/candidate executable prefix in the experimental warning is
canonicalized, leaving both warning lines and their text intact.

The unchanged ruby/test_box.rb selections add_constants_in_box,
eval_with_constants, eval_with_classes and
very_basic_method_calls_and_constants pass 4 tests / 53 assertions on
reference and both candidate engines, with RUBY_BOX=1. Main completes only
8 assertions and errors at Timeout::State::GET_TIME on each engine. These
are selected related cases, not a whole-file claim.

Maximum RSS bytes, /usr/bin/time -l, MERE_RUBY_GC_TIGHT=1 and --seed=1:

| Engine | Main f4303e14 | Candidate |
| --- | ---: | ---: |
| Evaluator | 242008064 | 281395200 |
| VM | 255541248 | 279986176 |

The candidate completes 45 more assertions and more stdlib loading, so
this table is not a matched-workload heap-growth comparison. No pass is
claimed for main's error. A1's separate missing Box prelude loaded features
remain outside this class-identity fix; no feature entry is fabricated.

The integration and completed record are pushed together after the local
checks. No full unit or Rails suite, reference gem installation or workflow
change. Main commits after the pinned integration are not claimed tested.

## Review corrections: actual scoped and absolute constant identity

Absolute qualified paths resolve their actual root head and then follow
that receiver's namespace. Relative scoped reads walk actual lexical
identities before textual map-name shortcuts, including lexical autoloads.
An internal anonymous superclass identity from SClassExpr is already a
resolved Class; it is not looked up as a named root constant. The ordinary
non-Box path is unchanged. No guessed constant or cross-Box class sharing.

Expanded corpus 1112 has 29 rows. It and lifetime controls 1057, 1061,
1062 match stdout, stderr and status on both engines. 1112 and lexical
autoload corpus 736 also match with the parent process in RUBY_BOX=1,
evaluator/VM and hash index ON/OFF, including real warning lines.

Unchanged original ruby/test_box.rb, four class/constant selections,
fixed --seed=1 and tight GC: reference and candidate both engines
4 tests / 53 assertions PASS; main f4303e14 both engines 4 / 8, one error.

| Max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original Box selection | 33734656 | 242237440 | 282902528 | 255328256 | 279511040 |

The candidate actually completes all 53 assertions, while main stops
early at the known error, so these are process maxima rather than a
same-workload heap delta. Final ordinary O2 SHA-256 and full corpus
acceptance are recorded after the pending sweeps. Earlier 965 totals
from the pre-review binary do not validate this revision.

## Review correction: public class and module frame labels

The additional Minor is fixed too. Class-body frame labels use the actual
constant-assigned name stored for the internal identity, without invoking
an overridden Module#name. The module/class tag still comes from the actual
identity. Corpus 1112 now has 44 rows, including class/module frame labels,
name, inspect and missing-constant messages, in the main box and two child
boxes. Its stdout, stderr and status match clean Ruby on both engines.
The 1057/1061/1062 lifetime controls pass again, and 1112/736 also match with
RUBY_BOX=1 on both engines and hash indexing ON/OFF.

Unchanged original Box selections still pass 4 tests / 53 assertions on
reference and both candidates; main f4303e14 has 4 / 8 and one error.
Tight GC, --seed=1, max RSS bytes:

| Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| ---: | ---: | ---: | ---: | ---: |
| 33718272 | 241483776 | 281853952 | 255737856 | 277790720 |

Different completed assertion counts mean these are process maxima, not a
same-workload heap-growth claim. Current ordinary O2 SHA-256:
b82c81d6f3153dc78edc2ab1c2be6b11ec3f990b2a143bf31a2047066ecb1bdf.
The r11 sweeps passed 965/965 on both engines before this final label fix;
the following completed r12 acceptance uses the final label-corrected binary.

- `sh run_corpus.sh --both`: 965/965, hash index ON/OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 965/965, ON/OFF, exit 0.
- Eight source gates, generated-C bracket depth, full and explicit loop
  record_hygiene, and whitespace checks: PASS.

All three review corrections, expanded regression and completed record are
pushed together. No full unit/Rails suite or workflow change.

## Follow-up review: eval nesting and bare constant error owners

The new internal-identity registration path now uses with_env_nest on the
actual caller environment before register_class_lex pushes the new class.
This preserves a method or binding's saved lexical identities for string
eval and restores the enclosing nesting when a class body raises. It uses
the same existing scope helper as ordinary class registration.

Bare-constant NameErrors now render the actual owner's stored/display
name, including the BasicObject lookup path. The receiver remains the real
owner identity. The earlier class/module frame-label correction is kept.

Corpus 1112 adds method eval, explicit binding, qualified class opening,
exception restoration and nested bare-constant messages in the main box
and two child boxes. All 68 rows match clean Ruby 4.0.10 on both engines,
including parent RUBY_BOX=1 and hash index ON/OFF. Corpus 1057 (72 rows),
1061 (44), 1062 (22) and parent-Box lexical-autoload corpus 736 also match.
Only the exact executable prefix of the experimental warning is normalized.

Unchanged original ruby/test_box.rb selections pass 4 tests / 53 assertions
on reference and both candidates; matching main f4303e14 has 4 / 8, one
Timeout::State::GET_TIME error. Additional unchanged ruby/test_eval.rb
selections eval_basic, eval_binding_basic, module_eval_string_basic and
instance_eval_string_basic pass 4 / 145 on reference, main and both
candidates. Each file runs separately with RUBY_BOX=1 and --seed=1.

| Tight-GC max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Box four selections | 33947648 | 241631232 | 279216128 | 256229376 | 279592960 |
| Eval four selections | 26017792 | 172769280 | 167084032 | 174637056 | 168984576 |

The Box candidate completes 45 extra assertions and additional library
loading; those process maxima are not a matched-workload growth claim.
Final ordinary O2 SHA-256:
eb761784e8fd2defec956d3d9bb1499c97ec91a7b38d8c018688a46badefb79b.
All eight source gates, bracket depth, full/explicit record_hygiene and
whitespace checks pass before this completed focused-record update.
Final r13 acceptance uses this exact binary:

- sh run_corpus.sh --both: 965/965 PASS, hash index ON/OFF, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: 965/965 PASS, ON/OFF, exit 0.
- All eight source gates and generated-C bracket depth PASS.
- Full and explicit completed-loop record_hygiene and whitespace PASS.

These final r13 sweeps validate the eval-nesting and bare-error corrections;
earlier r12 sweeps remain historical. Code, expanded corpus and completed
record are pushed together. No full unit/Rails suite or workflow change.
