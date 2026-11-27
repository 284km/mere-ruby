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

## R5: completed acceptance

Ripper scanner diagnostics preserve native escape spans and entry states. The
integration merges main 83bc5735, retaining its parser callbacks, regexp diagnostics and
real heredoc/stray-closer recovery before scanner diagnostic preparation. Both private
native patches compose in tools/gen_prism_src.sh, and the embedded Prism library is
regenerated.

Fresh local acceptance uses clean Ruby 4.0.10 through tools/ref_ruby.sh. The two full
sweeps use the same freshly built O2 candidate, with hash indexing ON and OFF.

- `sh run_corpus.sh --both`: **1007/1007 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1007/1007 PASS**, exit 0.

Focused corpus 1122, 1128, 1129, 1131, 1132 and 1133 matches the reference on both
engines (stdout, stderr and exit status). Related original CRuby selections are run
unchanged, one file at a time, against the exact matching main 83bc5735. Every
invocation uses `MERE_RUBY_GC_TIGHT=1` and parsed `--seed=1`. The selected test counts
below do not claim whole-file or full-suite passes.

| Original selection | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| ripper/test_lexer.rb (8 selected) | 8 / 120 PASS | 8 / 85, 4 failures, 0 errors | 8 / 120 PASS | 8 / 85, 4 failures, 0 errors | 8 / 120 PASS |
| ripper/test_scanner_events.rb (8 selected) | 8 / 33 PASS | 8 / 24, 6 failures, 1 errors | 8 / 33 PASS | 8 / 24, 6 failures, 1 errors | 8 / 33 PASS |
| prism/errors_test.rb (12 selected) | 12 / 24 PASS | 12 / 24 PASS | 12 / 24 PASS | 12 / 24 PASS | 12 / 24 PASS |
| ripper/test_parser_events.rb (6 selected) | 6 / 43 PASS | 6 / 43 PASS | 6 / 43 PASS | 6 / 43 PASS | 6 / 43 PASS |
| ripper/test_ripper.rb (6 selected) | 6 / 28 PASS | 6 / 28 PASS | 6 / 28 PASS | 6 / 28 PASS | 6 / 28 PASS |
| ripper/test_lexer.rb (3 selected) | 3 / 3 PASS | 3 / 3 PASS | 3 / 3 PASS | 3 / 3 PASS | 3 / 3 PASS |

RSS values below are measured maximum resident set sizes of the test driver from
`/usr/bin/time -l`, in bytes.

| Max RSS bytes, same selections | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ripper/test_lexer.rb (8 selected) | 23248896 | 217006080 | 217513984 | 217989120 | 218202112 |
| ripper/test_scanner_events.rb (8 selected) | 22986752 | 216776704 | 217169920 | 218611712 | 219037696 |
| prism/errors_test.rb (12 selected) | 32063488 | 214876160 | 214876160 | 216154112 | 216137728 |
| ripper/test_parser_events.rb (6 selected) | 23691264 | 231653376 | 232079360 | 229523456 | 231915520 |
| ripper/test_ripper.rb (6 selected) | 23265280 | 215744512 | 215990272 | 217972736 | 218447872 |
| ripper/test_lexer.rb (3 selected) | 22790144 | 216891392 | 217382912 | 217858048 | 218202112 |

Cost measurements use three alternating main/candidate O2 pairs, tight GC and parsed
--seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of three
runs. Elapsed time is diagnostic under shared-machine load.

| Workload / engine | Instruction change | Main / candidate median seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| empty / evaluator | +1.260% | 1.338116 / 1.294365 | 161333248 / 170901504 |
| ordinary / evaluator | +2.809% | 4.657606 / 4.792197 | 196149248 / 200245248 |
| unicode / evaluator | +31.164% | 2.130855 / 2.904689 | 168640512 / 197099520 |
| empty / VM | +1.162% | 1.363333 / 1.270333 | 161480704 / 169639936 |
| ordinary / VM | +3.617% | 4.829633 / 4.954055 | 211206144 / 205635584 |
| unicode / VM | +31.603% | 2.150624 / 3.018820 | 175341568 / 196050944 |

Each scanner benchmark performs 1000 lex calls. Common-path empty/ordinary overhead
remains and is reported above. The Unicode-error candidate emits two correct tokens
where main emits one and performs native provenance parsing; those measurements include
additional required work and do not compare equally correct outputs.

Additional composition probes combine real escape errors with unterminated/terminated
heredocs and either side of a stray right brace. Two complete heredoc/Unicode/hex rows
match the reference on both engines; all seven complete without a crash. Main and
published-R4 comparisons retain known follow-ups in generic stray-closer message
wording, squiggly-heredoc indentation during error recovery, and splitting a Unicode
character after a stray closer. The remaining five rows are not counted as full
reference matches, and no new integration regression was identified by these
comparisons.

The seven original resource cases were also repeated unchanged with tight GC and
--seed=1 on the matching main and this candidate. They retain their original counts,
assertions and timeouts: reference passes, and both main and candidate time out on both
engines. These are open throughput/resource REDs, not new regressions, measured leak
diagnoses or claimed fixes. The no_memory_leak methods stop at their first timed-out
empty-input subcase; later class/lambda subcases are not claimed executed.

| Original resource selection | Reference tests/assertions | Main and candidate, both engines | Reference / main evaluator / candidate evaluator / main VM / candidate VM max RSS bytes |
| --- | --- | --- | --- |
| ripper/test_lexer.rb | 1 / 3 PASS | original timeout | 22790144 / 217169920 / 217530368 / 217792512 / 218120192 |
| ripper/test_parser_events.rb | 2 / 9 PASS | original timeout | 24461312 / 219938816 / 220332032 / 224739328 / 225361920 |
| ripper/test_ripper.rb | 4 / 30 PASS | original timeout | 24051712 / 215728128 / 216006656 / 218103808 / 218497024 |

Resource RSS is the measured test driver only, rather than a process-family leak
measure. Functional selections above pass all selected assertions; the resource timeouts
remain explicitly separate.

All 45 native C/header files independently regenerate byte for byte from clean Ruby
sources a704b7cd95 with both private adaptations. The extracted reference LexCompat
consumer and embedded library also regenerate byte for byte. Embedded SHA-256:
`8392125e4cd2f34537b4f6c3594b4841450ccb2bc22a8a169be706b051802df4`.

Candidate O2 SHA-256:
`50624e880c2a3e9f35b24c75ed8b9110db53a78bbac6980df5e0166592d4c97b`. Matching-main
control: 83bc573585b0e73c3266edd2f30fd7d80c2391eb. Compiler 9dec2ff6, mgz 661a01d8.

Eight source gates (gc_roots, dup_defs, dead_defs, meth_writes, name_spec, rx_caps,
ns_names, name_len), generated-C bracket depth, full/explicit completed record_hygiene
and staged/unstaged whitespace: PASS. Code/integration and the completed loop record are
pushed together. No full unit/Rails suite, reference gem installation or workflow
change.
