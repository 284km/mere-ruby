# Upstream gem suite differences

This ledger describes file verdicts from `suites_latest.json`. Raw stdout and
stderr in CI's `gem-suites-*` artifacts identify individual failed tests.
Symptoms below are observed; an unconfirmed cause is explicitly marked.
None is excluded from the measurement to improve its score.

| Suite / file | Observed difference | Ownership and next step |
|---|---|---|
| minitest / `test_minitest_mock.rb` | Executes all 94 tests; 1 failure, 8 errors and 10 skips. File.open stubs now work with and without blocks. Remaining failures include private stubs and a dynamic method's super lookup. | Ruby semantics. Reduce the remaining alias/super witnesses; avoid dispatch functions currently edited by other sessions. |
| minitest / `test_minitest_spec.rb` | All 76 tests now run: 2 failures, 4 errors, 443 versus 458 assertions. Nested spec names retain an anonymous parent description; expectation aliases on Hash and one nested yield also fail. | Ruby semantics. Reduce those remaining witnesses; Module#name super now reaches its existing native value without editing the shared super lookup. |
| minitest / `test_minitest_test.rb` | Backtrace compression now works; 8 exception Marshal/equality failures and 1 missing-yield error remain. A small exception wrapper with an overridden backtrace compares unequal after a Marshal round trip. The dump stores its delegated trace as its native trace; the reference keeps the native trace nil. | Ruby semantics. The Marshal branch is in `stdlib_src`, also edited by the GC session in #91/#94, so avoid that function until available. This is a coordination constraint, not a GC cause. The missing-yield error needs its own witness. |
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
