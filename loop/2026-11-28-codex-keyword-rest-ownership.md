# Reuse owned keyword-rest packets on main after PR251

PR #251 is merged. This runtime integrates its post-merge main 40b25633, including the current C API buffer allocator, backtrace-node fixes and reference-aware class-watermark gate. The measurements below compare that actual main with the integrated ownership runtime; the older pre-integration measurements are not relabeled.

A completed fresh call-site keyword packet can become the callee's named keyword-rest Hash without a redundant allocation. Borrowed, forwarded, permanently flagged and ObjectSpace-published arguments retain their separate ownership rules. Native copies do not call user dup/initialize_copy hooks.

Bare super restores the invocation's original keyword origin even after an earlier call consumed the transient flag. Repeated super and consume-then-super therefore give each receiver its independent Ruby-visible keyword-rest Hash. Corpus 994 checks callback exposure, restoration and repeated-super identity; corpus 995 retains the prerequisite snapshot/isolation/exposure controls. The updated main backtrace-node corpus is also replayed.

The owner-requested ordinary method/block/matrix instruction rows are newly measured after #251 merged. The parent's one pending-source comparison is already in this main baseline. Positive measured rows remain explicit; no count-only per-call work or dummy Ruby object is introduced.

Validated runtime `f21fc4cea8bf7338ce04af03d2decc9ac9151ed1` against main `40b25633a699b24704335d95feb540cf3bb82a9c`. Documentation-only publication preserves this exact source, generated C, binaries and regression inputs.

## Complete upstream files

Seed 1; complete unchanged files, with no new RED, BOTH or EXTRA. No driver bound, exclusion, budget, GC policy or allocation counter is changed.

| File / engine | Main MATCH / RED | This runtime MATCH / RED |
| --- | ---: | ---: |
| `ruby/test_keyword.rb` / evaluator | 115 / 0 | 115 / 0 |
| `ruby/test_keyword.rb` / vm | 115 / 0 | 115 / 0 |
| `ruby/test_call.rb` / evaluator | 65 / 0 | 65 / 0 |
| `ruby/test_call.rb` / vm | 65 / 0 | 65 / 0 |
| `ruby/test_hash.rb` / evaluator | 298 / 0 | 298 / 0 |
| `ruby/test_hash.rb` / vm | 298 / 0 | 298 / 0 |
| `ruby/test_allocation.rb` / evaluator | 14 / 62 | 18 / 58 |
| `ruby/test_allocation.rb` / vm | 14 / 62 | 18 / 58 |

The Hash file has no RED cases in either mode. All 76 allocation cases run; the full upstream suite and Rails cold measurement are not run.

## Allocation causes

Groups count mismatching assertions, with overlapping case sets. Missing CRuby temporary Arrays/Hashes remain reported; no unused objects are manufactured.

| Engine / cause | Main assertions (cases) | This runtime assertions (cases) |
| --- | ---: | ---: |
| evaluator / extra Arrays | 116 (4) | 116 (4) |
| evaluator / absent CRuby Array temporaries | 346 (46) | 346 (46) |
| evaluator / extra keyword Hashes | 504 (38) | 280 (26) |
| evaluator / absent CRuby Hash temporaries | 8 (4) | 8 (4) |
| evaluator / missing ruby2_keywords copies | 8 (4) | 8 (4) |
| vm / extra Arrays | 116 (4) | 116 (4) |
| vm / absent CRuby Array temporaries | 346 (46) | 346 (46) |
| vm / extra keyword Hashes | 504 (38) | 280 (26) |
| vm / absent CRuby Hash temporaries | 8 (4) | 8 (4) |
| vm / missing ruby2_keywords copies | 8 (4) | 8 (4) |

The case and atomic mismatch tables are computed from these actual integrated runs. Keyword-rest packet reuse removes redundant observable Hash copies without hiding real Ruby objects. The four improved Method/Proc allocation cases cover positional arguments plus keyword rest, with and without blocks. Remaining generic ... rest Arrays belong to PR #245. Literal keyword packets, named-keyword filtering, native ruby2_keywords copies and source-Hash metadata remain separate follow-ups. Missing CRuby rest/concatenation Arrays and empty merger Hashes stay recorded as not matched rather than being synthesized. Every original case and assertion remains in the harness.

Reference source inspection is pinned to Ruby a704b7cd: vm_args.c arg_rest_dup/args_copy and the Prism/legacy argument compilers (prism_compile.c and compile.c setup_args_core) explain the additional CRuby splat/rest Arrays. Reference bytecode for none(*a, *a) emits splatarray true and concattoarray; none(**h, **h) emits an intermediate newhash plus two core#hash_merge_kwd calls even when h is empty. mere-ruby can retain native lists or elide an empty merge instead. Extra real keyword packets and required ruby2_keywords semantic copies remain optimization work; they are not declared fundamentally unmatchable. See the pinned [Prism argument compiler](https://github.com/ruby/ruby/blob/a704b7cd95a42cc0cf5f307137bf3aac0285b915/prism_compile.c#L1588) and [VM splat helper](https://github.com/ruby/ruby/blob/a704b7cd95a42cc0cf5f307137bf3aac0285b915/vm_insnhelper.c#L5754).

## Instructions retired

Same inputs and stdout, ordinary O2 builds; counts include startup.

| Workload / engine | Main | This runtime | Change |
| --- | ---: | ---: | ---: |
| `method_call.rb` / evaluator | 3,463,836,274 | 3,442,440,820 | -0.618% |
| `method_call_200k.rb` / evaluator | 5,936,215,730 | 5,937,498,091 | +0.022% |
| `block_call.rb` / evaluator | 4,291,910,039 | 4,292,176,045 | +0.006% |
| `block_call_200k.rb` / evaluator | 7,622,645,512 | 7,626,033,613 | +0.044% |
| `so_matrix.rb` / evaluator | 201,054,215,421 | 201,047,883,870 | -0.003% |
| `method_call.rb` / vm | 3,734,220,335 | 3,733,145,269 | -0.029% |
| `method_call_200k.rb` / vm | 6,517,285,337 | 6,518,073,190 | +0.012% |
| `block_call.rb` / vm | 5,162,221,123 | 5,164,338,508 | +0.041% |
| `block_call_200k.rb` / vm | 9,365,317,999 | 9,365,888,722 | +0.006% |
| `so_matrix.rb` / vm | 215,424,134,274 | 215,408,285,831 | -0.007% |
| `keyword_rest_method.rb` / evaluator | 4,931,200,590 | 4,833,480,167 | -1.982% |
| `keyword_rest_proc.rb` / evaluator | 5,995,186,803 | 5,894,730,490 | -1.676% |
| `keyword_rest_lambda.rb` / evaluator | 7,102,711,777 | 6,995,012,435 | -1.516% |
| `keyword_rest_method.rb` / vm | 4,951,620,405 | 4,844,435,542 | -2.165% |
| `keyword_rest_proc.rb` / vm | 6,207,148,090 | 6,093,036,838 | -1.838% |
| `keyword_rest_lambda.rb` / vm | 7,331,082,402 | 7,215,234,659 | -1.580% |

The requested instruction rows are measured on the actual post-PR251 main40b25633 and integrated runtimef21fc4ce. Ordinary method/block/matrix totals range from -0.618% to +0.044%; all positive rows remain explicit. Method/Proc/lambda keyword-rest controls improve 1.516% to 2.165% on both engines. The owned-packet operation stays inside the existing keyword-rest binding path; ordinary calls receive no new count-only operation or dummy Ruby object. The prerequisite pending-source comparison is already present in this main baseline. These data support final correctness/resource validation and make no claim of external approval or universal zero overhead.

## Controlled maximum RSS

Whole allocation file alone, GC_TIGHT=1 and seed 1. Kernel command/child high-water marks and sampled simultaneous family peaks are different measurements; all are retained.

| Engine | Kernel command bytes main → runtime | Largest child bytes main → runtime | Sampled family KiB main → runtime |
| --- | ---: | ---: | ---: |
| evaluator | 311,345,152 → 311,558,144 (+0.068%) | 311,345,152 → 311,558,144 (+0.068%) | 520,992 → 399,360 (-23.346%) |
| vm | 317,734,912 → 318,013,440 (+0.088%) | 317,734,912 → 318,013,440 (+0.088%) | 496,528 → 421,168 (-15.177%) |

The whole allocation file was measured alone with GC_TIGHT=1 and fixed seed 1 on both exact builds. Evaluator command and largest-child high-water marks rise 0.068%; VM command and largest-child marks rise 0.088%. These positive deltas remain explicit rather than being rounded to a memory reduction. Sampled simultaneous family RSS falls on both engines (evaluator 520,992 to 399,360 KiB; VM 496,528 to 421,168 KiB). Family samples measure concurrent wrapper/runner/forked-child pages separately from kernel per-process high-water marks. All 76 cases complete and match the corresponding ordinary-GC case results. The sub-0.1% per-process changes and lower family peaks show no material memory regression in this controlled local pair; this is local assessment, not external review or platform acceptance.

## Final local acceptance

- Full corpus `--both`: **1031/1031**, hash index ON and OFF.
- VM corpus: **1031 VM / 0 fallback / 0 differences / 0 failures**; no fallback-list mismatch.
- **32 focused engine comparisons** match clean reference stdout, stderr and exit status, including stress50 regressions.
- All ten source gates, record_hygiene before/after, header/vendor, CI-timing and class-watermark runtime checks PASS. Corpus driver runs the iv-door and shape-statistics preflights.

Own full corpus sweeps are serial; allocation measurements have no supplementary runtime from this session. Shared heavy cap: two across Codex sessions. Code and records are published in one batch. Hosted queued checks and reviewer approval remain separate from executed local passes. The owner performs the merge.

Reference: clean independently built Ruby 4.0.10, revision `a704b7cd95a42cc0cf5f307137bf3aac0285b915`, 46 default / 38 bundled / zero extra gems, Prism 1.8.2. Compiler `9dec2ff687a08433247dbdb7729bc19c8522e538`, mgz `661a01d8bb68f5acd68e3192bd47f081d179c436`.
Binary SHA-256 `5cef5a44684f0bec56a0435fa14fdcea178aa188836a272b89b3fa5835433329`; generated C `8e00a820bbe422889630f24a4910b6952b9b5288ef7ba420cd15a896a0ace8c0`.

Record: `loop/2026-11-28-codex-keyword-rest-ownership.md`.

## Per-case cause groups

| Engine / case | Main | This runtime |
| --- | --- | --- |
| evaluator / `TestAllocation::MethodCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_anonymous_splat_parameter` | A- | A- |
| evaluator / `TestAllocation::MethodCall#test_argument_forwarding` | A+, H+ | A+, H+ |
| evaluator / `TestAllocation::MethodCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall#test_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::MethodCall#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
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
| evaluator / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_parameter` | A- | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_argument_forwarding` | A+, H+ | A+, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A- |
| evaluator / `TestAllocation::MethodCall::WithBlock#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
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
| vm / `TestAllocation::MethodCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_anonymous_splat_parameter` | A- | A- |
| vm / `TestAllocation::MethodCall#test_argument_forwarding` | A+, H+ | A+, H+ |
| vm / `TestAllocation::MethodCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall#test_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::MethodCall#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
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
| vm / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_parameter` | A- | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_argument_forwarding` | A+, H+ | A+, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| vm / `TestAllocation::MethodCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A- |
| vm / `TestAllocation::MethodCall::WithBlock#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
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
