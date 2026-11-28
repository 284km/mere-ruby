# Reuse fresh keyword-rest packets

A method, Proc or lambda receiving only a named **rest previously allocated a second Hash to bind a completed fresh keyword packet. Transfer ownership of that unexposed packet. Forwarded, permanently flagged and ObjectSpace-exposed packets remain borrowed and receive an independent callee Hash. Acquire the rest before default callbacks, retaining validation and local-binding order. No dummy objects or accounting-only work are added to ordinary calls.

The reviewed bare-super P2 remains fixed: restore the forwarding frame's saved keyword provenance at every implicit-super boundary, after a previous consumer or super. Current main is integrated with its frame/ivar doors and callback boundaries. Corpus 994 retains the two bare-super witnesses and independence, capture, conversion/default/seeding exposure controls. Corpus 995 retains the anonymous-rest dependency's keyword-declaration, keyword-expression and live ObjectSpace exposure corrections.

Current validated runtime `e4d98dbcc3235324ac6eab41869c0f5779909931` integrates main `83bc573585b0e73c3266edd2f30fd7d80c2391eb` and anonymous-rest dependency runtime `41c3dac95da23fa65e9b9b467600b5a5a26bb161` (PR #251). The owner merges the dependency first. Documentation-only publication preserves this runtime, generated C and all regression inputs.

## Current-main integration acceptance

- Full corpus `--both`: **1007/1007**, hash index ON and OFF.
- VM corpus: **1007 VM / 0 fallback / 0 differences / 0 failures**, no fallback-list mismatch.
- **28 focused engine comparisons** match clean Ruby stdout, stderr and exit status, including GC stress50 controls.
- All ten source gates, record_hygiene before/after, header/vendor and CI-timing checks pass. The corpus driver retains iv-door and shape-statistics preflights.

These are fresh integrated corpus/gate results requested by the owner. Complete unchanged test-file and resource comparisons below were completed before integration, on runtime `6e8094f88322ae0243c075caa5f4096f5ccdac59` against main `6d8a416dec9f1e56f6594c077014fbd90789e719`. They are not relabeled as measurements of the current integrated binary. No full unit suite or Rails cold measurement is run.

Integrated binary SHA-256 `446bc8573bee5b6a0d7429d1c128cab5c1deac3f42fd8f586c56e75e2a7a1a9f`; generated C `9d4953d483aceca58989c5393ed67e9cb433b2f189cd264e7c7392d91ed3bfb6`.

## Completed pre-integration upstream files

Seed 1, complete unchanged files. No new RED, BOTH or EXTRA, case exclusion or driver limit.

| File / engine | Main MATCH / RED | Runtime 6e8094f8 MATCH / RED |
| --- | ---: | ---: |
| `ruby/test_keyword.rb` / evaluator | 115 / 0 | 115 / 0 |
| `ruby/test_keyword.rb` / vm | 115 / 0 | 115 / 0 |
| `ruby/test_call.rb` / evaluator | 65 / 0 | 65 / 0 |
| `ruby/test_call.rb` / vm | 65 / 0 | 65 / 0 |
| `ruby/test_hash.rb` / evaluator | 297 / 1 | 297 / 1 |
| `ruby/test_hash.rb` / vm | 297 / 1 | 297 / 1 |
| `ruby/test_allocation.rb` / evaluator | 14 / 62 | 18 / 58 |
| `ruby/test_allocation.rb` / vm | 14 / 62 | 18 / 58 |

All 76 allocation cases run. Four positional-splat-plus-keyword-splat method/Proc cases, with and without a block, become MATCH. The existing Hash RED is `TestHashOnly#test_replace_memory_leak` (timeout).

## Allocation causes

Groups count mismatching assertions; case sets overlap.

| Engine / cause | Main assertions (cases) | Runtime assertions (cases) |
| --- | ---: | ---: |
| evaluator / extra Arrays | 218 (10) | 116 (4) |
| evaluator / absent CRuby Array temporaries | 198 (40) | 346 (46) |
| evaluator / extra keyword Hashes | 504 (38) | 280 (26) |
| evaluator / absent CRuby Hash temporaries | 8 (4) | 8 (4) |
| evaluator / ruby2_keywords decoding temporaries | 8 (4) | 8 (4) |
| vm / extra Arrays | 218 (10) | 116 (4) |
| vm / absent CRuby Array temporaries | 198 (40) | 346 (46) |
| vm / extra keyword Hashes | 504 (38) | 280 (26) |
| vm / absent CRuby Hash temporaries | 8 (4) | 8 (4) |
| vm / ruby2_keywords decoding temporaries | 8 (4) | 8 (4) |

Generic forwarding Arrays remain PR #245 work. Literal keyword-packet representation, named-keyword filtering and Hash source metadata are separate causes. CRuby-only temporary Arrays/Hashes and ruby2_keywords decoding copies remain not matched: mere-ruby does not create those objects, and no unused allocation is manufactured. Every case cause is retained below.

## Instructions retired before integration

Ordinary O2, identical input and stdout; startup is included.

| Workload / engine | Main | Runtime | Change |
| --- | ---: | ---: | ---: |
| `method_call.rb` / evaluator | 3,433,895,181 | 3,443,509,855 | +0.280% |
| `method_call_200k.rb` / evaluator | 5,894,963,539 | 5,900,773,048 | +0.099% |
| `block_call.rb` / evaluator | 4,259,149,889 | 4,266,002,188 | +0.161% |
| `block_call_200k.rb` / evaluator | 7,577,796,157 | 7,583,760,561 | +0.079% |
| `so_matrix.rb` / evaluator | 200,316,424,707 | 200,512,514,742 | +0.098% |
| `method_call.rb` / vm | 3,714,342,603 | 3,709,030,199 | -0.143% |
| `method_call_200k.rb` / vm | 6,477,250,000 | 6,481,531,712 | +0.066% |
| `block_call.rb` / vm | 5,130,336,450 | 5,134,728,870 | +0.086% |
| `block_call_200k.rb` / vm | 9,315,646,232 | 9,321,740,250 | +0.065% |
| `so_matrix.rb` / vm | 214,591,012,221 | 214,843,685,852 | +0.118% |
| `keyword_rest_method.rb` / evaluator | 4,902,048,853 | 4,802,443,823 | -2.032% |
| `keyword_rest_proc.rb` / evaluator | 5,877,469,618 | 5,778,787,414 | -1.679% |
| `keyword_rest_lambda.rb` / evaluator | 6,963,349,364 | 6,861,727,987 | -1.459% |
| `keyword_rest_method.rb` / vm | 4,923,608,088 | 4,825,427,037 | -1.994% |
| `keyword_rest_proc.rb` / vm | 6,087,136,267 | 6,000,110,519 | -1.430% |
| `keyword_rest_lambda.rb` / vm | 7,192,209,647 | 7,096,896,288 | -1.325% |

Ordinary method/block/matrix totals range from -0.143% to +0.280%; the increases are retained. Keyword-rest method/Proc/lambda controls improve. This is local measurement evidence, not external approval.

## Controlled maximum RSS before integration

Whole allocation file measured alone, GC_TIGHT=1 and fixed seed 1. Kernel command and child high-water marks and sampled simultaneous family RSS are separate metrics.

| Engine | Kernel command bytes main → runtime | Largest child bytes main → runtime | Sampled family KiB main → runtime |
| --- | ---: | ---: | ---: |
| evaluator | 412,073,984 → 414,973,952 (+0.704%) | 310,788,096 → 311,066,624 (+0.090%) | 570,912 → 704,688 (+23.432%) |
| vm | 407,486,464 → 407,486,464 (+0.000%) | 317,095,936 → 317,128,704 (+0.010%) | 665,344 → 603,392 (-9.311%) |

Largest-child high-water marks change by less than 0.1% on either engine, and the VM command high-water mark is unchanged. Evaluator command RSS increases 0.704%. Sampled evaluator family RSS rises 23.432% while VM family RSS falls 9.311%; the family metric adds simultaneous runner, forked child and wrapper pages rather than measuring one heap. These increases remain visible; they are not described as flat RSS or a universal memory improvement. All controlled allocation outcomes match the complete-file comparison. Earlier measurements in the previous PR description are superseded by these explicitly pinned controls.

Own full corpus sweeps are serial; no supplementary runtime is launched by this session during allocation measurement. Shared heavy cap: two across Codex sessions. Code and records share one push. Exact-head bot review, hosted checks and owner merge remain separate.

Reference: clean independently built Ruby 4.0.10, revision `a704b7cd95a42cc0cf5f307137bf3aac0285b915`, 46 default / 38 bundled / zero extras, Prism 1.8.2. Compiler `9dec2ff687a08433247dbdb7729bc19c8522e538`, mgz `661a01d8bb68f5acd68e3192bd47f081d179c436`.

Record: `loop/2026-11-25-codex-keyword-rest-ownership.md`.

## Per-case cause groups

| Engine / case | Main | Runtime |
| --- | --- | --- |
| evaluator / `TestAllocation::MethodCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_anonymous_splat_parameter` | A+ | A- |
| evaluator / `TestAllocation::MethodCall#test_argument_forwarding` | A+, H+ | A+, H+ |
| evaluator / `TestAllocation::MethodCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::MethodCall#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_nested_argument_forwarding` | A+, H+ | A+, H+ |
| evaluator / `TestAllocation::MethodCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| evaluator / `TestAllocation::MethodCall#test_no_parameters` | A-, H- | A-, H- |
| evaluator / `TestAllocation::MethodCall#test_optional_parameter` | A- | A- |
| evaluator / `TestAllocation::MethodCall#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| evaluator / `TestAllocation::MethodCall#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| evaluator / `TestAllocation::MethodCall#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::MethodCall#test_required_parameter` | A- | A- |
| evaluator / `TestAllocation::MethodCall#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_ruby2_keywords` | R2K | R2K |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_parameter` | A+ | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_argument_forwarding` | A+, H+ | A+, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_nested_argument_forwarding` | A+, H+ | A+, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_no_parameters` | A-, H- | A-, H- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_optional_parameter` | A- | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_required_parameter` | A- | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_ruby2_keywords` | R2K | R2K |
| evaluator / `TestAllocation::ProcCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall#test_anonymous_splat_parameter` | A- | A- |
| evaluator / `TestAllocation::ProcCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall#test_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::ProcCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| evaluator / `TestAllocation::ProcCall#test_no_parameters` | A-, H- | A-, H- |
| evaluator / `TestAllocation::ProcCall#test_optional_parameter` | A- | A- |
| evaluator / `TestAllocation::ProcCall#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| evaluator / `TestAllocation::ProcCall#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| evaluator / `TestAllocation::ProcCall#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::ProcCall#test_required_parameter` | A- | A- |
| evaluator / `TestAllocation::ProcCall#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall#test_ruby2_keywords` | R2K | R2K |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_anonymous_splat_parameter` | A- | A- |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_no_parameters` | A-, H- | A-, H- |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_optional_parameter` | A- | A- |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_required_parameter` | A- | A- |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::ProcCall::WithBlock#test_ruby2_keywords` | R2K | R2K |
| vm / `TestAllocation::MethodCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_anonymous_splat_parameter` | A+ | A- |
| vm / `TestAllocation::MethodCall#test_argument_forwarding` | A+, H+ | A+, H+ |
| vm / `TestAllocation::MethodCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::MethodCall#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_nested_argument_forwarding` | A+, H+ | A+, H+ |
| vm / `TestAllocation::MethodCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| vm / `TestAllocation::MethodCall#test_no_parameters` | A-, H- | A-, H- |
| vm / `TestAllocation::MethodCall#test_optional_parameter` | A- | A- |
| vm / `TestAllocation::MethodCall#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| vm / `TestAllocation::MethodCall#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| vm / `TestAllocation::MethodCall#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::MethodCall#test_required_parameter` | A- | A- |
| vm / `TestAllocation::MethodCall#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_ruby2_keywords` | R2K | R2K |
| vm / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_parameter` | A+ | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_argument_forwarding` | A+, H+ | A+, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_nested_argument_forwarding` | A+, H+ | A+, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_no_parameters` | A-, H- | A-, H- |
| vm / `TestAllocation::MethodCall::WithBlock#test_optional_parameter` | A- | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| vm / `TestAllocation::MethodCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_required_parameter` | A- | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_ruby2_keywords` | R2K | R2K |
| vm / `TestAllocation::ProcCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall#test_anonymous_splat_parameter` | A- | A- |
| vm / `TestAllocation::ProcCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall#test_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::ProcCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| vm / `TestAllocation::ProcCall#test_no_parameters` | A-, H- | A-, H- |
| vm / `TestAllocation::ProcCall#test_optional_parameter` | A- | A- |
| vm / `TestAllocation::ProcCall#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| vm / `TestAllocation::ProcCall#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| vm / `TestAllocation::ProcCall#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::ProcCall#test_required_parameter` | A- | A- |
| vm / `TestAllocation::ProcCall#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall#test_ruby2_keywords` | R2K | R2K |
| vm / `TestAllocation::ProcCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall::WithBlock#test_anonymous_splat_parameter` | A- | A- |
| vm / `TestAllocation::ProcCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::ProcCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| vm / `TestAllocation::ProcCall::WithBlock#test_no_parameters` | A-, H- | A-, H- |
| vm / `TestAllocation::ProcCall::WithBlock#test_optional_parameter` | A- | A- |
| vm / `TestAllocation::ProcCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| vm / `TestAllocation::ProcCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ | MATCH |
| vm / `TestAllocation::ProcCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::ProcCall::WithBlock#test_required_parameter` | A- | A- |
| vm / `TestAllocation::ProcCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::ProcCall::WithBlock#test_ruby2_keywords` | R2K | R2K |
