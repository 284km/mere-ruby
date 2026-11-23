# Reaching a builtin past Ruby bodies: saved operators, Comparable after #<=>, super into IO/Time and into a builtin alias (Rails R1)

ActiveSupport's `core_ext/time/calculations.rb` saves `Time#<=>` and puts its
own in front of it:

    alias_method :compare_without_coercion, :<=>
    alias_method :<=>, :compare_with_coercion

Two integration tests of the Rails app in `railstest/` failed with
`unknown operator: <=>` here. Three separate faults stood behind that one
message, and each was reproduced without Rails first.

1. **A saved native operator went to `arith_bin`.** `blt_alias_call` sent every
   alias of a binary operator to `arith_bin`, which is the arithmetic of the
   primitive values only. A saved comparison (`<=>`, `==`, `<`, ...) on any
   receiver, and any saved operator of an object (`Time#<=>`, `Time#+`), failed:
   "unknown operator: <=>", or "Integer can't be coerced into Time" for `+`.
   Now `arith_bin` keeps only the arithmetic of a value. An object is asked
   again under the source name. If the program defines that name, its Ruby body
   is skipped once (`bi_skip`, as a builtin's Method does). If it does not,
   nothing is set, so the bypass cannot be left for a nested call. A value's
   comparison goes to `eval_bin_prim`, which asks no Ruby definition, so a
   `Float#<=>` that calls its saved self does not come back to itself.
2. **The Time arm refused the bypass.** The dispatcher's Time arm stands aside
   when the program wrote the name (`time_user_meth`), and it did that even
   for the one call that asked to skip the program's body. The call fell to
   Object's `<=>`, and the answer was nil. `time_native_wanted` lets that call
   in, and it consumes the bypass there.
3. **`Time#<` went round once `#<=>` was written.** In ruby, `Time#<` is
   `Comparable#<`, which asks `#<=>`. Here, `t1 < t2` found Time's builtin
   operator and dispatched it by name. The by-name arm saw a program's `#<=>`
   and sent it back to EBin, and the two went round until the stack ran out.
   This happened with any Ruby `Time#<=>`, alias or not, so in a Rails process
   every Time ordering died. Comparable's arms now come before the builtin arm
   whenever the program wrote `#<=>` (`cmp_user_derives`: `< > <= >=`, and
   `==` unless `==` is written too).

A builtin's Method of an object's operator (`Time.at(1).method(:<=>).call(t)`)
also went to `eval_bin_prim`, and it was nil. It now takes the object path.

Witness: `corpus/930_saved_native_operators.rb`.

## The app's remaining tests

With the Bundler selection of a direct `bin/rails` start corrected in the
measurement's environment (a separate change), the app's tests met three more
faults. Each one was reproduced without Rails as well.

4. **`super` into an object's builtin.** io-console 0.9.5 prepends
   `IO::platform_tty` to IO, and its C `#tty?` calls `rb_call_super`. Rails'
   test reporter asks `$stdout.tty?` for every result. The same thing happens
   in plain Ruby: `super` from a module prepended to IO, File or Time, or from
   a Time subclass's override, found no Ruby method above and ran out of chain.
   `super_missing` now sends it to the dispatcher's native arm when a builtin
   object class among the receiver's ancestors answers the name
   (`builtin_obj_anc_has`). The Ruby bodies of that name are skipped once
   (`bi_skip`). Witness: `corpus/931_super_into_builtin_object_methods.rb`.
5. **`super` into an alias of a builtin.** actionpack's
   `AbstractController::Base` has `alias send_action send`, and
   `ActionController::BasicImplicitRender#send_action` calls super into it.
   Every controller action failed with "super: no superclass method
   'send_action'". When `super` finds no Ruby method above, it now looks for an
   alias of a builtin among the remaining ancestors (`super_blt_alias_src`, from
   the same position `super_next_plain` continues from). It runs the builtin
   under its source name, and the sender family keeps the block.
6. **An ancestor's builtin alias shadowed nearer definitions.**
   `class A; alias saved_inspect inspect; end` and a `B < A` with its own
   `#saved_inspect`: the alias answered B's call. This happened on main
   already. The dispatcher's alias arm now requires the alias to come first in
   the receiver's chain (`alias_first`). Witness for 5 and 6:
   `corpus/932_super_into_a_builtin_alias.rb`.

Left, not fixed here (not on the app's path):
- `instance_method(:m).super_method` is nil when the method above is an alias
  of a builtin.
- A module prepended to IO is not asked for a pipe's methods (`IO.pipe`). The
  builtin answers first.
- `LoggedFile.open` for a File subclass is a TypeError in `IO.__fd_int`.
