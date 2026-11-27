# Corpus driver shape-stat fixtures

The corpus preflight now requires sh_cls_var/sh_cls_cap statistics and the IV-door
source guard. Its two driver-test fixtures did not provide them, so unittest-harness and
runtime-load-path CI stopped before exercising their intended checks.

Update the synthetic interpreters to answer the new probe, add the IV-door stub beside
existing guard stubs, and account for the additional invocation. The load-path test
checks that the statistics probe receives the same library ordering; new negative
controls verify that either missing statistics row or either row exceeding 300 stops the
driver before reference corpus execution.

Compared with main `8e757236`; measured source
`f4751983e8f98a6f427b3ef11ad24426491ab302`. The diff is the two Python check files and
these records. Runtime/corpus inputs have no delta. Clean Ruby 4.0.10 through
`tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism
1.8.2. Ordinary O2 compiler 9dec2ff6, mgz 661a01d8.

- Corpus --both: 973/973 hash ON/OFF; VM: 973 VM / 0 fallback / 0 differences.
- Nine source gates including IV-door, bracket check and default hygiene pass. Explicit
changed-record hygiene checked separately.
- Related driver checks run in three alternating before/after pairs, 600 s / 2 GiB
bounds, without limits. Before failures reproduce the reported baseline CI problem;
after runs pass.

| Check | Main tests / failures | Candidate tests / failures |
| --- | --- | --- |
| tools/runtime_load_path_check.py | 6 / 2 | 8 / 0 |
| unittest/harness_check.py | 21 / 2 | 21 / 0 |

Peak process-family RSS, KiB, all three samples:

| Check | Main | Candidate |
| --- | --- | --- |
| tools/runtime_load_path_check.py | 44592 / 37792 / 39008 | 39712 / 37312 / 38848 |
| unittest/harness_check.py | 44576 / 45152 / 45232 | 44112 / 45104 / 44928 |

Samples vary; no memory improvement is claimed. These are driver fixtures, so the
related checks above take the place of a CRuby/Rails test selection. Digests, UTC times
and the full paired results are in `unittest/records/ci-shape-stat-fixtures.json`.
