# The embedded Psych's literals frozen, as Psych's own files have them (note 559 §10)

After #342, what a `YAML.load` of activerecord's citations fixture holds is mostly the String store: 23 KB a row, about 1.5 GB at the fixture's 65,536 rows.
The parser made about 590 Strings a row and kept about 6. A String's slot is never reused; a dead one stays as an empty stub, and a page of 4,096 goes back only when none of its Strings lives -- and the survivors are on every page.

## Where the Strings came from

`MERE_RUBY_STORE_STATS=1`'s `str_slots`, 2,048 rows: the events alone (`Psych::Parser.new(Psych::Handler.new).parse`) made 1,120,000 of the load's 1,143,000. The scanner reads a byte at a time and compares it with literals -- `c == "\n"`, `c == ' '`, `c == "\t"` -- and each literal was a new String each time it was evaluated.

Psych's own files each begin with `# frozen_string_literal: true`. `tools/gen_psych_lib.rb` joins them, with mere-ruby's parser, emitter and native protocols, into the one source the binary embeds, and took the comment off each (d9753f6d): in the middle of a file a magic comment is a comment.
So the whole of the embedded Psych ran with literals that are not frozen.

## The change

- `tools/gen_psych_lib.rb` puts `# frozen_string_literal: true` at the top of the joined source. Each of Psych's files means what it means upstream again; the three of mere-ruby's are read with it too.
- What mutates a String in the joined source (`<<`, `force_encoding`, `replace`, `concat`, `insert`, `clear` and the bang methods), checked by grep on `ruby tools/gen_psych_lib.rb --ruby`: every one is on a `+''` buffer, a `.dup`, a slice or a join, or an Array. No literal.
- An empty scalar's value was the literal `''` in three places of `lib/psych_parser.rb` (an empty node with a tag or an anchor, and a block scalar of empty lines). It is `+''`: libyaml's is not frozen, and a program may append to it.
- Corpus 1069: the values a load returns -- empty, quoted, block, folded, stripped, tagged, an empty tagged one, an anchor and its alias -- are not frozen and take `<<`; a dump of a String subclass and back.

## Checked

Both binaries built with the Mere CI uses (9dec2ff6); the base is main 6a488680 (with #342).

`YAML.load` of the fixture's rows, with `MERE_RUBY_GC_TIGHT=1` (a collection by the allocations alone, so the counts are the same run to run), the CPU time of the process (a test run beside it):

| rows | Strings made, main | this | the String store, main | this | peak RSS, main | this | CPU, main | this |
|---|---|---|---|---|---|---|---|---|
| 8,192 | 4,837,204 | 970,475 | 179 MB | 36 MB | 463 MB | 301 MB | 28.5 s | 27.8 s |
| 16,384 | 9,654,250 | 1,920,897 | 358 MB | 70 MB | 553 MB | 397 MB | 62.0 s | 56.8 s |
| 32,768 | 19,288,311 | 3,821,650 | 715 MB | 141 MB | 1,086 MB | 586 MB | 401 s | 230 s |
| 65,536 | | 7,623,258 | | 279 MB | | 965 MB | | 3,593 s |

The times under `MERE_RUBY_GC_TIGHT=1` grow faster than the rows: it collects every so many allocations, and each collection walks a live set that grows with the rows. Without it, the collector waits longer as more is live:

| rows, the default collector | peak RSS, main | this | CPU, main | this |
|---|---|---|---|---|
| 32,768 | 1,262 MB | 774 MB | 108 s | 105 s |
| 65,536 (the fixture) | 2,066 MB | 1,112 MB | 238 s | 229 s |

At the fixture's size the load alone was past the 2 GiB limit on main; with this it is 1.1 GB. The time is the pure-Ruby parser's (about 3.5 ms a row; ruby's libyaml takes 0.2 s for 16,384 rows), which this does not change.

eager_test itself (`run.py run --jobs 1 --side mere`): still MEMORY_LIMIT, at 2.13 GB after 428 s (round 5: 197 s). The first 197 tests and the load together are past the limit, and the load's 230 s would leave the file near its 600 s as well. Those are the next steps.

test/psych (`unittest/run.sh`, 635 tests): MATCH 635 on main, and with this on the evaluator and on the VM; no FrozenError in any log. `test_yamldbm.rb` is ZERO on both sides, as before.

## The corpus

On main 6a488680, with `MERE_RUBY_SHAPES_CHECK=1`: 988/988 on the evaluator and on the VM, the hash index on and off (1069 among them).
