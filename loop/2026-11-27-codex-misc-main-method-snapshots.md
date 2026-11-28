# Captured top-level Method definitions and snapshot collection

A Method captured from a bare top-level definition called its replacement, or raised
after removal. Record its actual Object owner and consult the existing
captured-definition path before the current method table. Captured Methods now retain
the original behavior on both engines.

The review also identified an unbounded lifetime for the newly reachable saved
definitions. Saved bodies and per-definition metadata are now owned by reachable
Method/UnboundMethod objects, rather than by the permanent class. The collector follows
the same original-era boundary as dispatch, including dup, unbind/bind and singleton
classes, and removes unused boundaries after classifying every metadata table.
Temporarily installed definitions remain protected. The existing VM sweep retains its
collection grace before unloading an unused tree. No new global map or GC-root exemption
is added.

Boundary lookup searches the sorted decimal-token byte interval instead of splitting the
complete history for every live Method. This keeps tracing many retained versions from
scanning the entire history once per object. Capturing a retained old definition still
costs a body and per-definition-table snapshot copy; the correctness fix does not remove
that cost.

Corpus 1141 covers replacement/removal/undef, copy/bind, closures and metadata, a
surviving middle-era UnboundMethod with a singleton method, and collection of discarded
saved define_method closures. The collection assertion requires some targets to be
released and does not demand a fixed conservative finalizer count. The exact previous
head fails that release assertion in all four engine/index configurations. Three related
fixtures match Ruby stdout, stderr and exit status in 16 configurations, including GC
stress for 1141. An independent 128-definition probe verifies retained and pruned
intermediate eras on both engines with normal/stress GC.

Clean Ruby 4.0.10 through tools/ref_ruby.sh. Matching-main control and original branch
base 491cc5cab7e727606e1b00a141607e4742194d0a; exact reviewed-head control
eef67010313bc85a0432edda168bab1a56cb12c6. Ordinary O2, pinned compiler 9dec2ff6 and mgz
661a01d8.

- sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.

Original CRuby files, selectors, assertions and resource bounds are unchanged. All
comparisons use MERE_RUBY_GC_TIGHT=1 and parsed --seed=1. No full unit or Rails
component suite was run.

ruby/test_method.rb selection:
`/test_(clone|unbind|method_binding|eqq|super_method.*)\z/`.

ruby/test_alias.rb selection:
`/test_(alias|alias_with_zsuper_method|alias_complemented_method)\z/`.

ruby/test_method.rb selection: `/test_clone_under_gc_compact_stress\z/`.

| Original scope | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| Method behavior | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 89 assertions, 0 failures, 0 errors, 0 skips |
| Alias behavior | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 10 assertions, 0 failures, 0 errors, 0 skips |
| Method clone under GC compact stress | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips |

Measured driver /usr/bin/time -l maxima, bytes:

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Method behavior | 22839296 | 161185792 | 161153024 | 179814400 | 179863552 |
| Alias behavior | 22052864 | 156090368 | 156254208 | 156155904 | 156155904 |
| Method clone under GC compact stress | 23003136 | 161087488 | 161218560 | 179847168 | 180076544 |

Benchmarks use the same committed script, parsed --seed=1 and tight GC. Call performs
10000 captured calls; capture retains 2000 Methods while redefining. Discard captures
and redefines, calls the current definition, drops the Method each turn, collects every
128 iterations and performs ten final collections. Three alternating main/reviewed/fixed
runs are recorded for each discard size and engine. The reference executes the same
workloads three times. Whole-process retired instructions are medians and RSS is the
maximum of all three samples; the individual samples are shown to preserve allocator
variation.

| Engine / workload / iterations | Main / fixed instruction change | Ruby / main / reviewed / fixed max RSS bytes | Fixed RSS samples |
| --- | ---: | --- | --- |
| Evaluator / call / 10000 | +0.466% | 18890752 / 85229568 / — / 85196800 | [85180416, 85147648, 85196800] |
| VM / call / 10000 | +1.273% | 18890752 / 85032960 / — / 85032960 | [85016576, 85032960, 85016576] |
| Evaluator / capture / 2000 | +7.665% | 19496960 / 88178688 / — / 133169152 | [133152768, 133169152, 133103616] |
| VM / capture / 2000 | +7.817% | 19496960 / 87785472 / — / 133939200 | [133332992, 133939200, 133939200] |
| Evaluator / discard / 2000 | +6.302% | 19136512 / 79183872 / 117161984 / 79544320 | [79527936, 79544320, 79544320] |
| VM / discard / 2000 | +4.589% | 19136512 / 84164608 / 116686848 / 84426752 | [84426752, 84410368, 84426752] |
| Evaluator / discard / 8000 | +9.603% | 19038208 / 79167488 / 658505728 / 81362944 | [81362944, 81346560, 81362944] |
| VM / discard / 8000 | +8.527% | 19038208 / 84148224 / 657244160 / 84410368 | [84410368, 84410368, 84410368] |
| Evaluator / discard / 32000 | +12.048% | 19267584 / 99336192 / 6195838976 / 97468416 | [97337344, 97320960, 97468416] |
| VM / discard / 32000 | +10.541% | 19267584 / 106823680 / 6334627840 / 102727680 | [102678528, 102629376, 102727680] |

The retained capture row is intentionally distinct from the discard rows: live Method
objects must preserve their old bodies. The 2000/8000/32000 discard measurements verify
bounded storage after Methods die; they do not claim that retained definitions are free
or that unrelated GC/resource REDs are repaired.

Candidate O2 SHA-256 a66cedeab4acfd981ad9e650b0b30662d23ed865cb0b999444e3dbea83d69e60.
All historical previous-head receipts remain available.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and the completed record are
pushed together. No workflow change or reference gem installation.
