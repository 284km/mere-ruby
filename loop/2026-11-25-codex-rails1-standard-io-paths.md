# Standard IO display labels

ActiveSupport Logger could treat stdout and stderr as the same destination. Preserve
distinct ASCII-8BIT standard-stream labels separately from filesystem paths; File#reopen
still uses the descriptor. The review correction returns a fresh mutable copy from
path/to_path, so replace/force_encoding on a returned value cannot alter later labels.

Runtime `a0cdee53673f25c696fd997542aca0a4c2cf948b`; comparison main
`d0843046ca315ca41d5d697aa0ce1d51753dd795`. Ordinary O2 compiler 9dec2ff6. Clean Ruby
4.0.10 via `tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, no
extras, Prism 1.8.2.

- Corpus --both: 958/958 with hash index ON/OFF; VM: 958 VM / 0 fallback / 0
differences.
- Corpus 947 tests all three standard streams and both accessors, fresh mutable results,
replace, force_encoding, and reopening; 333/416 are regression controls. All 6
comparisons pass normally and with tight GC/hash OFF.
- Eight source gates, bracket check, default hygiene, and explicit changed-record
hygiene pass.

Related CRuby IO selection, all five executions COMPLETE:

| Mode | Tests / assertions / failures / errors |
| --- | --- |
| reference | 5 / 19 / 0 / 0 |
| before-evaluator | 5 / 19 / 0 / 0 |
| after-evaluator | 5 / 19 / 0 / 0 |
| before-vm | 5 / 19 / 0 / 0 |
| after-vm | 5 / 19 / 0 / 0 |

The historical whole-test_io REPORT_MISMATCH (three failures, one error, plus memory-
leak diagnostics) belongs to old 45f37ea3 versus ecd65075, both engines, with unchanged
case vectors. It remains separate from current selected acceptance; no whole-test_io
passing result is claimed.

Logger whole-file replay, all files COMPLETE with no bounds hit:

| File | Main MATCH / RED | Candidate MATCH / RED |
| --- | --- | --- |
| activesupport/test/logger_test.rb | 31 / 1 | 32 / 0 |

MISSING/BOTH/UNCF/EXTRA are zero. Three alternating seed-12345 replay pairs, 600 s / 2
GiB family bounds, jobs 2, MT_CPU=0. Explicit reuse of the owned 85-package native
install built by a9e68981; installing/measuring digests are separate in the record. Peak
family RSS, KiB:

| File | Main | Candidate |
| --- | --- | --- |
| logger_test.rb | 283312 / 363568 / 287728 | 284112 / 284112 / 289088 |

Samples vary; no stable memory improvement is claimed. Digests, UTC times and explicitly
historical observations are in `railstest/framework/records/activesupport-standard-io-
labels.json`.

The earlier hosted corpus job passed corpus/VM, then failed the separate ISeq metadata
comparison for corpus 830. The same failure reproduces on unchanged main; [issue
#323](https://github.com/284km/mere-ruby/issues/323) records the isolation. This
expected-failure diagnostic is excluded from passing local acceptance.
