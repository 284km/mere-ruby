# StringScanner reads its subject without Ruby method dispatch

The two REDs in CRuby's strscan/test_stringscanner.rb undefine every method
on the subject string after constructing the scanner. __init_check sent nil?
to that string. After replacing that check, bytesize and byteslice exposed
the same underlying issue. The native extension reads String storage directly.

The Ruby implementation now tests nil identity and binds seven original
String operations for internal subject access. Subject singleton overrides
and undefinitions cannot replace them. The generated StringScanner body is
updated to match. Unrelated pending ISeq-generator output is excluded.
Corpus 940 checks both fixed_anchor modes, scanning, positions, rest/peek/
bytes, pre/post match, an overridden nil?, and uninitialized scanners.

Base main: 2e402b94. Runtime commit: 0c2084bf. O2 compiler:
9dec2ff687a08433247dbdb7729bc19c8522e538. Reference Ruby 4.0.10 revision:
a704b7cd95a42cc0cf5f307137bf3aac0285b915. Its audit has 84 default/bundled
specifications, zero extras and default Prism 1.8.2. No reference gem-directory
installation was performed.

Validation:

- Corpus --both: 882/882, hash index ON and OFF; 3,348.322 s,
  maximum family RSS 1,159,952 KiB, no resource event.
- Full VM corpus: 882 VM / 0 fallback / 0 differences; 1,486.096 s,
  maximum family RSS 1,103,744 KiB, no resource event.
- Nine source gates and record_hygiene pass (342 existing records).
- CRuby strscan/test_stringscanner.rb before: 149 tests, 1,042 assertions,
  147 MATCH / 2 RED on evaluator and VM. After: all 149 tests and 1,050
  assertions pass, zero failures/errors/skips, in both modes. No passing
  case is lost. Corpus 940 also matches the reference in both modes.
- Related Rails duration_test and erb_util_test: 93 MATCH / 0 RED before and
  after, all files COMPLETE, in each of three alternating fixed-seed replays.
  No missing/unconfirmed/both/extra cases. The existing order_differs=1
  diagnostic is unchanged; case identities and summaries are complete.

The Rails replays retain seed 12345, MT_CPU=0, jobs 2 and 600-second / 2-GiB
per-file-family bounds. They explicitly reuse native gems installed by
8624fb60, copied into this stream's own gem directory. Both measured binary
and installer digests are in the portable record; these are not fresh installs
by either strscan comparison binary.

Maximum family RSS, KiB, for the larger duration_test (80 tests):

| Repeat | main 2e402b94 | candidate |
| --- | ---: | ---: |
| 1 | 209,152 | 334,512 |
| 2 | 283,808 | 334,848 |
| 3 | 333,776 | 189,856 |

The spread is large and neither a memory improvement nor a stable increase
is established. erb_util_test also varies: main 180,976–208,176 KiB,
candidate 221,184–271,552 KiB. The core strscan replay after the change peaks
at 140,144 KiB evaluator and 42,064 KiB VM; complete results and earlier
comparison peaks are retained.

Portable validation: unittest/records/strscan-subject-storage.json.

## Review follow-up

Runtime 064b34d4 addresses the hot-path finding. Captured native String reader
UnboundMethod#bind_call skips temporary Method allocation for exact primitive
argument shapes. Other definitions, coercions, TracePoint and receiver kinds
keep the binding path. Original native readers still work when subject or
String methods change after initialization; corpus 940 checks these cases.
An initialization-time plainness cache could become stale after overrides.

Three alternating scan-loop instruction samples per state and engine:

| Engine | main | previous PR | revised PR | revised overhead vs main |
| --- | ---: | ---: | ---: | ---: |
| evaluator | 254,243,331,432 | 292,677,898,700 | 257,075,047,479 | +1.11% |
| VM | 252,887,473,795 | 292,656,796,899 | 256,983,329,011 | +1.62% |

The original 15.12% / 15.73% cost is reduced, with the residual reported.
Every sample produces 80,000 tokens. The portable record retains all 18
samples and binary digests.

Latest full corpus: 882/882 ON/OFF, 1,216.034 s, 1,189,088 KiB peak family
RSS. VM: 882 VM / 0 fallback / 0 differences, 420.983 s, 1,287,408 KiB.
Eight corpus-prefix source gates, default record_hygiene and generated-C
bracket gate pass (155 of 1024). Core strscan remains 149 tests / 1,050
assertions passing in both engines. Related method bind_call controls are
2 tests / 10 assertions and String-reader controls 14 / 134, all passing on
main and candidate in both engines. An initial missing-extension attempt is
retained as incomplete; the unchanged CRuby extension was built privately
and the checks rerun completely.

Three further alternating fixed-seed 12345 Rails duration / erb_util replays
remain 93 MATCH / 0 RED on main and candidate, all files COMPLETE, with the
same order diagnostic of 1 and no other categories. Bounds remain 600 s /
2 GiB and jobs 2. Gems are an owned copy installed by 8624fb60, explicitly
reused rather than freshly installed by the measured binaries.

Duration maximum family RSS, KiB, main: 343,328 / 346,976 / 342,992; revised:
344,576 / 340,816 / 341,152. erb_util ranges: 300,912-316,640 main and
291,712-323,360 revised. These overlap; no stable memory improvement is
claimed. Earlier wider variation above is preserved.

Portable review evidence: unittest/records/strscan-review.json.
