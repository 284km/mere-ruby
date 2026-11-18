# Upstream gem suite differences

This ledger describes file verdicts from `suites_latest.json`. Raw stdout and
stderr in CI's `gem-suites-*` artifacts identify individual failed tests.
Symptoms below are observed; an unconfirmed cause is explicitly marked.
None is excluded from the measurement to improve its score.

| Suite / file | Observed difference | Ownership and next step |
|---|---|---|
| minitest / `test_minitest_mock.rb` | Executes all 94 tests; 1 failure, 8 errors and 10 skips. File.open stubs now work with and without blocks. Remaining failures include private stubs and a dynamic method's super lookup. | Ruby semantics. Reduce the remaining alias/super witnesses; avoid dispatch functions currently edited by other sessions. |
| minitest / `test_minitest_spec.rb` | `Minitest::Spec::DSL#name` calls super and cannot find the inherited Class/Module implementation. | Ruby semantics. Coordinate with #86, which edits `super_next_plain`; no AST tree failure is established. |
| minitest / `test_minitest_test.rb` | Backtrace compression now works; 8 exception Marshal/equality failures and 1 missing-yield error remain. A small exception wrapper with an overridden backtrace compares unequal after a Marshal round trip. The dump stores its delegated trace as its native trace; the reference keeps the native trace nil. | Ruby semantics. The Marshal branch is in `stdlib_src`, also edited by the GC session in #91/#94, so avoid that function until available. This is a coordination constraint, not a GC cause. The missing-yield error needs its own witness. |
| rack / `spec_headers.rb` | Class naming through `Minitest::Spec::DSL#name` fails before a summary. | Same super lookup issue as minitest spec; coordinate with #86. |
| rack / `spec_lint.rb` | `notice environment errors` expects Rack::Lint::LintError, but nothing is raised. | Ruby semantics; root cause not yet isolated. |
| rack / `spec_request.rb` | The result reporter cannot resolve super from `RackRequestTest::TestProxyRequest.name`; no final summary. | Same super lookup issue as minitest spec; coordinate with #86. |
| rack / `spec_rewindable_input.rb` | Exits with `unexpected return`, without a summary. | Ruby control-flow semantics; root cause not yet isolated. |
| rack / `spec_sendfile.rb` | Two tests opening a File subclass reach IO's descriptor conversion and reject a path string. | Ruby constructor inheritance; reduce a File subclass witness. |
| rack / `spec_multipart.rb` | The process family crosses 2 GiB in `test_0018_rejects insanely long boundaries`, a background-thread pipe writer and multipart reader. The reference completes 85 tests / 239 assertions. | Resource investigation, not a proven GC or VM cause. A separate 10 MiB string allocation plus one nonblocking pipe write succeeds on both interpreters, each writing 65,536 bytes. The combined workload still needs isolation; keep the cap and leave collector internals untouched. |
| rack-test / `uploaded_file_spec.rb` | All 10 tests pass on both sides, but 255 versus 368 assertions. The test enumerates `Tempfile.public_instance_methods(false)`. | Ruby reflection semantics; count discrepancy remains RED rather than concealing it. |

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
The latest snapshot uses the second full run. Cross-platform hosted checks
must retain this new MATCH under the same bounds before merge.
