# actionview-eval-node

Eval-generated template methods had no file-backed Prism index, so error highlighting
could not locate their call nodes. Attach compact compilation-unit node metadata to the
method and retain it through backtrace locations, aliases, old Method objects and GC,
without keeping source trees or defining frames.

Measured runtime `0fef6ef1718f8a2cd9494e9b62ad7aeb19487144`, main control
`b9ca06d6700c44ded301131930a5dbd9107202be`. Ordinary O2; Mere 9dec2ff6, mgz 661a01d8.
Reference `tools/ref_ruby.sh`, clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

- `run_corpus.sh --both`: 1013/1013, hash index ON/OFF.
- VM corpus: 1013 VM / 0 evaluator fallback / 0 differences.
- Source gates, generated-C bracket check and default record hygiene pass. Explicit
changed-record hygiene is checked after writing this record.
- Related CRuby checks complete on the reference and both before/after engines; no
previously passing selected case is lost. Existing failures remain visible in the
record.

An unpublished R11 candidate lost existing compound-write node lookup in eval-defined
methods. It was rejected before publication. Corpus 1004 now covers ten operator-write
shapes with real and synthetic filenames, and compact rows preserve every
kind/name/target used by the existing file index. The focused corpus also runs with
tight GC and hash indexes ON/OFF. The bounded native scan uses each definition subtree;
the embedded Ruby helper is regenerated from its source. The regressions include class-
eval block labels and zero-line Object instance_eval, primitive and Ruby raises, aliases
and old Method objects. Primitive failures capture indexed frame metadata before pooled
frames unwind; the original complete backtrace/eval files remain compared. The control
includes the merged SyntaxError formatter fix, so no template SyntaxError failures are
allowed. Ruby::Box journals restore the original compact metadata together with method
rows after replacement or removal; switching boxes allocates no new Ruby objects. A
separate lambda arity-entry comparison preserves current-main file-backed node lookup;
synthetic lambda entry lookup remains unsupported on both main and this candidate. On
ordinary alias/send caller frames the node lookup still returns nil on both main and
head, while Ruby returns a call node. Those pre-existing gaps are retained separately
and are not counted as passing reference comparisons.

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

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 524 | 12 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 536 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 524 | 12 | 0 | 0 | 0 | 0 |
| after-vm | 536 | 0 | 0 | 0 | 0 | 0 |

Fixed-seed full-file RSS samples (KiB): three new candidate executions compared with
three unchanged-main samples reused from R11, collected in separate cohorts. Original
record digests and times are retained; these are not alternating pairs.

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/render_test.rb | 698208 / 664928 / 652112 | 565008 / 570304 / 544784 | -15.03% |

Instructions retired, median of three alternating pairs on unchanged workloads: 200
string module_eval calls containing 80 one-line definitions, and -c on the pinned Rails
action_dispatch/routing/mapper.rb (100,374 bytes). Exact workload text/digests are in
the record. String eval now performs an extra native Prism pass to obtain compilation-
unit node IDs, which adds about 16% instructions in the definition-heavy workload. This
cost is disclosed; no zero-overhead claim is made for eval compilation.

| Workload | Engine | Before | After | Change |
| --- | --- | ---: | ---: | ---: |
| valid_class_eval | evaluator | 1703236488 | 1977642721 | +16.11% |
| valid_class_eval | VM | 1706432426 | 1977752846 | +15.90% |
| large_syntax_check | evaluator | 173423856 | 174313896 | +0.51% |
| large_syntax_check | VM | 173682553 | 173511215 | -0.10% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Separate prospective integration `74856ce33741c3da09f303f906ef9cc68d32ddda` with newer
main `ad289755a37de94e5faddf61763d49edda849c03` also passes corpus --both 1026/1026, VM
1026 /0 fallback /0 differences and all gates, including the new class-watermark
control. That binary freshly installed its own native gems; its source/binary/install
provenance and focused 34-row node matrix are retained separately from the PR-head
evidence. No full component sweep is claimed.

Evidence: `railstest/framework/records/actionview-eval-node.json`. This is targeted
acceptance; a complete ActionView passing result is not claimed.
