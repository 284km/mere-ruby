# actionview-eval-syntax

String class/module/instance eval exposed parser failures as StandardError. Raise
SyntaxError with the existing Prism report formatter so Rails can recognize the
compilation error and show its original template source.

Measured runtime `faca47922d84173b1b8428ba4270fd8ed7344307`, main control
`6d8a416dec9f1e56f6594c077014fbd90789e719`. Ordinary O2; Mere 9dec2ff6, mgz 661a01d8.
Reference `tools/ref_ruby.sh`, clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

- `run_corpus.sh --both`: 985/985, hash index ON/OFF.
- VM corpus: 985 VM / 0 evaluator fallback / 0 differences.
- Source gates, generated-C bracket check and default record hygiene pass. Explicit
changed-record hygiene also passes.
- Related CRuby checks complete on the reference and both before/after engines; no
previously passing selected case is lost. Existing failures remain visible in the
record.

The render file retains 12 pre-existing source-spot failures for eval-generated template
methods. This change fixes its four SyntaxError-classification cases; the source-spot
cases require the separate node-metadata follow-up.

| Core file / selection | Mode | Tests | Assertions | Failures | Errors |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_eval.rb | reference | 40 | 465 | 0 | 0 |
| ruby/test_eval.rb | before-evaluator | 40 | 461 | 0 | 0 |
| ruby/test_eval.rb | after-evaluator | 40 | 461 | 0 | 0 |
| ruby/test_eval.rb | before-vm | 40 | 461 | 0 | 0 |
| ruby/test_eval.rb | after-vm | 40 | 461 | 0 | 0 |

The mere test_eval runs retain one existing skip (461 assertions; reference 465); there
is no change in either engine.

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 520 | 16 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 524 | 12 | 0 | 0 | 0 | 0 |
| before-vm | 520 | 16 | 0 | 0 | 0 | 0 |
| after-vm | 524 | 12 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/render_test.rb | 575936 / 510064 / 518672 | 549472 / 508656 / 814496 | +5.94% |

Instructions retired, median of three alternating pairs on unchanged workloads: 200
string module_eval calls containing 80 one-line definitions, and -c on the pinned Rails
action_dispatch/routing/mapper.rb (100,374 bytes). Exact workload text/digests are in
the record.

| Workload | Engine | Before | After | Change |
| --- | --- | ---: | ---: | ---: |
| valid_class_eval | evaluator | 1696888107 | 1693880543 | -0.18% |
| valid_class_eval | VM | 1694807794 | 1695324546 | +0.03% |
| large_syntax_check | evaluator | 173197854 | 173598738 | +0.23% |
| large_syntax_check | VM | 174559399 | 173714612 | -0.48% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-eval-syntax.json`. This is targeted
acceptance; a complete ActionView passing result is not claimed.
