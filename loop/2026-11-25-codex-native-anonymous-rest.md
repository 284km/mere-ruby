# Anonymous-rest current-main integration and acceptance

Current integrated runtime `41c3dac95da23fa65e9b9b467600b5a5a26bb161` merges main `83bc573585b0e73c3266edd2f30fd7d80c2391eb`. The bot's Major is fixed: a bare positional splat into a keyword-declaring method uses a positional snapshot. Explicit keyword operands retain Ruby's separate copy/borrowing rules, including empty variables/nil versus a literal empty Hash and potentially mutating keyword expressions. Native immutable slices preserve the snapshot without a dummy Ruby Array.

The main conflict is resolved by retaining the shared native splat helper and main's `invoke_own` boundary for Hash/Object `to_a` callbacks. Frame and ivar doors remain intact. Corpus 995 includes 149 output lines, including a 48-control keyword-shape matrix, source append/replacement, frozen-source isolation and mutation/GC during keyword evaluation.

## Current-main integration acceptance

- Corpus `--both`: **1006/1006**, hash index ON and OFF.
- VM corpus: **1006 VM / 0 fallback / 0 differences / 0 failures**; no fallback-list mismatch.
- **24 focused engine comparisons** match clean Ruby stdout, stderr and exit status. 995, 987, 664 and main's builtin-refinement callback836 run normally and with stress50; 835 and795 controls run on both engines.
- All ten source gates, record_hygiene before/after, header/vendor and CI-timing checks pass. Corpus driver retains iv-door and shape-statistics preflights.

Per the owner's current-main replay request, these are fresh integrated corpus/gate results. The unchanged whole-file, allocation, RSS and instruction comparisons below were completed on runtime `05387e86` against main `6d8a416d` before this integration and the cold ObjectSpace publication correction; their exact identities are retained, and they are not relabeled as new-main measurements. The source-only main83 ancestry checkout is not presented as a tested binary. No full unit suite or Rails cold measurement is run.

Live anonymous rest is also published when ObjectSpace enumerates Array-compatible objects. The observer updates the actual retained/active/suspended frame slot before taking its object snapshot, so later mutation and freezing are seen by closures and resumed Fibers. This adds no registry, normal-dispatch check, count_objects change or forced GC. Direct and keyword-declared capture, active frames, suspended Fibers and frozen/shareable exposure match both engines, normally and with stress50.

Code and final records share one push. Exact-head review by the bot, hosted checks and the owner's merge remain separate from these local passes.

Integrated binary SHA-256 `f894163782453870c5601625ca5a96fd5dd92da2f03e82becd65be43a7e41565`; generated C `3777cac6e1dab750716298fe8cb5c79c07c0236acf826bc06bbd77b8b9847397`.

## Completed pre-integration file and resource comparisons

# Anonymous rest arguments in native frame storage

Validated runtime `05387e86418293d8e1f9cb09ec3a0aeb228c6770`, compared with main `6d8a416dec9f1e56f6594c077014fbd90789e719`. This integrates
the frame-area argument slot, String/Array/Hash ivar doors and current main
controls. The earlier replay used the runtime and binary identities stated in this subsection; the current integrated runtime is identified above.

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
borrowing. Expanded corpus 995 covers both review findings and capture/GC,
frozen state, isolation diagnostics, block conversion, reflection and 10,000
arguments. No unused Ruby object is created to imitate a CRuby temporary.

The follow-up P2 at 457a91b3 is corrected: keyword-declaring methods called
without an incoming keyword packet snapshot positional rest instead of
borrowing the caller's Array. The existing immutable native slice preserves
later source append/replacement and frozen-source isolation semantics,
without manufacturing a Ruby Array. This eligibility check is inside the
existing anonymous-splat slow path. The corpus covers anonymous/named keyword
rest, a named keyword and **nil, retaining explicit-keyword borrowing controls.
The exact direct-call review witnesses also run normally and with stress50.
The earlier ready state was withdrawn when this finding arrived; readiness
requires this new runtime's acceptance and the post-push comment audit.

The expanded regression also distinguishes explicit empty keyword syntax:
**empty and **nil can retain the spread source, while a literal **{} and
potentially mutating keyword expressions snapshot it. The key/value/splat
classification follows the same rule as the existing block-pass classifier.
The 48 shape controls and keyword-expression mutation/GC witnesses are part
of the 144-line corpus 995, which matches both engines normally and at
GC stress50. Native immutable slices retain the snapshot without an unused
Ruby Array.

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
| `method_call.rb` | 3,440,159,101 → 3,445,759,723 (+0.163%) | 3,705,945,873 → 3,712,213,508 (+0.169%) |
| `method_call_200k.rb` | 5,907,120,955 → 5,914,202,383 (+0.120%) | 6,477,998,639 → 6,492,959,264 (+0.231%) |
| `block_call.rb` | 4,265,552,772 → 4,277,223,464 (+0.274%) | 5,138,302,602 → 5,144,438,208 (+0.119%) |
| `block_call_200k.rb` | 7,591,863,778 → 7,589,082,427 (-0.037%) | 9,318,885,253 → 9,329,766,048 (+0.117%) |
| `so_matrix.rb` | 200,441,318,003 → 200,892,537,422 (+0.225%) | 214,719,586,439 → 215,435,994,747 (+0.334%) |
| `anonymous_rest_call.rb` | 4,736,542,591 → 4,484,876,906 (-5.313%) | 4,820,914,015 → 4,850,855,106 (+0.621%) |
| `anonymous_rest_borrowed.rb` | 3,163,134,923 → 2,956,695,657 (-6.526%) | 2,990,033,403 → 2,965,916,033 (-0.807%) |

Ordinary method/block/matrix totals range from -0.037% to +0.334%. The increases remain explicit; no material ordinary-call regression is established at this scale. Evaluator anonymous-rest controls improve 5.313% for direct calls and 6.526% for borrowed sources. VM borrowed-source forwarding improves 0.807%, while the direct anonymous-rest control increases 0.621%; no claim of universal VM improvement is made. The keyword-expression classification is confined to calls that already have a splat, and no counting-only operation or dummy Ruby object is added to every ordinary call. This is a local performance assessment, not external approval.

## Controlled maximum RSS

Whole allocation file alone, GC_TIGHT=1, seed 1. Every case outcome matches
normal GC. Kernel command/child high-water marks and sampled simultaneous
family peaks are distinct measurements; no Ruby observer or forced GC is added.

| Engine | Kernel command bytes main → runtime | Largest child bytes main → runtime | Sampled family KiB main → runtime |
| --- | ---: | ---: | ---: |
| evaluator | 310,886,400 → 311,918,592 (+0.332%) | 310,886,400 → 311,918,592 (+0.332%) | 563,808 → 496,832 (-11.879%) |
| vm | 316,899,328 → 317,440,000 (+0.171%) | 316,899,328 → 317,440,000 (+0.171%) | 401,648 → 461,760 (+14.966%) |

Current corrected-source whole-file controls retain all four runs. Kernel command/largest-child maxima rise 0.332% on evaluator and 0.171% on VM; these small increases are disclosed, not rounded to zero. Sampled simultaneous family RSS falls 11.879% on evaluator but rises 14.966% on VM (401,648 → 461,760 KiB). The VM sampled peak moves from MethodCall#test_argument_forwarding on main to Literal#test_hash_literal on this runtime; the dominant child high-water marks remain 316,899,328 → 317,440,000 bytes. Evaluator peaks likewise move from array literal to hash literal. The family metric counts simultaneous resident pages across runner, forked child and wrappers, and is not one process's heap. Peak-event components and every high-water measurement are retained. This does not establish a material retained-memory regression; the sampled-family increase remains visible for review. All 76 case outcomes remain identical under tight GC and seed 1. This local assessment permits final correctness checks and is separate from external review and owner merge. Earlier main7a/source60d4 samples retain their original identities.

The earlier five alternating pairs per engine used main7a and source60d4.
All 20 samples and their initial four controls remain in the JSON with their
original identities. They are historical, not current-main measurements.

### Pre-integration complete replay

- Corpus `--both`: **985/985 match**, hash index ON and OFF (775.962 s).
- VM corpus: **985 VM / 0 fallback / 0 differences / 0 failures** (232.089 s).
  No fallback-list mismatch; unchanged iv-door and shape-statistics preflights run.
- **32 focused engine comparisons** match reference stdout, stderr and exit status.
  995, 987, existing 664 and exact direct P2 witnesses run normally and with
  stress50; lexical yield, Method/frame/reader/ivar/box controls run on both engines.
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

Binary SHA-256: `ccb0cd75722e0cd951147851c1328bdcb2d90a4472e49e662b653c48f61b84dc`.
Generated C SHA-256: `2bae2356ace6c210dc188c9d583f47b70710d75dc8a45a5e845719cad6cec328`.

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
