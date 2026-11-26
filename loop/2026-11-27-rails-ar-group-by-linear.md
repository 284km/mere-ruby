# Enumerable#group_by grows each group in place (eager_test's preload)

After #347, eager_test was still MEMORY_LIMIT. Run alone with `MERE_REGION_STATS=1`, one STMT arena had grown to 64 GB of capacity, with a peak footprint of 45 GB, while the RSS showed 2.9 GB.
A build that stopped the process when a region added a block of 512 MB or more (a hook in `__lang_region_alloc_aligned`, attached with lldb) stopped in `arr_group_by` → `arr_new` → `map_set arr_store`, in `test_preloading_too_many_ids`: ActiveRecord's preloader grouping the fixture's 65,536 citations.

## What group_by did

The groups were a `Val list` of key/value pairs, rebuilt by `hash_put` for each new key. A key seen before got `arr_new (list_append (deref id) [x])`, a new Array of its old list plus one, and every one of those lists was copied into arr_store's arena.
Both halves are n^2 in memory:

| `(1..n).group_by` | main | this |
|---|---|---|
| 8,192 elements, one key | 18 s, 7.8 GB | 0.14 s, 69 MB |
| 32,768 elements, 8,192 keys | | 0.23 s, 89 MB |
| 32,768 elements, 32,768 keys | 9.8 GB (with the old table) | 0.27 s, 128 MB |

(The last row's main figure is the first version of this change, which still had the old table and pushed in place.)

## The change

ruby's own loop (enum.c `group_by_i`): `h[k]`, then `h[k] = [x]` for a new key or a push onto the group that is there. The push is the append queue (`arr_push_many`); the arrays are this call's own until it returns, so nothing sees them change.

- Up to `hsmall_max` (16) plain keys -- Integer, Symbol, nil, true/false, a Float that is not NaN, a String -- the table is a list, made into the Hash once at the end. mkhash keeps a small hash of plain keys as its list alone, so this is the Hash it would have been.
- Past that, or at the first key that is not plain, the list becomes the Hash and the rest go through it: a plain key by the index (`hidx_get`), any other through `[]` and `[]=`, which ask its `#hash` and `#eql?`.
- A String key is stored as a frozen copy, as `[]=` stores one (it was the block's String itself, not frozen).
- `break v` in the block answers v, as partition's does (it was stored as a key and the loop went on).

The first version sent every key through `[]` and `[]=`: +75% instructions on 20,000 group_bys of 10 elements.
With a plain key by the index it was still +5% -- all of it from new keys: `hpush_new`, and the read after it folding the Hash's queue, cost 2.4 times the old list's work on 10 keys. The list for small tables is what removed that.

## Checked

Both binaries built with the Mere CI uses (9dec2ff6). Instructions retired, `MERE_RUBY_GC_TIGHT=1`, the median of 3, main b7d90d5c → this:

| | 1 key | 3 keys | 10 keys |
|---|---|---|---|
| 10 elements, 20,000 times | -11.5% | -3.3% | -4.7% |

| | 20 keys | 50 keys | 100 keys |
|---|---|---|---|
| 100 elements, 2,000 times | -13% | -17% | -36% |

Against ruby, on the evaluator, the VM and with `MERE_RUBY_NO_HASH_INDEX=1`:
String keys (frozen copies, an unfrozen key changed after), a Struct key with its own `#hash` / `#eql?`, `1`, `1.0` and `1r` as three keys, `0.0` and `-0.0`, nil and false, an Array key among Integer ones, a table that spills past 16 keys, `break`, and the Enumerator without a block.

eager_test with ar5 (`-v --seed`, the default collector), the whole file (minitest's `-e` does not exclude, so this is all 199):

| | time | max RSS | peak footprint |
|---|---|---|---|
| main b7d90d5c | 580 s | 4.60 GB | 46.6 GB |
| this | 446 s | 2.78 GB | 3.7 GB |

With this, the 197 tests of EagerAssociationTest take 54 s together. `run.py run --side both`: MATCH 196, MISSING 2 (EagerLoadingTooManyIdsTest), BOTH 1 (the did_you_mean message, failing on both sides); still MEMORY_LIMIT at 2.10 GB, after 261 s.
`test_preloading_too_many_ids` alone: 439 s, peak 1.52 GB. About 290 s and 1.0 GB of that is loading the citations fixture (65,536 rows of YAML through the pure-Ruby parser). The preload is the other 150 s, up to 1.5 GB. Those are the next steps.

## The corpus

On main 1f782f89, with `MERE_RUBY_SHAPES_CHECK=1`: 991/991 on the evaluator and on the VM, the hash index on and off (1070 among them).
