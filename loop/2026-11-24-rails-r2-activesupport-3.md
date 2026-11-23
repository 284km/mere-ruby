# Rails R2, ActiveSupport round 3

The REDs left in the `68588737` records that come from this flow's own
shapes, plus the VM's nokogiri stop. Witness:
`corpus/935_activesupport_round_two_shapes.rb`, which matches ruby on the
evaluator and on the VM.

## What changed

- **A Ruby method whose name ends in `!` is not a builtin mutator.**
  ActiveSupport's `Object#try!` with a block on a frozen String raised
  "can't modify frozen String". `invoke_with_block0`'s frozen check now uses
  `builtin_mut_on_frozen`, the same check `builtin_iter` uses.
  (`try_test`, 2 RED)
- **A Struct class's `dup` is a Struct class.** `cls_copy` copies the
  member table and the marks Struct.new put on its methods. Before,
  `OtherWrapper = Wrapper.dup` made plain objects, and its `new(hash)` was
  read as Struct.new's class name. (`deep_mergeable_test`, 2 RED, evaluator)
- **A Range method that replaces Enumerable's reaches it through `super`.**
  ActiveSupport's `Range#sum` calls `super` with a block or with a
  non-Integer range. `super_missing` answers Enumerable's methods (sum, min,
  max, minmax, first, ...) over the range's elements, and `to_a` refuses a
  range that cannot be walked, in ruby's words. Only methods that answer a
  value go through here, not ones that answer the receiver.
  (`enumerable_test`'s range sums)
- **A Struct has no `#to_ary`.** Struct.new defined it, so a struct was
  destructured and flattened, and `Array.wrap(struct)` was the members.
  It is gone from the methods Struct.new writes, from Struct's generated
  names (`struct_gen`, `is_struct_gen_method`) and from the bound-method arm.
  (`array/wrap_test`'s `test_struct`)
- **A Symbol alias of a builtin takes all its arguments.** `alias
  ends_with? end_with?` on Symbol passed only the first one.
  `blt_alias_call` re-dispatches a Symbol receiver when there is no Ruby
  method of the name. (`symbol_ext_test`)
- **`module X` / `class X` on a constant that names another class or module
  reopens that one.** nokogiri's `html.rb` does `HTML = Nokogiri::HTML4;
  module HTML`. At the top level that raised "HTML is not a module" on both
  interpreters. Inside a module it raised on the VM, and the evaluator
  registered a second module under the alias (`N::HTML::Document` beside
  `N::HTML4`). Both paths of class registration now reopen the class or
  module the constant holds. The other kind is refused, as for any
  constant, with where the constant was set. The VM uses the same
  registration, so it needs no change of its own. (The two `xml_mini`
  nokogiri files, 40 MISSING on the VM.)
- **`iter_held` keys by number** (review suggestion on #195): its values live
  in `gc_iter_hold`, an Int-keyed root map, with a number drawn per walk. No
  key string is built.

## Results

All of `activesupport/test` with this build, run on the gem home of
`68588737` (`--other-install-binary`), compared with
`records/activesupport-68588737.json`:

| | MATCH | RED | MISSING |
|---|---|---|---|
| `68588737`, evaluator (record) | 4,546 | 34 | 159 |
| this build, evaluator | **4,711** | **27** | **1** |

`compare` exits 0: no MATCH is lost. Gained: `json/encoding_test` +158
(#195), `try` +2, `deep_mergeable` +2, `array/wrap` +1, `symbol_ext` +1 and
`enumerable` +1 (range sums). On the VM, the two `xml_mini` nokogiri files
that stopped now run 40 MATCH / 0 RED.

The 27 RED left: `hash_with_indifferent_access` 4, `deprecation` 4 and
`proxy_wrappers` 3, `time_ext` 4 (offsets around DST), `enumerable` 2 (array
sums, constant cache), `descendants_tracker` 2, and one each in
`numeric_ext`, `string_ext` and `inflector` (titleize), `time_with_zone`,
`gzip`, `logger`, `error_reporter` and `time_travel` (Time subclass).
`duplicable` has 1 MISSING.
