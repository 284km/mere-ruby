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

The review regression is fixed: SBranchTargets is recognized as a known nonexecuting
statement by ip_slots_known_stmt. Cached metadata no longer causes the fallback that
binds nine unused implicit argument slots. A returned child Proc therefore does not
retain every unused argument from its parent frame.

Corpus 1140 now retains 100 returned child Procs while checking both if and unless
factories over 30 explicit GC cycles. It requires that unused arguments can be collected
and that an actually used _1 remains alive. Positive finalizer counts are deliberately
not fixed because collection is conservative. The new checks match Ruby in evaluator/VM,
Hash index on/off, under both normal and tight GC. The reviewed head still fails the
evaluator retention check; matching main and its VM pass.

Clean Ruby 4.0.10 through `tools/ref_ruby.sh`; matching main
`e433affa596f582782b1c6932811a6461619faca`. Corpus 1140 and the related fixtures compare
stdout, stderr and exit status directly.

- `sh run_corpus.sh --both`: **1030/1030 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1030/1030 PASS**, exit 0.

Original CRuby comparisons below retain the original files, assertions, counts and
budgets. Runs use parsed `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. No full unit or Rails
component suite was run.

| Original file / scope | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| socket/test_addrinfo.rb / /test_marshal\z/ | 1 / 6 PASS | 1 / 6 PASS | 1 / 6 PASS | 1 / 6 PASS | 1 / 6 PASS |
| socket/test_addrinfo.rb / /test_marshal_memory_leak\z/ | 1 / 3 PASS | 1 / 0, 0 failure, 1 error | 1 / 0, 0 failure, 1 error | 1 / 0, 0 failure, 1 error | 1 / 0, 0 failure, 1 error |
| ruby/test_allocation.rb / /test_(array_literal&#124;hash_literal)\z/ | 2 / 8 PASS | 2 / 8 PASS | 2 / 8 PASS | 2 / 8 PASS | 2 / 8 PASS |
| ruby/test_proc.rb / /test_implicit_parameters_for_(numparams&#124;it&#124;it_complex&#124;it_and_numparams)\z/ | 4 / 114 PASS | 4 / 114 PASS | 4 / 114 PASS | 4 / 114 PASS | 4 / 114 PASS |

RSS is the measured `/usr/bin/time -l` test-driver maximum in bytes.

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| socket/test_addrinfo.rb / /test_marshal\z/ | 22495232 | 156893184 | 157319168 | 159154176 | 159842304 |
| socket/test_addrinfo.rb / /test_marshal_memory_leak\z/ | 22757376 | 156844032 | 157204480 | 159072256 | 159629312 |
| ruby/test_allocation.rb / /test_(array_literal&#124;hash_literal)\z/ | 77922304 | 312737792 | 320307200 | 317145088 | 319045632 |
| ruby/test_proc.rb / /test_implicit_parameters_for_(numparams&#124;it&#124;it_complex&#124;it_and_numparams)\z/ | 23904256 | 163807232 | 164282368 | 197902336 | 198754304 |

The exact original allocation selectors pass 2 tests / 8 assertions on all five
executions, including their current 100000-element Array and 100000-key Hash cases. The
separately timed workloads below retain the requested 100000-element Array and 50000-key
Hash; they are not described as the whole original test file.

Three alternating matching-main/candidate pairs per workload and engine, O2, tight GC
and parsed --seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of
three. Wall time is diagnostic on the shared machine.

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / marshal | -15.948% | 2.824941 / 2.366505 | 123305984 / 123502592 |
| Evaluator / array | +0.082% | 0.205081 / 0.195396 | 145080320 / 145424384 |
| Evaluator / hash | +0.011% | 0.400090 / 0.387504 | 189448192 / 189775872 |
| Evaluator / implicit | -0.293% | 0.152212 / 0.143201 | 72646656 / 72990720 |
| Evaluator / explicit | -0.444% | 0.137277 / 0.126076 | 72630272 / 72974336 |
| VM / marshal | -15.957% | 2.907847 / 2.752451 | 126779392 / 125845504 |
| VM / array | +0.223% | 0.239305 / 0.240541 | 150798336 / 151224320 |
| VM / hash | -0.100% | 8.801873 / 9.041113 | 283049984 / 284819456 |
| VM / implicit | +0.074% | 0.153948 / 0.148155 | 73547776 / 73973760 |
| VM / explicit | +0.388% | 0.142643 / 0.159003 | 73564160 / 73973760 |

Candidate O2 SHA-256:
`b866d8a990bf5cbd8513d5bd47f1b13292e9b73a2ab4284a840aa46a47b7cf99`. Compiler 9dec2ff6;
mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed record are
pushed together. No workflow change or reference gem installation.
