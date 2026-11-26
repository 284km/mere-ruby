# Standard IO display labels

Store ASCII-8BIT standard stream display labels separately from filesystem paths, while
File#reopen still uses the descriptor. Corpus 947 covers labels/reopening; 333/416 are
regression controls.

Final runtime 4f6893d9aea86149a54c302f7db7fd1325f0a51d; comparison main
d0843046ca315ca41d5d697aa0ce1d51753dd795. Ordinary O2 compiler 9dec2ff6. Clean Ruby
4.0.10 via `tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, no
extras, Prism 1.8.2.

- Corpus --both: 958/958 hash ON/OFF. VM: 958 VM / 0 fallback / 0 differences. Digests
and UTC cohort times are recorded.
- Eight source gates, bracket gate and default hygiene pass. Explicit changed-record
hygiene checked separately.
- Related current CRuby selection: all five executions COMPLETE.

| Mode | Summary |
| --- | --- |
| reference | {'tests': 5, 'assertions': 19, 'failures': 0, 'errors': 0, 'skips': 0} |
| before-evaluator | {'tests': 5, 'assertions': 19, 'failures': 0, 'errors': 0, 'skips': 0} |
| after-evaluator | {'tests': 5, 'assertions': 19, 'failures': 0, 'errors': 0, 'skips': 0} |
| before-vm | {'tests': 5, 'assertions': 19, 'failures': 0, 'errors': 0, 'skips': 0} |
| after-vm | {'tests': 5, 'assertions': 19, 'failures': 0, 'errors': 0, 'skips': 0} |

Historical whole test_io REPORT_MISMATCH (three failures, one error, plus memory-leak
diagnostics) belongs to old45f37ea3 versus ecd65075, both engines, with unchanged
failure vectors. No whole-test_io pass is claimed on final source. Current focused
results are below.

Three alternating seed-12345 full Rails replay pairs, all files COMPLETE with no bounds
hit: before {'files': 1, 'empty_files': 0, 'reference_unusable': 0, 'mere_incomplete':
0, 'order_differs': 0, 'MATCH': 31, 'RED': 1, 'MISSING': 0, 'UNCONFIRMED': 0, 'BOTH': 0,
'EXTRA': 0}; after {'files': 1, 'empty_files': 0, 'reference_unusable': 0,
'mere_incomplete': 0, 'order_differs': 0, 'MATCH': 32, 'RED': 0, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}. Bounds 600 s / 2 GiB per family, jobs 2,
MT_CPU=0. Native gems explicitly reuse owned a9e68981 install. Peak family RSS, KiB:

| File | main | candidate |
| --- | --- | --- |
| logger_test.rb | 327872 / 340672 / 355872 | 284848 / 300112 / 286176 |

Samples vary; no stable memory improvement is claimed. Evidence:
`railstest/framework/records/activesupport-standard-io-labels.json`; earlier probes are
preserved under an explicit historical heading.
