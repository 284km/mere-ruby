# Anonymous-rest review correction on current main

Runtime `943db8a20bbda75a85f74a3b0bdfea5f7b192e0a` integrates main `e433affa596f582782b1c6932811a6461619faca`. A keyword-declaring method called without keywords still snapshots positional rest; explicit keyword operands keep Ruby's borrowing rules. The bot's earlier isolation/snapshot findings remain fixed. Corpus 995 retains the keyword-shape, mutation, frozen-source and GC controls, and ObjectSpace publishes the actual retained/active/suspended frame slot.

The review correction combines the binder's two pending-source reads into one. With no source pending, it performs one comparison and skips all anonymous-rest parameter classification. With a source pending, every target retires it before defaults or callbacks run, including a method without an anonymous rest.

## Fresh integrated acceptance

- Corpus `--both`: **1030/1030**, hash index ON and OFF.
- VM corpus: **1030 VM / 0 fallback / 0 differences / 0 failures**; no fallback-list mismatch.
- **24 focused engine comparisons** match reference stdout, stderr and exit status, including normal/stress50 exposure and snapshot controls.
- All ten source/generated-C gates, record_hygiene before/after, header/vendor, CI timing and the class-watermark runtime gate pass. The corpus driver's iv-door and shape-statistics preflights remain enabled.
- All file, allocation, instruction and controlled RSS results below are newly measured on these two integrated builds. Seed 1, unchanged test files, no excluded case, no full unit suite or Rails cold measurement.

## Complete upstream files

| File | Engine | Main MATCH / RED | Runtime MATCH / RED |
| --- | --- | ---: | ---: |
| `test_keyword.rb` | evaluator | 115 / 0 | 115 / 0 |
| `test_keyword.rb` | vm | 115 / 0 | 115 / 0 |
| `test_call.rb` | evaluator | 65 / 0 | 65 / 0 |
| `test_call.rb` | vm | 65 / 0 | 65 / 0 |
| `test_hash.rb` | evaluator | 298 / 0 | 298 / 0 |
| `test_hash.rb` | vm | 298 / 0 | 298 / 0 |
| `test_allocation.rb` | evaluator | 14 / 62 | 14 / 62 |
| `test_allocation.rb` | vm | 14 / 62 | 14 / 62 |

BOTH and EXTRA are zero. Every main MATCH stays MATCH. All 76 allocation cases complete in each mode; every tight-GC outcome agrees with its normal-GC control.

## Instructions retired and requested small exception

Same benchmark inputs/outputs, ordinary O2 builds; counts include startup. These are the integrated rows requested by review 6082282050.

| Workload | Evaluator main → runtime | VM main → runtime |
| --- | ---: | ---: |
| `method_call.rb` | 3,466,511,739 → 3,469,393,540 (+0.083%) | 3,746,943,650 → 3,743,546,059 (-0.091%) |
| `method_call_200k.rb` | 5,948,651,899 → 5,938,769,979 (-0.166%) | 6,523,560,524 → 6,540,021,772 (+0.252%) |
| `block_call.rb` | 4,305,660,407 → 4,290,097,812 (-0.361%) | 5,168,541,055 → 5,171,760,758 (+0.062%) |
| `block_call_200k.rb` | 7,632,278,056 → 7,639,081,468 (+0.089%) | 9,384,527,950 → 9,394,137,504 (+0.102%) |
| `so_matrix.rb` | 201,143,656,635 → 201,420,003,020 (+0.137%) | 215,569,021,199 → 215,887,228,968 (+0.148%) |
| `anonymous_rest_call.rb` | 4,751,757,716 → 4,520,031,286 (-4.877%) | 4,858,679,257 → 4,867,337,529 (+0.178%) |
| `anonymous_rest_borrowed.rb` | 3,167,573,378 → 2,995,861,116 (-5.421%) | 3,004,283,013 → 2,997,739,070 (-0.218%) |

The redundant ordinary-binder state check is removed. The remaining comparison tests incoming call provenance, not just the callee's immutable parameter shape. Parameter scanning and eligibility work already occur only when a splat source is pending. Even a callee with no rest parameter, or a native entry that calls back into Ruby, must retire that incoming source before another binder runs. Caching an anonymous-rest parameter bit alone cannot replace that retirement. Eliminating the last dynamic check would require carrying an explicit argument packet through evaluator, VM, Method/Proc and native callback interfaces, a broader dispatch change than this fix.

I therefore retain and request the review's permitted small exception for the remaining measured common-path cost. Positive rows are disclosed rather than called zero; the VM direct anonymous-rest row is not presented as an improvement. No dummy Ruby allocation or count-only per-call operation is introduced. This explanation requests the owner's acceptance; local checks do not imply external approval.

## Controlled maximum RSS

Whole `ruby/test_allocation.rb` alone, `MERE_RUBY_GC_TIGHT=1`, seed 1; one declared main/head pair per engine, no concurrent supplementary run from this session. Kernel command and largest-child maxima are separate from sampled simultaneous process-family RSS. Active-test peak traces remain in the private raw evidence.

| Engine | Kernel command bytes main → runtime | Largest child bytes main → runtime | Sampled family KiB main → runtime |
| --- | ---: | ---: | ---: |
| evaluator | 329,924,608 → 318,242,816 (-3.541%) | 311,377,920 → 311,541,760 (+0.053%) | 521,040 → 463,952 (-10.957%) |
| vm | 320,651,264 → 317,898,752 (-0.858%) | 318,046,208 → 317,898,752 (-0.046%) | 479,728 → 438,640 (-8.565%) |

The family measure includes runner, forked children and wrappers; it is not the maximum heap size of one interpreter. Every increase is retained above for review.

## Allocation differences by cause

These are mismatching assertions with overlapping case groups, identical on evaluator and VM.

| Cause | Main assertions (cases) | Runtime assertions (cases) |
| --- | ---: | ---: |
| Extra rest Arrays | 218 (10) | 116 (4) |
| Absent CRuby Array temporaries | 198 (40) | 346 (46) |
| Extra keyword Hashes | 504 (38) | 504 (38) |
| Absent CRuby Hash temporaries | 8 (4) | 8 (4) |
| ruby2_keywords decoding temporary | 8 (4) | 8 (4) |

The remaining generic `...` rest allocations belong to PR #245; keyword-rest ownership belongs to PR #256. Missing CRuby rest/concatenation Arrays and decoding Hash temporaries remain recorded as not matched because native immutable storage does not create those internal Ruby objects. They are not manufactured to imitate counters. Observable copying, source isolation and reflection remain checked independently. No assertion is removed.

## Build provenance

Compiler `9dec2ff687a08433247dbdb7729bc19c8522e538`; mgz `661a01d8bb68f5acd68e3192bd47f081d179c436`; reference Ruby 4.0.10 revision `a704b7cd95a42cc0cf5f307137bf3aac0285b915`. The fresh audit finds 46 default / 38 bundled / zero extra gems, Prism 1.8.2. No gem is installed into the reference's own directory.

Main binary `2ce15dbb4657d835f4a2598021f50e4e2148e15a053edaa28c68017fb0ef9129`, generated C `f18fa8b3ab69ec032ae2bf33a65a342b3ce4a0c217873f2e221ef16ea44b09c2`.

Runtime binary `10be38ae137ae1bd04e6b6588487ba17bcbb18472bde7d4382ded81666f36063`, generated C `eeaa9cce5633ece6f7733e75928e49c7cb5a9dcdb1eafe457cd45dd8dc81b063`.

Code, main integration and records are published together. Exact-head bot review, hosted CI and the owner's merge remain separate steps. Historical records keep their original source identities and are not substituted for these runs.

Resource assessment: Fresh current-main tight-GC seed1 controls retain every allocation case. Kernel command high-water marks decrease on both engines, and sampled-family peaks also decrease. The evaluator largest-child high-water rises 0.0526% (163840 bytes), while the VM largest-child mark decreases. These small process-image differences are explicitly retained; the sampled process-family metric is kept separate. No GC policy, budget, expected count or harness assertion is changed.
