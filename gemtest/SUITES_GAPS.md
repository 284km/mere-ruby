# Upstream gem suite differences

This ledger describes file verdicts from `suites_latest.json`. Raw stdout and
stderr in CI's `gem-suites-*` artifacts identify individual failed tests.
Symptoms below are observed; an unconfirmed cause is explicitly marked.
None is excluded from the measurement to improve its score.

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
| minitest / `test_minitest_mock.rb` | Executes all 94 tests; 1 failure, 8 errors and 10 skips. File.open stubs now work with and without blocks. Remaining failures include private stubs and a dynamic method's super lookup. | Ruby semantics. Reduce the remaining alias/super witnesses; avoid dispatch functions currently edited by other sessions. |
| minitest / `test_minitest_spec.rb` | All 76 tests run: 2 failures, 0 errors, 451 versus 458 assertions. Hash expectation names now reach singleton method_missing and the nested yield reaches its outer command block. Nested spec names still retain an anonymous parent description. | Ruby semantics. A reduced class overrides to_s correctly in a direct call, but Array#join still uses its native class display. The join branch is in invoke_val_c0, shared with the other sessions, so leave it untouched until available. |
| minitest / `test_minitest_test.rb` | Backtrace compression works and the missing-yield error is resolved; 8 exception Marshal/equality failures, 0 errors and 1 skip remain. A small exception wrapper with an overridden backtrace compares unequal after a Marshal round trip. The dump stores its delegated trace as its native trace; the reference keeps the native trace nil. | Ruby semantics. The Marshal branch is in `stdlib_src`, also edited by the GC session in #91/#94, so avoid that function until available. This is a coordination constraint, not a GC cause. |
| rack / `spec_headers.rb` | All 51 tests now run: 37 failures, 2 errors, 151 versus 302 assertions. A Hash subclass's own class `[]` is bypassed by the inherited native constructor, so header keys remain uppercase. | Ruby semantics. A small subclass returning a sentinel from self.[] reproduces the bypass with both bracket and ordinary call syntax. An unaccepted priority-fix trial then exposed bare zero-argument new allocating a VObj without Hash storage, producing 51 errors. That route uses try_self_call and new_obj/new_obj_wb, edited by the AST/VM and C API sessions. The trial was reverted; this is a coordination constraint, not evidence of an AST-tree or C API cause. |
| rack / `spec_request.rb` | After the reporter's name super becomes available, execution reaches 2 GiB in TestProxyRequest's `handles ASCII NUL input of 16777216 bytes`. The reference completes 404 tests / 1,754 assertions with 2 skips. | Resource investigation, without a proven VM or GC cause; keep the cap. It changes from RED to MEMORY, with no MATCH gain. |
| rack / `spec_rewindable_input.rb` | Exits without a summary. A reduced Tempfile writes successfully, but rewind fails after chmod(0); the underlying File fails too. The same write/rewind without chmod succeeds. | Ruby File/IO semantics. file_flush_obj reads the path outside its guarded descriptor fallback. Completing the read path also reaches invoke_val_c0, shared with the other sessions; avoid editing that shared function. |
| rack / `spec_sendfile.rb` | Two tests opening a File subclass reach IO's descriptor conversion and reject a path string. | Ruby constructor inheritance; reduce a File subclass witness. |
| rack / `spec_multipart.rb` | The process family crosses 2 GiB in `test_0018_rejects insanely long boundaries`, a background-thread pipe writer and multipart reader. The reference completes 85 tests / 239 assertions. | Resource investigation, not a proven GC or VM cause. A separate 10 MiB string allocation plus one nonblocking pipe write succeeds on both interpreters, each writing 65,536 bytes. The combined workload still needs isolation; keep the cap and leave collector internals untouched. |
| rack-test / `uploaded_file_spec.rb` | All 10 tests pass on both sides, but 255 versus 368 assertions. `Tempfile.public_instance_methods(false)` exposes File/IO implementation helpers such as __fd_read and __ln_fill. | Ruby reflection/visibility semantics; count discrepancy remains RED. Do not hide Ruby APIs or change the test's enumeration to conceal it. |

The first batch establishes no confirmed dependency on C API/mkmf, native gem
extensions, RubyVM/ISeq, AST/Ripper/Prism trees, or GC's internal constants.
Overlap with another session's dispatch helper is a coordination constraint,
not evidence that the underlying behavior belongs to that subsystem.

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
