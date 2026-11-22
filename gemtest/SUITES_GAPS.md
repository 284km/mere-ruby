# Upstream gem suite differences

Further retention diagnostics identify old native arenas that current
map_bytes and the separate kept-region counter do not include. A read-only
exit observer sees retired capacity 17,227,776 bytes after the first batch,
153,240,752 after 19 total batches, and 95,605,176 after 21. These are separate
process observations of capacity, not RSS or a safe-to-free conclusion.
The logged full original program also reaches 2.163428x; its failed series
is retained alongside the separate passing ordinary macOS control. Inspect
native pinners, retirement epochs and declined method-store compaction in
the GC/allocator session. No release rule, root, threshold or original control
has changed. Actual metadata counters and the standalone reproduction are
documented in `tools/method_copy_retention.md`; full records are in
`method_copy_retention_r46.json`. This investigation is not a memory repair.

Hosted Method-copy still fails at 2.224702x on the unchanged 21,000-owner
control (reference 1.086532x). An operation-only receiver-elision candidate
was measured and withdrawn: it reduced transient STMT-region allocation by
33,600,288 bytes but did not improve retained RSS. Existing GC diagnostics
show logical class/method reclamation, which does not identify the retained
native allocation. VM/performance and GC/allocator investigation remains a
handoff; no collector internals, workload, warmup or threshold were changed.
Keep this failure as a merge gate. Samples and hashes are preserved in
`suites_ci_lifetime_r43.json` alongside the Linux APT/cancellation CI repairs.
Those repairs change setup and cancellation handling only; there is no new
gem sweep or baseline adoption in this round.

The IO byte-write correction in cb09d147 restores the complete original Rack
multipart file below the cap on macOS and Linux/aarch64. IO#__fd_write_nonblock
now writes the supplied bytes without the stream converter or String#b, as
CRuby does. Its repeated 10-MiB pipe writes no longer create the unnecessary
String on every retry. Witness 721 also reproduces the actual wrong bytes and
unexpected user callback before the fix. No VM, GC, C API or native allocation
policy changed. All preceding failed candidates and hosted failures below
remain historical observations; hosted validation of this fix is still needed.

The same-source macOS 129-file sweep retains all 120 strong MATCH files, eight
RED files and Request MEMORY, with no baseline regression. Separate native
Linux measurements retain the failed root/temporary-file probes and the final
ordinary-user run. The container may kill Request at its cgroup limit before
the family sampler reaches 2 GiB; its unchanged RED classification is not an
improvement over a prior MEMORY. Existing baselines, source locks and bounds
are preserved. The full records and resource comparisons are in the
`suites_io_r41_*` snapshots and `suites_io_runtime_r41.json`.

Method-copy growth remains open: the unchanged 21,000-owner control passes
in these macOS and Linux/aarch64 observations, but the earlier hosted x86-64
2x failures are not waived. An independent public ObjectSpace diagnostic sees
281 live Classes throughout on the reference and 283–297 on Mere. The actual
series is retained without assigning an unproven VM/GC cause or changing the
existing control, warmup, workload, skip policy or threshold.

The locked same-runner Linux Module comparison completes all three original
195-test / 1,240-assertion files. Actual dictionaries were independently
compared after review found a coverage-identity hole in the old collector.
The new acceptance rejects missing/extra cases or differing verdicts at equal
counts. Selected-case RSS observations are 1.492139x main / 1.575806x PR;
these do not waive older failures or identify a memory repair. The parent
observer's marker now starts on a new line to preserve the real case name.
See `module_rss_review_r53.json` for the original logs' hashes and PR audit,
including unresolved Method-copy and Module clone RSS assertions. Existing
baselines, workloads and resource bounds are unchanged.

The hosted Module complemented-entry check is under a separate controlled
comparison. PR #90 fails its RSS assertion at 2.407109x; current main fails
the same case by the original ten-second timeout. Independent O2 builds
using their actual CI compiler show full 195-test / 1,240-assertion parity
on macOS, with selected-case ratios near 1.67x on both. This does not rule
out Linux-specific behavior or establish a shared cause. A separate Ubuntu
job now compares both locked sources on one runner. Preserve the failed
hosted observations and unchanged gate in `module_rss_pr90_r50.json`.
There is no new gem measurement or memory fix in this round.

This ledger describes file verdicts from `suites_latest.json`. Raw stdout and
stderr in CI's `gem-suites-*` artifacts identify individual failed tests.
Symptoms below are observed; an unconfirmed cause is explicitly marked.
None is excluded from the measurement to improve its score.

Rake 13.2.1 contributes 46 MATCH files with its complete four-package child
dependency closure. Time ordering now follows the actual comparison
protocol; adjacent Symbol arguments after dotted calls parse; main's super
lookup retains its extended-module chain (703-705). The existing Ruby
FileUtils.touch implementation is used unchanged. Earlier preparation counts
with incomplete child environments are not baselines.

A separate Time singleton <=> override can still recurse through the native
ordered-comparison dispatcher on both the paired base and candidate. That
pre-existing case is outside Rake's now-passing files. Record it as a Ruby
semantics coordination gap in the shared dispatcher, not a VM or GC cause.

Additional pinned suites: Matrix has 2 MATCH files; Logger has 4 MATCH and
1 RED. Primitive super now stops at Hash/Array/String/Proc's actual native
ancestor before a Ruby method farther up the chain. The actual Test::Unit
Fixture observer registration therefore works in separated children. The
common method-copy path records real alias/Method-copy sharing as a private
flag in the existing owned method-source row. Replacing such a copy suppresses
its first redefinition warning; the next ordinary replacement warns. Clone
and refinement-import copies retain ordinary warnings. Anonymous owners carry
no new global warning-map entries; their flag has their method row's lifetime.
Witnesses 701 and 702; no new top-level let or collector change.

Logger's remaining test_logdevice failure compares a rotated open File with
its old pathname. File predicates currently discard its retained descriptor.
A /dev/fd path conversion trial did not match the reference and was reverted;
the real fstat primitive exists, but routing this predicate through it needs
the shared invoke_val_c0 branch. Defer that Ruby semantics edit while the
C API session owns the function; this is not a C extension dependency.

A separate pre-existing Hash subclass undef under a prepended [] wrapper
still reaches the primitive on both the paired parent and this candidate.
It is not repaired by the native-super ordering change or omitted from an
upstream file. The focused new witness tests native-super ordering and an
undef farther behind the already selected native entry.

PR #92 Module RSS follow-up (2026-11-20): its original complemented-entry
case still has a preserved hosted 2.026060x failure. A single-refinery live
snapshot no longer duplicates the fixed entry it already restores. The
unchanged local Linux case moves from 2.168020x failure to 1.722404x success,
with comparable initial RSS and all three original assertions. Complete
Module and Refinement files retain their case identities and results on
macOS and Linux/aarch64. This is a metadata-storage change in ref_snapshot,
not a change to GC or the bounds. Fresh hosted CI remains required, and
Method-copy and other resource failures are not waived. See
module_rss_pr92_r55.json; no existing source lock or baseline is replaced.

| Suite / file | Observed difference | Ownership and next step |
|---|---|---|
| minitest / `test_minitest_mock.rb` | Executes all 94 tests; 1 failure, 2 errors and 10 skips after native protocol aliases and sender fixes (previously 8 errors). The remaining cases are private Kernel stubs and a dynamic method's super fallback. | Ruby semantics. Keep the real source and exact assertion comparison; do not claim these remaining cases fixed. |
| minitest / `test_minitest_spec.rb` | All 76 tests run: 2 failures, 0 errors, 451 versus 458 assertions. Hash expectation names now reach singleton method_missing and the nested yield reaches its outer command block. Nested spec names still retain an anonymous parent description. | Ruby semantics. A reduced class overrides to_s correctly in a direct call, but Array#join still uses its native class display. The join branch is in invoke_val_c0, shared with the other sessions, so leave it untouched until available. |
| minitest / `test_minitest_test.rb` | Backtrace compression works and the missing-yield error is resolved; 8 exception Marshal/equality failures, 0 errors and 1 skip remain. A small exception wrapper with an overridden backtrace compares unequal after a Marshal round trip. The dump stores its delegated trace as its native trace; the reference keeps the native trace nil. | Ruby semantics. The Marshal branch is in `stdlib_src`, also edited by the GC session in #91/#94, so avoid that function until available. This is a coordination constraint, not a GC cause. |
| rack / `spec_headers.rb` | All 51 tests run: 3 failures, 0 errors, 282 versus 302 assertions. Hash fetch/fetch_values/dig super is corrected; the preceding result was 6 failures / 268 assertions. | Remaining Ruby semantics concern constructor default-plus-block, clone behavior and default-Proc key normalization. Native validation/copy paths reach the shared invoke_val_c0. Keep all cases and exact assertion comparisons; the shared dispatcher and allocator functions remain untouched. |
| rack / `spec_request.rb` | The complete file still reaches 2 GiB. Earlier compiler-408b03d9 runs finish the original 128-MiB NUL case and fail later in the multipart tempfile-limit case; other runs stop within NUL tests despite the same fixed seed. There is no stable failure position. The reference completes 404 tests / 1,754 assertions with 2 skips. Removing a second full regexp-subject cache copy reduces the isolated multipart case from 1,413,056 to 1,146,704 KiB, but does not repair the whole-file MEMORY verdict. | A redundant application copy is confirmed; ownership of the remaining retained pages is unproven. Keep the complete file, existing cap and failed comparisons. No VM, GC or native allocation policy change. |
| rack / `spec_rewindable_input.rb` | Exits without a summary. A reduced Tempfile writes successfully, but rewind fails after chmod(0); the underlying File fails too. The same write/rewind without chmod succeeds. | Ruby File/IO semantics. file_flush_obj reads the path outside its guarded descriptor fallback. Completing the read path also reaches invoke_val_c0, shared with the other sessions; avoid editing that shared function. |
| rack / `spec_sendfile.rb` | Two tests opening a File subclass reach IO's descriptor conversion and reject a path string. | Ruby constructor inheritance; reduce a File subclass witness. |
| rack / `spec_multipart.rb` | Local runs match all 85 tests / 239 assertions, while parent #115's macOS run 44414103487 again loses this file to MEMORY and fails the stronger gate. Earlier failures occur in the long-boundary pipe writer/reader workload. | Resource investigation, not a proven GC or VM cause. Preserve the actual failed snapshot in suites_hosted_r115_macos_failure.json, keep the 54-MATCH macOS gate and cap, and leave collector internals untouched. |
| rack-test / `uploaded_file_spec.rb` | All 10 tests pass on both sides, but 255 versus 368 assertions. `Tempfile.public_instance_methods(false)` exposes File/IO implementation helpers such as __fd_read and __ln_fill. | Ruby reflection/visibility semantics; count discrepancy remains RED. Do not hide Ruby APIs or change the test's enumeration to conceal it. |

The first batch establishes no confirmed dependency on C API/mkmf, native gem
extensions, RubyVM/ISeq, AST/Ripper/Prism trees, or GC's internal constants.
Overlap with another session's dispatch helper is a coordination constraint,
not evidence that the underlying behavior belongs to that subsystem.

A subsequent scanner investigation confirms a separate native UnboundMethod
binding gap on the paired preceding runtime as well: define a String's
singleton `length` to return `bytesize`, then bind
`String.instance_method(:length)` to that String. For `"éx"` the reference
returns 2, while the interpreter redispatches to the singleton and returns 3.
This is Ruby semantics requiring coordination in the shared `invoke_val_c0`
and `invoke_with_block0` dispatchers, rather than a native gem dependency.
Neither dispatcher changes here. A scanner position fast path that trusted
the overridden character count was withdrawn; corpus 767 preserves the
correct position behavior. No API is excluded or replaced with a fixed value.

Resolved in this batch:

- Minitest's continued format string followed by `% [arguments]` no longer
  opens a percent literal (`pct_strict_value`, corpus 667). It removes the
  syntax barrier; the rest of that original file remains measured and RED.
- Rack::MockResponse's local `alias [] new` takes precedence over its
  parent's Ruby `[]` method (`cls_meth_own`, corpus 668). The original
  `spec_mock_response.rb` changes from 1 error to 24 tests / 100 assertions
  passing, and from RED to MATCH.

Kramdown is deferred for explicit dependency reasons in the lock, not
classified as an interpreter failure. Rack 3.1.12 was replaced before the
baseline by 3.2.0 because the older test suite requires removed `cgi/cookie`.

Resolved in follow-up rounds 4-5:

- Rack's `spec_deflater.rb`: GzipWriter now consumes pending output before
  calling the destination. A consumer that accepts bytes and then raises
  no longer receives the same gzip prefix again from ensure's finish.
  `GzipWriter#__write_output` is the only zlib method changed; the original
  file becomes MATCH, as do all 96 CRuby zlib tests. Witness 671.
- Rack's `spec_mock_request.rb`: StringIO's eight backing ivars now use the
  existing internal namespace, so Psych sees only caller-added variables,
  as on the reference. It no longer serializes the stream's private State
  object. A caller's `@st` and `@label` remain visible and round-trip, while
  the stream still reads its own buffer. The original file becomes MATCH
  and all 103 CRuby StringIO tests pass. Witness 672.

Resolved in follow-up rounds 6-7:

- Block calls to File.open/new now respect Ruby overrides. The native File
  path remains available when a saved prelude IO alias is restored; its
  actual source metadata distinguishes that alias from a Ruby replacement.
  Only the File condition in `invoke_with_block0` changes. Witness 676.
- Chain receives Enumerable's existing implementation module, and
  `chunk_while` / `slice_when` defer the source and predicate until iteration.
  Early `take` stops infinite inputs, multiple yields retain their values,
  and reflected owner/ancestry remain consistent with the reference.
  Only `core_prelude_b` changes. Witness 677. The original minitest reporter
  now passes all 22 tests / 52 assertions and becomes MATCH. Enum and
  Enumerator report 159 MATCH / 0 RED / 1 BOTH; corpus reports 697/697.

Resolved in follow-up rounds 8-9:

- Rescue candidates are matched in order. A matching earlier candidate
  prevents evaluating the later expression or validating the next splatted
  value. Reached invalid values still raise TypeError. Empty/nil splats
  remain distinct from bare rescue; conversion, lexical constants,
  Module#=== and TracePoint matching retain their existing paths. Witness 678.
- Hash subclasses keep the default block supplied to Hash#initialize by
  super. The fallback retains the actual Proc, preserves existing entries,
  validates default-lambda arity and refuses conflicting arguments or a
  frozen receiver. `bind_params` and `method_body_flow_result` retain an incoming
  Proc across implicit super without confusing it with a literal wrapper's
  enclosing yield context; `block_source_proc` decodes that distinct metadata.
  Explicit replacement blocks and `&nil` retain their own behavior. Witness 679.
  Together the two fixes make the original Rack utils file MATCH with all
  63 tests / 285 assertions passing (previously 1 failure / 1 error).

The separate existing-suite merge gate is still pending. In #90's full
758-file report, ObjectSpace finalizer, Object copied-ivar and transcode ractor
tests cross their existing time bounds. Zlib is also 95 rather than 96 MATCH;
its failed case still needs confirmation. Local transcode gives 98/98 MATCH on both
main and #90; copied-ivar passes on both. Local finalizer controls instead
cross 2 GiB on #90 while main controls finish. Its cause remains unconfirmed;
do not waive the lower file count or change collector internals or limits.
The final local Hash file equals both baselines (297 MATCH / 1 RED / 8 BOTH),
and the Exception file gives 98/98 MATCH. A cancelled bootstrap shard left
nine files unmeasured; the ordinary hosted workflow is rerun at the same bounds.

Resolved in follow-up rounds 10-11:

- A primitive singleton's undef now blocks the inherited native method in
  response queries and calls, including block-bearing send/public_send.
  User method_missing/respond_to_missing?, redefinition and saved aliases keep
  their behavior. The original Rack Lint file becomes MATCH, with all
  37 tests / 763 assertions. Witness 681.
- A class/module override's super to Module#name uses the existing mod_name_val
  implementation, preserving nil anonymous names, late naming, frozen cached
  strings and arity. The shared super lookup remains unchanged. Witness 682.
  Minitest spec and Rack headers now reach their original test summaries;
  their remaining failures stay RED. Rack request instead reaches its memory cap.

Review corrections retain captured native Method/UnboundMethod definitions
and saved String/Array/Proc aliases after undef. The retained dispatch bypass
ends before Ruby block bodies, coercion methods and defaults, and string eval.
An Enumerator returned by a retained native each still redispatches by its
ordinary source name; its next/to_a correctly fail after that name is undefined.
Module#name super also checks the actual method origin: replacing Module's
own name no longer revives the native definition beyond Module. Expanded
witnesses 681/682, all 701 corpus programs and the unchanged 62-file inventory
pass their respective reference/baseline checks on fresh O2 source a3ad911a.
The file totals remain 53 MATCH / 7 RED / 2 MEMORY, with no lost MATCH.

An additional reduced lookup gap predates both rounds: prepending a name
wrapper above a singleton's undef can bypass the wrapper and return nil,
where Ruby raises from super. The before/after controls agree on that wrong
answer; the shared lookup/dispatch path remains untouched. It is not an
exclusion from any original upstream file or a claimed MATCH.

Additional reduced controls expose pre-existing primitive lookup gaps: a
String singleton's native to_s loses receiver identity, its concat override
can be ignored, and an UnboundMethod owned by that singleton refuses to bind
back to the same String. The paired base agrees on those wrong answers.
Original native Method/UnboundMethod retention and saved-alias lookup are
checked separately; these additional gaps are not claimed as repaired or
removed from an upstream file. Their shared dispatch paths remain occupied
by the other sessions.

Resolved in follow-up rounds 12-13:

- A missing name on a primitive reaches its singleton's Ruby method_missing.
  Real Ruby definitions, native aliases and the existing native owner table
  are checked first; response claims are not used to decide existence.
  Native method_missing super consumes the requested name before the generic
  primitive fallback, preserving NoMethodError name/receiver/args. Witness 683.
- Dotted and safe-navigation command arguments retain the enclosing command's
  do-block suppression. A trailing do...end belongs to the outer command;
  direct calls and brace blocks keep their binding. Only safe_nav_bare and
  attach_block_method change in the language parser, not the AST/Prism tree
  APIs. Witness 684 also reproduces Minitest's regex/filter/Mutex/yield shape.
- Minitest spec's 4 errors and Minitest test's 1 error are gone. Their files
  remain RED for the differences above. Fresh O2 source 61d57736 keeps the
  same 53 MATCH / 7 RED / 2 MEMORY and all 703 corpus programs match Ruby.

The round 12-13 review correction also checks active refined_impl_for before
declaring a primitive name missing. Expanded 683 covers refined Hash/Array/
String/Proc methods with singleton missing hooks, keywords and send/public_send;
ordinary unhandled names still reach the hook. Fresh O2 source 77e39520 keeps
the same file totals with no regressions. Method remains 97 MATCH / 1 RED,
and paired base/candidate Refinement files both give 121 MATCH / 1 BOTH.

A separate block-bearing refined Hash call falls through to an Array receiver
on both the pre-round base and the corrected runtime. This pre-existing block
dispatch gap is not claimed as repaired by the missing-hook guard; the
original upstream inventory and its file verdicts remain unchanged.
The source-audit correction also makes explicit physical gem libraries win
before the bundled stdlib at its actual load-path position. do_require0 and
resolve_feature share load_path_pick_shipped; witness 685 covers converted
path entries, physical and relative imports, and real Marshal dump/load after
clearing $LOAD_PATH. Mere's private serializer retains its existing internal
loading behavior. This adds no public __marshal feature.

The audited PR #90 build on main 3eb24fef retains 48 MATCH / 13 RED /
1 MEMORY. All 62 reference files and 61 Mere files record a library from the
locked gem's lib; the killed multipart process cannot finish an exit audit.
The previous snapshot is preserved and the explicit command-only protocol
transition reports no lost MATCH or changed reference coverage. Seven
classification/provenance controls pass. The core runner's reference fallback
now follows each runtime's stdlib, including the RubyGems-specific fallback.
Require 51 MATCH / 1 BOTH, Autoload 27 / 1, GemVersion 32, Integer 38,
TracePoint 97 and PP 36 MATCH retain the successful main controls. These
focused results do not replace the complete hosted file-level merge gates.
The integrated corpus is 705/705 MATCH and generated C needs bracket depth
932, within the existing 1024 build limit. Only the check's search seed is
updated to the measured depth; the compiler limit is unchanged.

On the rounds 4-5 branch, the same source-audit correction and main 3eb24fef
retain 50 MATCH / 11 RED / 0 BOTH / 1 MEMORY (normal O2 source f2f57fa7).
The preserved pre-audit snapshot and transition now refer to this branch's
own previous result; its two additional Rack MATCH files remain MATCH.
Reference audits cover 62 files and Mere audits 61. No inventory, dependency
or bound changes and no per-file comparison regressions.

On the rounds 6-7 branch, normal audited O2 source d403f444 including main
3eb24fef retains 51 MATCH / 10 RED / 0 BOTH / 1 MEMORY and 709/709 corpus
matches. Reference and Mere audits cover 62 and 61 files. Its own pre-audit
51-MATCH snapshot is preserved, and the explicit transition reports no lost
MATCH or reference coverage. Subsequent hosted-driver and standalone-loader
corrections are checked separately before claiming combined-head results.
Hosted validation exposed reference-fallback ordering in other existing
drivers and a fake interpreter that did not answer the new path query.
runtime_load_path.sh now supplies the actual selected runtime's paths before
reference fallbacks across core/bootstrap/tool, Unicode, NKF, Psych and YAML
checks. The fake harness explicitly answers the query and verifies the order.
Its 20 controls pass, as do Unicode, original NKF, Psych scalar/large-input/
lifetime and YAML Store controls. No timeout, RSS or skip policy changes.

Keep the existing standalone bundled-library contract as well: after the
physical prefix is searched, shipped source remains available even when the
user clears $LOAD_PATH. The original tmpdir-without-fileutils control passes;
Marshal's internal implementation uses the same general fallback. Normal O2
source 53e0077f retains the strict audited 48 MATCH / 13 RED / 1 MEMORY,
zero regressions and 705/705 corpus matches.

The bootstrap eval shortfall is independently corrected in const_assign_key:
an immediate string-eval scope has no singleton constant namespace. Follow
the existing lexical env and cref before a bare write, including iterator
and retained Proc bodies, and raise the actual TypeError without touching
the VM or collector. Witness 693. The original native bootstrap runner gives
49/49 MATCH; core Eval 39 MATCH / 1 RED, Module 195 and Const 5 retain both
baselines, and the isolated corpus gives 705/705. Combined-main validation
is still required. Class.new blocks that change cref incorrectly and bare
class declarations in such a scope remain separate existing lexical gaps;
they are not claimed as fixed by the bare-write guard.

Final combined rounds 6-7, normal O2 source 7a79b8db: 51 MATCH /
11 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY, zero strict-baseline regressions.
Final combined rounds 4-5, normal O2 source 9730ae28: 50 MATCH /
12 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY, zero strict-baseline regressions.
Final combined first gem-suite PR, normal O2 source 4ff6b54f: 48 MATCH /
14 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY, zero strict-baseline regressions.
All 62 files on both sides finish the locked-library source audit. Multipart
finishes below the RSS cap with one custom-params-hash error (test_0034),
85 tests / 238 assertions versus the reference's 239. Its prior MEMORY/RED
variation is not a new MATCH or an inferred VM/GC cause.
File override, Chain, provenance and constant witnesses 676/677/685/693 match the reference. The earlier full corpus was 709/709 before the final shared corrections. The final hosted corpus and every existing-file comparison remain merge gates.
The earlier full corpus was 707/707 before the final shared corrections. The final hosted corpus and every existing-file comparison remain merge gates.
Integrated corpus: 706/706. The provenance-checked bootstrap harness gives eval 49/49 MATCH, both COMPLETE. Hosted gem jobs pass on Linux and macOS. The Linux runtime job reaches the documented complemented-method-entry leak timeout. Its artifacts are preserved; GitHub rejects reruns while the enclosing workflow is active, so that retry remains pending.

Audited rounds 8-9, O2 source 72effb05 on main 3eb24fef: two consecutive
normal full runs give 53 MATCH / 9 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY.
All 62 files on each side audit the locked library. Ordinary comparison
against this branch's preserved pre-audit 52 MATCH / 9 RED / 1 MEMORY gives
zero regressions, with identical source/dependency pins and reference tallies.
Multipart gives 85 tests / 239 assertions in both runs, with peaks about
1.69 and 1.36 GiB. Its earlier MEMORY/RED variation remains recorded; neither
its cause nor attribution to a specific change is established by these runs.
The macOS snapshot uses the second full run. Hosted Linux before the audit
(43989409595) and after it (44248949546) both give 52 MATCH / 9 RED / 1 MEMORY,
with no per-file regression. Multipart remains MEMORY in both Linux runs.
Keep separate actual OS baselines and reject cross-platform comparisons;
retain the macOS 53-MATCH gate and both original Linux observations.

The subsequent rounds 10-11 candidate on the same main 12ca1df2 loses the
parent's macOS multipart MATCH to MEMORY, both in a full run and a focused
repeat. The parent's focused run still matches (85 tests / 239 assertions,
1,450,768 KiB peak). This is a real per-file merge blocker despite equal
total MATCH counts from a different gained file. Route the producer/reader
resource investigation to the VM/performance session; no specific VM or GC
cause is established. Keep the 600-second/2-GiB bounds and parent baseline.

The latest reviewed #107 hosted macOS observation (44282560161, merge source
1d0164ee) passes the unchanged original gate: 54 MATCH / 7 RED / 1 MEMORY.
Multipart completes all 85 tests / 239 assertions with both source audits,
at 2,037,376 KiB peak. The source of the local/hosted resource variation is
still unconfirmed. Keep the stronger stored baseline, the failed local
candidate and the successful hosted observation; neither erases the other.
The subsequent strict rounds 19-21 macOS run 44292334030 again loses multipart
to MEMORY. Keep that failure alongside #107's preceding successful hosted
observation. The cause of this variation remains open. Separately, strict
Linux run 44292334299 fails the new Method-copy lifetime check at 2.086x.
copy_meth_src now publishes each destination's location/flags once and avoids
rewriting an already-shared source. Paired unmodified controls lower peak RSS
on macOS and Linux/aarch64; their raw series and the failed hosted x86-64
observation are retained in method_copy_lifetime_latest.json. The unchanged
2x check and final hosted result remain merge gates.


Rounds 23-24 also retain a separate existing coordination gap: undef_method
on a Hash subclass's singleton rejects inherited native [] before a Ruby
entry is defined. A standalone control raises NameError on both the paired
parent and candidate, while the reference removes it. That native availability
path reaches the shared Module dispatcher. Witness 706 instead exercises a
real Ruby parent definition followed by undef, and proves that the resulting
tombstone blocks the native constructor. No upstream case is omitted.

The full candidate at 170fb4b8 passes the preceding macOS file gate with
54 MATCH / 7 RED / 1 MEMORY. Preserve both the preceding 53-MATCH baseline
and failed candidate independently; adopt the actual stronger 54-MATCH
snapshot without changing sources, reference counts or bounds. Multipart's
2,006,464-KiB success is an observation, not a proven resource fix. Linux keeps
its own measured baseline. The additional and Rake strict comparisons retain
6 MATCH / 1 RED and 46 MATCH respectively.


Review of the first constructor head found two regressions: consuming a
native alias bypass in the early guard let the final core check enter the
Ruby override, and a singleton walk could choose an included method after
Hash/Array's native owner. Source 1d0cbe6b preserves the bypass until the
correct native entry, stops ordinary lookup and super at that owner, and
retains earlier Ruby definitions/tombstones. New 708/709 detect the previous
head; all 706-709 match normally and with GC.stress. The corrected full run
retains the strict 54-MATCH macOS baseline, additional 6 MATCH / 1 RED and
Rake 46 MATCH. No failed observation or stronger gate is removed.

Rounds 26-27, source 72adb4d3, repair Hash's native fetch/fetch_values/dig
entries reached through super. The unchanged Rack Headers file now completes
51 tests / 282 assertions with 3 failures and no errors, versus 268 assertions
and 6 failures before this change (reference: 302 assertions). It remains RED.
The remaining failures concern clone's subclass behavior, a constructor given
both a default and a block, and default-proc key normalization. They are not
new API exclusions or attributed to native gem dependencies.

Separate controls retain two existing shared-dispatch gaps. With a custom
hash/eql? key, a Hash subclass's fetch can bypass its Ruby wrapper; the
reference returns [:ruby_wrapper, 42], while both the saved parent and this
candidate return 42. Binding the subclass's Ruby UnboundMethod to its own
Hash instance also raises TypeError on both implementations here, while the
reference calls the wrapper. The custom-key lookup in witness 710 runs before
the prepend; the native fetch_values super path still exercises that key
protocol. These dispatcher/binding coordination items are not claimed fixed.
The original upstream file is unchanged, and its three failures stay visible.

The unchanged Method-copy lifetime control fails on parent #115's hosted
Linux job 135189701023/run44414103412 at 2.056209x (85,040 to 174,860 KiB
post-GC); reference ratio is 1.086240. It completes in 3.089 seconds without a
600-second/2-GiB event. The raw series remains a real failed 2x assertion.
Consecutive saved-binary Linux/aarch64 controls observe parent 1.894/2.035
and candidate 2.053/1.889; both fixed binaries have a pass and a failure.
This does not establish a collector cause or make the failure known noise.

A trial reading each metadata row once preserves expanded warning controls,
but Linux observes 1.900/2.119, so it is not adopted. Its source edits and
added control are restored. All observations, including failures and the
unmodified check digest, remain in method_copy_lifetime_latest.json. No
threshold, warm-up, workload, metadata runtime or collector change follows
from the native protocol correction. Allocation/owner-lifetime investigation
remains open alongside the multipart resource issue; no resource fix is claimed.


Rounds 32–34 add two healthy original files: Abbrev 0.1.2 and Singleton 0.3.0
both MATCH on macOS and network-disabled Linux/aarch64. They have no native
extension/runtime dependency and reuse the existing pinned Test::Unit closure.
No runtime changes are adopted in this round.

A missing-super prototype reaches a class receiver's singleton hook, reducing
Mock to 1 failure / 1 error / 145 assertions, but it retains the super reason
after nested missing calls. The saved parent and reference correctly replace
that reason, including when the inner hook handles its missing call normally.
This is a real regression despite the prototype's 732/732 corpus and unchanged
core MATCH counts. All three runtime changes and both temporary witnesses are
withdrawn, with the observations retained in suites_rejected_r33.json and the
three named trial snapshots. New corpus 714 protects the previously passing
nested-call behavior. Mock remains at the parent result stated above.
Coordinated missing-reason work must cover shared dispatch paths, including
invoke_val_c0, which remains occupied. It is a Ruby semantics coordination
gap, not a C extension, VM or collector cause.

The final 117-file candidate on the unchanged runtime again loses multipart
to MEMORY. Preserve its failed candidate and the stronger 54-MATCH original
baseline. Parent #118's Linux additional run 44440077865 also fails the
unchanged lifetime assertion at 2.270x (85,032 to 193,020 KiB post-GC;
process peak 205,760 KiB, 2.979 seconds, exit zero; reference healthy).
Additional gem measurement is not reached. Retain every failed series;
neither the new passing files nor a local passing lifetime observation
resolves these resource gates.

A read-only reduction of Rack Sendfile confirms File.new/open, including a
block-bearing open, accepts a pathname on the reference but rejects it as an
Integer conversion on both the saved parent and rejected prototype when the
receiver subclasses File. File itself works. Keep this shared constructor/
allocator investigation separate; no native gem is required by the reduction.


Rounds 35–37 add twelve MATCH files from Forwardable 1.4.0, Delegate 0.7.0
and URI 1.1.2 on macOS and network-disabled Linux/aarch64. All 158 tests /
3229 assertions run without skips; no runtime change is adopted.

Retain the earlier preflight versions and their actual 9 MATCH / 1 RED /
2 BOTH verdicts. Forwardable 1.3.3 expects backtick message quoting and URI
1.0.3 calls the removed Ractor#take API, both failing on reference Ruby 4.0.9.
Delegate 0.4.0's Proc#ruby2_keywords/define_method forwarding passes its final
hash positionally on Mere. The underlying implementation site is not yet
confirmed or repaired; record it as Ruby keyword semantics. Delegate 0.7.0
uses generated `...` forwarding methods instead. Its passing result does not
claim that the old path is repaired. I18n's helper/Gemfile pre-audit still
needs a validated isolated Bundler development closure; it is not measured
or classified as an unavoidable native-extension dependency in this round.

Actual #119 small-suite hosted jobs are green on both OSes. Its Linux
lifetime check passes at 1.996285x using the identical fbbd0199 executable
that failed at 2.269969x on #118; preserve both separate-hosted-run series.
No resource cause is established. Its full build fails the known-noise
Module complemented-entry memory-leak case at 2.371912x. A requested job
rerun is rejected with HTTP 403 while the containing workflow remains active;
record the retry as pending, not accepted or successful. The stronger original
baseline, failed multipart observations, and all existing-file gates remain.

The remaining stdlib-caller P2 also affected `mspec/scoreboard.sh` and
`run_corpus.sh` when reference library directories were supplied through
RUBYLIB. Mere now receives its own load paths before those fallback paths;
the reference's order stays unchanged. The scoreboard queries Mere once per
sweep, and a direct `run_spec.sh` invocation applies the same ordering.
No interpreter function or explicit `-I`/`$LOAD_PATH.unshift` precedence changes.
The original `core/nil/to_s_spec.rb` changes from a monitor.so startup LoadError
to 2 passes on both sides. The stdlib-mode scoreboard gives 17 MATCH / 1 SKIP
for all 18 core/nil files, with no DIFF/CRASH/SLOW. Corpus 01, 220, 525 and
685 match in both hash modes with reference fallbacks supplied, including
physical Base64 replacement; they previously failed at monitor.so startup.
The ordinary complete corpus run gives 707/707 MATCH in both hash modes,
589.759 seconds and peak process-family RSS 1,061,456 KiB, within the unchanged
900-second / 2-GiB aggregate bound. Base64's original locked test file also
retains MATCH (9 tests / 73 assertions) and both physical source audits.
Six driver controls pass on macOS; five pass on Linux, where the BSD-time
mspec execution control runs only on the macOS job. These controls have a
separate two-OS workflow; existing workflow limits and gem snapshots are unchanged.

A separate exploratory full-corpus run with the added reference stdlib and
bundled-gem directories stops at corpus 178: `$_` before the first read is
`"ext/stringio/extconf.rb"` on Mere versus nil on the reference. This is an
observed additional environment-dependent Ruby semantic difference; its cause
is not isolated, and it is not assigned to VM, AST, C API or GC internals.
It is retained as an open difference, not counted as a successful full sweep.


PR 107 Method-copy follow-up (2026-11-22): restore the previously authorized
`compact_method_store` floor correction omitted from public `263c2dd6`.
Ordinary macOS O2 parent/candidate/candidate/parent gives
1.682880 / 1.380188 / 1.382723 / 1.679791 under the unchanged original 2x assertion
and all 21 prefixes. Preserve the hosted 2.151589x failure and require new hosted
evidence. Complete core Module, Refinement and Method lose no passing case.
The original 69 gem files retain 60 MATCH / 7 RED / 0 BOTH / 2 MEMORY with no
lost accepted MATCH. Logger is now MEMORY in the full sweep; a first separate
parent is RED, then all four predetermined whole-file comparisons are MEMORY,
including both parents. Neither Logger's root RSS growth nor its File identity
error is fixed. Rack Request remains MEMORY. Full corpus 738/738 matches in
both modes. See `method_floor_pr107_r101.json` for all observations and identities;
no snapshot or bound is changed, and this is not Linux or latest-main merge proof.
