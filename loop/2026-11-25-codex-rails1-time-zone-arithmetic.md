# Time zone arithmetic and constructor inheritance

Preserve destination-time DST semantics and live inherited Time subclass constructor
overrides; corpus 946/948 covers both paths.

Final runtime a66fd7da9b93751f5fb6d8fa0b6df6af8a4c13b1; comparison main
d0843046ca315ca41d5d697aa0ce1d51753dd795. Ordinary O2 compiler 9dec2ff6. Clean Ruby
4.0.10 via `tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, no
extras, Prism 1.8.2.

- Corpus --both: 959/959 hash ON/OFF. VM: 959 VM / 0 fallback / 0 differences. Digests
and UTC cohort times are recorded.
- Eight source gates, bracket gate and default hygiene pass. Explicit changed-record
hygiene checked separately.
- Related current CRuby selection: all five executions COMPLETE.

| Mode | Summary |
| --- | --- |
| reference | {'tests': 12, 'assertions': 219, 'failures': 0, 'errors': 0, 'skips': 0} |
| before-evaluator | {'tests': 12, 'assertions': 144, 'failures': 1, 'errors': 0, 'skips': 0} |
| after-evaluator | {'tests': 12, 'assertions': 144, 'failures': 1, 'errors': 0, 'skips': 0} |
| before-vm | {'tests': 12, 'assertions': 144, 'failures': 1, 'errors': 0, 'skips': 0} |
| after-vm | {'tests': 12, 'assertions': 144, 'failures': 1, 'errors': 0, 'skips': 0} |

Current whole test_time_tz is COMPLETE and passing in all five executions. Historical
whole test_time WALL_LIMIT at strftime_padding belongs to old80d561f0 versus ecd65075,
both engines. No whole-test_time pass is claimed on final source. The current selection
retains the same test_new_from_string failure before/after on both engines: 12 tests /
144 assertions / 1 failure; reference12 / 219 / 0. No selected pass is lost.

Three alternating seed-12345 full Rails replay pairs, all files COMPLETE with no bounds
hit: before {'files': 2, 'empty_files': 0, 'reference_unusable': 0, 'mere_incomplete':
0, 'order_differs': 1, 'MATCH': 193, 'RED': 5, 'MISSING': 0, 'UNCONFIRMED': 0, 'BOTH':
0, 'EXTRA': 0}; after {'files': 2, 'empty_files': 0, 'reference_unusable': 0,
'mere_incomplete': 0, 'order_differs': 1, 'MATCH': 198, 'RED': 0, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}. Bounds 600 s / 2 GiB per family, jobs 2,
MT_CPU=0. Native gems explicitly reuse owned a9e68981 install. Peak family RSS, KiB:

| File | main | candidate |
| --- | --- | --- |
| time_ext_test.rb | 358256 / 355936 / 364048 | 359024 / 357808 / 362176 |
| time_travel_test.rb | 364320 / 301344 / 303648 | 300144 / 303920 / 306320 |

Samples vary; no stable memory improvement is claimed. Evidence:
`railstest/framework/records/activesupport-time-zone-constructors.json`; earlier probes
are preserved under an explicit historical heading.
