# Class reflection overrides in ActiveJob adapter loading

AMQP defines a collection of protocol method classes as AMQ::Protocol::Method.methods.
The native reflection dispatch ran before that Ruby override, returned Symbols and
stopped ActiveJob exceptions_test before its 33 tests. Respect Ruby class overrides;
preserve inherited/extended methods, visibility, blocks, super and retained native methods.

Measured runtime `6183e2493d10a687a9dfabc3625de71698d5463c` against `42e57da3679bdb3d5699c1d27ffdbc9ebb2e9a2b` (PR #395 source).
Framework tooling `7dd171fe68f6dfc9dceb49941b817b84daf57758`. Compiler9dec2ff6; mgz661a01d8.
Reference `tools/ref_ruby.sh`: clean Ruby4.0.10, revision
`a704b7cd95a42cc0cf5f307137bf3aac0285b915`, Prism1.8.2, no extra gems.

- 1031/1031 corpus programs match ruby, with the hash index ON and OFF
- vm_corpus: 1031 programs -- 1031 on the VM, 0 on the evaluator (fell back), 0 FAIL, 0 against the list of fallbacks
- All 12 source/default-record checks passed; changed-record hygiene checked before publication.
- Expanded corpus959: all eight engine/hash/GC32 combinations match Ruby;
  both baseline engines reproduce the override bug. Real locked AMQP loads its
  64 method classes on both candidate engines and matches Ruby.

| Core file | Side | State | Tests | Assertions | Failures | Errors | Skips | Limit |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| test_module | reference | COMPLETE | 195 | 1240 | 0 | 0 | 0 | none |
| test_module | before-evaluator | COMPLETE | 195 | 1240 | 0 | 0 | 0 | none |
| test_module | after-evaluator | COMPLETE | 195 | 1240 | 0 | 0 | 0 | none |
| test_module | before-vm | COMPLETE | 195 | 1237 | 0 | 1 | 0 | none |
| test_module | after-vm | COMPLETE | 195 | 1237 | 0 | 1 | 0 | none |
| test_object | reference | COMPLETE | 67 | 429 | 0 | 0 | 0 | none |
| test_object | before-evaluator | COMPLETE | 67 | 420 | 2 | 0 | 0 | none |
| test_object | after-evaluator | COMPLETE | 67 | 420 | 2 | 0 | 0 | none |
| test_object | before-vm | COMPLETE | 67 | 420 | 2 | 0 | 0 | none |
| test_object | after-vm | COMPLETE | 67 | 420 | 2 | 0 | 0 | none |
| test_method | reference | COMPLETE | 99 | 564 | 0 | 0 | 0 | none |
| test_method | before-evaluator | COMPLETE | 99 | 556 | 1 | 0 | 1 | none |
| test_method | after-evaluator | COMPLETE | 99 | 556 | 1 | 0 | 1 | none |
| test_method | before-vm | INCOMPLETE | unknown | unknown | unknown | unknown | unknown | MEMORY_LIMIT |
| test_method | after-vm | COMPLETE | 99 | 556 | 1 | 0 | 1 | none |

Nonpassing core cases are retained explicitly:

- test_module / before-vm: TestModule#test_complemented_method_entry_memory_leak (T).
- test_module / after-vm: TestModule#test_complemented_method_entry_memory_leak (T).
- test_object / before-evaluator: TestObject#test_max_shape_variation_with_performance_warnings (F).
- test_object / before-evaluator: TestObject#test_remove_instance_variable_re_embed (F).
- test_object / after-evaluator: TestObject#test_max_shape_variation_with_performance_warnings (F).
- test_object / after-evaluator: TestObject#test_remove_instance_variable_re_embed (F).
- test_object / before-vm: TestObject#test_max_shape_variation_with_performance_warnings (F).
- test_object / before-vm: TestObject#test_remove_instance_variable_re_embed (F).
- test_object / after-vm: TestObject#test_max_shape_variation_with_performance_warnings (F).
- test_object / after-vm: TestObject#test_remove_instance_variable_re_embed (F).
- test_method / before-evaluator: TestMethod#test_singleton_method_not_interned_name (F).
- test_method / before-evaluator: TestMethod#test_hash_does_not_change_after_compaction (S).
- test_method / after-evaluator: TestMethod#test_singleton_method_not_interned_name (F).
- test_method / after-evaluator: TestMethod#test_hash_does_not_change_after_compaction (S).
- test_method / before-vm: TestMethod#test_zsuper_method_removed (X).
- test_method / before-vm: TestMethod#test_arity (X).
- test_method / before-vm: TestMethod#test_bound_method_entry (X).
- test_method / before-vm: TestMethod#test_bound_parameters (X).
- test_method / before-vm: TestMethod#test_define_method_invalid_arg (X).
- test_method / before-vm: TestMethod#test_receiver_name_owner (X).
- test_method / before-vm: TestMethod#test_prepended_public_zsuper (X).
- test_method / before-vm: TestMethod#test_singleton_method_not_interned_name (X).
- test_method / before-vm: TestMethod#test_compose_with_proc (X).
- test_method / before-vm: TestMethod#test_gced_bmethod (X).
- test_method / before-vm: TestMethod#test_super_method_bind_unbind_clone (X).
- test_method / before-vm: TestMethod#test_owner_missing (X).
- test_method / before-vm: TestMethod#test_curry_from_proc (X).
- test_method / before-vm: TestMethod#test_super_method (X).
- test_method / before-vm: TestMethod#test_unbound_method_parameters_inspect (X).
- test_method / before-vm: TestMethod#test_define_method_in_private_scope (X).
- test_method / before-vm: TestMethod#test_super_method_removed_public (X).
- test_method / before-vm: TestMethod#test_public_method_with_zsuper_method (X).
- test_method / before-vm: TestMethod#test_super_method_alias (X).
- test_method / before-vm: TestMethod#test_callee_top_level (X).
- test_method / before-vm: TestMethod#test_caller_top_level (X).
- test_method / before-vm: TestMethod#test_zsuper_method_removed_higher_method (X).
- test_method / before-vm: TestMethod#test_clone (X).
- test_method / before-vm: TestMethod#test_new (X).
- test_method / before-vm: TestMethod#test_umethod_bind_call (X).
- test_method / before-vm: TestMethod#test_prepended (X).
- test_method / before-vm: TestMethod#test_arity_special (X).
- test_method / before-vm: TestMethod#test_owner (X).
- test_method / before-vm: TestMethod#test_zsuper_method_redefined_bind_call (X).
- test_method / before-vm: TestMethod#test_method_in_block_in_define_method_block (X).
- test_method / before-vm: TestMethod#test_unbind (X).
- test_method / before-vm: TestMethod#test_super_method_unbound (X).
- test_method / before-vm: TestMethod#test_bmethod_unbound_parameters (X).
- test_method / before-vm: TestMethod#test_eqq (X).
- test_method / before-vm: TestMethod#test_bind_module_instance_method (X).
- test_method / before-vm: TestMethod#test_define_singleton_method (X).
- test_method / before-vm: TestMethod#test_caller_negative_level (X).
- test_method / before-vm: TestMethod#test_body (X).
- test_method / before-vm: TestMethod#test_singleton_define_method_in_private_scope (X).
- test_method / before-vm: TestMethod#test_public_methods_with_extended (X).
- test_method / before-vm: TestMethod#test_curry_method (X).
- test_method / before-vm: TestMethod#test_curry_var_args (X).
- test_method / before-vm: TestMethod#test_attrset_ivar (X).
- test_method / before-vm: TestMethod#test_define_singleton_method_public (X).
- test_method / before-vm: TestMethod#test_method_parameters_inspect (X).
- test_method / before-vm: TestMethod#test_define_method_with_symbol (X).
- test_method / before-vm: TestMethod#test_method_in_define_method_block (X).
- test_method / before-vm: TestMethod#test_unbound_method_equality_with_extended_module (X).
- test_method / before-vm: TestMethod#test_super_with_splat (X).
- test_method / before-vm: TestMethod#test_super_method_module_alias (X).
- test_method / before-vm: TestMethod#test_included (X).
- test_method / before-vm: TestMethod#test_instance_method (X).
- test_method / before-vm: TestMethod#test_warn_unused_block (X).
- test_method / before-vm: TestMethod#test_singleton_method (X).
- test_method / before-vm: TestMethod#test_to_proc_binding (X).
- test_method / before-vm: TestMethod#test_argument_error_location (X).
- test_method / before-vm: TestMethod#test_method_binding (X).
- test_method / before-vm: TestMethod#test_hidden_parameters (X).
- test_method / before-vm: TestMethod#test___dir__ (X).
- test_method / before-vm: TestMethod#test_curry_from_proc_var_args (X).
- test_method / before-vm: TestMethod#test_eq (X).
- test_method / before-vm: TestMethod#test_super_method_module (X).
- test_method / before-vm: TestMethod#test_inspect (X).
- test_method / before-vm: TestMethod#test_orphan_callee (X).
- test_method / before-vm: TestMethod#test_visibility (X).
- test_method / before-vm: TestMethod#test_invalidating_CC_ASAN (X).
- test_method / before-vm: TestMethod#test_singleton_method_prepend (X).
- test_method / before-vm: TestMethod#test_compose_with_method (X).
- test_method / before-vm: TestMethod#test_override_optimized_method_on_class_using_prepend (X).
- test_method / before-vm: TestMethod#test_super_method_after_bind (X).
- test_method / before-vm: TestMethod#test_bmethod_bound_parameters (X).
- test_method / before-vm: TestMethod#test_clone_under_gc_compact_stress (X).
- test_method / before-vm: TestMethod#test_unbound_method_proc_coerce (X).
- test_method / before-vm: TestMethod#test_super_method_with_prepended_module (X).
- test_method / before-vm: TestMethod#test_respond_to_missing_argument (X).
- test_method / before-vm: TestMethod#test_unbound_parameters (X).
- test_method / before-vm: TestMethod#test_define_method_transplating (X).
- test_method / before-vm: TestMethod#test_super_in_proc_from_define_method (X).
- test_method / before-vm: TestMethod#test_super_method_alias_to_prepended_module (X).
- test_method / before-vm: TestMethod#test_hash_does_not_change_after_compaction (X).
- test_method / before-vm: TestMethod#test_callee (X).
- test_method / before-vm: TestMethod#test_zsuper_private_override_instance_method (X).
- test_method / before-vm: TestMethod#test_splat_long_array (X).
- test_method / after-vm: TestMethod#test_singleton_method_not_interned_name (F).
- test_method / after-vm: TestMethod#test_hash_does_not_change_after_compaction (S).

The initial baseline VM Method file hit MEMORY_LIMIT during splat_long_array;
the candidate completed. The original bounded outcome is retained, with a serial
whole-file replay and relevant reflection-method selection reported separately.

| Method replay | Side | State | Tests | Failures | Errors | Skips | Limit |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| isolated-whole-method-file | before-vm | INCOMPLETE | unknown | unknown | unknown | unknown | MEMORY_LIMIT |
| isolated-whole-method-file | after-vm | COMPLETE | 99 | 1 | 0 | 1 | none |
| reflection-method-selection | reference | COMPLETE | 19 | 0 | 0 | 0 | none |
| reflection-method-selection | before-evaluator | COMPLETE | 19 | 1 | 0 | 0 | none |
| reflection-method-selection | after-evaluator | COMPLETE | 19 | 1 | 0 | 0 | none |
| reflection-method-selection | before-vm | COMPLETE | 19 | 1 | 0 | 0 | none |
| reflection-method-selection | after-vm | COMPLETE | 19 | 1 | 0 | 0 | none |

| Rails selection | Engine | Side | MATCH | RED | MISSING | BOTH | UNCONFIRMED | EXTRA |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| five-test-adapter-files | evaluator | before | 280 | 0 | 33 | 0 | 0 | 0 |
| five-test-adapter-files | evaluator | after | 313 | 0 | 0 | 0 | 0 | 0 |
| five-test-adapter-files | vm | before | 280 | 0 | 33 | 0 | 0 | 0 |
| five-test-adapter-files | vm | after | 313 | 0 | 0 | 0 | 0 | 0 |

| Target file | Engine | Before MATCH / RED / MISSING | After MATCH / RED / MISSING |
| --- | --- | --- | --- |
| activejob/test/cases/test_helper_test.rb | evaluator | 207 / 0 / 0 | 207 / 0 / 0 |
| activejob/test/cases/logging_test.rb | evaluator | 47 / 0 / 0 | 47 / 0 / 0 |
| activejob/test/cases/instrumentation_test.rb | evaluator | 5 / 0 / 0 | 5 / 0 / 0 |
| activejob/test/cases/structured_event_subscriber_test.rb | evaluator | 21 / 0 / 0 | 21 / 0 / 0 |
| activejob/test/cases/exceptions_test.rb | evaluator | 0 / 0 / 33 | 33 / 0 / 0 |
| activejob/test/cases/test_helper_test.rb | vm | 207 / 0 / 0 | 207 / 0 / 0 |
| activejob/test/cases/logging_test.rb | vm | 47 / 0 / 0 | 47 / 0 / 0 |
| activejob/test/cases/instrumentation_test.rb | vm | 5 / 0 / 0 | 5 / 0 / 0 |
| activejob/test/cases/structured_event_subscriber_test.rb | vm | 21 / 0 / 0 | 21 / 0 / 0 |
| activejob/test/cases/exceptions_test.rb | vm | 0 / 0 / 33 | 33 / 0 / 0 |

All candidate Rails files COMPLETE and unbounded. Baseline incomplete loader
results remain explicit; no baseline passing case was lost.

Large file: AS json/encoding_test.rb, three alternating pairs, seed12345, normal GC.

| Engine | Before samples KiB | After samples KiB | Median change |
| --- | --- | --- | ---: |
| evaluator | 1564320 / 1437248 / 1520080 | 1535424 / 1450352 / 1505232 | -0.98% |
| vm | 1214848 / 1210192 / 1289936 | 1192928 / 1225888 / 1150144 | -1.80% |

RSS varies between runs; the individual samples expose that variation.

| Instruction workload | Engine | Before median | After median | Change |
| --- | --- | ---: | ---: | ---: |
| class_methods_no_override | evaluator | 1426961515 | 1430856401 | +0.273% |
| class_methods_no_override | vm | 1421522673 | 1430262309 | +0.615% |
| class_public_methods_no_override | evaluator | 2485740932 | 2494071333 | +0.335% |
| class_public_methods_no_override | vm | 2476606568 | 2482506845 | +0.238% |
| ordinary_object_methods_control | evaluator | 1498219792 | 1499107077 | +0.059% |
| ordinary_object_methods_control | vm | 1491676716 | 1490658019 | -0.068% |

Whole-process instruction medians include startup; three alternating pairs with
5000 queries per workload. Both engines return the Ruby checksum.

Evidence: `railstest/framework/records/class-reflection-overrides.json`.
No C API or VM implementation changes. Final full components are a separate record.
