# self block forwarding

Calls such as `self.target(&block)` incorrectly rejected private Ruby methods. Preserve
private access and the supplied block across these call paths; class receivers resolve
through their singleton class. Corpus 953 covers forwarded/nil/literal/Symbol blocks,
generated methods, class methods and explicit-receiver refusals.

Runtime `2b0be6ffde5e1667816b8b1f518ffd195f753ae5`; Rails comparison
`d93de083088ce7a51260d0779929c6d9cd866477`. Ordinary O2 compiler 9dec2ff6, mgz 661a01d8.
Clean Ruby 4.0.10 through `tools/ref_ruby.sh`, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism 1.8.2.

A separate pre-existing direct-def refinement VM difference is recorded in [issue
#320](https://github.com/284km/mere-ruby/issues/320). The diagnostic is retained and
excluded from passing acceptance.

- Corpus --both: 965/965 hash ON/OFF; VM: 965 VM / 0 fallback / 0 differences.
- Eight source gates, bracket check and default hygiene pass; explicit changed-record
hygiene checked separately.
- Related selected CRuby cases are COMPLETE in all five executions, with no previously
passing selected case lost. No whole-file acceptance is claimed from selections.

| Core mode | Tests/assertions/failures/errors |
| --- | --- |
| reference | 3 / 260 / 0 / 0 |
| before-evaluator | 3 / 260 / 0 / 0 |
| after-evaluator | 3 / 260 / 0 / 0 |
| before-vm | 3 / 260 / 0 / 0 |
| after-vm | 3 / 260 / 0 / 0 |

Targeted Rails files are COMPLETE on both sides in every mode, without bounds events:

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | --- | --- | --- | --- | --- | --- |
| before-evaluator | 49 | 64 | 0 | 0 | 0 | 0 |
| after-evaluator | 113 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 49 | 64 | 0 | 0 | 0 | 0 |
| after-vm | 113 | 0 | 0 | 0 | 0 | 0 |

Per-file Rails MATCH/RED (all four modes COMPLETE):

| File | E before | E after | VM before | VM after |
| --- | --- | --- | --- | --- |
| activemodel/test/cases/attribute_methods_test.rb | 12 / 12 | 24 / 0 | 12 / 12 | 24 / 0 |
| activemodel/test/cases/attributes/normalization_test.rb | 5 / 7 | 12 / 0 | 5 / 7 | 12 / 0 |
| activemodel/test/cases/attributes_dirty_test.rb | 16 / 4 | 20 / 0 | 16 / 4 | 20 / 0 |
| activemodel/test/cases/attributes_test.rb | 9 / 4 | 13 / 0 | 9 / 4 | 13 / 0 |
| activemodel/test/cases/secure_password_test.rb | 7 / 37 | 44 / 0 | 7 / 37 | 44 / 0 |

Three alternating seed 12345 full Rails replay pairs; 600 s / 2 GiB family bounds, jobs
2, MT_CPU=0, all files COMPLETE. Native 89 installation explicitly reused from 1a454a94.
Peak family RSS, KiB:

| File | Comparison | Candidate |
| --- | --- | --- |
| attribute_methods_test.rb | 249472 / 245872 / 249776 | 255936 / 302400 / 241040 |
| secure_password_test.rb | 326624 / 324192 / 321920 | 298784 / 298032 / 296704 |

Samples vary; no stable memory improvement is claimed. Evidence with digests, UTC times,
per-case results and qualified historical 58-file context:
`railstest/framework/records/activemodel-private-self-blocks.json`. A complete-component
passing result is not claimed here.
