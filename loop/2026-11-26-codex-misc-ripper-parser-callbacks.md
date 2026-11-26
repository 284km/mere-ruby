# A2: parser callback prefixes, heredocs and ignored newlines

Start from current main 751362a3, independently of the queued Ripper
scanner-diagnostic PR. Record the remaining original-file failures before
changing callbacks:

| Original case | Cause to verify |
| --- | --- |
| ParserEvents#test_blockarg | An invalid parameter after a real BlockParameterNode prevents visiting the already accepted blockarg. Preserve actual parser prefix/event ordering. |
| ParserEvents#test_heredoc | Translation emits the squiggly heredoc callback path only; ordinary and indented heredocs need actual opening/closing token locations and content. |
| ParserEvents#test_ignored_nl | The lexer already owns the ignored newline token; parser callbacks must dispatch that real token. |

First compare event values, order and positions with clean Ruby 4.0.10.
No fabricated nodes, guessed offsets or token retokenization. Related
original-file controls, both corpus sweeps, source gates, record hygiene
and fixed-seed tight-GC RSS are recorded below. No workflow change.

## Focused acceptance

Actual ordinary/indented/empty/quoted/interpolated heredoc opening, content
and closing locations drive callbacks in their native order. Squiggly
heredocs keep their existing path. Parameter-order recovery visits the
actual recovered ParametersNode prefix through the accepted block argument,
then exits before later body events. No fake nodes or source re-tokenizing.
Ignored-newline recovery dispatches the native lexer token only on the
syntax-error path; valid parsing keeps its single parse.

Corpus 1129 has 18 rows, matching stdout, stderr and status on both engines.
Unchanged original ripper/test_parser_events.rb, six selected blockarg,
heredoc and ignored-newline cases, fixed --seed=1 and tight GC: reference
and candidate both engines 6 tests / 43 assertions PASS; main 751362a3
both engines 6 / 36 with three failures.

| Max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original ParserEvents selection | 23838720 | 238010368 | 243744768 | 237387776 | 239747072 |

Ordinary O2 candidate SHA-256
806d6c2d824bbed70e95d19fa0de8f32926b5e39687db5f976777750f0522938,
compiler 9dec2ff6, mgz 661a01d8. Source gates, bracket depth, full and
explicit completed record hygiene and whitespace checks pass.
`sh run_corpus.sh --both` and `MERE_RUBY_VM=1 sh run_corpus.sh --both`
each pass 968/968 programs, hash index ON/OFF, exit 0. Both full-sweep
binary proofs match the immutable O2 SHA above.
