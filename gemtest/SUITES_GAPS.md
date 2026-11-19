# Upstream gem suite differences

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

Final combined first gem-suite PR, normal O2 source 4ff6b54f: 48 MATCH /
14 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY, zero strict-baseline regressions.
All 62 files on both sides finish the locked-library source audit. Multipart
finishes below the RSS cap with one custom-params-hash error (test_0034),
85 tests / 238 assertions versus the reference's 239. Its prior MEMORY/RED
variation is not a new MATCH or an inferred VM/GC cause.
Integrated corpus: 706/706. The provenance-checked bootstrap harness gives eval 49/49 MATCH, both COMPLETE. Hosted gem jobs pass on Linux and macOS. The Linux runtime job reaches the documented complemented-method-entry leak timeout. Its artifacts are preserved; GitHub rejects reruns while the enclosing workflow is active, so that retry remains pending.

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
