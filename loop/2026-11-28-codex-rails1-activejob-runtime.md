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


## Corpus reference disassembly follow-up

CI396 job140873301577 stopped in clean referenceRuby4.0.10's ISeq#disasm
on corpus1009's static Unicode subclass and constant reference. Normal Ruby
execution was correct. The same named subclass is now made by Object.const_set
and Class.new, then used through its local variable. The name/parent/fallback
and encoding assertions remain; the original and updated outputs are identical.
All8 evaluator/VM/hash/GC32 comparisons match; whole-file ISeq comparison is
1031/1031same,zero refused/diff/format/errors,without a harness skip.

Corpus--both1031/1031; VM1031/0fallback/0FAIL/0list differences;12gates pass.
The exact O2 runtime42 binary is reused, with identical runtime/build inputs
and a freshly emitted byte-identical C. A prior source-age-gate refusal is
retained as pre-corpus failure; no mtime gate or resource bound was bypassed.
Original core/Rails/RSS evidence remains applicable to that unchanged runtime,
and is explicitly reused. This does not clear the separate hostedLinux Module
timeouts or396 Method-copy memory failure/global merge hold. Re-review exacthead.

Review follow-up: Range probe allocation and measurement scope

Runtime9e611af4 replaces hng_key with hng_key_q in prim_eq_override and avoids an endpoint-
list allocation for Integer-ended Ranges in arr_has_obj_d. Corpus948 now includes String-
subclass and singleton equality controls. The original record itself identifies the three
clock-name rows whose pairing needs396.

Corpora:1031/1031 both hash modes; VM1031/0fallback/0differences. Twelve source
gates/default record hygiene pass; explicit changed-file hygiene is checked at publication.
Range67 and Hash298 cases complete on both engines and both before/after binaries; no prior
PASS lost.

The three ActiveJob files remain121MATCH/0other, COMPLETE on both sides, both engines. Fresh
native installations use each exact measured binary. The checked-in follow-up evidence
retains all core case identities,24boundary comparisons, net instruction samples and
repeated large-file RSS controls.

evaluator RSS KiB: {'before': [1519776, 1537632, 1605440], 'after': [1541008, 1604576,
1572432]}; median change 2.26percent. Three alternating normal-GC seed12345 pairs; report
variance without a stable-improvement claim.

vm RSS KiB: {'before': [1273376, 1242160, 1265872], 'after': [1287280, 1205168, 1274816]};
median change 0.71percent. Three alternating normal-GC seed12345 pairs; report variance
without a stable-improvement claim.

Net per-call Range cost remains4–8percent above main491, while improving17–20percent for
String/mixed Ranges versus runtime42. Hash join still incurs the required per-call method-
dispatch increase, around26k→37k instructions; the earlier whole-process1percent number
includes startup. The PR body presents both quantities together.

Evidence:railstest/framework/records/activejob-equality-cost.json. Exact-head bot re-review
and owner merge-hold clearance remain required.
