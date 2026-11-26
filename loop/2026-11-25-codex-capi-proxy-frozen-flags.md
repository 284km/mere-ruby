# Native frozen flags reflect intrinsic state

A frozen Class or Module crossed the C API boundary with its frozen bit
clear. Other values could call a Ruby frozen? override while their native
proxy header was refreshed. rb_obj_frozen_p also sent that Ruby method,
although the C API declares its implementation as the native flag query.

Runtime 6588c51a makes proxy refresh read val_is_frozen for every kind and
implements rb_obj_frozen_p with RB_OBJ_FROZEN. No Ruby callback is entered
for this predicate, including during GC. The change is limited to the
native description and one C API function, plus conformance fixtures.
C API API tests add 40 checks across Class, Module, Object, String, Array,
Hash, Proc and Binding. Corpus 1020 compares function and macro flags,
including a frozen? override and ordinary mutable/frozen Regexps.

Base main 44aa511b, ordinary O2 compiler 9dec2ff6. Clean reference Ruby
4.0.10, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, 84 default/bundled
specifications, no extras and default Prism 1.8.2. No reference gem-directory
installation was performed. A prospective merge with main 5276535f is clean;
that prospective tree is not claimed as a measured build.

Validation:

- Corpus --both: 894/894 ON/OFF, 1,481.952 s, peak 1,197,472 KiB.
- VM corpus: 894 VM / 0 fallback / 0 differences, 301.340 s,
  peak 1,218,208 KiB. Eight prefix source gates and default hygiene pass;
  the generated-C bracket gate needs 155 of 1024.
- capi_check on evaluator and explicitly on VM: all six contracts hold,
  including GC stress at every safepoint; all six negative controls fail.
  API contract count is 351 on reference, Mere and stress in each mode.
- C API spec replay: all 46 per-side normalized output digests match main.
  Both runs have 2,602 reference / 2,420 Mere passing examples. Existing
  failures and io/thread wall limits remain; this is not an all-pass replay.
- Additional scalar and nil-returning Ruby callback checks match reference
  in evaluator/VM with and without GC stress (four complete executions).
- Related full Object/Module records and earlier child timeouts are retained.
  Latest copied-ivar retries pass 1 test / 2 assertions on main and candidate
  in both modes, keeping the unchanged 500,000 iterations and 60-second
  child deadline. A combined-stderr warning appends Ignoring to the parsed
  name; the requested single-test filter is explicit in the record.
- An unchanged-loop diagnostic completed all eight 500,000-clone runs.
  Wall times vary 40.580-55.564 s across builds and modes; no stable
  performance improvement is claimed and earlier timeouts are not erased.

Three alternating fixed-seed 12345 Rails duration/erb_util replay pairs:
93 MATCH / 0 RED before and after, both sides COMPLETE, all other verdicts
zero; existing order diagnostic remains 1. Bounds stay 600 s / 2 GiB,
jobs 2. Native gems explicitly reuse the owned fresh SDK/system-library
install of fdda9150; both installer and measured binary hashes are recorded.

Maximum family RSS, KiB:

| File | main, three repeats | candidate, three repeats |
| --- | --- | --- |
| duration | 332,512 / 327,328 / 329,744 | 329,360 / 330,848 / 328,000 |
| erb_util | 286,640 / 285,984 / 291,056 | 280,496 / 282,864 / 286,672 |

The ranges overlap; no stable memory improvement is claimed. This is a
focused component replay, not a full component run. Protected native-gem,
ERB-vendoring and bignum implementation files are unchanged.

Portable evidence: unittest/records/capi-proxy-frozen-flags.json.
