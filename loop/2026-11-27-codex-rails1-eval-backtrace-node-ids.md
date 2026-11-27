# actionview-eval-node

Twelve ActionView render tests failed because eval-generated template methods had no
compilation-unit node IDs. Retain compact metadata with methods/backtrace locations, including
aliases, old Method objects, Ruby::Box and GC.

Measured runtime `c6497f659c95e9f0d3ae42250a610ce44e684256`; this follow-up compares against
reviewed head `c9c97f7f` (binary from unchanged runtime `0fef6ef1`). Original main-control
acceptance remains in the historical record: 524 MATCH /12 RED →536 MATCH /0 RED on both engines.

The Major/P2 heredoc regression is fixed structurally: serialized nodes are preorder, so a reverse
pass computes each subtree end from its child fields. Indexing follows that subtree rather than
DefNode source offsets. This includes heredoc interpolation beyond the definition location while
keeping sibling definitions separate. Corpus 1004 covers endless/regular heredocs, neighboring
definitions, and real/synthetic filenames. All 8 engine/hash/GC combinations now match Ruby; the old
head reproduces the failure in all 8. Existing ordinary-file corpus 1022 matches in all 4
engine/hash combinations.

Ordinary O2; Mere 9dec2ff6, mgz 661a01d8. Reference `tools/ref_ruby.sh`: clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

- `run_corpus.sh --both`: 1013/1013, hash ON/OFF.
- VM corpus: 1013 VM / 0 fallback / 0 differences.
- Source gates, generated-C bracket check, default and explicit changed-record hygiene pass.

| Core file / selection | Mode | Tests | Assertions | Failures | Errors | Skips |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| ruby/test_backtrace.rb | reference | 31 | 3781 | 0 | 0 | 0 |
| ruby/test_backtrace.rb | before-evaluator | 31 | 3779 | 0 | 0 | 0 |
| ruby/test_backtrace.rb | after-evaluator | 31 | 3779 | 0 | 0 | 0 |
| ruby/test_backtrace.rb | before-vm | 31 | 3779 | 0 | 0 | 0 |
| ruby/test_backtrace.rb | after-vm | 31 | 3779 | 0 | 0 | 0 |
| ruby/test_eval.rb | reference | 40 | 465 | 0 | 0 | 0 |
| ruby/test_eval.rb | before-evaluator | 40 | 461 | 0 | 0 | 1 |
| ruby/test_eval.rb | after-evaluator | 40 | 461 | 0 | 0 | 1 |
| ruby/test_eval.rb | before-vm | 40 | 461 | 0 | 0 | 1 |
| ruby/test_eval.rb | after-vm | 40 | 461 | 0 | 0 | 1 |
| ruby/test_method.rb | reference | 99 | 564 | 0 | 0 | 0 |
| ruby/test_method.rb | before-evaluator | 99 | 556 | 1 | 0 | 1 |
| ruby/test_method.rb | after-evaluator | 99 | 556 | 1 | 0 | 1 |
| ruby/test_method.rb | before-vm | 99 | 556 | 1 | 0 | 1 |
| ruby/test_method.rb | after-vm | 99 | 556 | 1 | 0 | 1 |
| ruby/test_ast.rb (selected node-ID cases) | reference | 5 | 1 | 0 | 0 | 4 |
| ruby/test_ast.rb (selected node-ID cases) | before-evaluator | 5 | 1 | 0 | 0 | 4 |
| ruby/test_ast.rb (selected node-ID cases) | after-evaluator | 5 | 1 | 0 | 0 | 4 |
| ruby/test_ast.rb (selected node-ID cases) | before-vm | 5 | 1 | 0 | 0 | 4 |
| ruby/test_ast.rb (selected node-ID cases) | after-vm | 5 | 1 | 0 | 0 | 4 |

No previously passing selected core case is lost. Existing baseline failures/skips remain; AST rows
cover only the selected node-ID cases.

`actionview/test/template/render_test.rb`: all 12 runs (3 alternating evaluator pairs, the original
VM pair, and 2 fresh VM pairs) have **536 MATCH /0 RED**, all other counts 0; reference and mere
states COMPLETE, with no runner-reported wall/memory limit event. Each uses seed 12345, jobs 2
and 600 s / 2 GiB.

| Engine | Before RSS samples (KiB) | After RSS samples (KiB) | Median change |
| --- | --- | --- | ---: |
| evaluator | 595552 / 563728 / 590512 | 633232 / 598400 / 434000 | +1.34% |
| vm | 469424 / 490272 | 477232 / 489984 | +0.78% |

Evaluator RSS uses the three R13 pairs; VM RSS above uses two fresh R14 pairs. The original R13 VM
pair remains in the record: before 449200 KiB, after 482864 KiB. Its before run has an unexplained
roughly four-hour wall-clock gap, although the runner reports 254.9 s and no limit event; it is
excluded from the fresh VM RSS table.

`ruby/test_method.rb` VM RSS, three pairs including the original sample:

| Side | Samples (KiB) | Median (KiB) |
| --- | --- | ---: |
| before | 1189952 / 1661248 / 1612704 | 1612704 |
| after | 1449360 / 1174640 / 1655344 | 1449360 |

These repeats retain the same 99 tests, one existing failure and one skip. RSS varies substantially
even on the unchanged control; no stable memory improvement is claimed.

Instructions retired, median of 3 alternating pairs vs reviewed c9 head:

| Workload | Engine | Before | After | Change |
| --- | --- | ---: | ---: | ---: |
| valid_class_eval | evaluator | 1970549933 | 1987002293 | +0.83% |
| valid_class_eval | VM | 1971750725 | 1989148593 | +0.88% |
| large_syntax_check | evaluator | 172982541 | 173306970 | +0.19% |
| large_syntax_check | VM | 172525147 | 173120706 | +0.35% |

The original feature adds a native Prism pass during string eval (historically about 16%
instructions on the definition-heavy workload); the table isolates the structural follow-up. Exact
workload text/digests and prior measurements are in the record. RSS is load-sensitive; no stable
improvement is claimed.

Native gems explicitly reused from runtime 63213030 / binary c7800ad2 (targeted R3 install); not a
fresh install with this binary. The historical prospective integration 74856 still has the old
heredoc scanner and is not evidence for this fix. Full component sweeps have not been rerun. Known
external GC/Ripper/reference sanitizer residuals remain separately recorded (#312/#339/#345).

Evidence: `railstest/framework/records/actionview-eval-node.json`, including historical acceptance.
Owner merges after exact-head bot review and clearing the global merge hold.
