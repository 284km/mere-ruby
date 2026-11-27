# ActiveSupport deprecation dispatch

Respect Ruby overrides of Module#deprecate_constant before native frozen checks,
dispatch Module-subclass mixin hooks with their original receiver, and let undefined
==/!= reach method_missing. Corpus 942–944 covers the dispatch paths and super/refusal
controls.

Shared native-super lookup is extracted from the existing sender lookup. Ordinary native
feature insertion and ownership checks remain shared. This changes general interpreter
dispatch used by ActiveSupport deprecation proxies.

Reference: clean Ruby 4.0.10 through `tools/ref_ruby.sh`, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism 1.8.2. Ordinary O2
compiler9dec2ff6.

- Corpus --both:960/960 hash ON/OFF. VM:960 VM /0 fallback /0 differences. Corpus942–944
agrees on both engines.
- Eight source gates, bracket depth and default hygiene pass; explicit new-record
hygiene checked separately.
- Current related test_module, test_class and test_object selections compared with main;
exact per-mode summaries and cases are in the record. No whole-file pass is claimed from
a selection.
- All three targeted Rails files are COMPLETE on reference/main/candidate, evaluator and
VM. Per-mode verdicts:

- before-evaluator: {'files': 3, 'empty_files': 0, 'reference_unusable': 0,
'mere_incomplete': 0, 'order_differs': 1, 'MATCH': 86, 'RED': 7, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}
- after-evaluator: {'files': 3, 'empty_files': 0, 'reference_unusable': 0,
'mere_incomplete': 0, 'order_differs': 1, 'MATCH': 93, 'RED': 0, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}
- before-vm: {'files': 3, 'empty_files': 0, 'reference_unusable': 0, 'mere_incomplete':
0, 'order_differs': 1, 'MATCH': 86, 'RED': 7, 'MISSING': 0, 'UNCONFIRMED': 0, 'BOTH': 0,
'EXTRA': 0}
- after-vm: {'files': 3, 'empty_files': 0, 'reference_unusable': 0, 'mere_incomplete':
0, 'order_differs': 1, 'MATCH': 93, 'RED': 0, 'MISSING': 0, 'UNCONFIRMED': 0, 'BOTH': 0,
'EXTRA': 0}

Final runtime 065f2cbab9f18f0a3d69e445abf7f3eb55b25313; comparison main
d0843046ca315ca41d5d697aa0ce1d51753dd795. Exact digests and UTC cohort times are
retained. Three alternating seed12345 RSS pairs, 600s/2GiB per family, jobs2, MT_CPU=0,
native install explicitly reused from a9e68981:

| File | main RSS KiB | candidate RSS KiB |
| --- | --- | --- |
| deprecation_test.rb | 357728 / 364544 / 361200 | 295008 / 286304 / 285664 |
| proxy_wrappers_test.rb | 352224 / 362144 / 332096 | 295536 / 292544 / 289488 |

RSS varies; no stable memory improvement is claimed. Evidence: `loop/2026-11-26-codex-
rails1-deprecation-dispatch.md` and `railstest/framework/records/activesupport-
deprecation-dispatch.json`.

Current core summaries are tests/assertions/failures/errors; all executions are
COMPLETE. The existing TestObject#test_method_missing failure is unchanged before/after
on both engines. No selected pass is lost.

| File | Reference | Before E | After E | Before VM | After VM |
| --- | --- | --- | --- | --- | --- |
| test_module | 5/27/0/0 | 5/27/0/0 | 5/27/0/0 | 5/27/0/0 | 5/27/0/0 |
| test_class | 2/5/0/0 | 2/5/0/0 | 2/5/0/0 | 2/5/0/0 | 2/5/0/0 |
| test_object | 3/30/0/0 | 3/30/1/0 | 3/30/1/0 | 3/30/1/0 | 3/30/1/0 |
