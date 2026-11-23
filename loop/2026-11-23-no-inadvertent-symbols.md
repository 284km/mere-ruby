# 2026-11-23: a name is not made a Symbol to fail with it (-ext-/symbol/test_inadvertent_creation)

The file was 32 failures and a timeout of 49; it passes now, 1181
assertions as the reference's. Bug::Symbol.find is rb_check_symbol and
.pinneddown? is rb_check_id.

**Dynamic Symbols.** Most of the 32 were `name.to_sym` and then "not pinned
down": ruby's String#to_sym makes a dynamic Symbol, which rb_check_id does
not count until something uses it as an ID. sym_all's value now says which:
VNil a name source wrote (the lexer's sym_note, and the Prism loader's
literals), false one only #to_sym / #intern made. set_meth / set_fresh_meth
and const_store pin a dynamic name a method or constant is given, as
define_method, attr, alias_method and const_set pin it in ruby.
capi/symbol.c asks the interpreter (request 29, MR_SYM_STATE: 0 none, 1
dynamic, 2 pinned) instead of `Symbol.all_symbols.any?`, which built the
whole list per question -- test_gc_attrset's 1000 noninterned names were
the timeout. A C table entry knows whether C pinned it (rb_intern*,
rb_sym2id); one the interpreter's Symbol only crossed into C with
(mr_capi_intern) does not. rb_check_id of a dynamic Symbol is 0 and *namep
its name; rb_check_symbol finds either kind and answers a Symbol as itself.
A Symbol the interpreter has but never noted (an identifier, a method's
name) still counts as pinned. rb_iv_get is rb_check_id_cstr first, as
ruby's is, and then the variable by its own name when the object has it
(identifiers are not noted here, so `@a = 1` makes no Symbol).

**The name as given.** send / __send__ / public_send by a String that is no
Symbol: the NoMethodError for that receiver and name is given the String as
#name (send_str_named, around each send arm's call) -- unless the receiver
has a #method_missing of its own, which ruby hands a Symbol (corpus/555).
const_get by such a String skips Module's own const_missing and names the
String. Both stop at a name some method or constant already has: ruby has
that ID (corpus/248's `const_get("Outer::TOP_CONST")` names :TOP_CONST).

**Interning on the way to failing.** Struct#[], #[]= and #dig compared a
String key by `k.to_sym`; they compare names now, and the NameError's #name
is the key.

**Met on the way.** `def self.alias_method` on a class was never called: the
builtin arm came first; it yields to the class's own (cls_meth_own) and
`super` comes back through bi_skip, as include's does. untrace_var of a name
that is no global variable raises NameError. Kernel#method / #public_method
on a CLASS ask its singleton's respond_to_missing?, and the Method's call
goes to BasicObject#method_missing; #singleton_method asks it for a name
that is no pinned Symbol (Bug #10985).

Not done: identifiers are still not noted as Symbols (`def foo` leaves
rb_check_id("foo") 0, as before), and instance/class variable writes do
not pin a dynamic name.
