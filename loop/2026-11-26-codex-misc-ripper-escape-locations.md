# A2: native scanner provenance for Ripper diagnostics

Base main 751362a373089b7e0f9b4f5a5bea24ccbd73900d. Clean Ruby 4.0.10 via tools/ref_ruby.sh.

| Cause | Native parser data | Correction |
| --- | --- | --- |
| Invalid escapes lose scanner range/state or diagnostic callback arguments | Actual escape-read cursors, character entry state and native diagnostic kind | Retain private metadata, split actual consumed token ranges and dispatch the corresponding event without replacing public Prism locations. |

Ripper scanner diagnostics now use parser-owned escape ranges and the actual
character-escape entry state. The native lexer records its real cursors and pre-read
state separately from Prism's public diagnostic fields. Invalid escapes retain their
consumed bytes, callbacks receive the actual token/state/position and appropriate
semantic arguments, and multi-codepoint character literals flush the accepted prefix
and real closing token. Newline word separators follow physical token boundaries.
Public Prism diagnostics and serialization remain unchanged; no source search or
fabricated location/state is used.

Corpus 1122 matches 14 callback/default-handler rows and corpus 1128 matches 56
token/state/public-diagnostic rows on both engines, stdout/stderr/status. Controls
include nested control/meta escapes, multibyte text, Unicode extra codepoints,
argument/parenthesized/array/keyword contexts, subsequent tokens and offset first
lines. The added contexts prevent the earlier fixed-EXPR_BEG mistake.

## Completed focused acceptance

Original unchanged selections, fixed --seed=1 and MERE_RUBY_GC_TIGHT=1, one file at a time:

| Selection | Reference | Exact main 751362a3, both engines | Candidate, both engines |
| --- | --- | --- | --- |
| ripper/test_lexer.rb, 8 cases | 8 tests / 120 assertions PASS | 8 / 85, 4 failures | 8 / 120 PASS |
| ripper/test_scanner_events.rb, 7 cases including CHAR | 7 / 28 PASS | 7 / 19, 6 failures + 1 error | 7 / 28 PASS |
| prism/errors_test.rb, 12 controls | 12 / 24 PASS | 12 / 24 PASS | 12 / 24 PASS |

| Max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Lexer | 23150592 | 223526912 | 226377728 | 225787904 | 225886208 |
| Scanner | 23183360 | 224935936 | 223821824 | 228409344 | 228655104 |
| Prism errors | 32309248 | 221790208 | 222773248 | 221822976 | 223625216 |

## Measured cost

Three alternating exact-main/candidate ordinary O2 pairs, 1000 lex calls per workload,
parsed --seed=1 and MERE_RUBY_GC_TIGHT=1. Hardware instructions use medians; RSS is
the maximum of three samples:

| Workload | Evaluator instruction change | VM instruction change | Main/candidate evaluator max RSS bytes | Main/candidate VM max RSS bytes |
| --- | ---: | ---: | --- | --- |
| empty | +0.992% | +1.049% | 170475520 / 177815552 | 173965312 / 179568640 |
| ordinary | +2.749% | +2.709% | 209338368 / 207896576 | 210337792 / 217677824 |
| unicode | +31.326% | +30.858% | 178323456 / 214990848 | 182124544 / 216383488 |

The remaining common-path costs are about +1.0% for empty and +2.7% for ordinary
lexing, and are reported overhead. Error-only range/cut/position preparation is in a
private cold helper; this reduces R3's empty-lex overhead but does not eliminate
ordinary-lex overhead. Unicode-error work costs about +31%; candidate emits two
correct real tokens where main emits one and performs the native provenance parse, so
that timing does not compare equally correct work. No zero-cost or wall-time
significance claim is made.

## Reproducible provenance and scope

All 45 native C/header files independently regenerate byte for byte from clean Ruby
4.0.10 sources a704b7cd95 using the committed private metadata patch. Embedded Ruby
also regenerates byte for byte, SHA-256
5b02024e23a8098d03349bc1864067deee60368ae4f2660c4784b68eaa081559. Candidate O2 SHA-256
609d7e64a1075a52bd369a7fd0e23bf2f667a4c7c09f2a4516e775c498e00ff3; matching main O2
SHA-256 9dc5f571310ec47247949a8fc900a565ebb8c34eacd175591d9d2a3fa137347c. Compiler
9dec2ff6, mgz 661a01d8. Both full sweeps use that same candidate binary.

The original Scanner gvar expected-Array issue belongs to PR #329's percent-word
correction: real gvar tokens already match the reference, and its exact source probe
matches on both engines with that correction. It is recorded as a separate dependency
and is not counted as a whole-file pass here. Other recovery/parser-event/regexp
causes remain separate PRs.

## Completed publication acceptance

R4 focused, cost and generation checks above are complete.
`sh run_corpus.sh --both` and `MERE_RUBY_VM=1 sh run_corpus.sh --both`
each pass 969/969 programs, hash index ON/OFF, exit 0. Both binary proofs
match the final R4 SHA above. Eight source gates, generated-C bracket depth,
full/explicit completed record hygiene and staged/unstaged whitespace pass.
R2/R3 binaries and observations
remain private historical evidence, and their never-started full sweeps were parked.
Code, fixtures, benchmark and completed records will be pushed together. No full
unit/Rails suite, workflow change, reference gem installation or unrelated process
termination.
