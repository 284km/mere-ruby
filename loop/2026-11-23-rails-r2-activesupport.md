# Rails R2, activesupport: shapes that stopped whole test files, and super into a value's builtin

Rails plan R2, first round. ActiveSupport's 170 test files were measured with
`railstest/framework/` on main `2cae9413`, and again after #172 and after each
change here. Every fault below was reproduced without Rails first. Witness:
`corpus/933_activesupport_core_ext_shapes.rb`.

**Files that stopped part-way** (all 170 now run to the end):
- **A block written at `fork` lost the method's block.** Kernel#fork handed
  its block to Process.fork as written, without capturing the enclosing
  method's block (`blk_capture`), which every other block at a call site
  does. `ActiveSupport::Testing::Isolation#run_in_isolation` yields to its
  test from `fork do ... yield ... end`, so autoload_test,
  json_gem_encoding_test and json_cherry_pick_test died with "no block given".
- **`super` into Object#respond_to_missing? from a value.** super_missing
  answered it (false) only for objects. A value's branch, the one for a
  primitive subclass, has no such method. array_inquirer_test and
  string_inquirer_test redefine it on Array and String as `super`.
- **Endless ranges and the questions that stop at their answer.** An integer
  range with an open end walked `each`, `step`, `first` and `map` itself and
  turned everything else into the endless array first. `any?`, `all?`,
  `none?`, `find`, `detect` and `find_index` with a block now walk and stop
  (`range_seek`). ActiveSupport's `many?` is `any? { (cnt += 1) > 1 }`, and
  `(0..Float::INFINITY).many?` reached the 2-GiB bound in enumerable_test.

**RED**
- **`super` from a String/Hash/Array subclass into the builtin.**
  `ActiveSupport::SafeBuffer` wraps String's unsafe methods and calls super:
  `gsub!` / `sub!` / `gsub` / `sub` (prim_method has none of them) now go to
  the leaf builtin (`dispatch_prim`). With a block, the call goes through the
  dispatcher past the Ruby body once (`bi_skip`). An operator (`*`) goes to the
  value's operator (`eval_bin_prim`). `HashWithIndifferentAccess#default(key)`
  calls super, and `Hash#default(key)` now runs the default proc with the hash
  and the key.
  Other names stay with prim_method. An earlier try sent every name to
  `dispatch_prim`, and that turned `String.prepend M` with `M#upcase = super`
  into a loop, because dispatch_prim asks String's own Ruby definitions.
- **A Ruby `include?` / `member?` / `cover?` on Range was never called.**
  Range's own arms answered first. ActiveSupport prepends `CompareWithRange`
  (`include?(range)` is `cover?`). `range_native_wanted` lets the program's
  definition win. A `super` from it reaches Range's arm past the Ruby body
  once.
- **Kernel#=== asked by name of a plain object** (`obj.__send__(:===, x)`,
  minitest's `assert_operator`) was "undefined method '==='". Only `case` and
  the operator had it.

**Left for others**
- Time.new saved by `Time.singleton_class.alias_method` and then replaced
  (TimeHelpers' stub_object): 5 RED in time_travel_test. This is the path #178
  changes. The owner decided it is fixed there.

## The review's round, and the next ActiveSupport shapes

The review of `8bf5563b` found three regressions in the first round, all in
shapes ActiveSupport's tests do not take. Witness: `corpus/934_review_shapes_of_r2.rb`.
- **A module prepended to String, whose `#gsub` / `#sub` call super, looped.**
  `dispatch_prim` asks String's own Ruby definitions and came back to the
  module. The gsub family goes there now only for a subclass's value (a
  tagged value without a singleton class). A plain String keeps prim_method,
  as on main.
- **A module prepended to Range, whose `#cover?` calls super, looped.**
  `range_native_wanted` spent the one-call bypass in an arm that checked its
  argument afterwards and did not take the call. The `super` now calls Range's
  own answers directly: `rng_include` for `include?` / `member?`,
  `__cover_range` for a Range argument, and `rng_covers_w` otherwise. No
  bypass is set.
- **A Hash subclass with its own `#each` answered `select` / `reject`
  through super as an Array.** The block path through the dispatcher is now
  for a String's value only. A Hash or an Array keeps the iterator path.

Minor findings, also fixed here:
- A frozen String subclass refused nothing in `gsub!` / `sub!` through super.
  It now raises FrozenError, naming the subclass.
- Kernel#=== by name now requires Kernel among the ancestors and no undef.
- `Object#respond_to_missing?` through a value's super takes exactly two
  arguments, as ruby's does.
- `--mere-env` is checked before the output directory is made.

Left as a follow-up: an endless range whose answer lies past int64's
maximum. `range_seek` stops there with the RangeError the array form gave,
because the bignum walk is not here. ruby goes on and answers.

The next RED, each reproduced without Rails:
- **A protected method called on a value of the class** from another of its
  methods (SafeBuffer#* calls `mark_unsafe!` on the buffer it made) was
  refused for every value `self`. `protected_ok` now asks the value's class,
  its singleton class first.
- **`super` into String#initialize** copied the bytes and not the encoding,
  and ignored `encoding:`. `SafeBuffer.new` (`def initialize(_str = "") =
  super`) was BINARY, and its `#unicode_normalize` refused it.
- **`method_missing` on a String or an Array subclass** was never asked. Only
  a Hash subclass's was. ActiveSupport::StringInquirer answers
  `env.production?` from it.
- **`HashWithIndifferentAccess#transform_keys(mapping)` calls super**, which
  had no answer for a mapping. The arm's body is now
  `hash_transform_keys_map`, shared with the dispatcher. With a block, the
  call keeps the iterator path.
- **`gsub` / `sub` with a Hash replacement** looked each match up as a new
  UTF-8 string. A BINARY receiver's match is a BINARY key, and ActiveSupport's
  JSON escaping maps `"\u2028".b` that way: the separators came out empty.
  The match and the result now carry the receiver's encoding
  (`rx_gsub_hash`'s new `enc`). Left: `Regexp.union` of a BINARY non-ASCII
  string prints its pattern as characters with `/n`, where ruby keeps the
  `\x` escapes. The match itself is right.

## The review's second round

- **Major 1 was half fixed.** A String *subclass's* value still went to
  `dispatch_prim`, and a module prepended to String came back from there.
  Now no `super` from a value's String method goes through `dispatch_prim`.
  `gsub` / `sub` are prim_method's answer, as on main. `gsub!` / `sub!` are
  prim_method's plain `gsub` / `sub` written back with `replace` (nil when
  nothing changed), after the frozen check.
- **The U+2028 fix did not reach the dispatcher's gsub.** `rx_gsub_hash` is
  prim_method's path. The dispatcher's gsub (a String or a Regexp pattern with
  a Hash) built each match as UTF-8 too. Both use the receiver's encoding now.
  The witness had checked only `>`, because the U+2028 in it had become six
  characters of text on the way into the file. corpus 934 now packs the bytes.
- **`transform_keys!(mapping)` through super wrote to a frozen Hash
  subclass** (the review bot's P2). The new entry called the mapping helper
  directly, and its bang branch wrote without the frozen check that Hash's own
  path makes. It refuses first now. The plain form still answers from a frozen
  receiver. The other bang entries this PR adds (`gsub!` / `sub!`) check
  first. A String's block call goes through the dispatcher, which checks.

## The review's third round

- The new `gsub!` / `sub!` path through super answered nil where ruby does
  not. It now returns self when a match wrote the same text, an Enumerator
  for `gsub!(pattern)`, ArgumentError for `sub!(pattern)` and for no
  arguments, and TypeError for a pattern that is neither a String nor a
  Regexp, in ruby's words for each.
- Merged with #188 (`run --env`): `--env`, `--mere-env` and the install-binary
  check all stay, and check.py passes 21 controls.

Follow-up (the same on main): many other bang methods called through super
from a frozen subclass write instead of raising FrozenError. Examples are
Hash's compact! / clear / store / delete / shift, Array's compact! / flatten!
/ reverse! / concat / pop, and String's reverse! / replace / concat / << /
insert / slice! / succ! / clear. The entries this PR adds (gsub!, sub!,
transform_keys!) refuse.
