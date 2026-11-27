# PR326 current-main refresh

Module#included_modules returned an internal backing module for a Module-subclass
instance. Return the original instance so ActiveModel recognizes its existing validator
module and avoids adding another copy. Corpus955 covers identity, ordinary modules and
nested/prepend controls.

Merged current main29016cb8 and the #317 prerequisite with its no-hook optimization.
Measured runtime `17f4f9586b93745c6a56daf41d18cd21a34906fd`; comparison runtime
`d0336e573a7040a3768ab5816925b83c09a13fb9` already includes #317, so the identity change
is isolated. Ordinary O2, Mere9dec2ff6 / mgz661a01d8. Clean Ruby4.0.10 via
`tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism1.8.2, no
extra gems.

- Corpus --both: 1012/1012, hash ON/OFF.
- VM corpus (`-j 1` fresh full replay): 1012 VM / 0 fallback / 0 differences.
- Source gates, bracket check and default record hygiene pass. Explicit changed-record
hygiene also passes.
- Corpus955 matches reference stdout/stderr/status on evaluator and VM.

Related test_module selection, all modes COMPLETE with no lost passing case; no whole-
file acceptance is claimed:

| Mode | Tests | Assertions | Failures | Errors | Skips |
| --- | ---: | ---: | ---: | ---: | ---: |
| reference | 4 | 13 | 0 | 0 | 0 |
| before-evaluator | 4 | 13 | 0 | 0 | 0 |
| after-evaluator | 4 | 13 | 0 | 0 | 0 |
| before-vm | 4 | 13 | 0 | 0 | 0 |
| after-vm | 4 | 13 | 0 | 0 | 0 |

Targeted Rails files, all sides COMPLETE without bounds events:

| Component | Mode | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| activemodel | before-evaluator-1 | 9 | 1 | 0 | 0 | 0 | 0 |
| activesupport | before-evaluator-1 | 174 | 0 | 0 | 0 | 0 | 0 |
| activemodel | after-evaluator-1 | 10 | 0 | 0 | 0 | 0 | 0 |
| activesupport | after-evaluator-1 | 174 | 0 | 0 | 0 | 0 | 0 |
| activemodel | before-vm | 9 | 1 | 0 | 0 | 0 | 0 |
| activesupport | before-vm | 174 | 0 | 0 | 0 | 0 | 0 |
| activemodel | after-vm | 10 | 0 | 0 | 0 | 0 | 0 |
| activesupport | after-vm | 174 | 0 | 0 | 0 | 0 | 0 |

Max RSS, KiB, three alternating full-file evaluator pairs, seed12345, 600s / 2GiB per
family, jobs2, MT_CPU=0:

| File | Comparison samples | Candidate samples | Median change |
| --- | --- | --- | ---: |
| activemodel/test/cases/validations/acceptance_validation_test.rb | 278304 / 254064 / 276688 | 256752 / 257760 / 258096 | -6.84% |
| activesupport/test/core_ext/time_with_zone_test.rb | 384032 / 381312 / 387520 | 389536 / 375840 / 375056 | -2.13% |

The initial four-worker VM replay stalled in reference Ruby on the FIFO in corpus498.
Its owner terminated only that reference process; the initial 1011 VM / 0 fallback / 1
FAIL result remains in the record. The isolated reference/evaluator/VM program matches,
and a fresh complete VM replay with -j 1 passes. The successful corpus --both and Rails
measurements use the same unchanged runtime.

RSS varies; no stable memory improvement is claimed. Native extensions explicitly reused
from runtime63213030 / binary c7800ad2; measured and installing binary digests are
separate in the record. These are targeted files, not a new full-component run.

Evidence: `railstest/framework/records/activemodel-included-module-identity.json` and
`loop/2026-11-27-codex-rails1-included-module-identity.md`. Historical acceptance
remains pinned to its original record commit. #317 must land first.
