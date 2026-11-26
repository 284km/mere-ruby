# B13: independent class identities in Ruby boxes

Boxes that define the same displayed class name shared its internal
identity. Every newly defined box-owned class/module now receives its own
internal identity. Qualified lookups follow the box's constant binding,
including aliases, reopening and the VM include path. Outside boxes, a
removed constant starts a fresh identity; ordinary reopening remains the
same class. Registering the new class's lexical scope through the common
path also fixes Timeout::State::GET_TIME when a box requires Timeout.

## Review integration completed

The review of head cd8e47f8 required integration after #262, #285 and #288
changed the class-definition/singleton paths. This revision merges main
f4303e14 and validates the resulting tree with a fresh ordinary O2 build.
Older r6 sweeps are superseded by the following actual r7 results:

- `sh run_corpus.sh --both`: 965/965, hash index ON and OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 965/965, ON and OFF, exit 0.
- Eight source gates, generated-C bracket depth, full and explicit loop
  record_hygiene and staged/unstaged whitespace checks: PASS.

Binary SHA-256:
`7a62b41a2efccd196b46f01c854eebff888ed73ac1e7ca260c110bf0670809a7`.
Compiler 9dec2ff6; mgz 661a01d8. Reference is clean Ruby 4.0.10 selected by
`tools/ref_ruby.sh`. Matching main control is a fresh f4303e14 O2 build.

Requested targeted corpus comparisons match stdout, stderr and status on
both engines: 1112 (14 rows), 1057 (72), 1061 (44), and 1062 (22).
Corpus 1112 also matches on both engines with RUBY_BOX=1; only the exact
reference/candidate executable prefix in the experimental warning is
canonicalized, leaving both warning lines and their text intact.

The unchanged ruby/test_box.rb selections add_constants_in_box,
eval_with_constants, eval_with_classes and
very_basic_method_calls_and_constants pass 4 tests / 53 assertions on
reference and both candidate engines, with RUBY_BOX=1. Main completes only
8 assertions and errors at Timeout::State::GET_TIME on each engine. These
are selected related cases, not a whole-file claim.

Maximum RSS bytes, /usr/bin/time -l, MERE_RUBY_GC_TIGHT=1 and --seed=1:

| Engine | Main f4303e14 | Candidate |
| --- | ---: | ---: |
| Evaluator | 242008064 | 281395200 |
| VM | 255541248 | 279986176 |

The candidate completes 45 more assertions and more stdlib loading, so
this table is not a matched-workload heap-growth comparison. No pass is
claimed for main's error. A1's separate missing Box prelude loaded features
remain outside this class-identity fix; no feature entry is fabricated.

The integration and completed record are pushed together after the local
checks. No full unit or Rails suite, reference gem installation or workflow
change. Main commits after the pinned integration are not claimed tested.
