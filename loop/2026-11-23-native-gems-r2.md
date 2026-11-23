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
  and whose dump adds `"struct"`. capi/check typeddata covers it: 113
  contracts on both sides.
- **test_step_does_not_allocate_when_done: fixed.**
  `GC.stat(:total_allocated_objects)` taken twice around a `Statement#step`
  that allocates nothing read 2. That was three kinds of allocation the
  interpreter made for itself:
  - GC.stat built its whole Hash to answer one key;
  - each method frame's `__args` Array, kept for a bare `super`;
  - the Strings a flow signal makes, two per `return` through the
    interpreter's flow.
  GC.stat now answers a key without the Hash. The other two are made by
  arr_new_internal / mkstr_internal, which count themselves in str_n's
  second slot, and GC.__allocated_so_far leaves that slot out. corpus 906.
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
  - What is left: sqlite3's comparators and aggregators are held the same
    way, by the conservative scan of the interrupted method's stack and open
    regions. With MERE_RUBY_GC_DBG=4 (that scan left out) all four pass.
    That is not a precise hold to drop: it is what the scan reads (Mere's
    coro_scan_ints reads the open region blocks as well as the stack). It
    would need the scan, or what the C call path leaves in open regions, to
    change. A top-level `x = Plain.new; x = nil` and `Plain.new.tap {}`
    still keep 1 the same way.
  - No corpus program for the top-level fix: under MERE_RUBY_VM=1 the VM
    runs the file and its frames keep the values (1, 1, 3, 4 where ruby says
    0), so a corpus program would fail the VM corpus. Recorded for the VM.
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

## The dmark refusal names its request

work2026-fd's review of #178: the refusal of a dmark's request between C
calls said "(a method call, a write)" even for RHASH_SIZE, which is a read.
It now names the method a call names, for example: "a dmark called Hash#size
with no C call in progress (RHASH_SIZE and rb_hash_foreach are such
calls)". For any other request it names the operation. Checked with a
throwaway extension whose dmark reads RHASH_SIZE.

## Checks

- capi_check: every contract agrees on both sides and holds under stress
  (ensure 58, typeddata 113, loader 48 on ruby / 49 on mere-ruby, numeric 13,
  fiber 16, api 245),
  and every negative control fails as it must.
- corpus 906 matches on the evaluator, under MERE_RUBY_VM=1 and with
  MERE_RUBY_NO_HASH_INDEX=1.
- 157 corpus programs that use GC / ObjectSpace / top-level return /
  at_exit / BEGIN, run one at a time: all match.
- `--eval-print` still prints the last value.
