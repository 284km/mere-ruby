# Stored digests and actual values for native mutable Hash entries

Mutable Array/Hash keys need a stored digest for each entry: comparing a changed key
with the stored key object alone incorrectly finds it in the disabled-index walk, and
recomputing digests on copy changes lookup membership. Preserve the native stored-entry
associations across copies and rehashing.

Both review findings are fixed. Native mutable-key hits update the selected actual pair;
subsequent key mutation cannot undo the assignment. Distinct entries can retain the same
historical digest, so their values remain authoritative in the actual pairs on both
lookup paths. Settling an immutable-key overwrite does not copy one mutable entry value
over another. Deletion keeps an indexed digest while another entry still uses it and
points the cache at an actual remaining value.

Index membership is checked before settling or walking pairs. A new immutable key in a
hash containing a mutable key therefore keeps the indexed miss path. Only a mutable-key
hit requires entry verification. Group-by lookups use the same verified native entry.
Metadata contains native strings, not Ruby handles; its arenas are recycled after
collection.

Related Hash-key consistency: canonical digests sort whole encoded Hash pairs, and
native Hash-key equality compares keys/values without depending on pair order, with
recursive guards and the original empty/identity-mode rules. Array element order remains
significant. Equal numeric values with different eql? types remain different keys. Main
already had a distinct-Hash ordering gap; the earlier review iteration additionally
regressed lookup after reordering a stored Hash key. Both baseline results are retained
rather than attributed entirely to this PR.

Validation main 491cc5cab7e727606e1b00a141607e4742194d0a is merged. Clean Ruby 4.0.10
through tools/ref_ruby.sh; matching-main O2 control is built from that same main
revision. Corpus 1139 includes overwrite-before-mutation, duplicate historical digests,
values/copy settlement, restore/delete/overwrite/rehash, mutable group-by keys, Hash
pair order, nested containers, identity mode, numeric equality and GC. Nine related
corpus files match stdout, stderr and exit status in all four engine/index
configurations: 36/36.

- sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.

An earlier VM sweep was interrupted around an explicit user pause at corpus 335, with
native exit 143 and overall exit 1. Its log and receipt remain preserved. The complete
VM result above uses a separate fresh retry with the same executable and source digests;
the interrupted run is not acceptance.

Original CRuby ruby/test_hash.rb selections below are unchanged and use
MERE_RUBY_GC_TIGHT=1 and parsed --seed=1. The replace resource case retains 676 keys,
10000 warmup operations, 500000 replacements and its original time/memory bounds. These
are selected cases, not a whole-file or full-suite run. No reference gems were
installed.

Original functional selection in ruby/test_hash.rb:
`/test_(rehash|s_AREF_key_tampering|shift|dup|clone|replace)\z/`.

Original original replace resource selection in ruby/test_hash.rb:
`/test_replace_memory_leak\z/`.

Original key equality selection in ruby/test_hash.rb:
`/test_(eql|hash_hash|recursive_key|dup_equality)\z/`.

| Original scope | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| Functional | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips |
| Original replace resource | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips |
| Key equality | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips |

Measured /usr/bin/time -l maxima, in bytes:

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Functional | 23003136 | 130875392 | 129482752 | 140656640 | 144343040 |
| Original replace resource | 86163456 | 129073152 | 131448832 | 140574720 | 142278656 |
| Key equality | 23035904 | 134299648 | 161300480 | 180322304 | 180109312 |

Whole-process cost: three alternating main/candidate pairs per workload and engine, O2,
tight GC and parsed --seed=1. Retired instructions and elapsed seconds are medians; RSS
is the maximum of three. Ordinary reads use 100000 operations; mutable/copy workloads
use 10000, and growth workloads use 4000. Shared-machine wall times are diagnostic.

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / read | +0.122% | 0.624384 / 0.647115 | 75595776 / 76496896 |
| Evaluator / write | -0.628% | 0.253868 / 0.254427 | 73367552 / 74203136 |
| Evaluator / small_dup | +0.149% | 0.170036 / 0.418605 | 80642048 / 81494016 |
| Evaluator / large_dup | +0.157% | 0.214396 / 0.337366 | 75251712 / 76021760 |
| Evaluator / mutable_read | -0.116% | 0.264211 / 0.185757 | 86016000 / 86867968 |
| Evaluator / mutable_write | +2.620% | 0.346119 / 0.206707 | 86573056 / 87785472 |
| Evaluator / hash_key_read | +0.511% | 0.225602 / 0.228810 | 85917696 / 86769664 |
| Evaluator / churn | +10.075% | 0.372304 / 0.417312 | 105611264 / 101089280 |
| Evaluator / mixed_growth | +0.406% | 0.193160 / 0.198703 | 86360064 / 87064576 |
| Evaluator / immutable_growth | -0.117% | 0.169609 / 0.160253 | 86376448 / 86966272 |
| VM / read | +0.043% | 0.537017 / 0.447213 | 76742656 / 77676544 |
| VM / write | -0.152% | 0.189722 / 0.324422 | 74465280 / 75366400 |
| VM / small_dup | +0.132% | 0.252573 / 0.218331 | 81903616 / 82903040 |
| VM / large_dup | +0.197% | 0.277343 / 0.264551 | 76398592 / 77234176 |
| VM / mutable_read | -0.412% | 0.221740 / 0.269482 | 85868544 / 86671360 |
| VM / mutable_write | +2.630% | 0.195996 / 0.224015 | 86491136 / 87818240 |
| VM / hash_key_read | +0.666% | 0.229697 / 0.245916 | 85852160 / 86769664 |
| VM / churn | +9.642% | 0.353460 / 0.495792 | 106135552 / 101924864 |
| VM / mixed_growth | +0.293% | 0.151641 / 0.160387 | 86310912 / 87162880 |
| VM / immutable_growth | +0.041% | 0.148680 / 0.153700 | 86409216 / 87113728 |

The table includes the additional work for mutable-key writes and create/copy/mutate
churn, alongside the ordinary immutable-key controls. Mutable-key values are maintained
per actual entry to preserve independent lookup and copies. Retired-instruction deltas
and max RSS are measured on the matching current-main control; shared-machine wall times
are diagnostic.

Insertion-loop scaling separately excludes interpreter startup: h = {[] => :mutable};
count.times { |i| h[i] = i }. Three alternating current-main/reviewed-head/fixed-head
runs per size and engine, tight GC and parsed --seed=1. The reviewed head is 7450c284.
No loop count or resource budget is reduced.

| Engine / insertions | Main loop seconds | Reviewed loop seconds | Fixed loop seconds | Main / reviewed / fixed max RSS bytes |
| --- | ---: | ---: | ---: | --- |
| Evaluator / 1000 | 0.001884 | 0.039630 | 0.001489 | 72679424 / 96845824 / 73580544 |
| Evaluator / 2000 | 0.003083 | 0.109852 | 0.002665 | 72810496 / 137723904 / 73728000 |
| Evaluator / 4000 | 0.005009 | 0.676731 | 0.005932 | 73220096 / 209797120 / 74121216 |
| VM / 1000 | 0.001378 | 0.033308 | 0.000943 | 73580544 / 122486784 / 74416128 |
| VM / 2000 | 0.002960 | 0.140325 | 0.001990 | 73777152 / 266698752 / 74776576 |
| VM / 4000 | 0.006045 | 0.466612 | 0.004488 | 74186752 / 438943744 / 75104256 |

The exact review overwrite repro now returns [:new, :new] on both engines with indexing
on/off. The historical-digest probe also matches Ruby in all four configurations. The
earlier local review iteration passed both full corpora but failed that stronger probe;
it was rejected before commit/push. Its raw results are preserved.

Candidate O2 SHA-256: dbc94782cd3d96a51b8df13a8613379ff98a31b0f86c741ee87d023462c1d7a9.
Compiler 9dec2ff6; mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code, main integration and
completed loop record are pushed together. No new workflow change.
