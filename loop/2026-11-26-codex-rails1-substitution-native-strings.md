# substitution native strings

String substitution blocks rendered native Time and Struct values as `#<object>`,
breaking ActiveModel comparison messages. Use the existing native `to_s` conversion when
no Ruby `to_s` body exists. Corpus 954 covers Time, Struct, MatchData, Encoding, user
overrides and fallback controls.

Runtime `7184d65ae3b299e5bfcb224396352c9b01ac8c90`; Rails comparison
`fc646ea74e014bc9fa4167a99ed3973b3da824b9`. Ordinary O2 compiler 9dec2ff6, mgz 661a01d8.
Clean Ruby 4.0.10 through `tools/ref_ruby.sh`, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism 1.8.2.

The initial selected String replay stopped at missing `-test-/string` on every side and
is retained as INCOMPLETE. The current replay uses unchanged CRuby string test-extension
sources, compiled into private reference/mere output directories, without changing the
tests.

- Corpus --both: 967/967 hash ON/OFF; VM: 967 VM / 0 fallback / 0 differences.
- Eight source gates, bracket check and default hygiene pass; explicit changed-record
hygiene checked separately.
- Related selected CRuby cases are COMPLETE in all five executions, with no previously
passing selected case lost. No whole-file acceptance is claimed from selections.

| Core mode | Tests/assertions/failures/errors |
| --- | --- |
| reference | 4 / 84 / 0 / 0 |
| before-evaluator | 4 / 84 / 0 / 0 |
| after-evaluator | 4 / 84 / 0 / 0 |
| before-vm | 4 / 84 / 0 / 0 |
| after-vm | 4 / 84 / 0 / 0 |

Targeted Rails files are COMPLETE on both sides in every mode, without bounds events:

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | --- | --- | --- | --- | --- | --- |
| before-evaluator | 27 | 6 | 0 | 0 | 0 | 0 |
| after-evaluator | 33 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 27 | 6 | 0 | 0 | 0 | 0 |
| after-vm | 33 | 0 | 0 | 0 | 0 | 0 |

Per-file Rails MATCH/RED (all four modes COMPLETE):

| File | E before | E after | VM before | VM after |
| --- | --- | --- | --- | --- |
| activemodel/test/cases/validations/comparison_validation_test.rb | 27 / 6 | 33 / 0 | 27 / 6 | 33 / 0 |

Three alternating seed 12345 full Rails replay pairs; 600 s / 2 GiB family bounds, jobs
2, MT_CPU=0, all files COMPLETE. Native 89 installation explicitly reused from 1a454a94.
Peak family RSS, KiB:

| File | Comparison | Candidate |
| --- | --- | --- |
| comparison_validation_test.rb | 288512 / 290704 / 284064 | 296512 / 299248 / 294160 |
| time_with_zone_test.rb | 433504 / 431168 / 427408 | 431344 / 418640 / 438128 |

Samples vary; no stable memory improvement is claimed. Evidence with digests, UTC times,
per-case results and qualified historical 58-file context:
`railstest/framework/records/activemodel-native-substitution-strings.json`. A complete-
component passing result is not claimed here.
