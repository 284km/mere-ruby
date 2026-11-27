# Array sum blocks dispatch custom accumulator operators

A block-based Array#sum always used primitive arithmetic. A custom initial
accumulator and block values therefore missed their Ruby + operator, which
made an ActiveSupport Enumerable sum case error. Runtime fd7f5acb preserves
the existing native numeric path and dispatches other accumulators through
the existing binary-operator dispatcher, including numeric coerce.

Corpus 945 covers custom initial values, coerce, empty input, break/next and
core Integer/Float + replacements. The core numeric sum behavior is retained.
An earlier generic-dispatch prototype changed that numeric behavior and was
rejected; its output is not counted as successful validation.

Base a9e68981, ordinary O2 compiler 9dec2ff6. Clean reference selected with
tools/ref_ruby.sh: Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extra gems and Prism 1.8.2.
No reference gem-directory installation was performed.

Earlier fd7f5acb corpus --both: 942/942 with hash index ON and OFF, 1273.029 seconds,
maximum family RSS 1,193,648 KiB. VM corpus: 942 VM, zero fallback and zero
differences, 346.774 seconds, maximum family RSS 1,323,728 KiB. All eight
source gates and default record hygiene pass. The fresh run replaces an
invalid earlier run interrupted by disk exhaustion.

Three alternating before/after fixed-seed 12345 Rails replay pairs retain
all files COMPLETE. Enumerable changes 33 MATCH / 1 RED to 34 MATCH / 0 RED.
TimeWithZone remains 174 MATCH / 0 RED, making the two-file total 207/1 to
208/0. MISSING, UNCONFIRMED, BOTH and EXTRA remain zero. The existing order
diagnostic remains one. Native gems explicitly reuse the owned 85-package
install made by a9e68981, with installing and measuring digests recorded.
Bounds are unchanged: 600 seconds, 2 GiB per family, jobs 2, MT_CPU=0.

Maximum family RSS, KiB, three repetitions:

| File | main | candidate |
| --- | --- | --- |
| Enumerable | 354928 / 324480 / 290976 | 286480 / 335040 / 358464 |
| TimeWithZone | 456848 / 454736 / 452880 | 448736 / 452128 / 453712 |

The ranges vary and overlap; no stable memory improvement is claimed.

CRuby test_array's isolated whole-file replay still reaches MEMORY_LIMIT
on both main and candidate, in both engines, at the unchanged 2-GiB cap.
Reference completes 493 tests / 23681 assertions with two skips. Selected
TestArray and TestArraySubclass test_sum cases pass two tests / 156
assertions in all five executions. Whole test_enum remains COMPLETE with
90 tests / 589 assertions and the same test_callcc failure on both builds
and engines. These retained baseline failures are not called all-pass.

Portable evidence:
railstest/framework/records/activesupport-array-sum-operators.json.

Review follow-up, runtime 8a18fffc: a general accumulator may return an Integer
or Float. The block route now retains general Ruby + dispatch after that
transition, while numeric-only sums retain the native path. Corpus 945
adds Integer/Float return and addend transition controls. Focused corpus
945/426/593 matches reference on both engines.

The fresh exact-runtime full corpus passes 942/942 in both hash modes; VM
reports 942 VM / 0 fallback / 0 differences. Selected CRuby sum cases pass
2 tests / 156 assertions in all five executions. The whole Array/Enum
results above belong to fd7f5acb and are retained as earlier coverage, not
claimed as whole-file results on this final runtime.

Three fresh alternating Rails pairs again change Enumerable 33/1 to 34/0
and keep TimeWithZone 174/0, all COMPLETE. Peak family RSS in KiB:

| File | main | candidate |
| --- | --- | --- |
| enumerable_test.rb | 288448 / 368208 / 321488 | 289232 / 288272 / 361456 |
| time_with_zone_test.rb | 456544 / 454896 / 456528 | 490992 / 459456 / 458960 |

The samples vary; no stable memory improvement is claimed.
