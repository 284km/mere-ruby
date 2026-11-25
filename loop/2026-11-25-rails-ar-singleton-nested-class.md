# Rails-2: a class defined inside a singleton class is an ordinary class

Two REDs of Rails-2 round 4 (activerecord, sqlite3 adapter), present since round 3: has_many_associations_test's `test_defining_has_many_association_with_{delete_all,nullify}_dependency_lazily_evaluates_target_class`.
Both errored with `StandardError: mere-ruby: (ruby exception raised)` and a backtrace from an earlier test.

## The cause

The tests define a model with the test object's `class_eval`:

```ruby
class_eval(<<-EOF, __FILE__, __LINE__ + 1)
  class DeleteAllModel < ActiveRecord::Base
    has_many :nonentities, :dependent => :delete_all
  end
EOF
```

ActiveSupport's `Object#class_eval` is `singleton_class.class_eval`, so the class is defined inside the test object's singleton class.
mere-ruby keys such a class `(sng:159)::DeleteAllModel`: the singleton class's key, then the path.
`is_sng_cls`, "is this a singleton class", was a prefix test, so it said yes for this class too.

From there:
- Every `def`, `define_method` and `method_added` into the class died with "failed". The frozen check took `159)::` for an object id and `int_of_str` failed on it.
- `Class#new` refused it: "can't create instance of singleton class".
- `name` was nil, and `.class` of an instance answered Object.

On main, `class << o; class M; def hi; end; end; end` alone fails.

## The change

`is_sng_cls` is true only for a whole singleton key, `(sng:X)`, which is the old `is_sng_whole`.
The sites that print or name a class keep a prefix test, written out as `str_starts_with c "(sng:"`, because a class inside a singleton prints through the singleton:
- `cls_display`, `cls_display_nw`
- the value printer's VClass arm, and the explicit `to_s` / `inspect` arm
- `Module#name`
- m_strutil's world-free `to_s`

The last two split the key at `)::`: the singleton's text, then the rest of the path (`#<Class:#<Object:0x..>>::M`, `#<Class:Foo>::Out`).
`mod_name_val0` still answers nil for a whole singleton key.

## Every caller of `is_sng_cls`, and why the whole key is right there

150 calls in 76 functions. A class inside a singleton is an ordinary class in ruby: `singleton_class?` is false, it has instances, it is a subclass of its superclass, and its methods are its own.
So "is c a singleton class" has to be no for it at every site. No site needs a yes for a key that only starts with `(sng:`, apart from the printing sites above, which now say so explicitly.

**Reads the class behind the singleton** (`sng_inner`, `sng_supername`, `sng_base_cls`, `metaclass_class`), 54 sites. For `(sng:159)::M` these read `159)::` or the singleton's parent, which is meaningless: the call is only defined for a whole key.
- `eval_e` ×6 (the const_missing receiver of an inline-cache miss, the `extend` of a defining class)
- `super_vals`, `super_native_owner`, `defined_super_str`, `super_missing` ×2
- `inspect_w` ×4 (EnvHash, Enumerator::Chain, Method under a singleton)
- `invoke_val_c0_inner` ×9 (superclass, the singleton's own methods, the cvar and ancestors of a class singleton, the undefined-method message)
- `sng_user_owner`, `invoke_with_block0` ×3, `exc_real_cls`, `responds_x0`, `meth_source_location`, `try_self_call_x`, `try_self_call1`
- `has_meth_b`, `lookup_meth`, `cvar_chain`, `ancestors_of_raw`, `ir_params`, `tp_fire_owned_c`, `env_is_recv`, `run_sng_hook`, `fdio_route`
- `cls_display`'s singleton arm (the prefix arm before it now takes the nested class), `alias_builtin_exists`, `exec_stmt` ×2 (method_added after a def), `unused_blk_warn`
- m_eval_leaf: `defined_as_name`, `builtin_owns_here`, `val_is_frozen`, `cls_display_nw`, `resolve_scope_name`, `metaclass_class`, `sng_supername`

**An object's recorded class is a singleton, so look past it**, 25 sites. An instance of M records M, its real class. Looking past it answered its superclass: `.class` was Object, `inspect` was `#<Object:..>`.
- `invoke_val_c2` ×2, `invoke_val_c0_inner` ×11 (dup / clone of a tagged value, `class`, `Method#owner`, `instance_variable_*` on a singleton)
- `hsh_class_like`, `invoke_with_block0` ×2, `prim_method_raw` ×2, `undef_blame`, `hng_lookup_cls`, `for_recv_obj`, `exec_stmt`, `bound_meth_inspect`, `dispatch_cls_of`, `prim_sng_cls`

**What a singleton class refuses or allows**, 13 sites: `new`, `allocate`, `dup` / `clone`, `Class.new(sng)`, `instance_of?`, binding a singleton method, and a frozen object's singleton refusing a def.
- `invoke_val_c0_inner` ×6, `invoke_with_block0`, `super_refusal`, `kernel_copy_hook`, `alias_builtin_exists`, `register_class_statement`, `vis_names_check`, `undef_check`
- M is an ordinary class: ruby makes its instances and copies it. corpus/1061 checks `new`, `allocate`, `dup`, and the singleton itself still refusing `new` and `dup`.

**A singleton is not another singleton's owner, a listed ancestor, or a subclass**, 49 sites. These ask whether c is already a singleton class: don't make a second one, skip it in an ancestor walk, don't list it among `subclasses`, give it Module's own methods.
- `singleton_cls_of`, `hng_cls_of`, `super_base` ×2, `capi_describe_x`, `invoke_with_block0` (the existing singleton is reused): with the prefix, M's instance took M itself for its own singleton class, so `a.singleton_class.superclass` was `#<Class:Object>`.
- `invoke_val_c0_inner` ×10, `class_subclasses_native`, `sng_mixin_syms`, `ma_blt_go`, `collect_vis_go` ×2, `collect_cls_methods`, `responds_x0`, `dispatch_prim0` ×2, `str_keep_sub`, `obj_print_cls` (skip / look past singletons in a walk). M belongs in these: `Base.subclasses` lists it, and its ancestors are its own.
- `class_parent_is_a`, `obj_is_a`, `hng_sng_has`, `hng_undef_blocked`, `hng_missing_hook`, `attr_ic_cls`, `enum_take_m`, `collect_vis`, `alias_builtin_exists`, `undef_check`, `super_self_check`, `run_method_added` (its inner is itself a singleton), `bound_meth_inspect` (singleton-only rules)
- `eval_e` ×2, `super_vals` ×2, `super_native_owner`, `capi_up` (a singleton has no path for the C API), `autoload_cref`, `exec_stmt` (a def's key inside a singleton's cref) (singleton-only rules)

The other `(sng:` prefix tests that are written out by hand (m_state's `mro_local_name` and `obj_cls_name`, the GC owner keys, the nesting checks in eval_e) do not call `is_sng_cls`, and this change leaves them as they were.
`obj_cls_name` and `sng_base_cls` were given the whole-key test as well: they are the `.class` of an instance.

main after this branch's base adds one more call, in `capi_describe_x`'s VClass arm (#284): a class's CLASS_OF is "Class" for a singleton class, else its metaclass `(sng:c)`.
With the whole key, a class inside a singleton gets its own metaclass, as any class does in CRuby. It is in the last group below. The branch merges with main without a conflict.

## Review of #288

Things the first version left, found in review (44's and the inline review):

- **The object's death took the class with it.** The collector reads the object id of a key with `sng_key_id`, and that read `(sng:123)::N` and `(sng:123)::N#v` as object 123's too.
  When the object was collected, `gc_purge_sng` / `gc_purge_tbl` and `gc_sweep_classes` (through `gc_class_owner`) dropped N's rows: its methods, its superclass, its includes, its ancestors.
  A subclass or a constant holding N does not keep the object, so `class Keep < N` then `GC.start` answered NoMethodError for N's methods and Object for `Keep.superclass.superclass`. On main this could not happen, because N could not be given a method or a subclass.
  `sng_own_id` is `sng_key_id` but -1 for a key with `::` after the singleton's `)`. The purge and `gc_class_owner` use it, so a nested class has no owner and stays, like a named class.
  A value holding N still keeps the object (the mark of a VClass reads `sng_key_id`), so the singleton's own constants that N's methods can see stay as well.
- **The printed key was cut at the first `)::`.** For `(sng:(sng:X)::M)::N2`, N2 in M's singleton, the name was `#<Class:(sng:281474976710815>::M)::N2`.
  `sng_nested_at` (m_strutil) finds the `)` that closes the first `(`. `cls_display`, `cls_display_nw` and m_strutil's `to_s` cut there.
- **An instance's own singleton class printed its class's key**, `#<Class:#<(sng:..)::M:0x..>>`. `cls_display`'s object arm now prints a `(sng:` class through `cls_display`, as it already did an anonymous one.

- **`Module#name` was right only in the ordinary call.** `Module.instance_method(:name).bind_call(k)` and `super` from a `def k.name` go through `mod_name_val`, which has no world and answered the raw key `(sng:..)::M`. The ordinary call's String was also a new, unfrozen one each time.
  `mod_name_w world c` names a nested key with `cls_display`, freezes it and keeps it in `cls_name_str`, as `mod_name_val0` does every other name. All three paths call it.

corpus/1062 (new) is the collector's case: 20 classes held by a constant, 10 named subclasses and 50 `Class.new` subclasses of N, then 3 collections. It also checks the printed shapes (no `(sng:`, balanced `#<..>`, the path at the end), the three paths to `Module#name`, and that the name is frozen and the same String each time.

## Checked

- The two tests, alone in round 4's tree: 2 runs, 2 assertions, 0 failures (main: 2 errors).
- corpus/1061 (new): def, `def self.`, define_method, method_added, constants (its own, the singleton's around it, a nested one), `new` / `allocate` / `dup`, `.class`, `is_a?`, `name`, `inspect`, a string class_eval on a singleton with `inherited`, a frozen object's singleton, and a class under a named class's singleton.
  It matches ruby on both engines. main dies at its first `def`.
- `./run_corpus.sh --both`: 947/947, plain and with `MERE_RUBY_VM=1`, after the review's changes (the base is before corpus/1060).
- Gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth, loop_rss.

## Left

- A class inside `class << self` written INSIDE `class Foo` is keyed `Foo::(sng:Foo)::Inner` (the outer scope prefixed to the singleton's key). So `Foo.singleton_class.const_get(:Inner)` is a NameError. This was already so on main. Opened from outside (`class << Foo; class Out`), it is right.
- Such a class prints `#<Class:#<Object:0x..>>::M`, where ruby prints the singleton by its own address: `#<Class:0x..>::M`.
- A class's `dup` does not call `method_added` for each method it copies, as ruby does. This holds for any class.
- `M1 = o.singleton_class::M` names the class `M1` in ruby. Here it keeps the name it had (main: nil).
