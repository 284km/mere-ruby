# Reproducible ActiveJob adapter inputs and clock descriptions

ActiveJob exceptions_test eagerly loads SneakersAdapter even on a built-in adapter.
Lock its real Rails-pinned dependency closure; exceptions_test must use TestAdapter
to define its scheduling tests. No worker or external RabbitMQ service is started.

Add the opt-in rails-argument-descriptions policy for the three volatile current-clock
Range test descriptions in the exact pinned Rails source. It preserves offsets, types
and Range forms, accepts only unique COMPLETE inventories, and retains raw names plus
aliases. Changed/unknown sources remain literal. A paired failure remains RED.
The existing default/literal and opaque-class-address policies retain their behavior.

Framework checks: 43 passed, including negative source-pin, failure, offset, ambiguity,
incomplete inventory, namespace and strict all_pass/compare cases.
Measured tool source `7dd171fe68f6dfc9dceb49941b817b84daf57758`, runtime `42e57da3679bdb3d5699c1d27ffdbc9ebb2e9a2b`.
Reference `tools/ref_ruby.sh`: clean Ruby 4.0.10, revision
`a704b7cd95a42cc0cf5f307137bf3aac0285b915`, Prism 1.8.2, no extras.

| Additional archive | SHA-256 |
| --- | --- |
| sneakers-2.11.0.gem | 539ae7980d685d1d796b9daf62e81efa0cb592f7a287a71b24777868a5bccfc1 |
| bunny-2.24.0.gem | 072fe4ae98eaa9c95a17e4d166204f710bba8a9a7070b73a8c3b023f439d1682 |
| amq-protocol-2.8.0.gem | d06bbb341fa683459954f5a854388dac729171500116d81311cfbeaad83392ab |
| sorted_set-1.1.0.gem | bac01eb16b6bcfcdb7d732a28e87422be8b5c9fdcfeadbe9072682407524ee83 |
| rbtree-0.4.6.gem | 14eea4469b24fd2472542e5f3eb105d6344c8ccf36f0b56d55fdcfeb4e0f10fc |
| serverengine-2.0.7.gem | 14ed2e1c4e940739d7a2b9a18450842781d5afd6f99575b7e9296a69014275be |
| sigdump-0.2.5.gem | bb706c1cce70458b285d2c3a57121e801ccb79f68be7f7377692eb40b5437242 |

Each archive digest was checked against RubyGems metadata for platform=ruby.
Own archive cache only; shared archives and reference Gem.default_dir unchanged.
Both control/candidate native installations are fresh and record exact binary and
tool revisions. No earlier native install is reused.

- 1031/1031 corpus programs match ruby, with the hash index ON and OFF
- vm_corpus: 1031 programs -- 1031 on the VM, 0 on the evaluator (fell back), 0 FAIL, 0 against the list of fallbacks
- Source gates and default record_hygiene passed on the unchanged runtime.
- Targeted evaluator/VM Rails files and three fixed-seed large-file RSS pairs
  per engine are in the linked runtime record; every after target is strict all-pass.
- Explicit changed-record hygiene is run before publication.

Evidence: `railstest/framework/records/activejob-test-inputs.json` and
`railstest/framework/records/activejob-protocols.json`. Final component-wide
cohorts use disjoint inline 19 / TestAdapter 2 / async 1 ActiveJob files; supplemental
TestAdapter 21 is reported separately. No duplicate totals are combined.
The broadened TestAdapter main-control exposes a separate AMQP interpreter
loader failure: reference: 33 cases complete, Mere exceptions_test INCOMPLETE
with33 MISSING. This result is retained and not marked passing. Follow-up
interpreter work and candidate/VM broad diagnostics remain pending.
Owner merges after the bot reviews the exact publication head.
