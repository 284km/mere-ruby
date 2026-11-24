# Rails R2, ActiveSupport round 3

The REDs left in the `68588737` records that come from this flow's own
shapes, plus the VM's nokogiri stop. Witness:
`corpus/935_activesupport_round_two_shapes.rb` (section 7 holds the review's
cases), which matches ruby on the evaluator and on the VM.

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

## Review (no Critical or Major; Minor 1 and 2 fixed here)

- **P2 (review bot): a Struct copy lost the members' initializer.** `dup`
  copied `struct_mem` and `struct_gen` but not `struct_initializers`, and
  `struct_initialize_members` looks the initializer up on the class that
  `struct_members_cls` picks, which is the copy. An `#initialize` that calls
  super stopped, whether it was written in the original (`K = Struct.new(:x)
  { def initialize(x) = super(x + 1) }; K.dup.new(1)`) or in the copy after
  the dup. The copy now gets the entry too. A Struct with the generated
  initializer only worked because its body is copied directly.

- **Minor 1: the superclass mismatch named the class the alias resolves to**
  (`D = C; class D < String` said "class C"). Both registration paths now
  name the class as written, without its scope. This also fixes two older
  differences from ruby: a nested class said "class N::A" (ruby: "class A"),
  and an anonymous class held by a constant said "class AnonClass_1"
  (ruby: "class X").
- **Minor 2: Range's super into Enumerable built the range with `to_a`,
  called by name.** A Range#to_a that calls super recursed into
  SystemStackError, and `(1..).first(2)` through super was a RangeError.
  The super now walks an Enumerator over the range's `#each`. Without a
  block, the methods that answer an Enumerator answer one on the range
  itself (`#<Enumerator: 1..3:map>`).
  The walk met an older bug (main has it): an Enumerator over a range that
  starts with an Integer took the fast path for Integer ranges (`gen1_src`),
  whose `gen1_take` makes elements only when both ends are Integers.
  `(1..).each.first(2)` and `(1..Float::INFINITY).each.first(2)` were `[]`.
  The fast path now takes only Integer..Integer, and the others walk.
- **Re-review Minor: from a module prepended to Range, super on a range
  without an end never stopped** (`(1..).count`, and min, max, minmax,
  to_a, entries). Main raised NoMethodError and the first head RangeError. Given no
  block, on an endless or beginless range, these answer with Range's own
  method (Infinity, the value, or its RangeError), as ruby does. Witness: the
  end of corpus/935 section 7. The arm cannot tell where the super came from,
  so a super from a method defined in Range itself answers the same way. Ruby
  walks forever there (Enumerable's), so this stops where ruby does not.
- Left, as on main (the review allows recording these):
  - `super` from a module PREPENDED to Range should reach Range's own method
    (`(1.5..3.5).min` is 1.5 there). It reaches Enumerable's, as from a
    method in Range itself. Range's arms take no one-call bypass (#181
    removed it: a bypass was spent by an arm that did not take the call), so
    this needs its own design.
  - After a Symbol builtin is redefined, an alias of it reads only its first
    argument (outside the new branch's condition).
  - From main: `(1..).each_slice(2).first(1)` and `(1..).each_entry.first(2)`
    raise "cannot convert endless range to an array" (ruby answers).
  - From main (re-review): `(1.0..).each.first(2)` and `(..3).each.first(2)`
    raise RangeError where ruby raises TypeError; endless `each_cons` and
    `each_with_index` raise RangeError too; on the evaluator only, a nested
    anonymous class gets no superclass mismatch; with Range#first
    overridden, `zip` does not read a Range argument right.
  - From main: a Struct's error messages show the internal name
    (`Struct_1`), and `puts` does not use a user-defined `#to_ary`.
