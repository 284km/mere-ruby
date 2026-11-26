# actionview-process-scratch

Internal child-process scratch files trusted TMPDIR even when it did not name a usable
directory. Check temporary-directory candidates and fall back before creating files for
spawn and threaded backticks.

Measured runtime `257b8a243e02540c42d29d570295778dc0afd592`, main control
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

The translation cache case has a separate pre-existing catch-with-block-pass bug: it
returns a Proc instead of running it. It remains RED after the scratch-directory error
is fixed and is retained in every result, with a separate follow-up required.

| Core file / selection | Mode | Tests | Assertions | Failures | Errors |
| --- | --- | ---: | ---: | ---: | ---: |
| process-scratch-unit-process | reference | 6 | 20 | 0 | 0 |
| process-scratch-unit-process | before-evaluator | 6 | 20 | 0 | 0 |
| process-scratch-unit-process | after-evaluator | 6 | 20 | 0 | 0 |
| process-scratch-unit-process | before-vm | 6 | 20 | 0 | 0 |
| process-scratch-unit-process | after-vm | 6 | 20 | 0 | 0 |
| process-scratch-unit-backquote | reference | 1 | 5 | 0 | 0 |
| process-scratch-unit-backquote | before-evaluator | 1 | 5 | 0 | 0 |
| process-scratch-unit-backquote | after-evaluator | 1 | 5 | 0 | 0 |
| process-scratch-unit-backquote | before-vm | 1 | 5 | 0 | 0 |
| process-scratch-unit-backquote | after-vm | 1 | 5 | 0 | 0 |

Targeted Rails files: all reference and mere executions COMPLETE, no bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 71 | 6 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 76 | 1 | 0 | 0 | 0 | 0 |
| before-vm | 71 | 6 | 0 | 0 | 0 | 0 |
| after-vm | 76 | 1 | 0 | 0 | 0 | 0 |

Three alternating fixed-seed full-file RSS pairs (KiB):

| File | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| actionview/test/template/atom_feed_helper_test.rb | 376112 / 382848 / 399744 | 396272 / 388640 / 408448 | +3.51% |
| actionview/test/template/translation_helper_test.rb | 393632 / 446176 / 421472 | 463632 / 397232 / 444304 | +5.42% |

RSS samples vary with machine load; no stable memory improvement is claimed. Native
extensions explicitly reused from runtime63213030 / binary c7800ad2; the record retains
installation provenance.

Evidence: `railstest/framework/records/actionview-process-scratch.json`. This is
targeted acceptance; a complete ActionView passing result is not claimed.
