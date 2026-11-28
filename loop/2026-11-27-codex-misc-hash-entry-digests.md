# Stored Hash entries, deferred overwrites and digest collisions

A changed native key could undo an earlier Hash value assignment or become findable
through the index-off walk. Preserve the digest recorded for each entry and its latest
value across mutation, copying, deletion and rehashing, on both engines and lookup
configurations.

Unique mutable digest buckets verify their cached stored key and update the ordinary
deferred indexed value. Only a digest shared by distinct entries needs per-entry
deferred values, linked in insertion order. Stable native entry identifiers preserve
those associations after deletion and copying. Pair lists are materialized when needed;
an overwrite does not republish or copy the complete list. Ordinary frozen String keys
beside an Array key retain the indexed path.

Hash-key digests remain order-independent and content based, matching the relevant CRuby
Hash#hash behavior. Literal construction uses per-digest pair buckets and the actual
native key-equality rule; a digest match alone no longer collapses distinct
identity-mode Hash keys. Deletion uses the same hkey_same rule as lookup before removing
an entry. Empty ordinary/identity hashes, nested containers, a mode flip and replacement
of an identity key by an equal-content object are covered.

MERE_RUBY_NO_HASH_INDEX=1 again uses the independent walk for ordinary write membership,
as well as stored-digest entry verification. Index maintenance and deferred value
storage remain shared; the source comment explicitly describes that boundary. Existing
hash_index storage holds only its owning Hash keys/values, and is swept with that owner.
No new Val global or root exemption is introduced; the existing exemption rationale is
updated.

Clean Ruby 4.0.10 through tools/ref_ruby.sh; matching-main O2 control
491cc5cab7e727606e1b00a141607e4742194d0a. Corpus 1139 and eight related files match
stdout, stderr and exit status in evaluator/VM with the Hash index on/off (36/36). Four
additional GC-stress configurations bring the fixture checks to 40/40. A deterministic
48-operation mutation/copy/delete/rehash/GC trace matches in all eight
engine/index/stress configurations. The exact identity-collision reproducer passes on
reference, main and candidate and fails on the reviewed head in all four engine/index
configurations.

- sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.

The earlier head passed its own full sweeps but the review found additional overwrite
and collision shapes. Those historical results are retained; the complete sweeps above
use this repaired source and executable.

Original CRuby selections below use unchanged files, assertions, workloads and bounds,
MERE_RUBY_GC_TIGHT=1 and parsed --seed=1. The Hash replace resource case retains 676
keys, 10000 warmup operations and 500000 replacements. Allocation selectors retain the
original 100000-element Array and 100000-key Hash. No full unit or Rails component suite
was run.

Original hash functional selection in ruby/test_hash.rb:
`/test_(rehash|s_AREF_key_tampering|shift|dup|clone|replace)\z/`.

Original hash replace resource selection in ruby/test_hash.rb:
`/test_replace_memory_leak\z/`.

Original hash key equality selection in ruby/test_hash.rb:
`/test_(eql|hash_hash|recursive_key|dup_equality)\z/`.

Original array to_h selection in ruby/test_array.rb: `/test_to_h\z/`.

Original allocation literals selection in ruby/test_allocation.rb:
`/test_(array_literal|hash_literal)\z/`.

| Original scope | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| Hash functional | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 12 tests, 72 assertions, 0 failures, 0 errors, 0 skips |
| Hash replace resource | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 3 assertions, 0 failures, 0 errors, 0 skips |
| Hash key equality | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips | 8 tests, 20 assertions, 0 failures, 0 errors, 0 skips |
| Array to_h | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips |
| Allocation literals | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips |

Measured /usr/bin/time -l maxima, in bytes:

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hash functional | 22937600 | 161464320 | 161480704 | 180436992 | 180813824 |
| Hash replace resource | 86163456 | 161251328 | 161775616 | 180224000 | 180666368 |
| Hash key equality | 22839296 | 161202176 | 161628160 | 180011008 | 180649984 |
| Array to_h | 24559616 | 168050688 | 168214528 | 215515136 | 214974464 |
| Allocation literals | 78397440 | 315752448 | 327598080 | 329629696 | 336740352 |

Whole-process cost: three alternating main/candidate pairs per workload and engine, O2,
tight GC and parsed --seed=1. Retired instructions and elapsed seconds are medians; RSS
is the maximum of three. Ordinary reads use 100000 operations; mutable/copy workloads
use 10000, and growth workloads use 4000. Shared-machine wall times are diagnostic.

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / read | +0.232% | 0.572366 / 0.516072 | 75563008 / 75857920 |
| Evaluator / write | +0.140% | 0.169451 / 0.161346 | 73351168 / 73662464 |
| Evaluator / small_dup | -0.012% | 0.187401 / 0.170313 | 80625664 / 80822272 |
| Evaluator / large_dup | +0.152% | 0.195926 / 0.234980 | 75235328 / 75497472 |
| Evaluator / mutable_read | +0.883% | 0.171132 / 0.208998 | 86016000 / 86212608 |
| Evaluator / mutable_write | +4.027% | 0.174672 / 0.191075 | 86540288 / 87179264 |
| Evaluator / hash_key_read | +1.726% | 0.196897 / 0.199261 | 85999616 / 86196224 |
| Evaluator / churn | +21.922% | 0.347217 / 0.414628 | 105299968 / 103923712 |
| Evaluator / mixed_growth | +0.750% | 0.164978 / 0.214265 | 86425600 / 86917120 |
| Evaluator / immutable_growth | +0.048% | 0.155473 / 0.153282 | 86392832 / 86654976 |
| Evaluator / large_literal | +0.664% | 1.212218 / 1.320855 | 288210944 / 293978112 |
| VM / read | +0.264% | 0.482488 / 0.564661 | 76726272 / 77119488 |
| VM / write | +0.185% | 0.211540 / 0.225467 | 74465280 / 74858496 |
| VM / small_dup | +0.127% | 0.189165 / 0.202341 | 81952768 / 81985536 |
| VM / large_dup | +0.067% | 0.183694 / 0.181148 | 76414976 / 76824576 |
| VM / mutable_read | +0.864% | 0.181854 / 0.216294 | 87179264 / 87425024 |
| VM / mutable_write | +3.933% | 0.207738 / 0.233786 | 87818240 / 88408064 |
| VM / hash_key_read | +1.362% | 0.186555 / 0.190190 | 87179264 / 87425024 |
| VM / churn | +21.089% | 0.346593 / 0.442994 | 105594880 / 104120320 |
| VM / mixed_growth | +0.577% | 0.172783 / 0.196416 | 87703552 / 88195072 |
| VM / immutable_growth | +0.312% | 0.155519 / 0.156918 | 87703552 / 87965696 |
| VM / large_literal | +0.679% | 1.588457 / 1.547592 | 289259520 / 297074688 |

The common-workload table includes mutable writes, churn, growth and the 50000-key
literal control, alongside immutable reads/writes/copies. The new overwrite/read scaling
below retains 4000 and 8000 keys and compares matching main, reviewed head 0cce4e80 and
the repair in three alternating pairs. Loop seconds exclude construction and checksum
validation; instructions and max RSS are whole-process measurements. Every process uses
tight GC and parsed --seed=1.

| Engine / workload / keys | Main / reviewed / fixed loop seconds | Main / reviewed / fixed instructions | Main / reviewed / fixed max RSS bytes |
| --- | --- | --- | --- |
| Evaluator / array_overwrite / 4000 | 0.008031 / 0.686210 / 0.011969 | 1245859599 / 9773722373 / 1303087375 | 90128384 / 240779264 / 92618752 |
| VM / array_overwrite / 4000 | 0.011482 / 0.831443 / 0.015251 | 1277250883 / 9818296215 / 1333564434 | 91373568 / 554582016 / 92356608 |
| Evaluator / array_overwrite / 8000 | 0.021687 / 3.489310 / 0.024315 | 1512686618 / 35965719485 / 1627110638 | 92897280 / 724041728 / 97533952 |
| VM / array_overwrite / 8000 | 0.021294 / 3.333958 / 0.026225 | 1573224125 / 35918704836 / 1683361356 | 95387648 / 724664320 / 98074624 |
| Evaluator / array_first_overwrite / 4000 | 0.014721 / 0.589344 / 0.015794 | 1262604315 / 7363810024 / 1307348277 | 90128384 / 234881024 / 91537408 |
| VM / array_first_overwrite / 4000 | 0.008789 / 0.663174 / 0.014418 | 1298853900 / 7418829313 / 1344573262 | 91373568 / 392134656 / 90963968 |
| Evaluator / array_first_overwrite / 8000 | 0.026298 / 2.475882 / 0.031779 | 1546845192 / 25963643998 / 1636508282 | 92864512 / 396574720 / 96518144 |
| VM / array_first_overwrite / 8000 | 0.033436 / 2.415274 / 0.045181 | 1607333389 / 25973394580 / 1696501137 | 95059968 / 712900608 / 94601216 |
| Evaluator / mixed_string_overwrite / 4000 | 0.005430 / 0.795695 / 0.006209 | 1208766270 / 9756770733 / 1216884930 | 89882624 / 240205824 / 90423296 |
| VM / mixed_string_overwrite / 4000 | 0.005602 / 0.789050 / 0.008929 | 1278514143 / 9800754154 / 1291864507 | 92028928 / 398016512 / 92618752 |
| Evaluator / mixed_string_overwrite / 8000 | 0.013896 / 3.018283 / 0.016648 | 1438473056 / 35893506753 / 1459079938 | 92340224 / 408649728 / 93356032 |
| VM / mixed_string_overwrite / 8000 | 0.017572 / 2.974644 / 0.018327 | 1581299023 / 35904951003 / 1604569263 | 96337920 / 725434368 / 97206272 |
| Evaluator / mixed_string_read / 4000 | 0.014188 / 0.099301 / 0.016184 | 1261905729 / 1965263888 / 1273755388 | 90112000 / 89882624 / 90701824 |
| VM / mixed_string_read / 4000 | 0.015514 / 0.094637 / 0.011314 | 1339297076 / 2039877132 / 1347764331 | 91422720 / 91291648 / 91996160 |
| Evaluator / mixed_string_read / 8000 | 0.030941 / 0.336668 / 0.026558 | 1549316561 / 4632099739 / 1565974694 | 92733440 / 93208576 / 93700096 |
| VM / mixed_string_read / 8000 | 0.033264 / 0.388193 / 0.025055 | 1694166537 / 4778296650 / 1713533957 | 95289344 / 95715328 / 97173504 |
| Evaluator / mixed_integer_overwrite / 4000 | 0.004164 / 0.008046 / 0.009436 | 1150273183 / 1150127362 / 1163942656 | 89112576 / 89358336 / 89669632 |
| VM / mixed_integer_overwrite / 4000 | 0.006997 / 0.005103 / 0.008276 | 1182755258 / 1185156657 / 1192574043 | 89849856 / 89833472 / 90275840 |
| Evaluator / mixed_integer_overwrite / 8000 | 0.014220 / 0.009559 / 0.016017 | 1335584774 / 1334045665 / 1347456013 | 89948160 / 90357760 / 90898432 |
| VM / mixed_integer_overwrite / 8000 | 0.012274 / 0.012123 / 0.012917 | 1402869681 / 1402480885 / 1414946794 | 92913664 / 93093888 / 93667328 |
| Evaluator / plain_string_overwrite / 4000 | 0.008338 / 0.007276 / 0.005016 | 1209207926 / 1207980894 / 1210560024 | 89849856 / 89882624 / 90112000 |
| VM / plain_string_overwrite / 4000 | 0.005841 / 0.007320 / 0.006108 | 1282676261 / 1279693163 / 1286191427 | 92078080 / 92061696 / 92274688 |
| Evaluator / plain_string_overwrite / 8000 | 0.016372 / 0.014315 / 0.015251 | 1437987662 / 1437770785 / 1442795291 | 92291072 / 92471296 / 92553216 |
| VM / plain_string_overwrite / 8000 | 0.018662 / 0.026148 / 0.014150 | 1572581399 / 1582010663 / 1585558275 | 96354304 / 96501760 / 96518144 |

Pre-existing mutated-key differences after hset-based transforms remain recorded as
follow-ups. The original unchanged resource bounds remain in force. All measurement
samples are retained; shared-machine wall times are diagnostic.

Candidate O2 SHA-256: ce1e42b3ae4c25757124543cbd252a3febf8b0fce66bb6daeff231fe6f0333bd.
Compiler 9dec2ff6; mgz 661a01d8.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and the completed loop record
are pushed together. No workflow change or reference gem installation.
