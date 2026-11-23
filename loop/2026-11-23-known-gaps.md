# Seven gaps from round three: receiver names, singleton targets, clone(freeze: true), the hook's own name, struct and singleton-class singleton_methods (corpus 851)

Round three of test_ast's speed (#162, now #164) found these while its corpus program was written. They were set aside then, because main had them too (note 551, LOOP (95)). Each is checked against ruby 4.0.9.

1. **A builtin leaf's NoMethodError named no receiver.** `nil.upcase` said "undefined method 'upcase'", where ruby says "... for nil", and `1.upcase` says "for an instance of Integer". Many string-method fallbacks record the receiver (`prim_nm_set_ra`) but not how to name it. The message is now built from the recorded receiver (`prim_blame`) when no name was given.
2. **`define_singleton_method` on a Binding or a Proc** was "can't define singleton". Its target table now has both. They keep their singleton class aside, as `def pr.m` already did.
3. **A singleton method on a frozen String went through.** In ruby:
   - a deduplicated string (a frozen literal, `-"s"`, a constant holding a frozen literal) has no singleton class, so it is TypeError "can't define singleton", as `singleton_class` already said here;
   - a string frozen at run time is FrozenError.

   `sng_def_check` says this before every singleton definition: `def s.m` on a local or a constant, `define_singleton_method`, and a def under `__definee_recv`. `frz_recv_check` now refuses a frozen String, Array or Hash as it refused a frozen object. That also makes `extend` of a frozen string a FrozenError, as in ruby.
4. **`clone(freeze: true)` did not freeze** a String, an Array or a Hash. Only a receiver that was already frozen kept the state. Now `true` freezes, `false` does not, and nil or no keyword carries the receiver's state.
5. **`def o.singleton_method_added` did not hear its own definition.** An object's hook is fired before the write, so the first definition of the hook found no hook. For that one name it is now fired after the write, with the new hook (`run_sma_before`, and a line at the end of SDef). A redefinition is heard by the new hook only, as in ruby.
6. **A Struct class's `singleton_methods` had no `:inspect`.** Every struct class has `rb_struct_s_inspect` in ruby; it was defined here only for a keyword_init one. Now it is defined for all of them, and it is `to_s` for the others.
7. **A singleton class answered no `singleton_methods`.** In ruby, the singleton class of a class answers `allocate constants nesting used_modules used_refinements`, because its own singleton's ancestors reach `#<Class:Module>` and `#<Class:Class>`. The singleton class of a module answers the four without `allocate`, and an object's answers none. These are added to the full list, not to `singleton_methods(false)`.

**Witness.** corpus 851 covers each, with the neighbouring cases that must not change: an unfrozen `+"w"`, `nil.foo`, a frozen Object, `singleton_methods(false)`, and the hook redefined. On main, 25 of its lines differ from ruby.
