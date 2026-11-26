# A2: preserve live native Ripper lexer context

Base bb24014f07d639cc1af40d2f81b134f3097addb6, clean Ruby 4.0.10
through tools/ref_ruby.sh. The ordinary Prism stream remains unchanged.

| Cause | Parser-owned data | Correction |
| --- | --- | --- |
| Unfinished interpolation inside a heredoc loses its deferred header | Live lex modes, local/parameter scopes, saved header cursor | The private native Ripper parse unwinds the live interpolation and lets existing heredoc EOF recovery resume the real header. |
| A stray right brace uses ordinary brace kind/state | Actual brace nesting and pre-closer lexer state | The private native producer takes CRuby's zero-brace-nesting embedded-expression-end branch before normal stack/state updates. |

Ripper first uses ordinary LexCompat. Only a real heredoc_term diagnostic,
or unexpected_token_ignore at an actual right-brace error slice, selects
private recovery. Internal empty EOF markers flush LexCompat's real buffers
and are then hidden. No substring parse, cloned scope table, guessed token
position or source retokenization is used. The private consumer extracts
the actual LexCompat result method, changes only its native producer and
preserves its lexical constant scope and frozen-string setting.

All 45 generated C/header files, the extracted private consumer and embedded
Ruby regenerate byte for byte from clean reference sources. The four-file
native patch is reproducible. Public Prism controls retain their original
tokens, states and diagnostics.

## Completed focused acceptance

Corpus 1132 matches all 24 rows on both engines: nine unfinished-header
state/token cases, three nested/valid position/text cases and twelve public
Prism controls. Corpus 1133 matches 68 rows at line 1 and 41: fifteen full
Ripper token/state cases, two actual closer-only continuation cases, and
thirty-four full public Prism controls. Stdout, stderr and status match.

Continuation after an invalid closer has a separate existing native-parser
restart difference. For foo } bar the following space is state 1 in Ruby,
2 on main and 32 on this candidate; the corrected closer is state 32.
A following newline is on_nl instead of on_ignored_nl before and after.
CRuby Lexer#parse repeats its native parser, whose program entry resets
lexical state; Prism continues the current parse. The two explicit closer
cases do not claim that restart behavior fixed. No forced BEG state is
inserted to imitate it. An initial exploratory full-continuation attempt
failed on this pre-existing difference and is not counted as acceptance.

Original unchanged ripper/test_lexer.rb cases heredoc_unterminated_interpolation,
heredoc_inside_block_param and trailing_on_embexpr_end, --seed=1, tight GC:
reference and candidate both engines pass 3 tests / 3 assertions; exact
main has 3 / 3 and two failures on both engines. No test assertion,
workload or timeout changed.

| Tight-GC max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original Lexer selections | 22626304 | 225198080 | 224215040 | 223477760 | 225329152 |

Independent archived Scanner CHAR/gvar checks exposed additional gaps in
the separate scanner-diagnostic/percent-word causes. They are not claimed
fixed by this private parser-context change or counted as passing here.

## Measured cost

bench/ripper_lexer_recovery.rb parses --seed=1, seeds srand, and executes
1000 lex calls per workload. Three alternating exact-main/candidate pairs,
ordinary O2, MERE_RUBY_GC_TIGHT=1. Instructions are hardware-count medians;
RSS is the maximum of three runs, in bytes.

| Workload | Evaluator instruction change | VM instruction change | Main/candidate evaluator max RSS | Main/candidate VM max RSS |
| --- | ---: | ---: | --- | --- |
| Empty | -0.031% | +0.128% | 162512896 / 161447936 | 162201600 / 161546240 |
| Ordinary | +0.197% | +0.166% | 216137728 / 214646784 | 206077952 / 206782464 |
| Valid heredoc | -0.027% | +0.092% | 208928768 / 208879616 | 212402176 / 212090880 |
| Valid braces | +0.051% | -0.485% | 245383168 / 225378304 | 217661440 / 233488384 |
| Stray closer | +65.252% | +63.864% | 214581248 / 236093440 | 206159872 / 244056064 |
| Unfinished heredoc | +170.079% | +169.678% | 185663488 / 218365952 | 180240384 / 204472320 |

Empty, ordinary and valid-heredoc instruction ranges overlap on both engines.
Valid-brace ranges do not overlap: evaluator main 56456191098-56511725178,
candidate 56519288282-56534930156 (+0.051% median); VM main
56507248703-56861982803, candidate 56258304104-56284886952 (-0.485%).
All positive medians are reported, not described as zero overhead.

The diagnostic paths perform a real second parse: stray-closer instruction
cost increases about 64-65%, unfinished heredoc about 170%. Unfinished main
yields zero tokens; the candidate yields six actual tokens per call, so
that timing is not a matched-correct-output performance claim. No valid
source selects the private recovery producer.

Current final candidate O2 SHA-256:
dc07cc65f5c2e8f3848d40093a49050f53db7d67a2156b0737584a5d81afa0b6.
Exact main O2 SHA-256:
491b2d5963c3fec9a4be2ad8bdb0ec0f28abc1a1525c0d35818c43eae7992dea.
Compiler 9dec2ff6, mgz 661a01d8. Earlier rejected R1-R4 observations remain
private historical evidence and do not validate this final candidate.

## Completed publication acceptance

`sh run_corpus.sh --both` and `MERE_RUBY_VM=1 sh run_corpus.sh --both`
each pass 979/979 programs, hash index ON/OFF, exit 0. Both binary proofs
match the final O2 SHA above. Eight source gates, generated-C bracket depth,
full/explicit completed record_hygiene and staged/unstaged whitespace pass.
Code, fixtures and completed records are pushed together. No full unit/Rails suite, workflow change,
reference gem installation or unrelated process termination.
