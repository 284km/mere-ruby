# A String's, an Array's and a Hash's variables in the shape and the slab (note 559, step 2b')

Step 2b put an object's instance variables in a shape and one slab. A String's, an Array's and a Hash's stayed in the table under `"str:<id>@<name>"` and the like, and had no name index.
Once any of them had been given one (`hiv_made`), every `-str`, `dup`, `clone` and `$/ =` of any String, Array or Hash walked the whole table to find its own.

bc measured it under activerecord: `-("c"+"ol")` 0.317 ms (ruby 0.0007), `"abc".dup` 0.398 ms, `{}.dup` 0.476 ms. sqlite3's C asks `-@` of each column's name, which was about 36% of an `execute`.

## The owner key

- The door works by an **owner key**: the id times 8 and the kind, as the collector's live set spells it. 0 an object, 1 a String, 2 an Array, 3 a Hash.
- `obj_iv` is keyed by it, so the sweep asks the live set about the key itself.
- `iv_k_get_or` / `iv_k_set` / `iv_k_has` / `iv_k_del` take it. `iv_get` and the rest are an object's, by its id (`oid * 8`). `hiv_ok v` is a String's, an Array's or a Hash's key, or -1 for any other value.
- A too complex owner's keys in the table are `iv_tkey ok name`: `"<id>@"` for an object, `"str:<id>@"` and the like for the others, as before.
- The shape's variation count and the area size hint read the owner's class: an object's from `obj_cls`, the others' `String`, `Array`, `Hash`.

## What changed for them

- Self's `@x` in a String's, an Array's or a Hash's method (`ivs_has` / `ivs_get_or` / `ivs_set`), and `instance_variable_get` / `set` / `defined?` / `remove_instance_variable` / `instance_variables`, go through the door.
- `dup` and `clone` of a String, an Array, a Hash, and the Hash copy `ruby2_keywords_hash` makes: `iv_k_copy_all`, the area whole.
- `-str` and `$/ =` ask `iv_k_has_any`. `-str` made a Map at every call besides the walk.
- The walk of the table, with `hiv_made` before it, is left to an owner in the table.
- The collector: a String, an Array or a Hash marked for the first time with a record in `obj_iv` puts its key, negated, on `gc_obj_pend`; the drain walks its area. The sweep gives a dead one's area back.

## They were never given back

On main, a String's variables outlived it: 20,000 Strings each given an `@a` and dropped left 20,117 keys in the table and every value they held. `tools/loop_rss_check.rb` has a case for it, "a String's variables": 150,000 Strings, Arrays and Hashes each given one. Main ends at 2.16 times its starting RSS (FAIL at 1.6), this at 1.00.

A String's slot is never handed out again (a dead page is freed and the count only grows), so a new String does not read a dead one's variables today. Corpus 1066 checks it all the same: 3,000 Strings with one, dropped and collected, then 3,000 new ones with none.

## pack's pointers, behind the door

A `P` or `p` pack keeps the Strings it points at on the packed String, under `__pk_assoc`, as ruby keeps them alive.
It was written to the table by hand (`pack_assoc_key`, `"str:<h>@__pk_assoc"`) and read back the same way. It goes through `iv_k_set` / `iv_k_get_or` / `iv_k_has` with the packed String's owner key now, so it lives in the String's area and dies with it.
Corpus 1066 has a case: a `P` and a `p` pack, a `GC.start`, then unpacking them, the packed String's `instance_variables` (none shown: the name is the interpreter's) and a `dup`'s unpack.

## The collector's cost

The mark of a String, an Array or a Hash asks whether it has an area. Asking `obj_iv` (every object's record) cost 1.2% of a loop of `GC.start` on the VM.
`iv_hng` holds the owner keys of the Strings, Arrays and Hashes that have a record: kept by `iv_rec_put` (every write of a record), dropped at the sweep, compacted with `obj_iv`. The mark asks it only when it is not empty.
What is left is a check a String, an Array or a Hash marked (a `map_len`, and a lookup in a small Map when some have a record): +0.5% on the evaluator, +1.0% on the VM, in the loop below.

## The door check

`tools/iv_door_check.sh` (2b) looked for an object's key built by hand. It looks for a String's, an Array's and a Hash's too: `"str:"`, `"arr:"`, `"hsh:"` followed by an id and `"@`, and a name joined to `"@"`. `ivar_self_key`'s three arms are allowed (they build a too complex owner's key, as `iv_tkey` does).
⚠ It reads the spelling only. A key whose id is an expression, or whose `"@"` is added later, passes unseen. Keys are built by `iv_key` / `iv_tkey`, in the door (#322's review).

## The VM's inline cache (#332)

Step 2c (#332) came to main while this was in review. Its write, when the cache moves an object to the child shape that adds the name, set the object's record by hand: `map_set obj_iv oid`.
With the owner key that is some other owner's key: the object kept its old shape, and objects made after it read wrong values. It goes through `iv_rec_put (oid * 8)` now, and `tools/iv_door_check.sh` fails on any `map_set obj_iv` outside m_state.
Corpus 1067 is the case: 100 objects that set `@z` after `@x` and `@y` through a cache filled by the first, beside a String and an Array with variables. With the bare id, on the VM, 50 objects' `x` summed to 40349 (1275 in ruby) and `@z` went unlisted.

## Checked

Both binaries built with the Mere CI uses (9dec2ff6); the base is main 89ad241c (2b).

A script that loads activerecord's test helper and `models/post` (sqlite3), each line the time a call, the second of two runs (the first gave the same within a few percent):

| | main 89ad241c | this |
|---|---|---|
| `-("c"+"ol")` | 0.0335 ms | 0.0045 ms |
| `"abc".dup` | 0.0475 ms | 0.0127 ms |
| `{}.dup` | 0.0432 ms | 0.0105 ms |
| `[].dup` | 0.0466 ms | 0.0092 ms |
| `$/ = "\n"` | 0.1225 ms | 0.0793 ms |
| `raw_connection.execute` (5 rows) | 0.107 ms | 0.081 ms |
| `connection.select_value` | 6.159 ms | 5.722 ms |
| `Post.first` | 11.60 ms | 10.65 ms |

After the rebase onto main 018c0564 (#332 in it), the process's CPU time a call, the least of 5 rounds, main and this in turn, two runs:

| | main 018c0564 | this |
|---|---|---|
| `-("c"+"ol")` | 0.0309 / 0.0294 ms | 0.0027 / 0.0028 ms |
| `"abc".dup` / `{}.dup` / `[].dup` | 0.037-0.040 ms | 0.0086-0.0107 ms |
| `"abc".clone` / `{}.clone` / `[].clone` | 0.037-0.041 ms | 0.0086-0.0098 ms |
| `$/ = "\n"` | 0.1060 / 0.1049 ms | 0.0678 / 0.0698 ms |
| `raw_connection.execute` (5 rows) | 0.0840 / 0.0793 ms | 0.0761 / 0.0845 ms |
| `connection.select_value` | 4.72 / 5.00 ms | 4.09 / 4.21 ms |
| `Post.first` | 8.74 / 8.78 ms | 8.56 / 7.90 ms |

The wall clock with corpora running beside it once put `raw_connection.execute` at 0.14 ms against 0.09-0.12; the CPU time shows the two even.

Instructions retired, the median of 3 runs taken in turn, `MERE_RUBY_GC_TIGHT=1` (2b's loops, objects only):

| loop | evaluator | VM |
|---|---|---|
| 300 `dup` and `clone` among 20,000 objects | -0.0% | +0.0% |
| so_object | +0.1% | +0.1% |
| `s += @x` | -0.5% | -0.6% |
| `@x = i` | -0.4% | -0.7% |
| `s += a.x` (attr_accessor) | -0.6% | -0.7% |
| control | ±0 | ±0 |
| 30 `GC.start` over 100,000 objects of 4 variables | +0.5% | +1.0% |

`tools/loop_rss_check.rb`'s "a String's variables": main 2.16 (FAIL), this 1.00. `tools/shape_class_tables_check.rb`: 3 and 32 keys.

## The corpus

973 files, on main 89ad241c (before #332; on main 018c0564 below):
- `MERE_RUBY_SHAPES_CHECK=1`, the evaluator and the VM, the hash index on and off: 973/973, no write around the door.
- `MERE_RUBY_SHAPES=0` and `MERE_RUBY_SHAPES_MAX=8`: 973/973.
- `MERE_RUBY_GC_STRESS=50`: 7 wrong on the evaluator, 8 on the VM, each as on main.
  - 526 prints the same wrong line as on main.
  - 214, 512, 524, 656, 659, 676 and 988 run past 600 s on main as well (512 takes 695 s on main, and its output is ruby's).
  - 917 counted 118 of its 120 connections once: each worker stops after 3 s. Alone, 3 runs gave 120 each here and 120, 115, 120 on main.

After the rebase onto main 018c0564, 980 files with `MERE_RUBY_SHAPES_CHECK=1`, the evaluator and the VM, the hash index on and off: 980/980, no write around the door (1066 and 1067 among them).
