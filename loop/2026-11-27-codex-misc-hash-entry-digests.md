# Stored Hash entries and inexpensive singleton metadata

A mutable native key could become findable through the index-off walk, or a later key
mutation could undo a pending value overwrite. Preserve each entry's insertion-time
digest and latest value across mutation, copying, deletion and rehashing on both
engines.

A one-entry mutable-key Hash now retains only its saved native digest beside the
existing pair list and value index. Per-entry vectors and collision metadata are created
when a second entry is inserted. Promotion uses the original digest even if the first
key has changed. Copying takes that saved association directly and builds the
destination once, instead of constructing and immediately discarding an index from the
key's current contents.

Larger mutable buckets keep stable native entry identifiers. Unique buckets verify their
stored key and defer values in the index; historical digest collisions use ordered
per-entry values. Overwrites do not republish the pair list, ordinary frozen String keys
keep indexed lookup, and literal/deletion collision paths compare actual keys. Native
Hash-key digests remain content based and order independent.

Index-off membership follows actual pair order and saved digests independently of the
bucket index. Deferred values are shared authoritative storage. The singleton digest
table holds native text only, follows the existing index-release lifecycle, and is
compacted with Hash metadata. No new Val root or exemption is added.

Clean Ruby 4.0.10 through tools/ref_ruby.sh. Current-main control
8edcf953c37c3c7f0d4223c5227a7e4ea589ec6a; previous implementation integrated with the
same main in d1ac9a9223e7195422c8ad609859f3b0e4f60fd9. All three are ordinary O2 with
pinned compiler 9dec2ff6 and mgz 661a01d8.

Corpus 1139 adds singleton overwrite/copy/GC, mutation before dup/clone/replace,
promotion, historical collisions, deletion and reuse. Together with related fixtures and
the mutation/collision probes, 88 strict stdout/stderr/status comparisons pass across
previous/candidate, evaluator/VM, index ON/OFF and the applicable normal/stress-GC
configurations. Eight additional String-key construction/copy/freezing controls also
match, for 96 comparisons total.

- sh run_corpus.sh --both: **1037/1037 PASS**, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: **1037/1037 PASS**, exit 0.

The small-case benchmark uses 20000 iterations and parsed --seed=1 with
MERE_RUBY_GC_TIGHT=1. Each phase and engine has three alternating runs. Instructions
below subtract that phase's three-run empty-loop median; creation includes its Array
key, and create + dup includes both operations. These are operation costs with fixed
process/loop work removed.

| Engine / operation | Main / previous / candidate adjusted instructions | Previous / candidate vs main |
| --- | --- | --- |
| Evaluator / create | 548483677 / 793381134 / 560580782 | +44.650% / +2.206% |
| Evaluator / create + dup | 992390656 / 1834406301 / 972264148 | +84.847% / -2.028% |
| Evaluator / Symbol create + dup | 391039422 / 390767873 / 386541375 | -0.069% / -1.150% |
| VM / create | 586462768 / 822823365 / 593770495 | +40.303% / +1.246% |
| VM / create + dup | 1006545477 / 1859679864 / 997148149 | +84.759% / -0.934% |
| VM / Symbol create + dup | 430662982 / 432581660 / 429687342 | +0.446% / -0.227% |

Whole-process RSS is the maximum of all three samples, in bytes. The small mutable cases
remain about 1–2 MiB above main; this change does not claim lower peak memory. All raw
samples, including main and previous, are retained.

| Engine / operation | Main / previous / candidate max RSS bytes | Candidate samples |
| --- | --- | --- |
| Evaluator / small_create | 104923136 / 102973440 / 107036672 | [106921984, 107020288, 107036672] |
| VM / small_create | 106381312 / 104382464 / 107462656 | [107462656, 107462656, 107462656] |
| Evaluator / small_dup | 105562112 / 104153088 / 107003904 | [107003904, 106889216, 106938368] |
| VM / small_dup | 106561536 / 105152512 / 108019712 | [107970560, 107970560, 108019712] |
| Evaluator / small_symbol_dup | 88309760 / 88440832 / 88588288 | [88522752, 88539136, 88588288] |
| VM / small_symbol_dup | 92520448 / 92733440 / 93028352 | [92930048, 93028352, 92913664] |

The other committed benchmark modes retain three alternating main/previous/candidate
runs with tight GC and parsed seed 1. Instructions include startup/construction/checksum
work. The timed overwrite/read loops exclude those phases; shared-machine seconds are
diagnostic. Both 4000 and 8000 keys are retained to guard the previously repaired growth
and overwrite paths.

| Engine / workload / count | Candidate vs main / previous instructions | Main / previous / candidate max RSS bytes | Candidate loop seconds |
| --- | --- | --- | ---: |
| Evaluator / churn / 10000 | -3.176% / -21.120% | 105889792 / 104349696 / 106037248 | — |
| VM / churn / 10000 | -2.934% / -19.903% | 105807872 / 104398848 / 105070592 | — |
| Evaluator / mutable_read / 10000 | -2.017% / -2.869% | 86212608 / 86343680 / 86261760 | — |
| VM / mutable_read / 10000 | -2.153% / -3.314% | 87523328 / 87572480 / 87539712 | — |
| Evaluator / mutable_write / 10000 | -1.561% / -5.427% | 86867968 / 87408640 / 86867968 | — |
| VM / mutable_write / 10000 | -2.104% / -5.840% | 88178688 / 88637440 / 88195072 | — |
| Evaluator / hash_key_read / 10000 | -2.994% / -4.285% | 86278144 / 86441984 / 86212608 | — |
| VM / hash_key_read / 10000 | -2.465% / -3.870% | 87588864 / 87687168 / 87556096 | — |
| Evaluator / mixed_growth / 4000 | +0.933% / -0.035% | 87801856 / 88227840 / 88342528 | — |
| VM / mixed_growth / 4000 | +0.988% / +0.054% | 87998464 / 88391680 / 88719360 | — |
| Evaluator / immutable_growth / 4000 | +0.549% / -0.026% | 87834624 / 87982080 / 88064000 | — |
| VM / immutable_growth / 4000 | +0.147% / -0.087% | 88080384 / 88211456 / 88408064 | — |
| Evaluator / large_literal / 50000 | +0.377% / -0.273% | 286228480 / 292569088 / 293027840 | — |
| VM / large_literal / 50000 | +0.382% / -0.035% | 283557888 / 290897920 / 291323904 | — |
| Evaluator / array_overwrite / 4000 | +4.650% / +0.083% | 90537984 / 93011968 / 93110272 | 0.009205 |
| VM / array_overwrite / 4000 | +4.366% / +0.228% | 91684864 / 92569600 / 92864512 | 0.009978 |
| Evaluator / array_overwrite / 8000 | +7.264% / -0.078% | 95305728 / 98975744 / 99057664 | 0.021036 |
| VM / array_overwrite / 8000 | +7.070% / +0.178% | 95780864 / 98287616 / 98533376 | 0.020745 |
| Evaluator / array_first_overwrite / 4000 | +3.587% / +0.007% | 90439680 / 92422144 / 92520448 | 0.009827 |
| VM / array_first_overwrite / 4000 | +3.778% / -0.044% | 91570176 / 90849280 / 91013120 | 0.010165 |
| Evaluator / array_first_overwrite / 8000 | +6.047% / -0.092% | 93536256 / 97533952 / 97632256 | 0.023631 |
| VM / array_first_overwrite / 8000 | +5.946% / +0.156% | 95371264 / 94879744 / 95043584 | 0.022784 |
| Evaluator / mixed_string_overwrite / 4000 | +0.984% / -0.300% | 91308032 / 91832320 / 91963392 | 0.004794 |
| VM / mixed_string_overwrite / 4000 | +0.747% / +0.110% | 92356608 / 92880896 / 93011968 | 0.006107 |
| Evaluator / mixed_string_overwrite / 8000 | +1.285% / +0.100% | 94519296 / 95518720 / 95584256 | 0.010280 |
| VM / mixed_string_overwrite / 8000 | +1.198% / +0.082% | 96714752 / 97533952 / 97714176 | 0.013544 |
| Evaluator / mixed_string_read / 4000 | +0.445% / +0.054% | 90849280 / 91308032 / 91439104 | 0.012327 |
| VM / mixed_string_read / 4000 | +0.781% / +0.139% | 91766784 / 92307456 / 92422144 | 0.014629 |
| Evaluator / mixed_string_read / 8000 | +1.132% / -0.049% | 93929472 / 94994432 / 95059968 | 0.023134 |
| VM / mixed_string_read / 8000 | +1.265% / -0.245% | 94568448 / 96468992 / 96583680 | 0.023887 |

The larger Array-key overwrite rows retain the prior correctness cost versus main (up to
about 7% whole-process instructions here); this singleton follow-up changes their
instructions by less than 0.3% versus the integrated previous implementation. The
50000-key literal still has the previously disclosed several-MiB cost versus main. No
storage bound or assertion is relaxed.

Original CRuby files, selectors, assertions and resource bounds are unchanged.
Reference/main/candidate comparisons use tight GC and parsed --seed=1. All 25 selected
executions complete with the same reference summaries. The replace resource retains its
original 676 keys, 10000 warmup and 500000 replacements; allocation tests retain their
original 100000-element Array and 100000-key Hash. No full unit or Rails component suite
was run.

Hash functional original selection: ruby/test_hash.rb
`/test_(rehash|s_AREF_key_tampering|shift|dup|clone|replace)\z/`.

Hash replace resource original selection: ruby/test_hash.rb
`/test_replace_memory_leak\z/`.

Hash key equality original selection: ruby/test_hash.rb
`/test_(eql|hash_hash|recursive_key|dup_equality)\z/`.

Array to_h original selection: ruby/test_array.rb `/test_to_h\z/`.

Allocation literals original selection: ruby/test_allocation.rb
`/test_(array_literal|hash_literal)\z/`.

Summary cells: tests / assertions / failures / errors / skips.

| Scope | Ruby | Main E | Candidate E | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| Hash functional | 12 / 72 / 0 / 0 / 0 | 12 / 72 / 0 / 0 / 0 | 12 / 72 / 0 / 0 / 0 | 12 / 72 / 0 / 0 / 0 | 12 / 72 / 0 / 0 / 0 |
| Hash replace resource | 1 / 3 / 0 / 0 / 0 | 1 / 3 / 0 / 0 / 0 | 1 / 3 / 0 / 0 / 0 | 1 / 3 / 0 / 0 / 0 | 1 / 3 / 0 / 0 / 0 |
| Hash key equality | 8 / 20 / 0 / 0 / 0 | 8 / 20 / 0 / 0 / 0 | 8 / 20 / 0 / 0 / 0 | 8 / 20 / 0 / 0 / 0 | 8 / 20 / 0 / 0 / 0 |
| Array to_h | 2 / 16 / 0 / 0 / 0 | 2 / 16 / 0 / 0 / 0 | 2 / 16 / 0 / 0 / 0 | 2 / 16 / 0 / 0 / 0 | 2 / 16 / 0 / 0 / 0 |
| Allocation literals | 2 / 8 / 0 / 0 / 0 | 2 / 8 / 0 / 0 / 0 | 2 / 8 / 0 / 0 / 0 | 2 / 8 / 0 / 0 / 0 | 2 / 8 / 0 / 0 / 0 |

Measured /usr/bin/time -l driver maxima (not a repeated process-family RSS claim):

| Driver max RSS bytes | Ruby | Main E | Candidate E | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hash functional | 23052288 | 160923648 | 161169408 | 179765248 | 180240384 |
| Hash replace resource | 86212608 | 160858112 | 161136640 | 179830784 | 180011008 |
| Hash key equality | 23035904 | 160940032 | 161169408 | 179896320 | 180207616 |
| Array to_h | 24657920 | 167690240 | 167968768 | 214761472 | 214941696 |
| Allocation literals | 76546048 | 311541760 | 322928640 | 318193664 | 329285632 |

Pre-existing mutated-key differences through hset-based
delete_if/reject!/select!/keep_if/compact!/merge and
values_at/merge!/transform_values!/select remain follow-ups. The CRuby small-table
growth/rehashing detail is also separate. This PR does not claim those differences are
repaired.

Candidate O2 SHA-256 d715bcd0b8f0e979b1b7a28b73d3ee59766c5257977476f65c6a61d8111adde2.
Historical measurements remain retained with their original sources; all fresh results
above use the new integrated runtime.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth and strbuf_region: PASS. The packed-GC
probe passes O2 and ASan/UBSan. Full and explicit completed record_hygiene and
staged/unstaged whitespace: PASS. Code and its completed record are pushed together; no
workflow changes or reference gem installation.
