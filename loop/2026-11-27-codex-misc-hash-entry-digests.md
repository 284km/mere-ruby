# Stored entry digests for the independent Hash walk

With the Hash index disabled, looking up an Array or Hash key after it changed compared
its current value with the stored key object and incorrectly found the entry. A copy
also lost the original stored digest if the key changed before dup or replace. Retain a
native stored digest per mutable-key entry, preserve those associations in copies, and
update them deliberately on rehash.

The disabled-index path continues to walk actual pairs and reads its value from that
walk. The enabled path obtains its value from the index after validating the stored
entry. Metadata holds native strings only, with recyclable arenas reclaimed at
collection; it does not root Ruby keys. Immutable-key shared-copy storage retains its
existing representation.

Clean Ruby 4.0.10 through `tools/ref_ruby.sh`; matching main
`ad289755a37de94e5faddf61763d49edda849c03`. Corpus 1139 covers mutations before/after
copy, separate rehashing, repeated entries sharing the same key object,
overwrites/deletion, identity mode, custom hash protocol and GC. Mutable-key oracle
cases use tables larger than the small CRuby tables that use eight-bit hash hints,
avoiding process-random identity matches after mutation. Corpora 1139, 1137, 493, 1051
and 288 match stdout, stderr and exit status in all four engine/index configurations:
20/20 executions.

- `sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.

Original CRuby `ruby/test_hash.rb` selections, unchanged, with parsed `--seed=1` and
`MERE_RUBY_GC_TIGHT=1`: functional rehash/key-tampering/shift/dup/clone/replace cases
pass 12 tests / 72 assertions on reference, matching-main evaluator/VM and candidate
evaluator/VM. The original replace memory case also passes 1 test / 3 assertions on all
five executions, retaining its 676 keys, 10000 warmup operations, 500000 replacements
and original time/memory bounds. These are selected cases, not a complete test-file
rerun. No full unit or Rails component suite was run.

RSS is the measured test-driver maximum from `/usr/bin/time -l`, in bytes.

| Original selection driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Functional selections | 22937600 | 161021952 | 161136640 | 180191232 | 180436992 |
| Original replace memory case | 86228992 | 159891456 | 160088064 | 179879936 | 180224000 |

Hot-path cost: three alternating matching-main/candidate pairs per workload and engine,
O2, tight GC, parsed --seed=1. Instructions and seconds are medians; RSS is the maximum
of three. Ordinary reads use 100000 operations; the other workloads use 10000. Wall
times are diagnostic on the shared machine.

| Engine / workload | Instructions | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / read | +0.267% | 0.350357 / 0.354599 | 75317248 / 76283904 |
| Evaluator / write | +0.320% | 0.125224 / 0.130181 | 73072640 / 74055680 |
| Evaluator / small_dup | +0.353% | 0.129945 / 0.129328 | 88965120 / 85032960 |
| Evaluator / large_dup | +0.572% | 0.136094 / 0.130776 | 74989568 / 75907072 |
| Evaluator / mutable_read | +5.482% | 0.135576 / 0.138483 | 83427328 / 85049344 |
| Evaluator / churn | +12.590% | 0.233972 / 0.270725 | 104087552 / 101302272 |
| VM / read | +0.335% | 0.357824 / 0.395604 | 76578816 / 77512704 |
| VM / write | +0.380% | 0.126703 / 0.130184 | 74235904 / 75218944 |
| VM / small_dup | +0.551% | 0.124602 / 0.124231 | 81494016 / 82493440 |
| VM / large_dup | +0.587% | 0.123587 / 0.122855 | 76316672 / 77070336 |
| VM / mutable_read | +5.601% | 0.130887 / 0.150285 | 83312640 / 84934656 |
| VM / churn | +11.995% | 0.232630 / 0.282682 | 104677376 / 102039552 |

Mutable-key reads cost about 5.5% more instructions and mutable-key
creation/copy/mutation churn about 12% more; this is reported explicitly as the cost of
retaining per-entry digest associations. The ordinary immutable-key paths change by less
than 0.6% instructions in these runs. Metadata increases the ordinary-process RSS by
roughly 1 MB; the churn workload uses less maximum RSS than main.

Candidate O2 SHA-256:
`c12bdfe95cc91ca86b229f2a65fe2cff348c6a3a64cd81dcc100ed024720dd79`. Compiler 9dec2ff6;
mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed loop record are
pushed together. No workflow change or reference gem installation.
