# actionview-defined-hook-guard

After #341, defined?(recv.virtual) could leak Ruby exceptions raised by a builtin
subclass response gate or missing-method hook. Guard the complete probe with the same
exception boundary as receiver evaluation, restoring exception state while preserving
throw, return and break. This follows up the post-merge Major at
https://github.com/284km/mere-ruby/pull/341#discussion_r4710302378.

Measured runtime `5006f74a39ce273b5c8e62ca6df0199dda48a9ce`, main control
`ee9cf5dc7044092e97f6e86aca0ec58fa5b1d741`. Ordinary O2; Mere 9dec2ff6, mgz 661a01d8.
Reference `tools/ref_ruby.sh`, clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

- `run_corpus.sh --both`: 988/988, hash index ON/OFF.
- VM corpus: 988 VM / 0 evaluator fallback / 0 differences.
- Source gates, generated-C bracket check and default record hygiene pass. Explicit
changed-record hygiene also passes.
- Related CRuby checks complete on the reference and both before/after engines; no
previously passing selected case is lost. Existing failures remain visible in the
record.

Regression coverage includes raising gates and hooks on Hash, String and Array
subclasses and singleton objects; RuntimeError and direct Exception; bound and bare-
rescue $!, original backtrace and locations, and a later exception cause. Explicit
GC.start and nested probes check saved-state lifetime. Throw, return and break must
still escape the query. An initial unpublished candidate failed the bare-rescue
backtrace check; its diagnostic is retained separately from final acceptance.

| Core file / selection | Mode | Tests | Assertions | Failures | Errors |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_defined.rb | reference | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | before-evaluator | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | after-evaluator | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | before-vm | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | after-vm | 39 | 171 | 0 | 0 |
| defined-hook-guard-unit-exception | reference | 25 | 87 | 0 | 0 |
| defined-hook-guard-unit-exception | before-evaluator | 25 | 87 | 0 | 0 |
| defined-hook-guard-unit-exception | after-evaluator | 25 | 87 | 0 | 0 |
| defined-hook-guard-unit-exception | before-vm | 25 | 87 | 0 | 0 |
| defined-hook-guard-unit-exception | after-vm | 25 | 87 | 0 | 0 |

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 123 | 0 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 123 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 123 | 0 | 0 | 0 | 0 | 0 |
| after-vm | 123 | 0 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/asset_tag_helper_test.rb | 428528 / 425472 / 437760 | 430688 / 425552 / 430192 | +0.39% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-defined-hook-guard.json`. This is
targeted acceptance; a complete ActionView passing result is not claimed.
