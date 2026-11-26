# An object's variables in a shape and one slab (note 559, step 2b)

Steps 1 and 2a (#295, #299) put every reader and writer of an object's instance variable behind one door (`iv_get` / `iv_get_or` / `iv_set` / `iv_has` / `iv_del` and the rest, in m_state).
This changes what the door does. An object's variables are no longer keys `"<id>@<name>"` of the one table of every object's variables; they are values in one slab, in an area of the object's own, and the names are in a **shape** that objects share.

## What is kept, and where

- **The shape** is a node of one tree, as in ruby: the names in the order they were first set.
  - Adding `@b` to an object of shape `[@a]` moves it to the child `[@a, @b]`, made once and shared by every object (of any class) that takes the same path.
  - A shape is 4 ints in `sh_tree`: its parent, its last name's number, its slot count, its children.
  - `sh_next` holds the transitions. `sh_slot` remembers which slot a name has in a shape, and "not there" too, so `@memo ||=` does not walk the shape each time.
- **The values** are in `iv_slab`, one `Vec[Val]`. An object's area is `[base, base + cap)`, cap a power of 2. `obj_iv` holds one int an object: the area's base and size class, and the shape. An object with no variables has no entry.
- **The area's size** is what the object's class has come to need (`sh_cls_cap`, ruby's max_iv_count). Without it, an object whose `initialize` sets five variables moved from an area of 1 to 2, 4 and 8, copying its values into the slab's arena at each move. A loop of objects made and dropped peaked 6% higher than main for it.
- **Free lists**: an area given back (a dead object's, at the collector's sweep, or one an object outgrew) is emptied and put on its size's free list; the next area of that size reuses it. The free list is threaded through the areas themselves: an empty area's first slot holds the next one.
- **What never shrinks**: the slab's length is its high-water mark (the free lists reuse it; nothing returns it). The shape tree, the name numbers (`iv_nm`) and the remembered slots are never given back either. That is what the bounds below are for.

## Removing a variable

`remove_instance_variable` leaves a mark in the slot (`iv_absent`, a Proc with handle -1, which no Ruby value is) and the shape as it was. Every reader asks `iv_slot_read`, which reads the mark as "not there"; the listing and the collector's marking skip it.

Setting the name again:
- An internal name (`__f_unget`, `~m_dk`, a MatchData group, a Struct member's slot: `iv_name_hidden`) is written into its old slot. Its place is never shown, and Files remove and set some of them on every read.
- A name the program sees goes last, as in ruby. The object moves to the shape of its other names in order, then that one (`iv_readd`).

dup and clone copy the area whole, marks included.

## Objects in the table ("too complex")

An object goes to the table, for good, when it would need a new shape and:
- the tree has `MERE_RUBY_SHAPES_MAX` shapes (2^18 by default), or
- its class has made 8 variations already (a new child beside another child of the same parent: ruby's SHAPE_MAX_VARIATIONS, df's point: a single global bound would make performance depend on which class happened to fill it first), or
- the shape would have 4,096 names.

Its variables move to the table in their order, with its name index (`iv_idx`), and `obj_iv` holds -1 for it. The door's table path is step 2a's, unchanged. `MERE_RUBY_SHAPES=0` sends every object there: main before this change, and a way to bisect.

## The collector

- Marking: when an object is marked, `gc_mark_area` walks its area's slots with its shape's names beside them (a `~m_` name holds a class's name, as `gc_internal_ivar` reads off a key). The walk of the whole table and its per-owner chains are left to the table's keys: other owners (`cls:`, `str:` and the rest) and objects in the table.
- Sweeping: `obj_iv` is walked; a dead object's area goes to its free list, after its File's descriptor is found by name (`__f_fd`, and `__f_keep_fd`). `flush_files_at_exit` finds `__f_buf` the same way.
- The slab is compacted where the table is (`vec_compact`, beside `map_compact`): a value written over leaves its old copy in the arena, as a Map's does.
- **Pressure**: the collector collected when the table's entries passed a mark. A shaped object's variables are no entries, so a loop of objects made and dropped collected 41 times instead of 197 and peaked higher. `iv_entries` counts the shaped objects' slots with the table's entries; the cadence is main's again.

## Writers that went around the door

Steps 1 and 2a missed these. With shapes, what they wrote went where the door no longer looks (a MatchData's groups were written to the table and read through the door; a `dup` came back with no variables, which is how they were found):
- a MatchData's groups (`md_write_groups`, `md_sig`);
- a Method's and an UnboundMethod's definition marks (`msnap_*`, `~m_dk`, `~m_era`);
- an Enumerator::ArithmeticSequence's bounds, an Enumerator's inspect, a lazy's;
- a Thread's interrupt mask, ThreadGroup, pending interrupt;
- the copy in `dup` and `clone` (keys of the copy were made and written to the table);
- C's read of an ivar during a dmark (`MR_IVAR_READ`);
- the singleton-class lookup (`class << @x`) and a call's receiver read from an `@ivar` by name.

`MERE_RUBY_SHAPES_CHECK=1` prints any object key written to the table for an object that is not in it. Under it the corpus prints none.

## Also

- The sweep's comment said deleting allocates nothing; what is dead is gathered in Vecs first. A duplicated comment line is gone (both from the review of #299).
- Since #299 the sweep and the flush at exit match a File's names exactly, so a dead object's variable named like `@x@__f_fd` no longer closes a live File's descriptor.
- Two bugs main has, left as they are: `instance_variable_set("@a@b", 1)` is accepted (ruby raises NameError), and a Thread's fiber-locals (`Thread#[]`) and its thread variables (`thread_variable_get`) share one listing.

## Checked

Both binaries built with the Mere CI uses (9dec2ff6); the base is main f13ccfc8. Instructions retired, the median of 3 runs taken in turn, `MERE_RUBY_GC_TIGHT=1`:

| loop | evaluator | VM |
|---|---|---|
| `s += @x`, 300,000 times | -3.5% | -5.5% |
| `@x = i` | -5.0% | -7.6% |
| `s += a.x` (attr_accessor) | -2.8% | -4.9% |
| control (no instance variable) | -0.2% | -0.1% |
| 30 `GC.start` over 100,000 objects of 4 variables | -68.5% | -67.5% |
| 300 `dup` and `clone` among 20,000 objects | -10.1% | -12.2% |
| so_object (ruby's benchmark) | -11.3% | -10.4% |
| `Prism.parse` of a 5,571-line file, 4 times | -10% | |
| the Rails application's boot (`bin/rails runner`, warm) | -7.0% | -6.7% |

The boot's peak RSS (`MERE_RUBY_GC_TIGHT=1`, the median of 3) is the same: 656 MB and 665 MB on the evaluator, 736 MB and 731 MB on the VM. Little of a boot is objects' variables.

RSS of a live object (40,000 kept, after `GC.start`, the median of 3):

| object | main | this |
|---|---|---|
| no variables | 120 B | 120 B |
| 1 variable | 514 B | 238 B |
| 4 variables | 1,005 B | 372 B |
| 10 variables | 1,378 B | 632 B |

Objects made and dropped (300,000 a batch, two classes of 2 and 5 variables, a seventh given one more; `MERE_RUBY_GC_TIGHT=1`):

| | main | this |
|---|---|---|
| peak RSS, 1 batch | 114.5 MB | 91.3 MB |
| peak RSS, 4 batches | 120.1 MB | 94.2 MB |
| collections, 4 batches | 197 | 197 |
| slab slots after 1 / 4 batches | | 42,287 / 42,293 |

The slab does not grow from one batch to the next: the areas are reused.

The fixture of activerecord's eager_test (16,384 rows of `YAML.load`): peak RSS 1,099 MB on main, 997 MB with this; 94.3 s and 73.6 s. Most of that peak is the parser's short-lived Strings and Arrays (note 559 §4.1), not objects' variables.

## The corpus

On this branch (main 751362a3 under it), with `MERE_RUBY_SHAPES_CHECK=1`: 969/969 on the evaluator and on the VM, the hash index on and off, and no write around the door.

On the base f13ccfc8, 957 files:
- `MERE_RUBY_SHAPES_MAX=8` (most objects go to the table): 957/957.
- `MERE_RUBY_SHAPES=0`: 957/957. The first run had 17 Prism, Ripper and ISeq files wrong: a node the loader put in the table had no -1 in `obj_iv`, and its variables read as none. Fixed in `iv_new_obj`.
- `MERE_RUBY_GC_STRESS=50`: 5 wrong on the evaluator, 6 on the VM. Each fails on main the same way: 526 prints the same wrong line, and 214, 524, 656, 659, 676 and 988 run past 600 s on main as well.
