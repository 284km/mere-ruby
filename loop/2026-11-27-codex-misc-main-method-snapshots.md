# Retain the definition captured by a top-level Method

A Method captured from main could silently call a replacement definition instead of the
definition it captured. For example, capture a one-argument top-level method, redefine
it with no arguments, then call the captured Method with one argument: main raises
ArgumentError, while Ruby 4.0.10 and this change call the old body.

Record the actual Object owner when constructing a Method for a top-level definition, so
the existing snapshot mechanism preserves it on replacement/removal. The main-receiver
call path checks the retained snapshot before looking up the current bare method. The
existing snapshot and GC machinery is reused; no method-cache or MRO-epoch optimization
is included.

Corpus 1141 checks old definitions across replacement, GC, dup, unbind/bind,
remove_method and undef_method, plus alias/visibility/closure metadata controls. Corpora
1141, 831 and 1136 match Ruby stdout, stderr and exit status in both engines with the
Hash index on and off (12/12 executions). The short regression also fails on the
matching current-main control and passes on reference and both candidate engines.

Clean Ruby 4.0.10 through tools/ref_ruby.sh. Branch base
491cc5cab7e727606e1b00a141607e4742194d0a; matching-main O2 control is built from the
exact same main revision, including the merged forwarding-highlight, prelude-Ractor and
eval-node-frame changes.

- sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.

An earlier evaluator attempt against main ffff8b77 stopped at the outer watchdog while
the clean reference Ruby waited in the FIFO readlines of corpus 498. Its exit 125 and
native sample are preserved. The results above are complete sweeps of this main
integration; no partial or waived result is counted.

Related original CRuby selections are unchanged, with MERE_RUBY_GC_TIGHT=1 and parsed
--seed=1. These are focused cases, not a complete file or suite. No full unit or Rails
component suite was run.

Original selection in ruby/test_method.rb:
`/test_(clone|unbind|method_binding|eqq|super_method.*)\z/`.

Original selection in ruby/test_alias.rb:
`/test_(alias|alias_with_zsuper_method|alias_complemented_method)\z/`.

| Original file / scope | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| ruby/test_method.rb | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_alias.rb | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips |

Measured /usr/bin/time -l maxima in bytes:

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ruby/test_method.rb | 22708224 | 162316288 | 161202176 | 179961856 | 180060160 |
| ruby/test_alias.rb | 22102016 | 156205056 | 156237824 | 156221440 | 156254208 |

Three alternating matching-main/candidate pairs, O2, tight GC and parsed --seed=1. Call
uses 10000 ordinary calls through a captured top-level Method. Capture retains 2000
Methods while replacing the ordinary top-level def, then collects. Instructions and
seconds are medians; RSS is the maximum of three.

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / call | +0.377% | 0.232816 / 0.218979 | 85229568 / 85262336 |
| Evaluator / capture | +5.505% | 0.238049 / 0.288761 | 88113152 / 131481600 |
| VM / call | +0.315% | 0.201469 / 0.191645 | 85049344 / 85131264 |
| VM / capture | +3.880% | 0.327302 / 0.270184 | 87900160 / 131219456 |

Retaining old top-level definitions has a measured cost, shown in the table. Main did
not retain these definitions correctly; the capture workload deliberately keeps all 2000
Method objects alive. No leak or timeout cure is claimed, and no original resource bound
is changed.

Candidate O2 SHA-256 324bcc0b07ae08035466ea46f6da7b15c8753afc39d8fa5e0a36e58585cc7632;
compiler 9dec2ff6, mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed record are
pushed together. No workflow change or reference gem installation.
