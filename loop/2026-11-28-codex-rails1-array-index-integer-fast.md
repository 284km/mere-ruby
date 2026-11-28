# Action Mailer array protocol correction

Runtime `425c78236c99c9b7797ba45b5dd89bce772c3927`; main baseline8edcf953; clean Ruby4.0.10
via tools/ref_ruby.sh, revisiona704b7cd95, Prism1.8.2, zero extra gems. Compiler9dec2ff6;
mgz661a01d8.

Index and count conversion now occurs only when entering Array native code; Ruby overrides
receive their original arguments. Native aliases, retained Methods and super still apply
to_int. Exact Integer arguments already pass unchanged, so their native path avoids both
conversion and the additional Ruby-override lookup. String keys, assignment return values,
frozen override bodies, original to_int-bearing objects and superclass entry are in
corpus941.
Both comparison sides include main8edcf953 with the merged Class singleton-super
prerequisite. The before binary is the same pinned main8ed control used by keyword tests,
with a fresh native installation made by that exact binary. No runtime substitution.
The whole Array file reaches its existing permutation-array-modified memory bound;
incomplete observations and isolated replays remain explicit. Only the separately COMPLETE
index-related selection proves retained previous PASS identities beyond the bounded prefix.
The targeted Mailer comparison holds every prerequisite identical on both sides, including
unmerged parser402, ActiveJob395 and class reflection399. Beforef2ab6b90 removes only the
final Array and keyword fixes from afterf38e6ad2; both fixes are present in the after
integration. Per-file counts and all raw identities are retained. This is an integration
target comparison, not the standalone PR binary.
Standalone main+keyword runs were0MATCH25MISSING because the measured main8ed predates parser402 and
strict Nokogiri warnings abort loading. Those incomplete diagnostic logs are preserved and
not relabeled passing. No warning suppression or harness assertion removal.
Fresh native gems for each exact measured binary; fixed seed12345, normal GC,
jobs2,600seconds and2GiB per-file family. Large AS JSON encoding158 cases run in three
alternating pairs per engine; sample ranges and medians remain explicit.
The runtime code/corpus commit is pinned independently from this publication record. No
local absolute path is published. Source/default/explicit record hygiene are required before
push.
Full-framework integration measurements use additional reviewed/unmerged prerequisites and
are separate from these targeted per-fix comparisons. A targeted pass does not turn an
incomplete whole-file observation into a pass.

Corpus --both1036/1036; VM1036/0fallback/0differences. Source and strbuf gates pass.
Explicit changed-file record hygiene runs at publication.

evaluator before prerequisite-held target: {'MATCH': 85, 'RED': 17, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}

evaluator after prerequisite-held target: {'MATCH': 102, 'RED': 0, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}

evaluator standalone-PR RSS KiB: {'samples_kib': {'before': [1479664, 1543104, 1510912],
'after': [1505312, 1468464, 1407536]}, 'medians_kib': {'before': 1510912, 'after': 1468464},
'change_percent': -2.8094290071162265, 'qualification': 'Three alternating fixed-seed12345
pairs, normal GC; report sample ranges, no stable improvement claim.'}

vm before prerequisite-held target: {'MATCH': 85, 'RED': 17, 'MISSING': 0, 'UNCONFIRMED': 0,
'BOTH': 0, 'EXTRA': 0}

vm after prerequisite-held target: {'MATCH': 102, 'RED': 0, 'MISSING': 0, 'UNCONFIRMED': 0,
'BOTH': 0, 'EXTRA': 0}

vm standalone-PR RSS KiB: {'samples_kib': {'before': [1266352, 1220496, 1262880], 'after':
[1293296, 1251712, 1282624]}, 'medians_kib': {'before': 1262880, 'after': 1282624},
'change_percent': 1.5634106170024031, 'qualification': 'Three alternating fixed-seed12345
pairs, normal GC; report sample ranges, no stable improvement claim.'}

All raw core states, previous passing identities, native-source receipts, net instruction
samples and targeted/RSS results are retained in railstest/framework/records/actionmailer-
array-index-overrides.json.

Exact-head automated review and owner acceptance remain required.

The targeted prerequisites395/399/402/405 have since merged. These records keep their
original exact source pins; they are not retroactively relabeled current-main measurements.

Current-main373 introduces read_path_whole/read_path_at StrBuf region findings,
independently confirmed by the reviewers of395 and405. The unchanged IO helpers are tracked
with that stream at https://github.com/284km/mere-ruby/pull/373#issuecomment-7239786026. The
measured8ed-based sources here do not include373.

The initial20000-iteration read medians had substantial startup-subtraction variation. The
additional100000-iteration three-pair control improves on every pair: evaluator
median-1.35percent and VM-1.25percent versus main8ed. Both original and higher-iteration raw
samples are retained.

The36-case complete index selection retains the same two baseline failures,
TestArray#test_range_with_len_max_end and TestArraySubclass#test_range_with_len_max_end, on
both Mere binaries and engines. It is not an all-pass file. Whole-file and isolated
permutation memory bounds remain explicit.
