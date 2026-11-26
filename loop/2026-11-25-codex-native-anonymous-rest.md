# Follow-up review: keyword declarations without keyword arguments

The review of 457a91b3 found that borrowing an unaccompanied positional
Array is incorrect when the target declares keyword parameters, including
an anonymous or named keyword rest. Ruby snapshots this rest even when no
keyword Hash is peeled. Retain the existing immutable native snapshot for
this path; explicit keywords after the spread keep their separate borrowing
behavior. The change is confined to the existing anonymous-splat slow path.
Corpus 995 adds source append/replacement across GC and frozen-source
isolation controls for anonymous/named keyword rest, a named keyword, and
**nil. Both engines and final-head acceptance are pending. The PR is draft
again; the earlier results below apply to the earlier runtime only.

# Anonymous rest arguments in native frame storage

Validated runtime `bd5d4b09a835919f4d1ba657ad5d4ea6e62865fd`, compared with main `6d8a416dec9f1e56f6594c077014fbd90789e719`. This integrates
the frame-area argument slot, String/Array/Hash ivar doors and current main
controls. The documentation-only final commit preserves this exact runtime,
generated C, binaries, regression inputs and upstream test files.

## Result and implementation

Anonymous method rest previously constructed an unread Ruby Array on every
call. Keep private synthesized arguments as an immutable native list owned
by the method frame. Escaped closures retain it, and GC marks its Ruby values.
Named rest and explicit Array expressions remain real independent Arrays.
Eligible splats preserve the actual source Array, frozen state and mutation.
A synthesized rest becomes an Array when an isolation diagnostic observes it.

The inaccessible `__ar~` identity survives parsing, VM locals, parameter
reflection and the captured-variable walk. Ruby locals and Binding writes
cannot replace the private storage. Direct empty, nil and explicit mutable
or frozen splats retain their different shareable-Proc behavior.

Block conversion retains ephemeral sources through scoped iterator roots;
complex block expressions snapshot arguments before callbacks. The existing
root table owns and compacts deleted native storage, avoiding retained copies.
No allocation counter, exclusion, GC policy, budget or upstream test changes.

The integrated replay also fixed keyword peeling: a flagged final Hash that
becomes keywords must not remain in a borrowed positional rest. Keep the
already bound positional slice; explicit keywords after a spread still allow
borrowing. Corpus 995 now has 78 output lines covering this and capture/GC,
frozen state, isolation diagnostics, block conversion, reflection and 10,000
arguments. No unused Ruby object is created to imitate a CRuby temporary.

## Complete upstream files

Seed 1, complete unchanged files on evaluator and VM. Every main MATCH stays
MATCH. BOTH and EXTRA are zero; no driver limit or case exclusion is added.

| File | Main MATCH / RED | This runtime MATCH / RED |
| --- | ---: | ---: |
| `ruby/test_keyword.rb` | 115 / 0 | 115 / 0 |
| `ruby/test_call.rb` | 65 / 0 | 65 / 0 |
| `ruby/test_hash.rb` | 297 / 1 | 297 / 1 |
| `ruby/test_allocation.rb` | 14 / 62 | 14 / 62 |

All 76 allocation cases run. The existing Hash RED is
`TestHashOnly#test_replace_memory_leak` (timeout). No full upstream suite or
Rails cold measurement was run.

## Allocation differences by cause

These are mismatching assertions with overlapping case groups. Evaluator and
VM have identical groups. Newly missing temporaries are explicitly retained.

| Cause | Main assertions (cases) | This runtime assertions (cases) |
| --- | ---: | ---: |
| Extra rest Arrays | 218 (10) | 116 (4) |
| Absent CRuby Array temporaries | 198 (40) | 346 (46) |
| Extra keyword Hashes | 504 (38) | 504 (38) |
| Absent CRuby Hash temporaries | 8 (4) | 8 (4) |
| ruby2_keywords decoding temporary | 8 (4) | 8 (4) |

A+ remains in four generic `...` forwarding cases (PR #245). H+ is
separate keyword ownership and native-packet work. A- increases because
anonymous native storage needs no CRuby rest/concatenation Array; some checks
which previously matched now count fewer objects. Those differences remain
reported. Missing H- temporaries are not manufactured either.

For the eight R2K assertions, the marked Ruby/Proc receiver retains the
original flagged Hash, while CRuby vm_args.c creates a decoding temporary.
That internal-only copy is not imitated. Observable native-consumer copying
is a separate compatibility fix. Every assertion remains in the harness.

## Instructions retired

Same inputs and outputs, ordinary O2 builds. Counts include startup.

| Workload | Evaluator main → runtime | VM main → runtime |
| --- | ---: | ---: |
| `method_call.rb` | 3,446,823,277 → 3,421,364,678 (-0.739%) | 3,707,925,775 → 3,709,458,741 (+0.041%) |
| `method_call_200k.rb` | 5,901,609,617 → 5,910,137,287 (+0.144%) | 6,476,140,470 → 6,484,007,363 (+0.121%) |
| `block_call.rb` | 4,260,208,649 → 4,266,906,263 (+0.157%) | 5,136,699,327 → 5,137,743,822 (+0.020%) |
| `block_call_200k.rb` | 7,582,144,110 → 7,588,491,331 (+0.084%) | 9,318,702,030 → 9,330,312,717 (+0.125%) |
| `so_matrix.rb` | 200,437,802,712 → 200,615,865,919 (+0.089%) | 214,666,868,565 → 214,774,955,350 (+0.050%) |
| `anonymous_rest_call.rb` | 4,719,189,148 → 4,484,211,967 (-4.979%) | 4,810,243,900 → 4,824,835,023 (+0.303%) |
| `anonymous_rest_borrowed.rb` | 3,138,053,763 → 2,919,218,349 (-6.974%) | 2,983,438,115 → 2,924,891,917 (-1.962%) |

Ordinary method/block/matrix totals range from -0.739% to +0.157%; no material ordinary-call regression is established. Evaluator anonymous-rest controls reduce instructions by 4.979% and 6.974%. VM borrowed-source forwarding reduces 1.962%; the direct anonymous-rest VM control increases 0.303% and is retained explicitly. No counter-only operation is added to every ordinary call.

## Controlled maximum RSS

Whole allocation file alone, GC_TIGHT=1, seed 1. Every case outcome matches
normal GC. Kernel command/child high-water marks and sampled simultaneous
family peaks are distinct measurements; no Ruby observer or forced GC is added.

| Engine | Kernel command bytes main → runtime | Largest child bytes main → runtime | Sampled family KiB main → runtime |
| --- | ---: | ---: | ---: |
| evaluator | 411,877,376 → 413,728,768 (+0.450%) | 310,837,248 → 310,984,704 (+0.047%) | 727,008 → 648,976 (-10.733%) |
| vm | 406,913,024 → 408,272,896 (+0.334%) | 317,161,472 → 317,161,472 (+0.000%) | 738,352 → 725,376 (-1.757%) |

Fresh main337 whole-file controls retain every original sample. Command high-water marks rise by about 0.450% on evaluator and 0.334% on VM; these increases are disclosed, not rounded to zero. The largest-child marks differ by about 0.047% and 0.000%, while the sampled simultaneous family peaks are lower on both engines. No material retained-memory increase is established by these controlled runs. The 20 earlier alternating samples use main7a/source60d4 and remain historical evidence with their own identities, not measurements of this runtime. Final correctness validation may proceed; completed performance controls, review and owner merge are still required.

The earlier five alternating pairs per engine used main7a and source60d4.
All 20 samples and their initial four controls remain in the JSON with their
original identities. They are historical, not current-main measurements.

## Final local acceptance

- Corpus `--both`: **985/985 match**, hash index ON and OFF (669.519 s).
- VM corpus: **985 VM / 0 fallback / 0 differences / 0 failures** (214.325 s).
  No fallback-list mismatch; unchanged iv-door and shape-statistics preflights run.
- **24 focused engine comparisons** match reference stdout, stderr and exit status.
  995, 987 and existing 664 run normally and with stress50; main 949/1119,
  reader834, ivar1066/1067 and box1112 controls run normally on both engines.
- All ten source gates PASS, including iv_door and bracket-depth.
  record_hygiene PASS before/after sweeps. Header/vendor and CI-timing checks PASS.

Own full corpus sweeps are serial. Allocation runs have no supplementary
runtime probes from this session. The shared heavy-run cap is two across
Codex sessions. Code and records share one push; hosted/queued checks are
separate from these executed local passes. The owner performs the merge.

An existing native inspection callback/shareable-Proc difference remains
equally on main and this runtime. It is tracked in the native-boundary
follow-up and is not claimed fixed here.

Reference: independently built clean Ruby 4.0.10, source revision
`a704b7cd95a42cc0cf5f307137bf3aac0285b915`, 46 default / 38 bundled / zero
extra gems, Prism 1.8.2. Compiler `9dec2ff687a08433247dbdb7729bc19c8522e538`,
mgz `661a01d8bb68f5acd68e3192bd47f081d179c436`.

Binary SHA-256: `8056d420057e9b03647e6118f757cfa74c64a83532fda4be2aae24f1919dfc51`.
Generated C SHA-256: `dcbe662cb5d85a94cc2be9a3ad94963c52e22f0d1109002a060f951408aec2a2`.

## Per-case cause groups

| Case | Main | This runtime |
| --- | --- | --- |
| `TestAllocation::MethodCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| `TestAllocation::MethodCall#test_anonymous_splat_parameter` | A+ | A- |
| `TestAllocation::MethodCall#test_argument_forwarding` | A+, H+ | A+, H+ |
| `TestAllocation::MethodCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall#test_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| `TestAllocation::MethodCall#test_nested_argument_forwarding` | A+, H+ | A+, H+ |
| `TestAllocation::MethodCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| `TestAllocation::MethodCall#test_no_parameters` | A-, H- | A-, H- |
| `TestAllocation::MethodCall#test_optional_parameter` | A- | A- |
| `TestAllocation::MethodCall#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| `TestAllocation::MethodCall#test_positional_splat_and_keyword_splat_parameter` | H+ | H+ |
| `TestAllocation::MethodCall#test_required_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall#test_required_parameter` | A- | A- |
| `TestAllocation::MethodCall#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall#test_ruby2_keywords` | R2K | R2K |
| `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| `TestAllocation::MethodCall::WithBlock#test_anonymous_splat_parameter` | A+ | A- |
| `TestAllocation::MethodCall::WithBlock#test_argument_forwarding` | A+, H+ | A+, H+ |
| `TestAllocation::MethodCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall::WithBlock#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ | A-, H+ |
| `TestAllocation::MethodCall::WithBlock#test_nested_argument_forwarding` | A+, H+ | A+, H+ |
| `TestAllocation::MethodCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| `TestAllocation::MethodCall::WithBlock#test_no_parameters` | A-, H- | A-, H- |
| `TestAllocation::MethodCall::WithBlock#test_optional_parameter` | A- | A- |
| `TestAllocation::MethodCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| `TestAllocation::MethodCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ | H+ |
| `TestAllocation::MethodCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall::WithBlock#test_required_parameter` | A- | A- |
| `TestAllocation::MethodCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::MethodCall::WithBlock#test_ruby2_keywords` | R2K | R2K |
| `TestAllocation::ProcCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall#test_anonymous_splat_parameter` | A- | A- |
| `TestAllocation::ProcCall#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall#test_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall#test_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| `TestAllocation::ProcCall#test_no_parameters` | A-, H- | A-, H- |
| `TestAllocation::ProcCall#test_optional_parameter` | A- | A- |
| `TestAllocation::ProcCall#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| `TestAllocation::ProcCall#test_positional_splat_and_keyword_splat_parameter` | H+ | H+ |
| `TestAllocation::ProcCall#test_required_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall#test_required_parameter` | A- | A- |
| `TestAllocation::ProcCall#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall#test_ruby2_keywords` | R2K | R2K |
| `TestAllocation::ProcCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall::WithBlock#test_anonymous_splat_parameter` | A- | A- |
| `TestAllocation::ProcCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall::WithBlock#test_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall::WithBlock#test_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- | A- |
| `TestAllocation::ProcCall::WithBlock#test_no_parameters` | A-, H- | A-, H- |
| `TestAllocation::ProcCall::WithBlock#test_optional_parameter` | A- | A- |
| `TestAllocation::ProcCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ | H+ |
| `TestAllocation::ProcCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ | H+ |
| `TestAllocation::ProcCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall::WithBlock#test_required_parameter` | A- | A- |
| `TestAllocation::ProcCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ | A-, H+ |
| `TestAllocation::ProcCall::WithBlock#test_ruby2_keywords` | R2K | R2K |
