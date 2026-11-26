# A2: validate static Ripper regexps with the actual regexp parser

Branch from actual current main 89ad241c. Initial independent reproduction
used its predecessor 4920ac75, clean Ruby 4.0.10 and
both Mere engines before changing code:

| Original test | Main evaluator / VM | Required cause |
| --- | --- | --- |
| Ripper#test_regexp_with_option, including TestInput | /[\xC0-\xF0]/u has no error; /n correctly has none | Ripper must run the regexp compiler's validation after the parser's static regexp node, beyond Prism's syntax errors. |

The independent event probe also shows invalid byte escapes and invalid
character ranges follow the same missing validation. Use the actual regexp
validator and actual parser-owned closing boundary. Do not evaluate source,
call an overridable Regexp.new, invent AST positions or modify public Prism
diagnostics. Preserve callbacks, return values, error timing and dynamic
regexp behavior. Source warnings and exception state must not leak out of
validation. The parser's existing callback differences for errors already
reported by Prism remain a separate cause, not evidence of success here.

Related original-file comparisons, both corpus sweeps, source gates, record
hygiene and fixed-seed tight-GC RSS remain required. No workflow change.

The shared origin/main ref advanced between fetch and worktree creation.
Git records the actual base as 89ad241c, including the ivar-shape change.
The first build metadata's 4920 label is corrected by explicit provenance;
its measured binary is unchanged. A new exact-base main control and original
file comparison are required before final acceptance.

## Native regexp validation and completed focused checks

The private validation entry point uses the actual regexp compiler checks,
with the actual closing token encoding/options and parser-owned end
location. It creates no Regexp and invokes no overridable Regexp.new.
Scanner callback argument mutation cannot change the original source used
for validation. Callback return values and compile_error/error? timing are
preserved; dynamic interpolated regexps retain their existing path.

Corpus 1131 has 28 output rows matching clean Ruby 4.0.10 on both
engines, including a callback-mutation control. Public Prism diagnostics
remain unchanged. The reference bridge agrees byte-for-byte with native
C_Ripper on all 28 rows. No library is installed into the reference.

Unchanged original ripper/test_ripper.rb selections regexp_with_option,
regexp_enc_error and invalid_multibyte_character_in_regexp, including
TestInput inheritance: reference and candidate pass 6 tests / 28 assertions
on both engines; exact main 89ad241c has 6 / 26, two failures.

Three alternating main/candidate pairs, same fixed srand(1) benchmark
source and MERE_RUBY_GC_TIGHT=1. Instruction medians and maximum RSS:

| Engine | Workload | Instruction change | Main max RSS bytes | Candidate max RSS bytes |
| --- | --- | ---: | ---: | ---: |

| Evaluator | empty | -0.032% | 187662336 | 189628416 |

| Evaluator | sexp | +0.091% | 190103552 | 185810944 |

| Evaluator | regexp | +9.956% | 163774464 | 166625280 |

| Evaluator | regexp_invalid | +10.183% | 163938304 | 166150144 |

| VM | empty | +0.098% | 188956672 | 189005824 |

| VM | sexp | -0.087% | 188841984 | 190529536 |

| VM | regexp | +9.941% | 165052416 | 170803200 |

| VM | regexp_invalid | +10.205% | 164462592 | 163938304 |


Common parse controls are within 0.10%, with overlapping instruction
ranges. The corrected static-regexp workload costs about 10% more for
actual validation and callback state; that cost is reported explicitly.
The visitor reads existing parser end_line/end_column instead of allocating
a copied Location. Wall-clock observations on this shared machine are not
a significance claim.


Ordinary O2 binary SHA-256: dc73efa358f5d88767bd34047d9c5c54a9351c5ac34a7195d11c5f3dac29eac9.
Compiler 9dec2ff6; mgz 661a01d8.

Completed full-sweep acceptance on the immutable O2 binary above:
`sh run_corpus.sh --both` and `MERE_RUBY_VM=1 sh run_corpus.sh --both`
each pass 973/973 programs, hash index ON/OFF, exit 0. Eight source gates,
generated-C bracket depth, full/explicit completed record hygiene and
staged/unstaged whitespace checks pass. Original-file results above are
selected cases rather than a whole-file pass.
