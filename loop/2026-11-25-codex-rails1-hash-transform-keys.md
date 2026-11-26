# Hash transform_keys mapping arguments

Hash#transform_keys and transform_keys! accepted only a literal Hash mapping.
A to_hash conversion was ignored or rejected, and frozen or iteration checks
could run before argument conversion. ActiveSupport's
HashWithIndifferentAccess transform_keys tests consequently failed.

Runtime c1d1c07a adds checked mapping conversion at native entry points.
Merge b2a15185 integrates pinned main 45b09326 without a manual conflict.
The mapping is converted once, before iteration and frozen checks; Ruby
overrides retain their arguments. Missing conversion and a conversion that
returns nil are distinguished, including private or dynamic conversion
methods and singleton methods on primitive values. Bare transform_keys!
on a frozen Hash still returns an Enumerator. Corpus 941 covers these
cases, aliases, super, wrong arity, blocks and conversion callbacks that
mutate or freeze the receiver.

Both comparison executables are fresh ordinary O2 builds using compiler
9dec2ff687a08433247dbdb7729bc19c8522e538. The first baseline setup lacked
its mgz checkout and stopped before emitting a runtime; only the successful
build with the pinned mgz sources is measured. Reference is tools/ref_ruby.sh,
clean Ruby 4.0.10, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915:
84 default/bundled gems, zero extras, default Prism 1.8.2.

Focused validation:

- Corpus 941 and imported regressions 1007, 1021 and 1024 match the reference
  on evaluator and VM (eight executions).
- HashWithIndifferentAccess: main 95 MATCH / 2 RED; candidate 97 MATCH /
  0 RED, repeated three times, both sides COMPLETE. VM candidate also has
  97 MATCH / 0 RED and passes the strict gate. All other verdicts are zero;
  the existing ordering diagnostic is retained.
- CRuby test_hash: all 298 tests COMPLETE before and after on both engines.
  Each Mere run has 1,902 assertions and the same existing
  TestHashOnly#test_replace_memory_leak child timeout; the reference has
  1,905 assertions with no failure/error. No previously passing case is lost.
- Related test_object conversion checks: 4 tests / 12 assertions pass on
  reference and both builds in both engines.

Three alternating fixed-seed 12345 HashWithIndifferentAccess measurements:

| Build | Maximum family RSS, KiB |
| --- | --- |
| main45 | 342,976 / 341,072 / 349,408 |
| candidate | 295,360 / 361,440 / 299,328 |

The candidate varies by 66,080 KiB, and the ranges overlap. No stable memory
improvement is claimed. The VM candidate measurement is 320,256 KiB.
Bounds remain 600 seconds / 2 GiB per file family, jobs 2, MT_CPU=0.
The focused replays explicitly reuse the owned native-gem install made by
fdda9150d8bbdef666f5b24cc15b64f713b6e4f1; its receipt and the measured
binary digests are retained separately. No full component run was started.

Final validation: corpus --both 939/939 ON/OFF, 1,407.489 seconds,
maximum family RSS 1,182,448 KiB. VM corpus: 939 VM / 0 fallback /
0 differences, 284.899 seconds, maximum family RSS 1,231,376 KiB.
Eight corpus-prefix gates and default record hygiene pass; the bracket
gate needs 155 of 1024. New record and loop hygiene are checked explicitly
before committing the validation batch.
Portable evidence: unittest/records/hash-transform-keys-mapping.json.
