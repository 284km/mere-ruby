# Destination timezone offsets and inherited Time constructor overrides

Time arithmetic kept the source instant's cached UTC offset when the zone
object represented a timezone with a later DST transition. The candidate
marks a derived time for lazy offset refresh at its destination instant.
The first offset or zone query runs the existing timezone callback and
caches the result. Fixed offsets and UTC retain their existing path.
The metadata is a boolean on the Time object; no global roots or frame
retention are introduced. Corpus 946 checks DST and half-hour boundaries,
fractional offsets, rounding, copying, freezing and invalid callback results.

A second failure ignored Time.now stubs inherited by a Time subclass.
The native constructor dispatch now honors a live inherited Ruby method
for subclasses, with the existing private-call and native-skip rules.
Corpus 948 covers inherited methods across two levels, saved native Method
and aliases, private/send behavior, at/utc overrides and restoration.
The two Time changes share runtime 80d561f0 and one planned PR.

Base ecd65075, ordinary O2 compiler 9dec2ff6. Reference selected with
tools/ref_ruby.sh: clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, 84 default/bundled specifications,
no extras and Prism 1.8.2. No reference gem-directory install was performed.

The final combined binary passes corpus --both: 948/948 with hash index
ON and OFF, 691.591 seconds, maximum family RSS 1,182,368 KiB. VM corpus:
948 VM, zero fallback and zero differences, 170.061 seconds, maximum family
RSS 1,188,016 KiB. Eight source gates, default record hygiene and bracket
155/1024 pass. Exact binary/generated-C digests and UTC start/end times
are retained in the execution cohort. Earlier DST-only measurements are
separate and are not used as evidence for the combined constructor change.

Selected Rails cases, reference/main/candidate on both engines:

- Four TimeExt DST cases: 0 MATCH / 4 RED becomes 4 MATCH / 0 RED.
- One TimeTravel subclass case: 0 MATCH / 1 RED becomes 1 MATCH / 0 RED.

All five selected cases are COMPLETE. The CRuby Time selection covers
at, delegate, round and getlocal_utc_offset before and after; exact case
counts and summaries remain in the portable record. Native gems explicitly
reuse the owned 85-package install made by a9e68981; installing and measured
binary digests are separate. Rails seed is 12345, with unchanged 600-second
and 2-GiB process-family bounds.

The owner released the full-file hold. Whole test_time_tz passes all five
executions, COMPLETE with 155 tests / 928 assertions. Whole test_time is
COMPLETE on the reference (89 tests / 994 assertions); both comparison and
candidate, in both engines, retain the 600-second WALL_LIMIT at
TestTime#test_strftime_padding. These are isolated file replays at the
unchanged bound, not all-pass results. Repeated fixed-seed Rails RSS is complete and recorded below. Full
ActiveSupport completion is measured in a separate integration cohort.

Portable evidence:
railstest/framework/records/activesupport-time-zone-constructors.json.


Final fixed-seed 12345 full Rails replay, three alternating pairs: 193 MATCH / 5 RED to
198 MATCH / 0 RED. All selected files COMPLETE; MISSING/BOTH/UNCONFIRMED/EXTRA zero.
Bounds remain 600 seconds / 2 GiB per family, jobs 2, MT_CPU=0. Native gems explicitly
reuse the owned install made by a9e68981; installing and measuring binary digests are
recorded separately.

Peak family RSS, KiB, three repetitions:

| File | main | candidate |
| --- | --- | --- |
| time_ext_test.rb | 371776 / 370096 / 391552 | 369376 / 363584 / 360128 |
| time_travel_test.rb | 302768 / 302864 / 301856 | 361296 / 333744 / 302288 |

Samples vary; no stable memory improvement is claimed.
