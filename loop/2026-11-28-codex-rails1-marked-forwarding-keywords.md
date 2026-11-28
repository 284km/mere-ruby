# Action Mailer keywords protocol correction

Runtime `04e11f7091ffa20fe6772b5068f58b36105ffa92`; main baseline8edcf953; clean Ruby4.0.10
via tools/ref_ruby.sh, revisiona704b7cd95, Prism1.8.2, zero extra gems. Compiler9dec2ff6;
mgz661a01d8.

A ruby2_keywords-marked splat now retains keywordness when binding a forwarding (...)
method. The pending-splat/marked-Hash branch applies to forwarding parameters as well as
explicit keyword parameters. Ordinary positional marked hashes and non-marked splats retain
their separate behavior.
Corpus958 covers direct implicit-super, block-super and explicit-spread-super forwarding,
plus positional negative controls. The native allocation/frame-storage work in245 is
separate. A later marker rename there must retain the semantic forwarding check.
Initial test_keyword could not start on any side because its unchanged CRuby test extension
was absent. Those original INCOMPLETE logs remain; the supplement freshly builds
rb_call_super_kw and iter for clean reference, current main and candidate, without modifying
CAPI implementation. Any remaining native/upstream failure is retained separately.
Super50 cases pass all sides. Proc120 retains the same existing curry-proc error and
compaction skip on both Mere binaries and both engines. They are not reported as complete
all-pass files.
The targeted Mailer comparison holds every prerequisite identical on both sides, including
unmerged parser402, ActiveJob395 and class reflection399. Beforef2ab6b90 removes only the
final Array and keyword fixes from aftere3c16e54; both fixes are present in the after
integration. Per-file counts and all raw identities are retained. This is an integration
target comparison, not the standalone PR binary.
Standalone main+keyword runs were0MATCH25MISSING because parser402 is still unmerged and
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

evaluator before prerequisite-held target: {'MATCH': 22, 'RED': 3, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}

evaluator after prerequisite-held target: {'MATCH': 25, 'RED': 0, 'MISSING': 0,
'UNCONFIRMED': 0, 'BOTH': 0, 'EXTRA': 0}

evaluator standalone-PR RSS KiB: {'samples_kib': {'before': [1450224, 1507344, 1554272],
'after': [1604944, 1378368, 1504864]}, 'medians_kib': {'before': 1507344, 'after': 1504864},
'change_percent': -0.16452780519907728, 'qualification': 'Three alternating fixed-seed12345
pairs, normal GC; report sample ranges, no stable improvement claim.'}

vm before prerequisite-held target: {'MATCH': 22, 'RED': 3, 'MISSING': 0, 'UNCONFIRMED': 0,
'BOTH': 0, 'EXTRA': 0}

vm after prerequisite-held target: {'MATCH': 25, 'RED': 0, 'MISSING': 0, 'UNCONFIRMED': 0,
'BOTH': 0, 'EXTRA': 0}

vm standalone-PR RSS KiB: {'samples_kib': {'before': [1195904, 1228784, 1246880], 'after':
[1186240, 1230864, 1216000]}, 'medians_kib': {'before': 1228784, 'after': 1216000},
'change_percent': -1.0403781299235693, 'qualification': 'Three alternating fixed-seed12345
pairs, normal GC; report sample ranges, no stable improvement claim.'}

All raw core states, previous passing identities, native-source receipts, net instruction
samples and targeted/RSS results are retained in railstest/framework/records/actionmailer-
marked-keyword-forwarding.json.

Exact-head automated review and owner acceptance remain required.
