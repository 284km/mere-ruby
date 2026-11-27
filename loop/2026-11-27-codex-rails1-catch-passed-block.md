# actionview-catch-passed-block

Kernel catch evaluated the syntax placeholder for a passed block instead of running the
coerced Proc. Use the already resolved block and reject an explicitly absent block, so
I18n caching executes its translation block.

Measured runtime `2035059ee0ebefef8ee42d0a2e7306bc7bda254e`, main control
`6d8a416dec9f1e56f6594c077014fbd90789e719`. Ordinary O2; Mere 9dec2ff6, mgz 661a01d8.
Reference `tools/ref_ruby.sh`, clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

- `run_corpus.sh --both`: 984/984, hash index ON/OFF.
- VM corpus: 984 VM / 0 evaluator fallback / 0 differences.
- Source gates, generated-C bracket check and default record hygiene pass. Explicit
changed-record hygiene also passes.
- Related CRuby checks complete on the reference and both before/after engines; no
previously passing selected case is lost. Existing failures remain visible in the
record.

| Core file / selection | Mode | Tests | Assertions | Failures | Errors |
| --- | --- | ---: | ---: | ---: | ---: |
| catch-passed-block-unit-exception | reference | 7 | 18 | 0 | 0 |
| catch-passed-block-unit-exception | before-evaluator | 7 | 18 | 0 | 0 |
| catch-passed-block-unit-exception | after-evaluator | 7 | 18 | 0 | 0 |
| catch-passed-block-unit-exception | before-vm | 7 | 18 | 0 | 0 |
| catch-passed-block-unit-exception | after-vm | 7 | 18 | 0 | 0 |

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 59 | 1 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 60 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 59 | 1 | 0 | 0 | 0 | 0 |
| after-vm | 60 | 0 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/translation_helper_test.rb | 445664 / 450112 / 455056 | 451616 / 496704 / 462688 | +2.79% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-catch-passed-block.json`. This is
targeted acceptance; a complete ActionView passing result is not claimed.
