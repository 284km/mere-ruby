# actionview-class-visibility

Named private, public and protected statements inside class methods changed top-level
marks instead of the receiver. Dispatch these statements to the class or module
receiver, preserving method visibility and normal errors.

Measured runtime `1d4a87dd040bbd54ba86929deccc4a56b1958a37`, main control
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
| class-visibility-unit-module | reference | 7 | 56 | 0 | 0 |
| class-visibility-unit-module | before-evaluator | 7 | 56 | 0 | 0 |
| class-visibility-unit-module | after-evaluator | 7 | 56 | 0 | 0 |
| class-visibility-unit-module | before-vm | 7 | 56 | 0 | 0 |
| class-visibility-unit-module | after-vm | 7 | 56 | 0 | 0 |
| class-visibility-unit-class | reference | 1 | 4 | 0 | 0 |
| class-visibility-unit-class | before-evaluator | 1 | 4 | 0 | 0 |
| class-visibility-unit-class | after-evaluator | 1 | 4 | 0 | 0 |
| class-visibility-unit-class | before-vm | 1 | 4 | 0 | 0 |
| class-visibility-unit-class | after-vm | 1 | 4 | 0 | 0 |

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 44 | 1 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 45 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 45 | 0 | 0 | 0 | 0 | 0 |
| after-vm | 45 | 0 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/actionpack/abstract/layouts_test.rb | 378480 / 380736 / 387840 | 373840 / 381600 / 367088 | -1.81% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-class-visibility.json`. This is
targeted acceptance; a complete ActionView passing result is not claimed.
