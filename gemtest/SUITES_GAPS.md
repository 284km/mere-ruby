# Upstream gem suite differences

This ledger describes file verdicts from `suites_latest.json`. Raw stdout and
stderr in CI's `gem-suites-*` artifacts identify individual failed tests.
Symptoms below are observed; an unconfirmed cause is explicitly marked.
None is excluded from the measurement to improve its score.

| Suite / file | Observed difference | Ownership and next step |
|---|---|---|
| minitest / `test_minitest_mock.rb` | Now executes all 94 tests; 2 failures, 13 errors and 10 skips. Stubbing `File.open` still reaches the real file operation, and a dynamic method's super lookup fails. | Ruby semantics. Inspect builtin aliases and super lookup. Shared dispatch functions are being edited by PRs #86–#88; do not edit those functions concurrently. |
| minitest / `test_minitest_reporter.rb` | 1 error while compressing a SystemStackError backtrace. `[0].chain([1,1,2].each_slice(1)).chunk_while { ... }.to_a` raises ArgumentError about a missing block; the same operation without Chain succeeds. | Ruby semantics. The Chain block dispatcher is in `invoke_with_block0`, also edited by the VM session in #88; recorded for coordination, not attributed to an ISeq failure. |
| minitest / `test_minitest_spec.rb` | `Minitest::Spec::DSL#name` calls super and cannot find the inherited Class/Module implementation. | Ruby semantics. Coordinate with #86, which edits `super_next_plain`; no AST tree failure is established. |
| minitest / `test_minitest_test.rb` | Backtrace compression errors as above, exception Marshal/equality failures, and a missing yield under the backtrace filter helper. | Ruby semantics. Separate the Marshal and block-forwarding witnesses before changing implementations. |
| rack / `spec_deflater.rb` | Aborting a gzip stream raises Zlib::DataError instead of the test's FakeDisconnect. | Ruby semantics in the streaming zlib API; no native extension is requested by this suite. Reduce the incomplete-stream witness. |
| rack / `spec_headers.rb` | Class naming through `Minitest::Spec::DSL#name` fails before a summary. | Same super lookup issue as minitest spec; coordinate with #86. |
| rack / `spec_lint.rb` | `notice environment errors` expects Rack::Lint::LintError, but nothing is raised. | Ruby semantics; root cause not yet isolated. |
| rack / `spec_mock_request.rb` | Psych tries to revive an instance variable named `@` when loading the test's environment dump. | Ruby semantics; trace the dump/load boundary before attributing a parser or object-model cause. |
| rack / `spec_request.rb` | The result reporter cannot resolve super from `RackRequestTest::TestProxyRequest.name`; no final summary. | Same super lookup issue as minitest spec; coordinate with #86. |
| rack / `spec_rewindable_input.rb` | Exits with `unexpected return`, without a summary. | Ruby control-flow semantics; root cause not yet isolated. |
| rack / `spec_sendfile.rb` | Two tests opening a File subclass reach IO's descriptor conversion and reject a path string. | Ruby constructor inheritance; reduce a File subclass witness. |
| rack / `spec_utils.rb` | Custom query parameter hash loses `foo`; an invalid-cookie test reports a non-class rescue clause. | Ruby semantics; separate the two failures. |
| rack / `spec_multipart.rb` | The mere-ruby process family crosses 2 GiB. | Resource investigation, not a proven GC or VM cause. Keep the cap. Record a specific hot test before assigning a fix to the VM session; collector internals remain untouched. |
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
