# Preserve actual forwarding and lambda caller identities

A lambda arity refusal lost its actual Proc call name when the definition frame was
added to the backtrace. Keep the invoked entry on the exception only when binding
refuses arguments, then annotate the caller Location separately from the lambda
definition. Ordinary calls gain no catch wrapper or metadata write. A rejected
set_backtrace assignment preserves that identity; a valid replacement clears it.

Index a literal target of send/__send__/public_send/const_get as another name of the
same actual Prism call node. Its existing location remains authoritative; ambiguous or
unrelated nodes still return no id. The original spoofed-filename test remains a
negative control. No source location is fabricated.

Callable === now dispatches its actual entry instead of call, including Method objects
with singleton methods. Replacing Proc/Method#call does not replace its native ===.
Corpus 1142 covers both forms, the caller identities for call/[]/()/yield/===, failures
in the body, GC and rejected backtrace replacement. Embedded Prism is regenerated from
the same clean reference, with no vendor-C change.

Clean Ruby 4.0.10 through `tools/ref_ruby.sh`; matching main
`ad289755a37de94e5faddf61763d49edda849c03`. Corpus 1142 and the related fixtures compare
stdout, stderr and exit status directly.

- `sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.

Original CRuby comparisons below retain the original files, assertions, counts and
budgets. Runs use parsed `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. No full unit or Rails
component suite was run.

| Original file / scope | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| error_highlight/test_error_highlight.rb / full file | 120 / 797 PASS, 1 skip | 120 / 785, 4 failure, 0 error | 120 / 797 PASS, 1 skip | 120 / 785, 4 failure, 0 error | 120 / 797 PASS, 1 skip |
| ruby/test_method.rb / /test_eqq\z/ | 1 / 2 PASS | 1 / 2 PASS | 1 / 2 PASS | 1 / 2 PASS | 1 / 2 PASS |
| ruby/test_proc.rb / /test_(prepended_call&#124;refined_call)\z/ | 2 / 6 PASS | 2 / 6 PASS | 2 / 6 PASS | 2 / 6 PASS | 2 / 6 PASS |
| ruby/test_exception.rb / /test_set_backtrace/ | 1 / 8 PASS | 1 / 8 PASS | 1 / 8 PASS | 1 / 8 PASS | 1 / 8 PASS |

RSS is the measured `/usr/bin/time -l` test-driver maximum in bytes.

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| error_highlight/test_error_highlight.rb / full file | 36241408 | 609501184 | 516702208 | 585367552 | 568541184 |
| ruby/test_method.rb / /test_eqq\z/ | 22724608 | 160874496 | 159694848 | 177815552 | 179650560 |
| ruby/test_proc.rb / /test_(prepended_call&#124;refined_call)\z/ | 24133632 | 163856384 | 163856384 | 197951488 | 198066176 |
| ruby/test_exception.rb / /test_set_backtrace/ | 23068672 | 161759232 | 161759232 | 170164224 | 170115072 |

The entire error_highlight file completes 120 tests / 797 assertions with the same one
skip as reference on each candidate engine; matching main has four failures and 785
assertions on both. Related Method#===, Proc call prepend/refinement and
Exception#set_backtrace selections also pass on both.

Three alternating matching-main/candidate pairs per workload and engine, O2, tight GC
and parsed --seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of
three. Wall time is diagnostic on the shared machine.

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / ordinary | -0.056% | 0.428126 / 0.397466 | 84901888 / 84983808 |
| Evaluator / plain_cases | +0.026% | 0.280181 / 0.270132 | 84967424 / 85032960 |
| Evaluator / arity_errors | -4.186% | 0.192178 / 0.177201 | 96780288 / 93388800 |
| VM / ordinary | -0.007% | 0.491088 / 0.414857 | 85082112 / 85180416 |
| VM / plain_cases | +0.005% | 0.250897 / 0.243296 | 84901888 / 84983808 |
| VM / arity_errors | -4.741% | 0.183395 / 0.169270 | 95830016 / 95322112 |

Candidate O2 SHA-256:
`a8e0311d448e41fd271ea1146e5219c3b3224994f0452e773a8c01f184691846`. Compiler 9dec2ff6;
mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed record are
pushed together. No workflow change or reference gem installation.
