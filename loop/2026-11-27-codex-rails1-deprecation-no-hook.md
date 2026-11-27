# PR317 no-hook review response

Respect Ruby overrides of Module#deprecate_constant, preserve the original Module-
subclass mixin-hook receiver, and dispatch undefined ==/!= through method_missing.
Corpus 942–944 covers these paths.

Merged main `29016cb8b45142e7e57af80fbb49ae03d4916fb3` and addressed the no-hook
performance Minor. Measured runtime `d0336e573a7040a3768ab5816925b83c09a13fb9`; ordinary
O2, Mere 9dec2ff6 / mgz661a01d8. Reference: `tools/ref_ruby.sh`, clean Ruby 4.0.10,
revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

Ordinary modules retain the original hook lookup until a Module-subclass backing is
created. The usual no-hook workload removes the reviewed increase. After a backing
exists, the lookup still distinguishes the original Ruby receiver; its residual cost is
shown separately, since skipping it would lose subclass hooks. Removing that lookup for
every ordinary module after this point would require separate per-module bookkeeping or
a different backing representation. This patch keeps the existing mapping and reports
the remaining warm cost as a small exception.

Instructions retired, medians of three alternating before/after pairs against current
main. The mixin cases each execute 20,000 class bodies containing include, prepend and
extend. Exact workload text and hashes are recorded.

| Workload / engine | Main | Candidate | Change |
| --- | ---: | ---: | ---: |
| mixins_cold-evaluator | 3698012944 | 3694316658 | -0.10% |
| mixins_cold-vm | 4099068001 | 4085566605 | -0.33% |
| mixins_after_backing-evaluator | 3702786048 | 3759806311 | +1.54% |
| mixins_after_backing-vm | 4101901051 | 4155196906 | +1.30% |
| method_identity-evaluator | 5255079744 | 5257342886 | +0.04% |
| method_identity-vm | 7551147408 | 7552115093 | +0.01% |

- `run_corpus.sh --both`: 1011/1011, hash ON/OFF.
- VM corpus: 1011 VM / 0 fallback / 0 differences.
- Source gates, bracket check and default record hygiene pass. Explicit changed-record
hygiene also passes.
- Extended corpus943 matches all nine reference rows on evaluator and VM, including
ordinary mixins before backing creation, after it, and after GC.

All current selected CRuby cases pass on all five executions. No whole-file acceptance
is claimed from these selections.

| Selection | Mode | Tests | Assertions | Failures | Errors | Skips |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| test_module | reference | 5 | 27 | 0 | 0 | 0 |
| test_module | before-evaluator | 5 | 27 | 0 | 0 | 0 |
| test_module | after-evaluator | 5 | 27 | 0 | 0 | 0 |
| test_module | before-vm | 5 | 27 | 0 | 0 | 0 |
| test_module | after-vm | 5 | 27 | 0 | 0 | 0 |
| test_class | reference | 2 | 5 | 0 | 0 | 0 |
| test_class | before-evaluator | 2 | 5 | 0 | 0 | 0 |
| test_class | after-evaluator | 2 | 5 | 0 | 0 | 0 |
| test_class | before-vm | 2 | 5 | 0 | 0 | 0 |
| test_class | after-vm | 2 | 5 | 0 | 0 | 0 |
| test_object | reference | 3 | 30 | 0 | 0 | 0 |
| test_object | before-evaluator | 3 | 30 | 0 | 0 | 0 |
| test_object | after-evaluator | 3 | 30 | 0 | 0 | 0 |
| test_object | before-vm | 3 | 30 | 0 | 0 | 0 |
| test_object | after-vm | 3 | 30 | 0 | 0 | 0 |

All three Rails files are COMPLETE on both sides in every run, with no wall or memory
bounds events.

| Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator-1 | 86 | 7 | 0 | 0 | 0 | 0 |
| after-evaluator-1 | 93 | 0 | 0 | 0 | 0 | 0 |
| before-vm | 86 | 7 | 0 | 0 | 0 | 0 |
| after-vm | 93 | 0 | 0 | 0 | 0 | 0 |

Max RSS, KiB, three alternating full-file evaluator pairs, fixed seed12345, 600s / 2GiB
per family, jobs2, MT_CPU=0:

| File | Main samples | Candidate samples | Median change |
| --- | --- | --- | ---: |
| activesupport/test/deprecation_test.rb | 294016 / 286944 / 337424 | 278896 / 312960 / 364384 | +6.44% |
| activesupport/test/deprecation/proxy_wrappers_test.rb | 359024 / 281072 / 277712 | 353136 / 275856 / 274048 | -1.86% |
| activesupport/test/deprecation/method_wrappers_test.rb | 355552 / 273376 / 278256 | 276928 / 279408 / 288064 | +0.41% |

RSS varies between samples; no stable memory improvement is claimed. Native gems are
explicitly reused from runtime63213030 / binary c7800ad2, with installation provenance
retained separately from measured digests. These are targeted files, not a new full-
component run.

Evidence: `railstest/framework/records/activesupport-deprecation-dispatch.json` and
`loop/2026-11-27-codex-rails1-deprecation-no-hook.md`. Historical acceptance remains
pinned to its original record commit.
