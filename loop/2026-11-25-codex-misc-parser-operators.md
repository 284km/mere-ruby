# Parser follow-up 5: operator method definitions

The branch starts from main 323706a7 and integrates main fd5f54b0.
A singleton unary operator left its @ token unconsumed, so an endless
definition swallowed the following source. The common operator-name parser
now consumes the actual name consistently for implicit, explicit and
parenthesized receivers. It also distinguishes a spaced endless = after
[] from a []= method name. Main's spaced & and ~@/!@ normalization remain.
No source position is fabricated.

Corpus 991 covers -@, +@, !, ~, +, ==, [], <=>, zero-argument [], !@, ~@,
and & in both endless and conventional definitions, for all three receiver
forms. Its 72 cases plus the following-source marker give 73 output lines
matching clean Ruby 4.0.10 on evaluator and VM. Existing corpus 1059 adds
24 matching lines for the native ~@ naming control.

## Completed acceptance

- `sh run_corpus.sh --both`: 949/949, hash index ON and OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 949/949, ON and OFF, exit 0.
- gc_roots, dup_defs, dead_defs, meth_writes, name_spec, rx_caps,
  ns_names and name_len: PASS. Generated-C bracket depth: PASS.
- Full and explicit loop record_hygiene, staged and unstaged diff checks:
  PASS on the completed record and source changes.

Ordinary O2, compiler 9dec2ff6, mgz 661a01d8; binary SHA-256
`e27a69c3ca69bb4007d482c2400240456566062bb71e6615b360ffccabc3800a`.
Reference: `tools/ref_ruby.sh`, clean Ruby 4.0.10 (a704b7cd95).
Related original CRuby files were checked one file at a time, unchanged,
with `MERE_RUBY_GC_TIGHT=1` and `--seed=1`. Reference, main fd5f54b0,
and candidate pass every selected case on both engines. RSS is maximum
resident bytes from `/usr/bin/time -l`:

| Original file / selection | Result on each engine | Main eval RSS | Main VM RSS | Candidate eval RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| `ruby/test_syntax.rb` | 2 tests / 48 assertions | 175456256 | 191725568 | 176308224 | 192380928 |
| `ruby/test_method.rb` | 1 test / 4 assertions | 170147840 | 186318848 | 169246720 | 187006976 |

Syntax selects test_methoddef_endless*; Method selects test_singleton_method.
These are selected related cases, not whole-file or full-suite claims.
No full unit suite, Rails component suite, reference gem installation or
workflow change. The completed record is committed with the integration
and expanded regression fixture in one push.
