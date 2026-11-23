# 2026-11-23: native gems' own suites, round 2 -- sqlite3's remaining differences

Round 1 (loop/2026-11-23-native-gems-r1.md) left sqlite3 2.10.2's suite at
the reference's failures plus seven, all tests the gem guards with
`RUBY_ENGINE == "ruby"`. That guard is no reason here: mere-ruby says it is
"ruby", and each of them is something a Ruby program can observe. Another
session starts Rails' activerecord on sqlite3 now, so sqlite3 comes first.

## sqlite3 2.10.2 (minitest), as run

Both sides as in round 1: installed with `-- --enable-system-libraries`,
minitest 6.0.0, every test file required in one process with `--seed 1`,
the seven `/longer_than_int_max/` tests excluded on both sides (below).

| | runs | assertions | failures | errors | skips |
|---|---|---|---|---|---|
| ruby 4.0.9 | 410 | 807 | 9 | 2 | 17 |
| mere-ruby, round 1 | 410 | 799 | 16 | 2 | 23 |
| mere-ruby, now | 410 | 799 | 13 | 2 | 23 |

The reference's 9 failures and 2 errors are the forking tests: macOS's
system libsqlite crashes in the forked child, on ruby too. They fail by the
same names on both sides. The differences, one by one:

- **test_typed_data_struct_name (Database, Statement): fixed.**
  `ObjectSpace.dump` of a C data object said `"type":"OBJECT"` and had no
  `"struct"`. mr_capi_data_name (m_capi_api.mere) answers what a handle is
  to C as a data object (none, an RData, or a typed data's
  wrap_struct_name). `ObjectSpace.__data_struct` carries it into the
  objspace prelude, whose `__type_of` now says :T_DATA (count_objects too)
  and whose dump adds `"struct"`. Deciding the type makes nothing
  (`ObjectSpace.__data_p`, a yes or no); only the dump's `"struct"` makes the
  name's String. (A first version had `__type_of` ask for the name: one
  `count_objects` with 100 sqlite3 Statements alive allocated 119 objects,
  15 without them -- #190 review.) capi/check typeddata covers both: the
  dump, and that one count_objects allocates no more with 100 more typed
  data objects alive; 115 contracts on both sides.
- **test_step_does_not_allocate_when_done: fixed.**
  `GC.stat(:total_allocated_objects)`, read twice around a
  `Statement#step` that allocates nothing, differed by 2. The interpreter
  was making objects for itself, and they are real objects:
  `ObjectSpace.each_object(String)` and `(Array)` found them too.
  - GC.stat built its whole Hash to answer one key. It now answers the key
    without the Hash.
  - Each method frame got an Array of its arguments, `__args`, which only
    Struct's generated initializer reads (a bare `super` reads
    `__params`). It is now built only for that body (`SReturn EStructInit`).
  - Each `return` / `break` / `next` / `throw` out of a block made two
    Strings: the flow signal's kind (`flow_sig "k"`) and its "unhandled"
    message (`prim_missing "i"`). Both are Symbols now (VSym), and their
    readers -- capi_capture / capi_resume, which carry the kind through C,
    among them -- read the Symbol's name. No String is made for a flow at
    all.
  So nothing is subtracted from the count: the objects are no longer made.
  Two earlier versions did something else and were dropped:
  - the first subtracted them from the count (mkstr_internal /
    arr_new_internal), which made the count disagree with the objects;
  - the second kept one frozen String per text in gc_hold (flow_str), which
    each_object(String) still found ("returnret", "mere-ruby: (unhandled
    return out of a block)", ...): objects the program never made (#190
    review).
  - corpus 906 shows the count and each_object agreeing around the same
    code. It runs String-, Array-making and calling code 1 and 10 times;
    the delta of GC.stat and of each_object(String) / each_object(Array)
    match each other and match ruby. Before, an instance or class method
    call with an argument added an Array.
  - corpus 907: 10 and 100 `return` / `break` / `throw` out of a block add
    no String, as on ruby. On main, 10 such calls added 31 Strings on the
    evaluator and 21 on the VM (work2026-fd's measurement). It also walks
    every String for the flows' own words, written as bytes so that the
    check makes no such String: 0, as on ruby.
  - Not changed, found on the way: counting with
    `ObjectSpace.each_object(Array).count` (an Enumerator) makes Arrays in
    proportion to the objects it walks; counting with a block does not.
    The corpus programs count with a block.
- **One GC.start leaving released objects (4 tests): partly found, not
  fixed.** test_replacing_a_collation_(by_another_case_)releases_the_previous_comparator
  and test_aggregate_instance(s)_are_released_* count with
  ObjectSpace.each_object after one GC.start. The aggregate ones pass when
  run alone and fail in the whole suite, so what the scan finds depends on
  what ran before.
  - What I found: the plain top-level case,
    `a = [Plain.new]; a = nil; GC.start`, and `Plain.new` written N times at
    the top level keeping N objects. That was a precise hold, now dropped:
    run_until_gc recursed once per statement, each frame holding its
    statement's value, and each value was copied out into the chunk's region
    DRV. MERE_RUBY_GC_DBG=4 showed the collection's conservative scan of the
    interrupted stack, and of its open regions, finding them.
    run_until_gc_n is a tail call now, and a statement's value is dropped
    inside its own region STMT unless --eval-print prints it. Three
    statements that kept 3 keep 0; 20 that kept 20 keep 0.
  - What is left: sqlite3's comparators and aggregators. The
    conservative scan of the interrupted stack, and of the regions open on
    it, holds them. With that scan left out (MERE_RUBY_GC_DBG=4), all four
    tests pass. Mere's coro_scan_ints reads the open region blocks as well
    as the stack, and some region still open while the test method runs
    keeps the object ids of the comparators and aggregators that went
    through C (`Database#collation`, `#define_aggregator`). I have not
    found which allocation, in which region, it is. A top-level
    `x = Plain.new; x = nil` and `Plain.new.tap {}` still keep 1 the same
    way.
  - **This hold is not bounded, and is a leak in practice.**
    - In a method, `SQLite3::Database.new` with 50 `define_aggregator`s,
      then `close`, done 5 times: after 2 and then 7 more `GC.start`s, all
      5 Databases and their 250 aggregators are still there. Ruby has 0.
    - Without the scan (MERE_RUBY_GC_DBG=4), 1 Database and 50 aggregators
      remain after the first GC.start, and 0 of each by the later ones.
    - With 3,000 `define_aggregator`s on one Database, closed and dropped:
      3,007 aggregators remain on mere-ruby, 1 on ruby.
    - So the objects are not released by a later collection. It is the
      scan, and it grows with what was made.
  - **Whether this affects activerecord:** activerecord's own sqlite3
    adapter (8.1.4.1, activerecord/lib/active_record/connection_adapters/
    sqlite3_adapter.rb and sqlite3/) registers none of what is held here.
    It never calls `collation`, `create_function` / `define_function`,
    `create_aggregate` / `define_aggregator`, `trace` or `authorizer`. The
    raw connection methods it calls are `prepare`, `execute_batch`,
    `changes`, `total_changes`, `encoding`, `busy_handler_timeout=`,
    `rollback`, `closed?`, and the pragma writers through `public_send`.
    Its tests use no comparator or aggregator either (`collation` there is
    `DatabaseTasks.collation`, another thing). So no activerecord test
    waits for one to be freed. But the scan holds closed Databases
    themselves (the first item above), so a process that opens and closes
    many connections keeps them: memory, not results.
  - No corpus program for the top-level fix: under MERE_RUBY_VM=1 the VM
    runs the file and its frames keep the values (1, 1, 3, 4 where ruby says
    0), so a corpus program would fail the VM corpus. Recorded for the VM.
  - **Owner:** the follow-up for this retention is d4's, in aidocs note
    553 §7.4, item 1 ("C 拡張と GC の境目で残っている物").
  - work2026-fd's repro: open a Database, register 20 collations, close it,
    351 times. The Databases left: 52-67 on #190's binary, 48-49 on main.
    RSS grows about 33-40 MB on both. With no collations, nothing grows.
    This is a problem from before this PR; the PR does not make it worse.
- **The 2 GiB tests (`/longer_than_int_max/`, 7): excluded on both sides,
  not runnable here.** They build `"\0" * 2**31`. CRuby gets that from
  calloc, so its pages are never touched. Here the String is 2 GiB in the
  interpreter and C's mirror copies it again. Together they exceed the CI
  limit of 2 GiB, and the limit stays. Running them needs a String store that
  allocates zero-filled pages lazily, and a mirror that answers RSTRING_LEN
  without fetching the bytes.
- **The 6 GC-compaction tests: skipped (GC.compact is not
  implemented).** The collector does not move objects, and
  `GC.respond_to?(:compact)` is false, as on a CRuby built without
  compaction. A GC.compact that did nothing would make these tests check
  nothing.

## What else allocates differently from ruby (measured, #190 review)

Each case run 10 times after 3 warm-ups, GC disabled. The figures are the
`GC.stat(:total_allocated_objects)` delta for the 10 calls, with
each_object(String / Array / Hash) agreeing.

| case | ruby 4.0.9 | mere-ruby before | mere-ruby now |
|---|---|---|---|
| `P.new(1, 2)` | 10 | 10 | 10 |
| `K.new(a: 1)` (keyword `initialize`) | 10 | 20 (+10 Hashes) | 20 |
| `S.new(1, 2)` (Struct) | 10 | 20 (+10 Arrays) | 20 |
| `KS.new(a: 1, b: 2)` (keyword_init Struct) | 20 | 210 (120 Strings, 60 Arrays, 20 Hashes) | 90 (0 Strings) |
| `kw(a: 1)` (explicit keywords) | 0 | 10 (Hashes) | 10 |
| `kwr(a: 1)` (`**o`) | 10 | 20 | 20 |
| `pos(1, 2)` | 0 | 0 | 0 |
| `raise E` + rescue | 20 | 100 (80 Strings) | 100 |
| `raise E, "m"` + rescue | 30 | 110 | 110 |

- Fixed: a keyword_init Struct's `#new`, `#[]`, `#[]=` and `#to_h` spelled
  each member's slot name in Ruby (`"@" + s + 1.chr`), 3 Strings a member.
  `::Struct.__mslot_get` / `__mslot_set` read and write the slot by name
  (struct_slot) with nothing made; the prelude's `__mslot` is gone.
  corpus 908.
- Follow-up, with these numbers:
  - A keyword call passes its keywords as a Hash: one Hash per call to a
    method with explicit keywords (ruby makes none) and a second for `**o`.
  - A Struct's `#initialize` takes `*__sa`, an Array per `new`.
  - keyword_init's `__struct_kw_init` is Ruby (`members`, `keys`,
    `reject`): 6 Arrays and 1 Hash more than ruby per `new`.
  - `raise` builds its backtrace eagerly: 4 Strings (one per frame here)
    and an Array per raise, where ruby builds them when they are read.
  These are real objects the program can find, made where ruby makes none;
  each is a change to how arguments or backtraces are carried, not one
  arm.

## The dmark refusal names its request

work2026-fd's review of #178: the refusal of a dmark's request between C
calls said "(a method call, a write)" even for RHASH_SIZE, which is a read.
It now names the method a call names, and the C function only where it is
that one: "a dmark called Hash#size (RHASH_SIZE) with no C call in
progress", "Hash#to_a (rb_hash_foreach)", and plain "String#upcase" for
another call. For any other request it names the operation, from a table
with designated initializers (`[MR_STR_GET] = "a String read"`, ...), so
it stays right when the enum changes. Checked with a throwaway extension
whose dmark reads RHASH_SIZE.

## GC.stat's keys are one list

The key form answered from a `case`, and the Hash form from a Hash literal
with the same keys (and an old Symbol branch that no longer ran). Both now
read gc_stat_entries (main.mere), one list of keys with how each value is
read: `GC.__stat_value(key)` makes nothing, `GC.__stat_keys` lists them for
the Hash form.

## Checks

After the #190 review fixes, with an O2 build, one after another (the gem
check alone, last):

- gates (dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names,
  bracket depth) and record_hygiene: pass.
- capi_check (ruby-4.0.9's source, as CI pins it): ensure 58, typeddata
  115, loader 48 on ruby / 49 on mere-ruby, numeric 13, fiber 16, api 245,
  on both sides and under stress; every negative control fails as it must.
- capi_spec_check: ruby 2,592, mere-ruby 2,410 -- "the reference passes
  what is recorded, and mere-ruby no less than is recorded" (io_spec and
  thread_spec hit WALL_LIMIT on mere-ruby, as recorded).
- capi_mkmf_check: mkmf contracts 14 on both sides and under stress;
  every control fails as it must.
- run_corpus.sh: 841/841 match ruby.
- tools/iseq/vm_corpus.sh: 841 programs, 837 on the VM and 4 on the
  evaluator, 0 FAIL.
- capi_gem_check (--gems as fetched): seventeen gems install and behave the
  same on both sides (173 lines).
- sqlite3's suite: ruby 410 runs, 807 assertions, 9 failures, 2 errors,
  17 skips; mere-ruby 410 runs, 799 assertions, 12 failures, 2 errors, 23
  skips. Beyond the reference's are three of the four release counts
  (which of the aggregate two fails depends on the order).
- corpus 906, 907 and 908 also match under MERE_RUBY_VM=1 and with
  MERE_RUBY_NO_HASH_INDEX=1.
