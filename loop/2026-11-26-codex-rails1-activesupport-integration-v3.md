# ActiveSupport final integration measurement

Both engines, all162 selected files. Eight external-service/gem/JVM/XML files remain explicitly
excluded by the manifest.

| Cohort | MATCH | RED | MISSING | BOTH | UNCONFIRMED | EXTRA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator | 4721 | 19 | 1 | 27 | 0 | 1 |
| before-vm | 4721 | 19 | 1 | 27 | 0 | 1 |
| after-evaluator | 4766 | 2 | 0 | 0 | 0 | 0 |
| after-vm | 4766 | 2 | 0 | 0 | 0 | 0 |

UNCONFIRMED is UNCF. File-state counts:

| Cohort / side | COMPLETE | ZERO | INCOMPLETE | COUNT_MISMATCH | REPORT_MISMATCH | MEMORY_LIMIT | WALL_LIMIT | ABSENT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| before-evaluator / reference | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| before-evaluator / mere | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| before-vm / reference | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| before-vm / mere | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| after-evaluator / reference | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| after-evaluator / mere | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| after-vm / reference | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| after-vm / mere | 162 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

RED causes:

```json
{
  "evaluator": {
    "native_root_handoff_issue312": [
      "DescendantsTrackerTest#test_.descendants_with_garbage_collected_classes",
      "EventedFileUpdateCheckerTest#test_can_be_garbage_collected"
    ],
    "requires_investigation": []
  },
  "vm": {
    "native_root_handoff_issue312": [
      "DescendantsTrackerTest#test_.descendants_with_garbage_collected_classes",
      "EventedFileUpdateCheckerTest#test_can_be_garbage_collected"
    ],
    "requires_investigation": []
  }
}
```

Before/after qualifications:

- Before is historical mainA232 with 85-package native installation; after is integration1a454a94
with a fresh89-package installation made by its measured binary.
- Before uses literal test identities; after explicitly uses the reviewed opaque-class-addresses
policy. Raw names and aliases remain in the original records. Do not compare these records with the
same-policy compare command.
- Listen dependency installation and the identity policy each change non-RED verdicts; the totals do
not attribute every new MATCH to interpreter fixes.
- The duplicated short949 preflight is excluded from acceptance; independent full corpus both hash
modes and VM includes949 and is the source of acceptance.
- A component with any RED is not an all-pass component. Native-root failures are handed off in
issue312; remaining unexpected failures need investigation.

Fixed-seed12345 large-file family RSS, KiB (single whole-component observation per side; per-fix PRs
retain repeated measurements):

| File | before E | after E | before VM | after VM |
| --- | ---: | ---: | ---: | ---: |
| activesupport/test/core_ext/time_with_zone_test.rb | 457680 | 429536 | 422160 | 433088 |
| activesupport/test/deprecation_test.rb | 303552 | 290000 | 321504 | 320064 |

Per-file final states:

| File | E reference | E mere | VM reference | VM mere |
| --- | --- | --- | --- | --- |
| activesupport/test/actionable_error_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/array_inquirer_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/autoload_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/backtrace_cleaner_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/benchmark_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/benchmarkable_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/broadcast_logger_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/cache_coder_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/cache_entry_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/cache_key_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/cache_store_logger_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/cache_store_namespace_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/local_cache_middleware_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/serializer_with_fallback_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/stores/file_store_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/stores/memory_store_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/cache/stores/null_store_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/callback_inheritance_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/callbacks_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/clean_logger_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/concern_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/concurrency/load_interlock_aware_monitor_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/concurrency/thread_monitor_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/configurable_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/configuration_file_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/continuous_integration_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/array/access_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/array/conversions_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/array/extract_options_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/array/extract_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/array/grouping_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/array/wrap_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/bigdecimal_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/class/attribute_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/class_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/date_and_time_compatibility_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/date_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/date_time_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/digest/uuid_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/duration_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/enumerable_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/erb_util_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/file_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/hash/transform_values_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/hash_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/integer_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/kernel/concern_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/kernel_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/load_error_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/anonymous_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/attr_internal_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/attribute_accessor_per_thread_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/attribute_accessor_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/attribute_aliasing_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/concerning_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/introspection_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module/remove_method_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/module_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/name_error_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/numeric_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/acts_like_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/blank_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/deep_dup_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/duplicable_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/inclusion_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/instance_variables_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/json_cherry_pick_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/json_gem_encoding_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/to_param_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/to_query_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/try_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/object/with_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/pathname/blank_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/pathname/existence_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/range_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/regexp_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/secure_random_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/string_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/symbol_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/time_ext_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/core_ext/time_with_zone_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/current_attributes_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/deep_mergeable_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/dependencies_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/deprecation/deprecators_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/deprecation/method_wrappers_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/deprecation/proxy_wrappers_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/deprecation_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/descendants_tracker_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/digest_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/editor_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/encrypted_configuration_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/encrypted_file_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/environment_inquirer_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/error_reporter_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/event_reporter_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/evented_file_update_checker_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/execution_context_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/executor_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/file_update_checker_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/fork_tracker_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/gzip_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/hash_with_indifferent_access_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/i18n_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/inflector_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/isolated_execution_state_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/json/decoding_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/json/encoding_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/key_generator_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/lazy_load_hooks_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/log_subscriber_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/logger_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/message_encryptor_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/message_encryptors_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/message_pack/cache_serializer_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/message_pack/serializer_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/message_verifier_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/message_verifiers_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/messages/message_encryptor_metadata_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/messages/message_encryptor_rotator_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/messages/message_verifier_metadata_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/messages/message_verifier_rotator_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/messages/rotation_configuration_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/messages/serializer_with_fallback_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/multibyte_chars_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/multibyte_proxy_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/notifications/evented_notification_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/notifications/instrumenter_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/notifications_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/number_helper_i18n_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/number_helper_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/option_merger_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/ordered_hash_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/ordered_options_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/parallelization_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/parameter_filter_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/reloader_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/rescuable_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/safe_buffer_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/secure_compare_rotator_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/security_utils_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/share_lock_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/silence_logger_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/string_inquirer_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/structured_event_subscriber_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/subscriber_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/tagged_logging_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/test_case_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/testing/after_teardown_assertion_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/testing/after_teardown_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/testing/constant_lookup_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/testing/file_fixtures_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/testing/method_call_assertions_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/testing/notification_assertions_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/testing/test_without_assertions_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/time_travel_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/time_zone_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/transliterate_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/xml_mini/nokogiri_engine_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/xml_mini/nokogirisax_engine_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/xml_mini/rexml_engine_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |
| activesupport/test/xml_mini_test.rb | COMPLETE | COMPLETE | COMPLETE | COMPLETE |

Source/native/reference digests, UTC start/end, per-file counts and limits remain in
railstest/framework/records/activesupport-integration-v3.json. Any bounded file needs the separately
recorded isolated retry.

This branch preserves the measured source1a454a94 for issue312 reproduction. It is a measurement
snapshot; individual implementation PRs carry their own targeted validation. Clean source gates,
bracket depth and record hygiene pass.
