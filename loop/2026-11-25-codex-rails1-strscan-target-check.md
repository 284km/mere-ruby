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
