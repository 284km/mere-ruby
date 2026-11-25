# Native module insertion rejects refinement arguments

Native include/prepend/extend accepted a Refinement argument after #292, leaking refined
methods into ordinary ancestors. Reject that argument with `ArgumentError: refinement
module is not allowed`, preserving frozen-target priority. Ordinary modules can still be
inserted into a refinement target. This repairs the post-merge Major on #292. The
runtime change is six lines in request 36; API fixtures and corpus 1025 cover all three
operations, no ancestry/leak mutation, frozen receivers and valid refinement targets.

Runtime c15756b9, comparison main 03694405, ordinary O2 compiler 9dec2ff6. Clean Ruby
4.0.10 through `tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915,
zero extra gems, Prism 1.8.2.

Local validation:

- Corpus --both: 953/953 ON/OFF. VM corpus: 953 VM / 0 fallback / 0 differences.
Extended corpus 1025 changes from a difference on both base engines to matching
reference stdout/stderr/exit on both candidate engines.
- All eight source gates, default/explicit record hygiene, bracket depth 155 and header
check pass.
- C API evaluator: all six contracts under normal/GC stress, API 405 checks, negative
controls retained. VM: other five contracts pass; full API and stress API retain the
same `check(A.errinfo_now.nil?)` failure as fresh comparison main. All 30 targeted
insertion checks pass on reference, evaluator/VM and GC stress with newly built fixture
libraries. No full VM API all-pass claim.
- C API spec replay: 46 files, all 92 reference/Mere raw outputs byte-identical to fresh
comparison main, including existing bounded IO/thread results.
- Three alternating seed-12345 full Rails pairs: deprecation and TimeWithZone remain 250
MATCH / 4 RED; all COMPLETE, no MISSING/BOTH/UNCONFIRMED/EXTRA. Four existing DST REDs
are unchanged. Own 85-package native install explicitly reused from a9e68981; installing
and measuring binary digests recorded. Bounds 600 s / 2 GiB, jobs 2.

Peak family RSS, KiB:

| File | main | candidate |
| --- | --- | --- |
| deprecation_test.rb | 325472 / 344128 / 312304 | 324128 / 305520 / 312656 |
| time_with_zone_test.rb | 460640 / 448288 / 448432 | 445856 / 466768 / 448784 |

Ranges vary; no stable memory improvement is claimed. Evidence: `loop/2026-11-26-codex-
capi-native-refinement-arguments.md` and `capi/check/records/codex-capi-native-
refinement-arguments.json`.
