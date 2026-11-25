# Rails-2 round 3, part 2: a key with its own #hash is one key wherever a table is built

**Where this comes from.** Rails-2 round 3 (activerecord, sqlite3 adapter, 427 files, main 30de57d4 with #225, ruby 4.0.10): MATCH 8,943, RED 133, MISSING 84. The RED by cause are in the third part of this series. This part is the #hash / #eql? protocol: 15 RED.

## group_by, to_h, Hash[] and tally (13)

ActiveRecord's preloader runs

```ruby
loaders.grep_v(ThroughAssociation).group_by(&:loader_query).each_pair do |query, similar_loaders|
  query.load_records_in_batch(similar_loaders)
end
```

A LoaderQuery defines #hash and #eql? so that one query asked for by several associations is sent once. `h[k] = v` and a hash literal already asked a key for its own #hash.
`group_by`, `to_h` (with and without a block), `Hash[]` and `tally` built their tables by structure, where two objects are two keys. Each loader was a group of its own, and 13 tests of associations_test counted one SELECT too many.

- **`arr_group_by`** looks a key up and stores it with `hash_lookup_w` / `hash_put_w` when it carries the protocol (an Array or Hash key holding such an object too), and records the stored codes (`hstored_seed`).
- **`hash_rekey_w`** enters a table built from pairs again through `[]=` when a key carries the protocol, as a hash literal does. `Array#to_h`, the block form, and `Hash[]` use it.
- **`tally`** with such elements counts into a new Hash through `tally_into`, which looks the key up by its #hash (it looked it up by structure, so every count was 1).

Two more places were on the way to the same answer:

- **`Array#hash`** asks a Hash element that holds such a key or value, as `Hash#hash` itself does. A LoaderQuery's hash is `[association_key_name, scope.table_name, ..., scope.values_for_queries].hash`, and the last is a Hash of where clauses.
- **`Array#eql?`** asks elements that define #eql? and no #==. It answered the structural false without asking them, so an Array of such keys was never found as a Hash key.

Corpus 1051.

## Array#- asks no #hash of a small array (2)

When either array has 16 elements or fewer, ruby's `rb_ary_diff` looks each element up with `rb_eql` alone: the same object, or the element's own #eql?. When both are longer it builds a hash table and #hash is asked.

`where(id: 1).or(where(id: 9223372036854775808))` computes `predicates - other.predicates`. The bind's #hash serializes its value and raises ActiveModel::RangeError for an Integer out of range.
Its #eql? compares the plain values first and answers false. #hash was asked, and finder_test and relation/or_test each had one test raise.

`val_subtract_w` takes the small-array path (`val_member_eql_small`) when either list has 16 elements or fewer. `&`, `|` and `intersect?` have the same kind of rule in ruby and still ask #hash here.

Corpus 978: both sizes, on both sides of the 16, with a #hash that raises.

## The test files

Each file alone, in round 3's tree, starting from an empty `debug.log`:

| file | round 3 | this change | ruby |
|---|---|---|---|
| associations_test | 136 runs, 13 failures | 136 runs, 0 failures | 136 runs, 0 failures |
| finder_test | 278 runs, 1 error | 278 runs, 0 errors | 278 runs, 0 errors |
| relation/or_test | 26 runs, 1 error | 26 runs, 0 errors | 26 runs, 0 errors |

Max RSS on this build: 1,281 MB, 1,149 MB and 705 MB, one run each; main 66a7afd0 gave 1,262 MB and 1,164 MB for the first two. One run says little: with the seed fixed, attribute_methods_test's max RSS ranged from 828 to 1,642 MB between runs.
With `MERE_RUBY_GC_TIGHT=1`, which collects by bytes allocated alone, round 3's binary and main give 880 MB and 865 MB for it.

**Checked.**

- Corpus 978 and 1051 differ from ruby on main, evaluator and VM alike, and match here both ways.
- `run_corpus.sh --both`: 879/879. `MERE_RUBY_VM=1 run_corpus.sh --both`: 879/879.
- The source gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth. `tools/loop_rss_check.sh`. `mspec/record_hygiene.sh`.
