# Rails-2 round 3, part 3: what the 133 RED were, and the rest of the causes

**What round 3 measured.** activerecord, sqlite3 adapter, 427 files, main 30de57d4 with #225, against ruby 4.0.10. Round 2 was against 4.0.9: the reference moved between them (#208).

| | MATCH | RED | MISSING | BOTH | UNCF | EXTRA |
|---|---|---|---|---|---|---|
| round 2 (main 8c39dd51, ruby 4.0.9) | 7,717 | 1,008 | 399 | 240 | 36 | 124 |
| round 3 (main 30de57d4 + #225, ruby 4.0.10) | 8,943 | 133 | 84 | 240 | 0 | 124 |

mere-ruby states: 331 COMPLETE, 89 ZERO, 5 INCOMPLETE, 1 COUNT_MISMATCH, 1 MEMORY_LIMIT. No file reached the time limit. Four of the files that did not complete are the same on the reference side (three postgresql files, arel/attributes/attribute_test).
The other three are eager_test (MEMORY_LIMIT) and registration_test and reload_models_test (a forked child crashes in the sqlite3 extension: native).

Time and max RSS of round 3 are not to be compared with later rounds: an append-mode flush rewrote the whole file (#235), and `debug.log` had grown to 45 MB by the end of the round.

Round 2's causes are gone: calculations_test 135 RED to 1, batches_test 55 to 1, and nothing is left of the `File.binread`, `to_ary`, index SQL, autoload and migrator groups.

**RED by cause.**

| RED | cause | where |
|---|---|---|
| 37 | migration_test: a class defined again under a removed name kept the old class's methods | the remove_const PR |
| 23 | a local first assigned in a branch that is passed over, then assigned in a block | part 1 |
| 13 | preloads not grouped: `group_by` with keys that define #hash and #eql? | part 2 |
| 11 | a Fiber subclass calling `alive?` with no receiver | here |
| 9 | a forked child crashes (marshal data too short, an empty pipe, the child's exit status) | native |
| 8 | a `do` after `cmd [a], x` or `cmd -> { }, x` went to the last argument | part 1 |
| 8 | numericality_validation_test: `super` from a class's own #dup answered the class itself | the remove_const PR |
| 7 | attribute_methods_test: the owner of a method in a Module subclass instance (3), its name (1), the private-call message (3, fixed on main by #219) | here |
| 5 | `defined?(name)` in a class method called the instances' #respond_to_missing? | here |
| 2 | base_test: the name of a Module subclass instance | here |
| 2 | `Array#-` asked #hash of a small array | part 2 |
| 2 | yaml_column_test: content after the first document | here |
| 2 | a class under an object's singleton class (known) | open |
| 4 | one each: `Enumerator#first(n)` with a block (batches_test), a class method named `count` lost its block (calculations_test), `super` into Hash#delete on a frozen Hash (enum_test), the owner again (statement_cache_test) | here |

**MISSING.** 77 are Arel's: a nested `describe` got the name `#<Class:0x...>::as` (Array#join, below), which is also all 124 EXTRA. 5 are the two forked-child files. 2 are eager_test's last class, which loads a fixture of 65,536 rows.

## A class in a join is asked its #to_s (77 MISSING, 124 EXTRA)

`[cls, "desc"].join("::")` asks the class its #to_s, as it asks every other element. minitest's spec classes answer the name they were described with (#to_s and #name come from a module the base class extends), and a nested `describe` builds its name with that join.
The join wrote the class as `#<Class:0x...>`, so 77 of Arel's tests ran under names ruby does not give them. Corpus 976.

With the names right, one test that the mismatch hid is RED: `Nodes::UnaryOperation` "should handle BitwiseNot" in arel/visitors/to_sql_test. Not looked at yet.

## An instance of a Module subclass: its name, and the owner of its methods

ActiveRecord keeps each model's attribute methods in a GeneratedAttributeMethods, a Module subclass, set on the model with `const_set`.

- A constant names it through the module it backs (`const_store`), and it prints by that name: `mod_inst_name_s`, read by `inspect_w` and by the dispatch of #inspect / #to_s. `Post.ancestors.reject(&:name)` is empty.
- `Method#owner` and `UnboundMethod#owner` answer the instance, not the nameless Module behind it (`mod_inst_self`). ActiveRecord's `method_missing` walks `method.super_method while !method.owner.is_a?(GeneratedAttributeMethods)`.
  With a plain Module as the owner the walk ran off the end, and every attribute read after `undefine_attribute_methods` was a NoMethodError.

Corpus 976 and 1052.

## A Fiber subclass has Fiber's methods

`class ThreadlikeFiber < Fiber; def join; resume while alive?; end; end`: the bare `alive?` was a NameError and `respond_to?(:alive?)` false. The table of Fiber's methods was asked by the object's own class name. Corpus 977. `method_defined?` on the subclass is still false.

## `defined?` in a class asks the class's own #respond_to_missing?

With a class as self, `defined_self_rtm` looked the hook up on the class's instance side.
ActiveRecord::TestFixtures defines #respond_to_missing? for the test instances, and its class method `fixtures` reads `defined?(file_fixture_path)`: the instances' method was called on the class, and its `super` found nothing. Corpus 1050.

## Enumerator#first and #take stop at the count with a block too

A block given to them is not called. With one, the call went to the iterator path and ran the enumerator to its end: 12 queries for `enum.first(4) do |batch| ... end`. Corpus 1054. `en.each_slice(2).first(2)` still runs the source to its end.

## A class method named like a builtin keeps its block

`Account.count(:firm_id) { true }` is ActiveRecord's own `count`. `builtin_answers` asked the class's instance side, found nothing, and took the call for the builtin `count`, which drops a block when it has an argument ("given block not used"). A class is asked through its singleton class.
Corpus 1055.

## A builtin mutator refuses a frozen receiver when an alias or `super` reaches it

The frozen check is asked at the doors a call comes through by name, with the name that was called, and it is skipped for a name the class defines itself. So two ways in had no check:

- **An alias.** `alias_method :regular_writer, :[]=` (HashWithIndifferentAccess) wrote to a frozen Hash: `Book.statuses["bad_enum"] = 40` changed a frozen enum mapping. `blt_alias_call` refuses a frozen String, Array or Hash for a mutating source name.
- **`super` from the class's own method.** `def delete(key) = super(convert_key(key))` deleted from a frozen Hash: `Book.statuses.delete("published")`.
  `super_missing` refuses a frozen String, Array or Hash for a mutating name, with the exceptions the direct door has (Array#delete of an element that is not there, a bang method that answers an Enumerator without a block, an arity error first).

The message names the value's own class (`frz_cls`): "can't modify frozen H2". It was "frozen Hash" for a subclass instance at every door, the builtin names too. Corpus 1053.

## YAML.load answers the first document before what follows it

libyaml ends a document before it looks for the start of the next one.
The parser raised "did not find expected <document start>" before the end of the first document was announced, so `YAML.load('--- {}\n')` (single quotes: a backslash and an `n` follow the mapping) was a SyntaxError where ruby answers `{}`. `lib/psych_parser.rb`, regenerated into `m_psych_lib.mere`.
Corpus 1056.

The parser is still more lenient than libyaml elsewhere: `"--- 1\n2: 3"` loads as a mapping, where ruby says "mapping values are not allowed in this context".

## The test files

Each file alone, in round 3's tree, starting from an empty `debug.log`:

| file | round 3 | this change | ruby |
|---|---|---|---|
| connection_pool_test | 154 runs, 2 failures, 9 errors (RED 11, MISSING 0) | 154 runs, 0 failures, 0 errors | 154 runs, 0 failures, 0 errors |
| attribute_methods_test | 136 runs, 4 failures, 3 errors (RED 7, MISSING 0) | 136 runs, 0 failures, 0 errors | 136 runs, 0 failures, 0 errors |
| test_fixtures_test | 9 runs, 0 failures, 5 errors (RED 5, MISSING 0) | 9 runs, 0 failures, 0 errors | 9 runs, 0 failures, 0 errors |
| base_test | 196 runs, 2 failures, 1 errors (RED 3, MISSING 0) | 196 runs, 0 failures, 1 errors | 196 runs, 0 failures, 0 errors |
| coders/yaml_column_test | 23 runs, 2 failures, 0 errors (RED 2, MISSING 0) | 23 runs, 0 failures, 0 errors | 23 runs, 0 failures, 0 errors |
| batches_test | 116 runs, 1 failures, 0 errors (RED 1, MISSING 0) | 116 runs, 0 failures, 0 errors | 116 runs, 0 failures, 0 errors |
| calculations_test | 235 runs, 1 failures, 0 errors (RED 1, MISSING 0) | 235 runs, 0 failures, 0 errors | 235 runs, 0 failures, 0 errors |
| enum_test | 100 runs, 1 failures, 0 errors (RED 1, MISSING 0) | 100 runs, 0 failures, 0 errors | 100 runs, 0 failures, 0 errors |
| statement_cache_test | 13 runs, 0 failures, 1 errors (RED 1, MISSING 0) | 13 runs, 0 failures, 0 errors | 13 runs, 0 failures, 0 errors |
| arel/visitors/to_sql_test | 131 runs, 0 failures, 58 errors (RED 0, MISSING 50) | 131 runs, 0 failures, 58 errors | 131 runs, 0 failures, 57 errors |
| arel/select_manager_test | 113 runs, 0 failures, 21 errors (RED 0, MISSING 13) | 113 runs, 0 failures, 21 errors | 113 runs, 0 failures, 21 errors |
| arel/table_test | 25 runs, 0 failures, 2 errors (RED 0, MISSING 5) | 25 runs, 0 failures, 2 errors | 25 runs, 0 failures, 2 errors |
| arel/nodes/window_test | 6 runs, 0 failures, 0 errors (RED 0, MISSING 4) | 6 runs, 0 failures, 0 errors | 6 runs, 0 failures, 0 errors |
| arel/nodes/case_test | 6 runs, 0 failures, 3 errors (RED 0, MISSING 3) | 6 runs, 0 failures, 3 errors | 6 runs, 0 failures, 3 errors |
| arel/nodes/binary_test | 2 runs, 0 failures, 0 errors (RED 0, MISSING 2) | 2 runs, 0 failures, 0 errors | 2 runs, 0 failures, 0 errors |

The Arel files have the same counts before and after: what changed is the test names. Compared with ruby's by name, MISSING goes from 50, 13, 5, 4, 3 and 2 to 0 in the six files, and EXTRA from 124 to 0.
One test the wrong names had hidden is RED in to_sql_test (BitwiseNot). base_test's remaining error is the forked child (native).

numericality_validation_test is not in this table: its cause is `super` from a class's own #dup, in the PR with remove_const.

**Checked.**

- Corpus 976, 977, 1050 and 1052 to 1056 differ from ruby on main, evaluator and VM alike, and match here both ways.
- `run_corpus.sh --both`: 885/885. `MERE_RUBY_VM=1 run_corpus.sh --both`: 885/885.
- The source gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth. `tools/loop_rss_check.sh`. `mspec/record_hygiene.sh`.

**Left.**

- **The 37 of migration_test, and numericality_validation_test's 8.** A class defined again under a name `remove_const` removed reopens the old class, and `super` from a class's own #dup answers the class itself. The PR after this one.
- **eager_test.** 197 of 199 tests match. The last class loads a fixture of 65,536 rows and the file reaches 2 GiB there. The reference takes 324 MB for this file, against about 75 MB for an ordinary one.
- The forked-child crash in the sqlite3 extension (9 RED, 5 MISSING). Fixed by #237 (mkmf's libdir placeholder linked the extension to the system libsqlite3); to be confirmed in the next round with the mere side installed again.
- **`Array#-` with both sides over 16 elements** (from #240's review): ruby builds a hash table and asks the receiver's elements for #hash too, so `([b] + 20 others) - 20 others` raises when b's #hash does. Here the receiver's elements are not asked. As on main.
- **`super` into a block-taking bang method of an Array subclass.** `class A2 < Array; def map!(&b) = super; end` is NoMethodError "undefined method 'map!' for an instance of Array" on main, frozen or not (also `select!`). Found while writing corpus 1053; not changed here.
