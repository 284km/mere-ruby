# actionview-struct-keyword

Struct construction converted keywords to member positions before calling a custom Ruby
initializer. Preserve the original arguments until the native member initializer runs,
including super forwarding and explicit keyword modes.

Measured runtime `46761b874056bcd9e2e4e6504a6967b972211043`, main control
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

| Core file / selection | Mode | Tests | Assertions | Failures | Errors |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_struct.rb | reference | 102 | 394 | 0 | 0 |
| ruby/test_struct.rb | before-evaluator | 102 | 394 | 0 | 0 |
| ruby/test_struct.rb | after-evaluator | 102 | 394 | 0 | 0 |
| ruby/test_struct.rb | before-vm | 102 | 394 | 0 | 0 |
| ruby/test_struct.rb | after-vm | 102 | 394 | 0 | 0 |

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 363 | 2 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 365 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 363 | 2 | 0 | 0 | 0 | 0 |
| after-vm | 365 | 0 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/form_helper_test.rb | 659744 / 644480 / 563280 | 656432 / 655760 / 593648 | +1.75% |
| actionview/test/template/record_identifier_test.rb | 333920 / 328864 / 329712 | 333856 / 327744 / 326640 | -0.60% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-struct-keyword.json`. This is targeted
acceptance; a complete ActionView passing result is not claimed.
