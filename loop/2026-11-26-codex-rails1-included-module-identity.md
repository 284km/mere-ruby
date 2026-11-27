# included module identity

Module#included_modules returned an internal backing module for a Module-subclass
instance. Return the original instance so ActiveModel recognizes its existing validator
module and avoids adding another copy. Corpus 955 includes ordinary/nested/prepend
controls.

Runtime `d8817df6f50aed342d2556df9c1455791c2b6308`; Rails comparison
`fe575de0b069cb26207b40c52079795449da83bd`. Ordinary O2 compiler 9dec2ff6, mgz 661a01d8.
Clean Ruby 4.0.10 through `tools/ref_ruby.sh`, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism 1.8.2.

This PR depends on #317. The Rails comparison uses main cc87d8b0 plus reviewed #317
(b018a5ab), with this identity change as the only runtime delta. Related CRuby
selections use pure main cc87d8b0.

- Corpus --both: 970/970 hash ON/OFF; VM: 970 VM / 0 fallback / 0 differences.
- Eight source gates, bracket check and default hygiene pass; explicit changed-record
hygiene checked separately.
- Related selected CRuby cases are COMPLETE in all five executions, with no previously
passing selected case lost. No whole-file acceptance is claimed from selections.

| Core mode | Tests/assertions/failures/errors |
| --- | --- |
| reference | 4 / 14 / 0 / 0 |
| before-evaluator | 4 / 14 / 0 / 0 |
| after-evaluator | 4 / 14 / 0 / 0 |
| before-vm | 4 / 14 / 0 / 0 |
| after-vm | 4 / 14 / 0 / 0 |

Targeted Rails files are COMPLETE on both sides in every mode, without bounds events:

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | --- | --- | --- | --- | --- | --- |
| before-evaluator | 9 | 1 | 0 | 0 | 0 | 0 |
| after-evaluator | 10 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 9 | 1 | 0 | 0 | 0 | 0 |
| after-vm | 10 | 0 | 0 | 0 | 0 | 0 |

Per-file Rails MATCH/RED (all four modes COMPLETE):

| File | E before | E after | VM before | VM after |
| --- | --- | --- | --- | --- |
| activemodel/test/cases/validations/acceptance_validation_test.rb | 9 / 1 | 10 / 0 | 9 / 1 | 10 / 0 |

Three alternating seed 12345 full Rails replay pairs; 600 s / 2 GiB family bounds, jobs
2, MT_CPU=0, all files COMPLETE. Native 89 installation explicitly reused from 1a454a94.
Peak family RSS, KiB:

| File | Comparison | Candidate |
| --- | --- | --- |
| acceptance_validation_test.rb | 281440 / 279136 / 285344 | 276624 / 273872 / 272976 |
| time_with_zone_test.rb | 420608 / 430864 / 443664 | 433888 / 446624 / 428400 |

Samples vary; no stable memory improvement is claimed. Evidence with digests, UTC times,
per-case results and qualified historical 58-file context:
`railstest/framework/records/activemodel-included-module-identity.json`. A complete-
component passing result is not claimed here.
