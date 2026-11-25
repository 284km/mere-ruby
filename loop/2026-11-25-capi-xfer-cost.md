# C API: what crossing to C costs -- a String's bytes, the safepoint, and three calls that were sends

C reads a String's bytes through RSTRING_PTR, and in r3's measurements
(loop/2026-11-24-native-gems-r3.md, MiniSSL) each crossing cost the bytes
made (`bytes_of_str`, a copy in the request's region), copied into the
transit buffer (`mr_capi_give`), copied into the mirror's buffer and hashed,
and hashed again when the call ended. The C API's safepoint (#267) cost a
round trip into the interpreter and a copy of the transit at every String
fetched, call and new String, whether a collection was due or not. And
sqlite3's step spent a third of its time in three sends: `rb_obj_freeze` of
each value and the row, `rb_ary_store` of each column, and
`rb_default_internal_encoding`, which called `Encoding.default_internal`.

## What changed

- **A String's bytes go straight into its struct.** MR_STR_GET's answer is
  the interpreter's own String: `mr_capi_give_str` (m_capi_api.mere) passes
  its bytes and length, and C copies them into the mirror while the request
  runs (capi/core.c `mr_give_next` / `give_to`, capi/mirror.c `str_take`).
  The copy compares, copies where the bytes differ and hashes in one pass
  (`copy_hash`). `bytes_of_str`'s copy and the transit buffer's are gone.
  Where the bytes go is set for that one request alone: a collection at the
  safepoint before it, whose dmark may read Strings too, does not see it.
- **The hash takes four lanes past 32 bytes** (`hash_long`): one lane was a
  chain of dependent multiplies. Under 32 bytes it is the one lane, inlined
  where `write_back` uses it, as before.
- **The safepoint is counted in C.** The interpreter answers MR_SAFEPOINT with
  how many to pass over before it is asked again -- 31, a statement
  boundary's one in 32, or `16 * N - 1` under `MERE_RUBY_GC_STRESS=N` -- and
  at the ones it is asked it decides as before (pressure, or a collection
  under stress). `gc_tick`'s third slot, which counted the stress ones in the
  interpreter, is gone.
- **Only what is live in transit is set aside.** A write-back or a safepoint
  in the middle of a request's preparation saved the words, the bytes and
  the name in transit -- also what an earlier request had put there and
  read: `join_in_c` copied its 64 KB String's bytes at every safepoint after
  it. `mr_up` now marks the transit read once a request is answered, and
  `mr_transit_save` copies only what was put since.
- **rb_obj_freeze, rb_ary_store and rb_enc_default_internal make no call**,
  as CRuby's do not. `rb_obj_freeze` of a String, an Array or a Hash sets the
  flag (MR_FREEZE, 34); `rb_ary_store` at the end of an Array that is not
  frozen appends (MR_ARY_APPEND, 35). Anything else -- another kind of
  object, an index inside or before the Array, a frozen Array -- is sent as
  before, so the errors are ruby's own. `MERE_RUBY_CAPI_WITHOUT=builtin`
  still sends, so its negative control still fails. `rb_enc_default_internal`
  reads a variable `Encoding.default_internal=` writes
  (`capi_global_note "default_internal"`, slot 7 of `mr_capi_set_global`),
  filled at boot like `$stdout`'s.

## GC safety, as contracts (capi/check/api.rb)

- `lent_across_collections`: C takes RSTRING_PTR of a String (one past any
  slot, 100 KB, and one in the slot), makes 400 64 KB Strings and calls a
  method 400 times, with `rb_gc` every 100 turns; then the pointer is the
  one RSTRING_PTR answers again, the bytes under it are unchanged, a byte
  written through it reaches the interpreter, and a String and an Array C
  made and held only in its locals are still those values. On the reference
  as on mere-ruby, and under `MERE_RUBY_GC_STRESS=1` (a collection every
  16th request as well).
- `store`, `row`, `default_internal`: rb_ary_store at the end, past it,
  inside, from the end, too far from the end (IndexError's message), on a
  frozen Array (FrozenError's), on a subclass whose `#[]=` is not called;
  rb_obj_freeze of an Array, a Hash and a String; a row built as sqlite3's
  step builds one, and what C reads of it; rb_default_internal_encoding
  after `Encoding.default_internal=` and after clearing it.

api contracts: 320 -> 334 on the branch (374 once main with #278 is merged), the
same on both sides and under stress.

## Measured

Base: main 5276535f; new: this branch; both built with mere 9dec2ff6, -O2.
Each row is the median of 3 runs, base and new alternately, with
`/usr/bin/time -l` (instructions retired of the whole process). Load average
10 to 18 throughout, from other sessions. The gems are sqlite3 2.10.2
(`--enable-system-libraries`) and puma 8.1.2 (with MiniSSL) installed with
each side's `gem install`; the scripts are in the PR description.

| | base | new | |
|---|---|---|---|
| MiniSSL write_nonblock loop, 8 MiB | 25.78 G | 22.33 G | -13% |
| ...of which in write_nonblock (s) | 1.86 | 0.52 | -72% |
| sqlite3 `execute("select 1")` x 5000 | 9.12 G | 8.73 G | -4% |
| sqlite3 prepared `reset!; step` x 30000 | 9.42 G | 7.97 G | -15% |
| sqlite3, require and open only | 3.64 G | 3.63 G | |
| `join_in_c(3000)`, GC.disable | 2.18 G | 1.88 G | -14% (0.28 s -> 0.14 s) |
| `hold_locals(20000)`, GC.disable | 28.38 G | 30.60 G | +8% (1.75 s -> 1.66 s) |
| capi/check api.rb, GC_STRESS=1 | 242.1 G | 243.8 G | +0.7% |
| typeddata.rb, GC_STRESS=1 | 33.30 G | 33.37 G | |
| ensure.rb, GC_STRESS=1 | 34.33 G | 34.29 G | |
| fiber.rb, GC_STRESS=1 | 5.48 G | 5.49 G | |
| numeric.rb, GC_STRESS=1 | 2.52 G | 2.52 G | |

Per operation, subtracting the open-only run: execute 1.10 -> 1.02 M
instructions, step 0.193 -> 0.145 M. Ruby 4.0.10 on the same scripts:
execute 0.0033 ms, step 0.0002 ms, the 8 MiB MiniSSL loop 0.02 s.

Max RSS with `MERE_RUBY_GC_TIGHT=1` (median of 3; the scripts' data are
fixed -- `Random.new(42)`, the same statements):

| | base | new |
|---|---|---|
| MiniSSL loop, 8 MiB | 569.9 MB | 552.5 MB |
| sqlite3 execute x 5000 | 130.5 MB | 135.1 MB |
| sqlite3 step x 30000 | 125.8 MB | 125.7 MB |
| 5000 rows built by C (`A.row(5)`) | 87.0 MB | 86.2 MB |
| capi/check api.rb | 178.7 / 179.2 / 206.4 MB | 192.6 / 208.8 / 192.8 MB |

api.rb's peak moves from run to run on either build even with GC_TIGHT (it
starts threads); cut at line 702 it is the same on both (94.2 MB), and its
three collection-heavy contracts run alone are the same within 0.5 MB
(join_in_c 130.8 / 130.4, hold_locals 72.1 / 72.1, the lent contract
157.3 / 157.0).

## Checked

On 2a1327d9 (this branch with main 779c7cc9, #278, merged), mere 9dec2ff6,
reference ruby 4.0.10:

- `run_corpus.sh --both`: the gates, then 939/939 with the hash index on
  and off; `MERE_RUBY_VM=1 run_corpus.sh --both`: 939/939, the same.
- capi_check: the contracts agree on both sides (api 374), hold under
  collection stress, and each negative control fails.
- capi_spec_check: the reference passes what is recorded and mere-ruby no
  less (2420 of 2602); capi_mkmf_check passes.
- capi_gem_check (with #281's `--build-jobs 1`): seventeen gems install and
  behave the same on both sides (173 lines); the other-ruby control fails.
- After #278: a freeze from Ruby is seen by C reading again -- MR_FREEZE is
  not a read-only request, so it advances the epoch, and rb_obj_freeze
  forgets the mirror's header after it either way.

## Left

- **The MiniSSL loop is still quadratic**, and most of what is left is not
  the C API: of 16 MiB's 7.9 s, 3.8 s is `byteslice` copying the tail it
  answers (ruby's shares it) and the C side is the one copy-and-hash of the
  String fetched and the hash when the call ends. A tail that shares its
  source's bytes is the fix, in the interpreter's String.
- **Every crossing hashes every String the C call has touched.** A C call
  that reads many Strings (hold_locals reads 20,000) checks each of them at
  every later request, which is quadratic -- the same on main. hold_locals
  takes 8% more instructions than main here and 5% less time. What it would
  take: knowing which structs C can have written since the last crossing
  (a page protection, or a pointer handed out only once).
- **sqlite3's execute is mostly Ruby**: the C API is about a quarter of
  `execute("select 1")` (sample, base: 24% of the samples under
  mr_capi_enter, 12% in C's calls back into Ruby methods); the rest is the
  gem's Ruby code in the interpreter.
- **A data object's header is asked again at every call** (`rb_mere_basic`,
  MR_DESCRIBE, 9% of a step): TypedData_Get_Struct reads its flags, and the
  interpreter has run since the last call. Its type cannot change; its
  frozen flag and class can.
