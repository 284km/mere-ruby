# Native C API module insertion bypasses Ruby hooks

rb_include_module, rb_prepend_module and rb_extend_object used Ruby-level
include/prepend/extend, incorrectly calling target overrides, feature hooks
and notification hooks. A dedicated native request inserts the module using
the existing class machinery while retaining frozen-target checks and
Enumerable bookkeeping. It adds no global roots or retained frames.

Runtime 0b6e5f49 integrates fd5 main. MR_MIXIN uses opcode 36; main's native
freeze (34) and Array append (35) remain intact. Corpus 1025 and twelve new
API checks cover hooks, target overrides, frozen targets and all three APIs.
The separate loader-quiet control makes thirteen isolated checks. All pass
on clean Ruby 4.0.10, evaluator, VM, and both Mere engines with GC stress.

Reference selected by tools/ref_ruby.sh: Ruby 4.0.10, source revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, 84 default/bundled specifications,
zero extra gems, Prism 1.8.2. Compiler 9dec2ff6, ordinary O2. No gems were
installed into the reference's own gem directory.

Full corpus: 949/949 with both hash modes; VM: 949 VM, zero fallback and
zero differences. All eight source gates, bracket depth 155/1024, default
record hygiene and vendored-header/source comparisons pass.

capi_check passes all six evaluator contracts, including 388 API checks,
normal and GC stress, with all six negative controls failing as expected.
The VM passes the other five contracts but its full API replay fails the
existing rescue-clear rb_errinfo check in both normal and stress modes.
The comparison-main binary with its own baseline fixture fails at the same
statement. This is retained as a VM limitation, not reported as passing.
The thirteen isolated checks added by this fix pass in all five modes.

The C API spec replay has 46 files and 92 per-side raw outputs. Every output
is byte-identical before and after (2602 reference and 2420 Mere examples).
Existing io/thread wall limits and missing digest-extension coverage remain
visible; no all-pass claim is made for those specs.

Two alternating Rails pairs use seed 12345, jobs 2, MT_CPU=0, and unchanged
600-second / 2-GiB family bounds. Both files remain COMPLETE, with combined
250 MATCH / 4 RED before and after and zero MISSING/UNCONFIRMED/BOTH/EXTRA.
The four deprecation REDs need the separate Ruby dispatch change. Native
gems explicitly reuse the owned a9e68981 85-package install; each replay
records the installing and measured binary digests separately.

Maximum family RSS, KiB:

| File | comparison main | candidate |
| --- | --- | --- |
| deprecation_test.rb | 311600 / 365376 | 346160 / 355904 |
| time_with_zone_test.rb | 456544 / 461376 | 456880 / 453024 |

Ranges vary across repetitions; no stable RSS improvement is claimed.

This PR also carries documentation-only corrections for merged PR #278:
the complete 45-file frozen-flags comparison record and its loop note.
They do not reintroduce or change that merged runtime implementation.

Portable evidence: capi/check/records/codex-capi-native-module-mixins.json.
