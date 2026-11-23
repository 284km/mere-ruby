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
