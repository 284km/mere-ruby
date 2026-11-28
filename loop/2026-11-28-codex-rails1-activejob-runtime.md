# ActiveJob container comparison, Hash conversion and lexical block scopes

ActiveJob argument round trips compared Time-ended Ranges structurally inside containers;
logging printed nested Hash objects through the leaf printer; continuation methods defined
by a stored concern block lost their defining Module.nesting. Restore the world-aware
comparison/conversion and the captured class/module-body nesting.

Measured source `42e57da3679bdb3d5699c1d27ffdbc9ebb2e9a2b` against main `491cc5cab`, ordinary O2. Framework tool
`7dd171fe68f6dfc9dceb49941b817b84daf57758`. Each before/after native install is fresh for its measured binary.
Reference `tools/ref_ruby.sh`: clean Ruby 4.0.10, revision
`a704b7cd95a42cc0cf5f307137bf3aac0285b915`, Prism 1.8.2, no extra gems.
Mere compiler 9dec2ff6; mgz 661a01d8.

- 1031/1031 corpus programs match ruby, with the hash index ON and OFF
- vm_corpus: 1031 programs -- 1031 on the VM, 0 on the evaluator (fell back), 0 FAIL, 0 against the list of fallbacks
- All 12 source-gate/default-record checks passed; changed-record hygiene is checked before publication.
- Corpus 948/955/1009: all 24 candidate engine/hash/GC32 combinations match Ruby;
  all six current-main controls reproduce a gap. The rejected Hash fallback also fails
  the raising-object_id control on both engines. It is retained only as a negative control.

| Core file | Side | State | Tests | Assertions | Failures | Errors | Skips | Limit |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| test_range | reference | COMPLETE | 67 | 396548 | 0 | 0 | 0 | none |
| test_range | before-evaluator | COMPLETE | 67 | 397596 | 0 | 0 | 0 | none |
| test_range | after-evaluator | COMPLETE | 67 | 397596 | 0 | 0 | 0 | none |
| test_range | before-vm | COMPLETE | 67 | 397596 | 0 | 0 | 0 | none |
| test_range | after-vm | COMPLETE | 67 | 397596 | 0 | 0 | 0 | none |
| test_array | reference | COMPLETE | 493 | 23681 | 0 | 0 | 2 | none |
| test_array | before-evaluator | INCOMPLETE | unknown | unknown | unknown | unknown | unknown | MEMORY_LIMIT |
| test_array | after-evaluator | INCOMPLETE | unknown | unknown | unknown | unknown | unknown | MEMORY_LIMIT |
| test_array | before-vm | INCOMPLETE | unknown | unknown | unknown | unknown | unknown | MEMORY_LIMIT |
| test_array | after-vm | INCOMPLETE | unknown | unknown | unknown | unknown | unknown | MEMORY_LIMIT |
| test_hash | reference | COMPLETE | 298 | 1905 | 0 | 0 | 0 | none |
| test_hash | before-evaluator | COMPLETE | 298 | 1905 | 0 | 0 | 0 | none |
| test_hash | after-evaluator | COMPLETE | 298 | 1905 | 0 | 0 | 0 | none |
| test_hash | before-vm | COMPLETE | 298 | 1905 | 0 | 0 | 0 | none |
| test_hash | after-vm | COMPLETE | 298 | 1905 | 0 | 0 | 0 | none |
| test_eval | reference | COMPLETE | 40 | 465 | 0 | 0 | 0 | none |
| test_eval | before-evaluator | COMPLETE | 40 | 461 | 0 | 0 | 1 | none |
| test_eval | after-evaluator | COMPLETE | 40 | 461 | 0 | 0 | 1 | none |
| test_eval | before-vm | COMPLETE | 40 | 461 | 0 | 0 | 1 | none |
| test_eval | after-vm | COMPLETE | 40 | 461 | 0 | 0 | 1 | none |
| test_module | reference | COMPLETE | 195 | 1240 | 0 | 0 | 0 | none |
| test_module | before-evaluator | COMPLETE | 195 | 1240 | 0 | 0 | 0 | none |
| test_module | after-evaluator | COMPLETE | 195 | 1240 | 0 | 0 | 0 | none |
| test_module | before-vm | COMPLETE | 195 | 1237 | 0 | 1 | 0 | none |
| test_module | after-vm | COMPLETE | 195 | 1237 | 0 | 1 | 0 | none |

The whole Array file reaches MEMORY_LIMIT at permutation_array_modified on all four
Mere sides. Module evaluator passes 195 on both sides; Module VM has the same
test_complemented_method_entry_memory_leak inner Timeout before and after.
Neither baseline outcome is presented as a passing full file.

Complete files and bounded/incomplete files retain their actual states. Isolated full
Array reruns and the relevant Array/Module selections are recorded separately. The JSON
lists every observed main PASS regression and every main PASS absent after the change;
absence in an incomplete run is unconfirmed, never a passing result.

| Rails selection | Adapter | Engine | Side | MATCH | RED | MISSING | BOTH | UNCONFIRMED | EXTRA |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| continuation | test | evaluator | before | 0 | 30 | 0 | 0 | 0 | 0 |
| arguments-and-logging | inline | evaluator | before | 83 | 8 | 0 | 0 | 0 | 0 |
| continuation | test | evaluator | after | 30 | 0 | 0 | 0 | 0 | 0 |
| arguments-and-logging | inline | evaluator | after | 91 | 0 | 0 | 0 | 0 | 0 |
| continuation | test | vm | before | 0 | 30 | 0 | 0 | 0 | 0 |
| arguments-and-logging | inline | vm | before | 83 | 8 | 0 | 0 | 0 | 0 |
| continuation | test | vm | after | 30 | 0 | 0 | 0 | 0 | 0 |
| arguments-and-logging | inline | vm | after | 91 | 0 | 0 | 0 | 0 | 0 |
| test-adapter-extra | test | evaluator | before | 275 | 5 | 33 | 0 | 0 | 0 |

All three primary target files are COMPLETE and unbounded on both sides/engines.
The broader TestAdapter before-control retains its AMQP loader failure:33 MISSING
and an INCOMPLETE Mere exceptions_test. Its candidate/VM diagnostics are pending;
it is not presented as all-pass. The runner retains original names
and source-pinned clock aliases. Assertions are unchanged; failures remain RED.

Large file: activesupport/test/json/encoding_test.rb, fixed seed 12345, jobs 2,
600 seconds /2 GiB per file family, normal GC. Three alternating pairs per engine.

| Engine | Before samples KiB | After samples KiB | Median change |
| --- | --- | --- | ---: |
| evaluator | 1365264 / 1532384 / 1477904 | 1428720 / 1519312 / 1404960 | -3.33% |
| vm | 1125696 / 1104560 / 1225872 | 1164176 / 1202368 / 1190864 | +5.79% |

RSS varies between runs; the individual samples above expose that variation. No stable
memory improvement is claimed. Optional instruction measurements remain queued;
no instruction-count or per-operation cost claim is made.

Evidence: `railstest/framework/records/activejob-protocols.json`.
The six framework tooling/dependency files are a separate PR. Final component-wide
measurements and the AMQP interpreter follow-up are separate from these three fixes.
Owner merges after the bot reviews the exact publication head.
