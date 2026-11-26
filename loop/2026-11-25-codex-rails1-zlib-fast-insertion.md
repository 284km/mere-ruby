# Fast deflate levels skip insertion inside long matches

The fast levels inserted every intermediate match position into the hash
chains, doing the work that zlib intentionally skips for speed. Compression
levels 1 and 9 therefore produced equal sizes on ActiveSupport's witness.
Runtime 5a090d8c applies zlib's fast-level max-insert thresholds of 4, 5 and
6 to levels 1, 2 and 3. Higher levels keep their existing insertion behavior.
The correction changes match selection rather than adding padding or a
special case for the Rails input. The source is m_zstream.mere; the pinned
mgz package and native zlib code are untouched.

Primary algorithm reference: zlib 1.2.12 configuration_table and
[deflate_fast](https://raw.githubusercontent.com/madler/zlib/v1.2.12/deflate.c).
That function skips the interior of long matches at the fast levels.

Corpus 950 covers compression-level selection, insertion-threshold shapes,
binary data, all five strategies, sync/full flush and gzip framing. It and
existing 547/76 match reference on evaluator and VM. An independent Python
zlib decoder verifies 105 candidate-produced streams per engine: seven
levels, five strategies and raw/zlib/gzip framing. No compressed-byte
identity between conforming encoders is assumed.

The selected Rails gzip level case changes from 0 MATCH / 1 RED to
1 MATCH / 0 RED on both engines; all five executions are COMPLETE with
three assertions. Selected-case peak RSS is 295,312 to 310,768 KiB on the
evaluator and 324,864 to 305,264 KiB on the VM. These single samples do not
replace the pending repeated fixed-seed full-file memory comparison.
The native gems explicitly reuse the install made by a9e68981; installing
and measuring binary digests are retained separately.

Base a2322f53, ordinary O2 compiler 9dec2ff6. Reference selected with
tools/ref_ruby.sh: clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extra gems, Prism 1.8.2.
No gems were installed into its own gem directory.

Full corpus passes 949/949 with both hash modes (664.671 seconds,
1,187,168 KiB family peak). VM corpus passes 949 VM, zero fallback and zero
differences (173.371 seconds, 1,282,800 KiB). Eight source gates, default
record hygiene and bracket depth 155/1024 pass. Selected CRuby deflate,
level and params cases pass four tests / nine assertions in all five modes.
The unmodified full CRuby zlib/test_zlib.rb passes 96 tests / 544 assertions
on the reference and both engines before and after, all COMPLETE with no
limits. Family peak RSS before/after is 1,427,920/1,214,416 KiB on the
evaluator and 1,209,360/1,375,200 KiB on the VM. These single full-core
samples are distinct from the separate three alternating fixed-seed Rails
Gzip/TimeWithZone RSS pairs. The owner released the full-file hold; checks
retain 600-second / 2-GiB bounds. Repeated RSS validation is appended below.

Portable evidence:
railstest/framework/records/activesupport-zlib-fast-insertion.json.


Final fixed-seed 12345 full Rails replay, three alternating pairs: 178 MATCH / 1 RED to
179 MATCH / 0 RED. All selected files COMPLETE; MISSING/BOTH/UNCONFIRMED/EXTRA zero.
Bounds remain 600 seconds / 2 GiB per family, jobs 2, MT_CPU=0. Native gems explicitly
reuse the owned install made by a9e68981; installing and measuring binary digests are
recorded separately.

Peak family RSS, KiB, three repetitions:

| File | main | candidate |
| --- | --- | --- |
| gzip_test.rb | 296032 / 368800 / 297744 | 283840 / 355824 / 278096 |
| time_with_zone_test.rb | 451344 / 459040 / 451040 | 471952 / 458064 / 449632 |

Samples vary; no stable memory improvement is claimed.
