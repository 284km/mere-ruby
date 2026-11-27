# actionview-rescue-backtrace

A bare rescue handler could retain $! through a custom cause reader without preserving
its backtrace. Pin the exception before nontrivial handler code runs, matching the VM
policy; empty/nil-only handlers keep the existing cheap path.

Measured runtime `7af1d4c59aedd1cd3c9e3f484c1d2a862cec8e79`, main control
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

The targeted render file still has pre-existing source-spot failures for eval-generated
template methods. The backtrace-only change also leaves the separate template
SyntaxError-classification failures. These cases are retained explicitly and need
independent follow-ups.

| Core file / selection | Mode | Tests | Assertions | Failures | Errors |
| --- | --- | ---: | ---: | ---: | ---: |
| rescue-backtrace-unit-exception | reference | 18 | 69 | 0 | 0 |
| rescue-backtrace-unit-exception | before-evaluator | 18 | 69 | 0 | 0 |
| rescue-backtrace-unit-exception | after-evaluator | 18 | 69 | 0 | 0 |
| rescue-backtrace-unit-exception | before-vm | 18 | 69 | 0 | 0 |
| rescue-backtrace-unit-exception | after-vm | 18 | 69 | 0 | 0 |

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 523 | 17 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 524 | 16 | 0 | 0 | 0 | 0 |
| before-vm | 524 | 16 | 0 | 0 | 0 | 0 |
| after-vm | 524 | 16 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/template_error_test.rb | 322080 / 341520 / 319456 | 324208 / 326272 / 319552 | +0.66% |
| actionview/test/template/render_test.rb | 717424 / 894640 / 793584 | 658672 / 781152 / 842528 | -1.57% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-rescue-backtrace.json`. This is
targeted acceptance; a complete ActionView passing result is not claimed.
