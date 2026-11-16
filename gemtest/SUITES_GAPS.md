# Upstream gem suite differences

This ledger describes file verdicts from `suites_latest.json`. Raw stdout and
stderr in CI's `gem-suites-*` artifacts identify individual failed tests.
Symptoms below are observed; an unconfirmed cause is explicitly marked.
None is excluded from the measurement to improve its score.

| Suite / file | Observed difference | Ownership and next step |
|---|---|---|
| minitest / `test_minitest_mock.rb` | Executes all 94 tests; 1 failure, 8 errors and 10 skips. File.open stubs now work with and without blocks. Remaining failures include private stubs and a dynamic method's super lookup. | Ruby semantics. Reduce the remaining alias/super witnesses; avoid dispatch functions currently edited by other sessions. |
| minitest / `test_minitest_spec.rb` | `Minitest::Spec::DSL#name` calls super and cannot find the inherited Class/Module implementation. | Ruby semantics. Coordinate with #86, which edits `super_next_plain`; no AST tree failure is established. |
| minitest / `test_minitest_test.rb` | Backtrace compression now works; 8 exception Marshal/equality failures and 1 missing-yield error remain. | Ruby semantics. Separate the Marshal and block-forwarding witnesses before changing implementations. |
| rack / `spec_headers.rb` | Class naming through `Minitest::Spec::DSL#name` fails before a summary. | Same super lookup issue as minitest spec; coordinate with #86. |
| rack / `spec_lint.rb` | `notice environment errors` expects Rack::Lint::LintError, but nothing is raised. | Ruby semantics; root cause not yet isolated. |
| rack / `spec_request.rb` | The result reporter cannot resolve super from `RackRequestTest::TestProxyRequest.name`; no final summary. | Same super lookup issue as minitest spec; coordinate with #86. |
| rack / `spec_rewindable_input.rb` | Exits with `unexpected return`, without a summary. | Ruby control-flow semantics; root cause not yet isolated. |
| rack / `spec_sendfile.rb` | Two tests opening a File subclass reach IO's descriptor conversion and reject a path string. | Ruby constructor inheritance; reduce a File subclass witness. |
| rack / `spec_utils.rb` | Custom query parameter hash loses `foo`; an invalid-cookie test reports a non-class rescue clause. | Ruby semantics; separate the two failures. |
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
  Only the File condition in `invoke_with_block0` changes. Witness 673.
- Chain receives Enumerable's existing implementation module, and
  `chunk_while` / `slice_when` defer the source and predicate until iteration.
  Early `take` stops infinite inputs, multiple yields retain their values,
  and reflected owner/ancestry remain consistent with the reference.
  Only `core_prelude_b` changes. Witness 674. The original minitest reporter
  now passes all 22 tests / 52 assertions and becomes MATCH. Enum and
  Enumerator report 159 MATCH / 0 RED / 1 BOTH; corpus reports 697/697.
