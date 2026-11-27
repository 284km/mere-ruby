# Four tables that kept every string written to them (note 559 §10, activerecord's eager_test)

activerecord's eager_test stops at the 2 GiB limit in its last class, `EagerLoadingTooManyIdsTest`: the fixture `citations.yml` is 65,536 rows of ERB, and `YAML.load` of it grows with the rows.
At 16,384 rows (`MERE_RUBY_GC_TIGHT=1`) the load takes 66 s and RSS +745 MB; ruby takes 0.2 s and +31 MB. 65,536 rows would be about 3 GB.

## Where it was

`MERE_RUBY_STORE_STATS=1` and `MERE_REGION_STATS=1` after the load, at 8,192, 16,384 and 32,768 rows; each grows with the rows:

| | a row | at 16,384 rows |
|---|---|---|
| the String store (`str_store`) | 23 KB | 375 MB |
| the default region | 13 KB | 256 MB |
| the slab of objects' variables | 2.8 KB | 46 MB |

- The String store: the pure-Ruby parser makes about 590 Strings a row, of which about 6 live. A String's slot is never reused, a dead one stays as an empty stub, and a page of 4,096 is given back only when none of its Strings lives -- the survivors are on every page. That is the next change.
- The default region, by line (a build with `mere -c --region-sites`): global tables written with strings. A write leaves the old copy where the table's storage is, and these four had no arena of their own, so nothing ever gave the copies back.

## The four

| table | what is written | at 16,384 rows, before | after |
|---|---|---|---|
| `rxv_ls` (main) | the last regexp search's pattern, flags, cut, key, required bytes, start set, literal and lead: eight strings each time the pattern is not the last one's | 127.6 MB | 0 |
| `rx_cur` (m_state) | the cache key of the pattern being matched | 15.1 MB | 0 |
| `cut_e` (m_strutil) | the encoding a cut is made in, set and put back around a non-UTF-8 search | 9.1 MB | 0 |
| `uprop_enc` (m_unicode) | the encoding a property class is read in | 4.9 MB | 0 |

Each now has an arena of its own from birth (`vec_compact` / `map_compact` when it is made, as `iv_slab` and the tables marked "its own arena" do), and the collector compacts them beside `iv_slab`, after the mark, where the other arenas are compacted.
A compaction defers a pinned arena, so a search a collection interrupts -- a `gsub`'s block runs between its matches -- keeps what it read.
Corpus 1068 is that case: the block collects and searches with other patterns and a binary subject, and the outer `gsub` goes on; it matches ruby on both engines, with `MERE_RUBY_GC_STRESS=50` as well.

What is left in the default region is `Array#join`'s own: its `seen` table, its StrBuf and its two-slot Vec are made in whatever region the call is in, 1.8 KB a row here (29 MB at 16,384 rows). Its body calls a program's `to_s` and `to_str`, so a region of its own is not a small change; it is left.

`tools/loop_rss_check.rb` has a case, "alternating regexp searches": two patterns taking turns on a UTF-8 String and on its binary copy, 200,000 times. Main ends at 4.26 times its starting RSS (FAIL at 1.6), this at 1.13; ruby 1.00.

## Checked

Both binaries built with the Mere CI uses (9dec2ff6); the base is main 6d8a416d.

`YAML.load` of the fixture's rows, `MERE_RUBY_GC_TIGHT=1`. The default region's total is deterministic; the peak RSS was measured with a corpus running beside it:

| rows | default region, main | this | peak RSS, main | this |
|---|---|---|---|---|
| 8,192 | 151 MB | 69 MB | 474 MB | 379 MB |
| 16,384 | 256 MB | 92 MB | 753 MB | 678 MB |
| 32,768 | 481 MB | 155 MB | 1,312 MB | 1,209 MB |

Instructions retired, the median of 3 runs taken in turn, `MERE_RUBY_GC_TIGHT=1`:

| program | evaluator | VM |
|---|---|---|
| two patterns taking turns, 100,000 times | -2.65% | -2.60% |
| the same on a binary String | -2.53% | -2.64% |
| one pattern, `scan`, 2,000 times | -0.09% | -0.00% |
| `gsub` with a block, 5,000 times | +0.14% | +0.08% |
| corpus 326, 340, 363 (as test_regexp asks) | -0.17%, -0.80%, +0.25% | -0.38%, -0.24%, +0.26% |

## The corpus

On main 6d8a416d, with `MERE_RUBY_SHAPES_CHECK=1`: 985/985 on the evaluator and on the VM, the hash index on and off (1068 among them).
