# Cache completed branch target analysis

Executing an already parsed if/when branch repeatedly walked its entire syntax tree to
rediscover local targets. Store that immutable summary once when the branch finishes
parsing. The evaluator still declares names at the same points and in the same text
order. The summary executes no Ruby statement and is omitted from parse-tree/warning
accounting.

Native sampling of the unchanged Addrinfo Marshal sequence identified recurring
deep_targets/whens_targets work. This removes about 16% of Marshal instructions on both
engines. The original 1000-warmup/20000-load resource test STILL times out on main and
candidate at its unchanged bound: this is an analysis-cost improvement, not a completed
timeout or leak cure. That remaining result is explicitly retained below.

Corpus 1140 and 974 preserve conditional/eval local declaration timing and branch values
on all four engine/index configurations. Pattern-case parsing/execution is unchanged. An
independent control also reproduces an evaluator-only case/in unexecuted-local gap on
main while its VM matches Ruby; that separate parser/AST issue remains recorded.

Clean Ruby 4.0.10 through `tools/ref_ruby.sh`; matching main
`61b0c716665b92d1c073366550347e874b41c57d`. Corpus 1140 and the related fixtures compare
stdout, stderr and exit status directly.

- `sh run_corpus.sh --both`: **1028/1028 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1028/1028 PASS**, exit 0.

Original CRuby comparisons below retain the original files, assertions, counts and
budgets. Runs use parsed `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. No full unit or Rails
component suite was run.

| Original file / scope | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| socket/test_addrinfo.rb / /test_marshal\z/ | 1 / 6 PASS | 1 / 6 PASS | 1 / 6 PASS | 1 / 6 PASS | 1 / 6 PASS |
| socket/test_addrinfo.rb / /test_marshal_memory_leak\z/ | 1 / 3 PASS | 1 / 0, 0 failure, 1 error | 1 / 0, 0 failure, 1 error | 1 / 0, 0 failure, 1 error | 1 / 0, 0 failure, 1 error |
| ruby/test_allocation.rb / /test_(array_literal&#124;hash_literal)\z/ | 2 / 8 PASS | 2 / 8 PASS | 2 / 8 PASS | 2 / 8 PASS | 2 / 8 PASS |

RSS is the measured `/usr/bin/time -l` test-driver maximum in bytes.

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| socket/test_addrinfo.rb / /test_marshal\z/ | 22642688 | 156745728 | 157171712 | 159072256 | 159350784 |
| socket/test_addrinfo.rb / /test_marshal_memory_leak\z/ | 22609920 | 156729344 | 177389568 | 164757504 | 178290688 |
| ruby/test_allocation.rb / /test_(array_literal&#124;hash_literal)\z/ | 76070912 | 316129280 | 311443456 | 324386816 | 325615616 |

The exact original allocation selectors pass 2 tests / 8 assertions on all five
executions, including their current 100000-element Array and 100000-key Hash cases. The
separately timed workloads below retain the requested 100000-element Array and 50000-key
Hash; they are not described as the whole original test file.

Three alternating matching-main/candidate pairs per workload and engine, O2, tight GC
and parsed --seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of
three. Wall time is diagnostic on the shared machine.

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / marshal | -15.918% | 2.083445 / 1.639707 | 122896384 / 123387904 |
| Evaluator / array | +0.290% | 0.168224 / 0.178914 | 144982016 / 145244160 |
| Evaluator / hash | -0.217% | 0.355788 / 0.330127 | 189300736 / 189628416 |
| VM / marshal | -16.131% | 2.184906 / 1.923166 | 125845504 / 125812736 |
| VM / array | +0.056% | 0.189309 / 0.180580 | 150683648 / 150994944 |
| VM / hash | +0.045% | 8.022593 / 8.263706 | 285622272 / 282329088 |

Candidate O2 SHA-256:
`cacb0e9a0963c97dd7b4b17d243ae66e4e8881bf4ad5c25f605d72c68014e835`. Compiler 9dec2ff6;
mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed record are
pushed together. No workflow change or reference gem installation.

Publication whitespace check removed one final empty line from corpus 1140 after the
full sweeps. The tested executable and runtime sources are unchanged; the exact pre-edit
fixture and its digest are retained. The full-sweep counts above reuse those executions;
they are not described as an additional rerun after that whitespace-only edit.
