# Native frozen flags reflect intrinsic state

A frozen Class or Module crossed the C API boundary with its frozen bit
clear. Other values could call a Ruby frozen? override while their native
proxy header was refreshed. rb_obj_frozen_p used a Kernel predicate round
trip; the C API declares its implementation as the native flag query.

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
- Historical capi_check cohorts: all six contracts hold, including GC
  stress; all six negative controls fail, with 351 API checks. The historical
  VM label did not retain an executable-level mode pin. Since capi_check
  strips MERE_RUBY_* from child environments, that label does not establish
  VM execution. See the integration audit below for executable-pinned proof.
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

## Executable-pinned mode audit after integration

The owner merged #278 as main 779c7cc9 during the follow-up checks. Local
integration 282be638 has an identical tracked tree to that merge and is the
fresh O2 build measured here. Pinned main 45b09326 is the comparison binary.
Both binary digests are separate from the historical 6588c51a cohort above.
The already merged #273 fixes the former Linux headers-check failure;
headers_check now verifies 194 headers and 21 unchanged vendored sources.

The historical VM-labeled contract run was not execution-level proof:
capi_check removes MERE_RUBY_* variables from child environments. The new
audit supplies an explicit --mere executable wrapper exporting
MERE_RUBY_VM=1. The default evaluator full check passes all six contracts
with 356 API checks, including GC stress and all negative controls.

The explicit VM full API check fails after rb_protect leaves an
ArgumentError in errinfo and Ruby rescues E2. Pinned main45 fails at
capi/check/api.rb:545, the candidate at :559 (the same check shifted by
14 added lines). Both normal execution and GC stress reproduce it. The
other five VM contracts pass in both conditions. All negative controls
fail; no-builtin fails at its native override check, before the existing
errinfo failure. This VM difference is reported to the owner separately;
the VM implementation is unchanged in this PR.

All 40 added frozen checks plus loader silence pass independently on the
reference, evaluator, VM, evaluator under GC stress and VM under GC stress:
41 checks in each execution. These targeted successes do not replace the
retained full-script API failures. The historical contract label is
qualified in the original record, and the PR description is corrected.

The C API spec replay completes 46 files before and after: all 92 per-side
raw outputs are byte-identical, including existing failures, io/thread wall
limits and the unavailable digest extension. Totals remain 2,602 reference /
2,420 Mere passing examples; no all-pass spec claim is made.

Three alternating fixed-seed 12345 duration/erb_util replay pairs retain
93 MATCH / 0 RED, all COMPLETE, with the existing order diagnostic 1.
Maximum family RSS in KiB:

| File | main45, three repeats | candidate, three repeats |
| --- | --- | --- |
| duration | 311,216 /309,728 /321,040 | 310,064 /307,424 /315,216 |
| erb_util | 289,008 /289,888 /288,768 | 285,984 /283,760 /285,264 |

Bounds remain 600 seconds / 2 GiB per file family, jobs 2, MT_CPU=0. These
focused checks reuse the owned fdda9150 native install explicitly; no full
component run was started. No stable memory improvement is claimed.

Integrated corpus --both: 939/939 ON/OFF, 1,283.820 seconds, maximum family
RSS 1,216,592 KiB. VM corpus: 939 VM / 0 fallback / 0 differences,
234.762 seconds, maximum family RSS 1,159,856 KiB.
Source gates, default hygiene, headers and bracket 155/1024 pass. New and
corrected records are checked explicitly before any local record commit.

This supplemental record will be batched with a future code update; the
merged PR branch receives no record-only push. Portable evidence:
unittest/records/capi-proxy-frozen-main45.json.
