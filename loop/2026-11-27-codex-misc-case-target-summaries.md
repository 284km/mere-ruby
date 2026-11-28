# Cache completed branch target analysis

Executing an already parsed if/when branch repeatedly walked its entire syntax tree to
rediscover local targets. Store that immutable summary once when the branch finishes
parsing. The evaluator still declares names at the same points and in the same text
order. The summary executes no Ruby statement and is omitted from parse-tree/warning
accounting.

Native sampling of the unchanged Addrinfo Marshal sequence identified recurring
deep_targets/whens_targets work. The matching-main instruction and wall-time
measurements are shown below. The original 1000-warmup/20000-load resource test STILL
times out on main and candidate at its unchanged bound: this is an analysis-cost
improvement, not a completed timeout or leak cure. That remaining result is explicitly
retained below.

Corpus 1140 and 974 preserve conditional/eval local declaration timing and branch values
on all four engine/index configurations. Pattern-case parsing/execution is unchanged. An
independent control also reproduces an evaluator-only case/in unexecuted-local gap on
main while its VM matches Ruby; that separate parser/AST issue remains recorded.

Validation main 491cc5ca is merged, including the eval-node, native-argument and GC
changes. Both SBranchTargets and SNodeIds remain known nonexecuting metadata in the
shared parser/implicit-parameter paths. Corpus 1004 from that merge also matches Ruby in
all four engine/index configurations.

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
`491cc5cab7e727606e1b00a141607e4742194d0a`. Corpus 1140 and the related fixtures compare
stdout, stderr and exit status directly.

- `sh run_corpus.sh --both`: **1032/1032 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1032/1032 PASS**, exit 0.

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
| socket/test_addrinfo.rb / /test_marshal\z/ | 22659072 | 157089792 | 157663232 | 159416320 | 159973376 |
| socket/test_addrinfo.rb / /test_marshal_memory_leak\z/ | 22773760 | 157155328 | 163725312 | 159350784 | 162004992 |
| ruby/test_allocation.rb / /test_(array_literal&#124;hash_literal)\z/ | 76988416 | 316243968 | 317734912 | 338411520 | 329285632 |
| ruby/test_proc.rb / /test_implicit_parameters_for_(numparams&#124;it&#124;it_complex&#124;it_and_numparams)\z/ | 23986176 | 164134912 | 164610048 | 198262784 | 198803456 |

The exact original allocation selectors pass 2 tests / 8 assertions on all five
executions, including their current 100000-element Array and 100000-key Hash cases. The
separately timed workloads below retain the requested 100000-element Array and 50000-key
Hash; they are not described as the whole original test file.

Three alternating matching-main/candidate pairs per workload and engine, O2, tight GC
and parsed --seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of
three. Wall time is diagnostic on the shared machine.

The initial VM 50000-key Hash RSS samples varied materially despite tight GC and fixed
seed. One bounded supplement of exactly three additional alternating pairs uses the same
executables, workload and seed. The workload table preserves the original three-pair
results; the supplement table reports every RSS sample and the maximum across all six
per executable. No runs were discarded or repeated until a favorable result, and no leak
cure is claimed.

| VM Hash RSS bytes | Initial three | Additional three | Maximum of all six |
| --- | --- | --- | ---: |
| main | 220741632, 217219072, 222838784 | 222691328, 222855168, 219545600 | 222855168 |
| candidate | 224444416, 282607616, 195641344 | 219299840, 226066432, 214745088 | 282607616 |

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / marshal | -15.820% | 2.682573 / 2.313710 | 123813888 / 123879424 |
| Evaluator / array | +0.283% | 0.247602 / 0.227813 | 145129472 / 145440768 |
| Evaluator / hash | +0.051% | 0.393325 / 0.400801 | 189497344 / 189825024 |
| Evaluator / implicit | -0.316% | 0.271065 / 0.250767 | 72712192 / 73007104 |
| Evaluator / explicit | -0.692% | 0.276862 / 0.181071 | 72695808 / 73007104 |
| VM / marshal | -15.945% | 2.939318 / 2.238504 | 124764160 / 125190144 |
| VM / array | -0.314% | 0.182801 / 0.189278 | 150913024 / 151207936 |
| VM / hash | +0.091% | 9.892419 / 10.654297 | 222838784 / 282607616 |
| VM / implicit | +0.256% | 0.187403 / 0.194430 | 73613312 / 74006528 |
| VM / explicit | +0.139% | 0.157768 / 0.168252 | 73662464 / 73957376 |

Candidate O2 SHA-256:
`2bae4e1f83c2a9ab223ff580b8dcaa7a144e72f3a9b8f5d6bfa767438bd3ea19`. Compiler 9dec2ff6;
mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed record are
pushed together. No workflow change or reference gem installation.
