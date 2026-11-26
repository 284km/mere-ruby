# Optional anonymous Class test identity policy

Add an explicit `--case-identity-policy opaque-class-addresses` for anonymous Class
addresses embedded in Rails test names. Duplicable runs all 20 tests successfully on
both interpreters, but literal addresses differ between processes and previously produce
one MISSING plus one EXTRA. Keep the default literal policy unchanged; opt-in aliases
only unique, complete, one-to-one inventories, preserves repeated-address relationships
across cases and recorded runs, and retains raw names/aliases. `compare` rejects mixed
policies and still detects failures and extra-name collisions.

Shared framework tooling only: run.py, its check.py controls and README. No interpreter
source changes. Final tool revision f1b43a14; tested runtime 90b80e18 is byte-unchanged
by that Python-only amendment. Clean Ruby 4.0.10 through `tools/ref_ruby.sh`, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism 1.8.2.

Validation:

- 37 harness controls pass. The five new cross-run compare controls fail against the
earlier implementation (5 failures / 0 errors), providing a negative control.
- Real Duplicable file: all 20 tests pass and both sides are COMPLETE on evaluator and
VM. Default literal policy retains 19 MATCH / 1 MISSING / 1 EXTRA, strict gate exit 1;
opt-in gives 20 MATCH, zero other verdicts, strict gate exit 0.
- Actual opt-in records compare successfully in both directions across evaluator/VM. A
synthetic recorded pass deliberately changed to F is detected (exit 1); mixed policies
are refused (nonzero). Synthetic data is clearly labeled and is not a test execution.
- Unchanged runtime corpus --both: 951/951 ON/OFF. VM: 951 VM / 0 fallback / 0
differences. Eight runtime source gates and default hygiene pass; explicit new-record
hygiene checked separately. No fresh full-corpus claim on the final Python-only
amendment.
- Two alternating fixed-seed 12345 full TimeWithZone pairs: 174 MATCH / 0 RED, all
COMPLETE. Both harness sides use the identical 90b runtime binary. Before tool 03694405
is literal; after tool f1b opts in. Native gems explicitly reuse a9e68981's owned
install. Bounds 600 s / 2 GiB per family, jobs 2.

Peak family RSS, KiB:

| File | old harness / literal | new harness / opt-in |
| --- | --- | --- |
| time_with_zone_test.rb | 462672 / 425920 | 455344 / 467216 |

The samples vary; no stable memory improvement is claimed. Evidence:
`loop/2026-11-26-codex-rails1-anonymous-test-identities.md` and
`railstest/framework/records/activesupport-anonymous-test-identities.json`.
