# actionview-defined-primitive

defined? ignored respond_to_missing? on Hash, String and Array subclasses and singleton
objects. Resolve the actual lookup class and apply the missing-method hook protocol with
public visibility.

Measured runtime `a65af192b0e896626d547c781cd03959d60beec2`, main control
`99441f4e065bca18bca161384c94ff05d2e0783e`. Ordinary O2; Mere 9dec2ff6, mgz 661a01d8.
Reference `tools/ref_ruby.sh`, clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

- `run_corpus.sh --both`: 985/985, hash index ON/OFF.
- VM corpus: 985 VM / 0 evaluator fallback / 0 differences.
- Source gates, generated-C bracket check and default record hygiene pass. Explicit
changed-record hygiene is checked after writing this record.
- Related CRuby checks complete on the reference and both before/after engines; no
previously passing selected case is lost. Existing failures remain visible in the
record.

| Core file / selection | Mode | Tests | Assertions | Failures | Errors |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_defined.rb | reference | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | before-evaluator | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | after-evaluator | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | before-vm | 39 | 171 | 0 | 0 |
| ruby/test_defined.rb | after-vm | 39 | 171 | 0 | 0 |

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 102 | 21 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 123 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 102 | 21 | 0 | 0 | 0 | 0 |
| after-vm | 123 | 0 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/asset_tag_helper_test.rb | 426032 / 421664 / 435152 | 432896 / 435904 / 432064 | +1.61% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-defined-primitive.json`. This is
targeted acceptance; a complete ActionView passing result is not claimed.
