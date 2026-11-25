# Parser follow-up 5: operator method definitions

Branch codex-misc-parser-followups starts from main 323706a7, including
#239. Corpus 991 uses the parser/lexer range; batch B's 1100 range is not
consumed here.

The singleton operator parser left unary @ in the token stream. The
endless definition then took the wrong body path and swallowed subsequent
source. The common operator-name parser now consumes unary operator names
consistently for implicit, explicit and parenthesized receivers. The lexer
also distinguishes a spaced endless = after [] from a []= method name.

Corpus 991 compares -@, +@, !, ~, +, ==, [], and <=>, plus zero-argument
[], in endless and conventional body forms. Each runs inside a class,
on a singleton receiver, and on a parenthesized receiver (54 cases), with
a following-source marker. All 55 output lines match Ruby on both engines.
Conventional body forms remain covered, including the unary singleton
forms. No source positions are fabricated.

## Related unchanged upstream files

| File | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_syntax.rb | 2 tests, 48 assertions, 0 failures, 0 errors, 0 skips | 179535872 | 177225728 | 193675264 | 191660032 |
| ruby/test_method.rb | 1 tests, 4 assertions, 0 failures, 0 errors, 0 skips | 166526976 | 167903232 | 185794560 | 187564032 |

## Validation policy

The reference is the clean pinned Ruby 4.0.10. The unchanged upstream
files above run one file at a time, against main and both candidate engines,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. RSS is max resident bytes from
`/usr/bin/time -l`. No gems are installed into the reference.

The O2 binary uses compiler 9dec2ff6 and mgz 661a01d8. Full acceptance is
running sequentially: `sh run_corpus.sh --both`, followed by
`MERE_RUBY_VM=1 sh run_corpus.sh --both`. Each includes gc_roots,
dup_defs, dead_defs, meth_writes, name_spec, rx_caps, ns_names, name_len
and full record_hygiene. Generated C is checked with
`MR_C=mr.c sh tools/bracket_depth_check.sh`; this loop record is also
checked explicitly with record_hygiene. Focused passing cases are not a
substitute for those pending sweeps. No full unit suite or Rails component
suite was run; no workflow is changed.
