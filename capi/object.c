/* Classes, modules, methods, instance variables, constants, and the objects
 * that wrap a C struct. */
#include "mr_capi.h"
#include <stdarg.h>
#include <string.h>

/* ---- defining ---------------------------------------------------------- */
extern int mr_const_name_p(const char *name);
extern VALUE mr_hidden_const_get(VALUE outer, const char *name, int *found);
extern void mr_hidden_const_set(VALUE outer, const char *name, VALUE value);
extern VALUE mr_hidden_const_remove(VALUE outer, const char *name, int *found);
static int hidden_const_defined(VALUE klass, const char *name, int inherit) {
    int found = 0;
    if (!inherit) {
        mr_hidden_const_get(klass, name, &found);
        return found;
    }
    VALUE ancestors = mr_call(klass, "ancestors", 0);
    for (long i = 0; i < RARRAY_LEN(ancestors); i++) {
        mr_hidden_const_get(rb_ary_entry(ancestors, i), name, &found);
        if (found) return 1;
    }
    return 0;
}
/* A class or module named under `outer`: the one that is there, or a new
 * one set as that constant (which is also what names it). */
static VALUE define_class(VALUE outer, const char *name, VALUE super, int module) {
    if (NIL_P(outer)) outer = rb_cObject;
    /* A name that is not a constant's ("platform_tty", which io-console
     * defines and prepends to IO): ruby keeps it under an ID that
     * `constants` and `const_get` do not see, and the module's name is
     * still "IO::platform_tty". Kept on the C side (capi/hidden.c), out of
     * Ruby's sight, and named by a temporary name -- the outer's path, or
     * its inspect when it has none. */
    if (!mr_const_name_p(name)) {
        int there = 0;
        VALUE found = mr_hidden_const_get(outer, name, &there);
        if (there) {
            if (module ? !RB_TYPE_P(found, T_MODULE) : !RB_TYPE_P(found, T_CLASS))
                rb_raise(rb_eTypeError, "%s is not a %s", name, module ? "module" : "class");
            return found;
        }
        if (!module && (NIL_P(super) || super == 0)) rb_raise(rb_eArgError, "no super class for '%s'", name);
        VALUE made = module ? mr_call(rb_cModule, "new", 0) : mr_call(rb_cClass, "new", 1, super);
        VALUE full;
        if (outer == rb_cObject) full = rb_str_new_cstr(name);
        else {
            VALUE path = rb_mod_name(outer);
            full = rb_str_dup(NIL_P(path) ? rb_inspect(outer) : path);
            rb_str_cat_cstr(full, "::");
            rb_str_cat_cstr(full, name);
        }
        mr_call(made, "set_temporary_name", 1, full);
        mr_hidden_const_set(outer, name, made);
        return made;
    }
    VALUE sym = ID2SYM(rb_intern(name));
    if (RTEST(mr_call(outer, "const_defined?", 2, sym, outer == rb_cObject ? Qtrue : Qfalse))) {
        VALUE found = mr_call(outer, "const_get", 2, sym, outer == rb_cObject ? Qtrue : Qfalse);
        if (module) {
            if (!RB_TYPE_P(found, T_MODULE)) rb_raise(rb_eTypeError, "%s is not a module (%" PRIsVALUE ")", name, rb_obj_class(found));
            return found;
        }
        if (!RB_TYPE_P(found, T_CLASS)) rb_raise(rb_eTypeError, "%s is not a class (%" PRIsVALUE ")", name, rb_obj_class(found));
        if (!NIL_P(super) && super != 0 && mr_call(found, "superclass", 0) != super)
            rb_raise(rb_eTypeError, "superclass mismatch for class %s", name);
        return found;
    }
    if (!module && (NIL_P(super) || super == 0)) rb_raise(rb_eArgError, "no super class for '%s'", name);
    /* The class statement itself, where the scope and the superclass have
     * names; else an anonymous class, set as the constant. */
    mr_put_text(name);
    VALUE made = mr_up(MR_DEFINE_CLASS, outer, module ? Qnil : super, (VALUE)(module ? 1 : 0), 0, 0);
    if (made != 0) return made;
    made = module ? mr_call(rb_cModule, "new", 0) : mr_call(rb_cClass, "new", 1, super);
    mr_call(outer, "const_set", 2, sym, made);
    return made;
}
VALUE rb_define_module(const char *name) { return define_class(Qnil, name, Qnil, 1); }
VALUE rb_define_module_under(VALUE outer, const char *name) { return define_class(outer, name, Qnil, 1); }
VALUE rb_define_module_id(ID id) { return define_class(Qnil, rb_id2name(id), Qnil, 1); }
VALUE rb_define_module_id_under(VALUE outer, ID id) { return define_class(outer, rb_id2name(id), Qnil, 1); }
VALUE rb_define_class(const char *name, VALUE super) { return define_class(Qnil, name, super, 0); }
VALUE rb_define_class_under(VALUE outer, const char *name, VALUE super) { return define_class(outer, name, super, 0); }
VALUE rb_define_class_id(ID id, VALUE super) { return define_class(Qnil, rb_id2name(id), super, 0); }
VALUE rb_define_class_id_under(VALUE outer, ID id, VALUE super) { return define_class(outer, rb_id2name(id), super, 0); }
/* class.c's: a subclass, with no `inherited` called -- rb_check_inheritable's
 * refusals first, in its words */
VALUE rb_class_new(VALUE super) {
    if (!RB_TYPE_P(super, T_CLASS)) rb_raise(rb_eTypeError, "superclass must be an instance of Class (given an instance of %"PRIsVALUE")", rb_obj_class(super));
    if (RB_FL_TEST(super, RUBY_FL_SINGLETON)) rb_raise(rb_eTypeError, "can't make subclass of singleton class");
    if (super == rb_cClass) rb_raise(rb_eTypeError, "can't make subclass of Class");
    return mr_call(rb_cClass, "__new_quiet", 1, super);
}
VALUE rb_module_new(void) { return mr_call(rb_cModule, "new", 0); }
VALUE rb_refinement_new(void) { mr_unsupported("rb_refinement_new"); }

/* A C function becomes a method by way of a lambda that runs it: defined
 * with define_method, it is found, inherited, aliased and made private as
 * any method is. */
static void define_method(VALUE klass, const char *name, VALUE (*fn)(ANYARGS), int arity, int kind) {
    if (arity < -2 || arity > 15) rb_raise(rb_eArgError, "arity out of range: %d for -2..15", arity);
    long number = mr_register_function((void *)fn, arity);
    VALUE body = mr_up(MR_PROC_NEW, (VALUE)number, (VALUE)(long)arity, 2, (VALUE)rb_intern(name), 0);
    VALUE sym = ID2SYM(rb_intern(name));
    if (kind == MR_M_SINGLETON) mr_callv(klass, rb_intern("define_singleton_method"), 1, &sym, body, 0);
    else {
        mr_callv(klass, rb_intern("define_method"), 1, &sym, body, 0);
        if (kind == MR_M_PRIVATE) mr_call(klass, "private", 1, sym);
        else if (kind == MR_M_PROTECTED) mr_call(klass, "protected", 1, sym);
        else if (kind == MR_M_MODULE_FUNCTION) {
            mr_call(klass, "private", 1, sym);
            mr_callv(klass, rb_intern("define_singleton_method"), 1, &sym, body, 0);
        }
    }
    /* (rb_f_notimplement: an entry that is no method -- see capi_notimpl.
     *  Noted after the definition, which clears any note of the name.) */
    if (fn == (VALUE (*)(ANYARGS))rb_f_notimplement) {
        mr_put_text(name);
        mr_up2(MR_NOTIMPL, klass, kind == MR_M_SINGLETON ? 1 : kind == MR_M_MODULE_FUNCTION ? 2 : 0);
    }
}
#undef rb_define_method
#undef rb_define_method_id
#undef rb_define_singleton_method
#undef rb_define_module_function
#undef rb_define_private_method
#undef rb_define_protected_method
#undef rb_define_global_function
void rb_define_method(VALUE klass, const char *name, VALUE (*fn)(ANYARGS), int arity) { define_method(klass, name, fn, arity, MR_M_INSTANCE); }
void rb_define_method_id(VALUE klass, ID id, VALUE (*fn)(ANYARGS), int arity) { define_method(klass, rb_id2name(id), fn, arity, MR_M_INSTANCE); }
void rb_define_singleton_method(VALUE obj, const char *name, VALUE (*fn)(ANYARGS), int arity) { define_method(obj, name, fn, arity, MR_M_SINGLETON); }
void rb_define_module_function(VALUE module, const char *name, VALUE (*fn)(ANYARGS), int arity) { define_method(module, name, fn, arity, MR_M_MODULE_FUNCTION); }
void rb_define_private_method(VALUE klass, const char *name, VALUE (*fn)(ANYARGS), int arity) { define_method(klass, name, fn, arity, MR_M_PRIVATE); }
void rb_define_protected_method(VALUE klass, const char *name, VALUE (*fn)(ANYARGS), int arity) { define_method(klass, name, fn, arity, MR_M_PROTECTED); }
void rb_define_global_function(const char *name, VALUE (*fn)(ANYARGS), int arity) { define_method(rb_mKernel, name, fn, arity, MR_M_MODULE_FUNCTION); }

void rb_define_alloc_func(VALUE klass, rb_alloc_func_t fn) {
    mr_up(MR_DEFINE_ALLOC, klass, (VALUE)mr_register_function((void *)fn, 0), 0, 0, 0);
}
void rb_undef_alloc_func(VALUE klass) { mr_up(MR_DEFINE_ALLOC, klass, (VALUE)-1L, 0, 0, 0); }
void rb_define_alias(VALUE klass, const char *fresh, const char *old) {
    mr_call(klass, "alias_method", 2, ID2SYM(rb_intern(fresh)), ID2SYM(rb_intern(old)));
}
void rb_alias(VALUE klass, ID fresh, ID old) { mr_call(klass, "alias_method", 2, ID2SYM(fresh), ID2SYM(old)); }
/* (C's rb_undef_method is not Module#undef_method: it does not warn that
 *  undefining `initialize` "may cause serious problems", and a name nothing
 *  defines is not an error) */
void rb_undef_method(VALUE klass, const char *name) {
    mr_call(mr_ruby("->(k, n) { v = $VERBOSE; $VERBOSE = nil; begin; k.send(:undef_method, n); rescue NameError; ensure; $VERBOSE = v; end }"),
            "call", 2, klass, ID2SYM(rb_intern(name)));
}
void rb_undef(VALUE klass, ID id) { mr_call(klass, "undef_method", 1, ID2SYM(id)); }
void rb_remove_method(VALUE klass, const char *name) { mr_call(klass, "remove_method", 1, ID2SYM(rb_intern(name))); }
void rb_remove_method_id(VALUE klass, ID id) { mr_call(klass, "remove_method", 1, ID2SYM(id)); }
void rb_define_attr(VALUE klass, const char *name, int read, int write) {
    VALUE sym = ID2SYM(rb_intern(name));
    if (read) mr_call(klass, "attr_reader", 1, sym);
    if (write) mr_call(klass, "attr_writer", 1, sym);
}
void rb_attr(VALUE klass, ID id, int read, int write, int ex) {
    (void)ex;
    if (read) mr_call(klass, "attr_reader", 1, ID2SYM(id));
    if (write) mr_call(klass, "attr_writer", 1, ID2SYM(id));
}
void rb_include_module(VALUE klass, VALUE module) { mr_call(klass, "include", 1, module); }
void rb_prepend_module(VALUE klass, VALUE module) { mr_call(klass, "prepend", 1, module); }
void rb_extend_object(VALUE obj, VALUE module) { mr_callk(obj, "extend", 1, module); }
VALUE rb_singleton_class(VALUE obj) { return mr_callk(obj, "singleton_class", 0); }

/* ---- constants and variables --------------------------------------------- */
void rb_define_const(VALUE klass, const char *name, VALUE value) { mr_call(klass, "const_set", 2, ID2SYM(rb_intern(name)), value); }
void rb_define_global_const(const char *name, VALUE value) { rb_define_const(rb_cObject, name, value); }
/* A name that is no constant's ("_INVALID"): CRuby keeps it under an ID that
 * `constants` and Ruby's const_get do not see, and C finds it again. Kept on
 * the C side (capi/hidden.c, the table define_class uses for a class of
 * such a name), out of Ruby's sight. */
extern int mr_const_name_p(const char *name);
extern VALUE mr_hidden_const_get(VALUE outer, const char *name, int *found);
extern void mr_hidden_const_set(VALUE outer, const char *name, VALUE value);
void rb_const_set(VALUE klass, ID id, VALUE value) {
    const char *name = rb_id2name(id);
    if (!mr_const_name_p(name)) { mr_hidden_const_set(klass, name, value); return; }
    mr_call(klass, "const_set", 2, ID2SYM(id), value);
}
VALUE rb_const_get(VALUE klass, ID id) {
    const char *name = rb_id2name(id);
    if (!mr_const_name_p(name)) {
        VALUE ancestors = mr_call(klass, "ancestors", 0);
        for (long i = 0; i < RARRAY_LEN(ancestors); i++) {
            int found = 0;
            VALUE v = mr_hidden_const_get(rb_ary_entry(ancestors, i), name, &found);
            if (found) return v;
        }
        /* (not there: the lookup's own words, not Ruby's refusal of the name) */
        if (klass == rb_cObject) rb_raise(rb_eNameError, "uninitialized constant %s", name);
        rb_raise(rb_eNameError, "uninitialized constant %"PRIsVALUE"::%s", rb_class_path(klass), name);
    }
    return mr_call(klass, "const_get", 1, ID2SYM(id));
}
VALUE rb_const_get_at(VALUE klass, ID id) {
    const char *name = rb_id2name(id);
    if (!mr_const_name_p(name)) {
        int found = 0;
        VALUE value = mr_hidden_const_get(klass, name, &found);
        if (found) return value;
        rb_raise(rb_eNameError, "uninitialized constant %"PRIsVALUE"::%s", rb_class_path(klass), name);
    }
    return mr_call(klass, "const_get", 2, ID2SYM(id), Qfalse);
}
VALUE rb_const_get_from(VALUE klass, ID id) {
    if (!mr_const_name_p(rb_id2name(id))) return rb_const_get(klass, id);
    return mr_call(klass, "const_get", 1, ID2SYM(id));
}
int rb_const_defined(VALUE klass, ID id) {
    const char *name = rb_id2name(id);
    if (!mr_const_name_p(name)) return hidden_const_defined(klass, name, 1);
    return RTEST(mr_call(klass, "const_defined?", 1, ID2SYM(id)));
}
int rb_const_defined_at(VALUE klass, ID id) {
    const char *name = rb_id2name(id);
    if (!mr_const_name_p(name)) return hidden_const_defined(klass, name, 0);
    return RTEST(mr_call(klass, "const_defined?", 2, ID2SYM(id), Qfalse));
}
int rb_const_defined_from(VALUE klass, ID id) {
    if (!mr_const_name_p(rb_id2name(id))) return hidden_const_defined(klass, rb_id2name(id), 1);
    return RTEST(mr_call(klass, "const_defined?", 1, ID2SYM(id)));
}
VALUE rb_const_remove(VALUE klass, ID id) {
    const char *name = rb_id2name(id);
    if (!mr_const_name_p(name)) {
        int found = 0;
        VALUE value = mr_hidden_const_remove(klass, name, &found);
        if (found) return value;
        rb_raise(rb_eNameError, "constant %"PRIsVALUE"::%s not defined", rb_class_path(klass), name);
    }
    return mr_call(klass, "remove_const", 1, ID2SYM(id));
}
/* "A::B::C" to the class it names: each part looked up in the one before it
 * and nowhere else (Object's constants are not every module's). */
VALUE rb_path_to_class(VALUE path) {
    StringValue(path);
    VALUE parts = mr_call(path, "split", 2, rb_str_new_cstr("::"), INT2FIX(-1));
    VALUE c = rb_cObject;
    long n = RARRAY_LEN(parts);
    if (n == 0 || RSTRING_LEN(path) == 0) rb_raise(rb_eArgError, "can't retrieve anonymous class %" PRIsVALUE, path);
    if (RSTRING_PTR(path)[0] == '#') rb_raise(rb_eArgError, "can't retrieve anonymous class %" PRIsVALUE, path);
    for (long i = 0; i < n; i++) {
        VALUE name = rb_ary_entry(parts, i);
        VALUE so_far = mr_call(mr_call(parts, "first", 1, LONG2NUM(i + 1)), "join", 1, rb_str_new_cstr("::"));
        VALUE sym = rb_str_intern(name);
        if (!RTEST(mr_call(c, "const_defined?", 2, sym, Qfalse)))
            rb_raise(rb_eArgError, "undefined class/module %" PRIsVALUE, so_far);
        c = mr_call(c, "const_get", 2, sym, Qfalse);
        if (!RB_TYPE_P(c, T_CLASS) && !RB_TYPE_P(c, T_MODULE))
            rb_raise(rb_eTypeError, "%" PRIsVALUE " does not refer to class/module", so_far);
    }
    return c;
}
VALUE rb_path2class(const char *path) { return rb_path_to_class(rb_str_new_cstr(path)); }

/* An instance variable by ID. A name with no `@` is one only C sees (CRuby's
 * "internal" variables): it is kept under a name of the interpreter's hidden
 * kind, which instance_variables and Marshal pass over. */
static VALUE ivar_name(ID id) {
    long len = 0;
    const char *s = mr_id_name(id, &len);
    if (!s) rb_raise(rb_eNameError, "invalid instance variable ID");
    if (len > 0 && s[0] == '@') return ID2SYM(id);
    char *buffer = alloca((size_t)len + 16);
    memcpy(buffer, "@__capi_", 8);
    memcpy(buffer + 8, s, (size_t)len);
    return ID2SYM(rb_intern2(buffer, len + 8));
}
/* (a dmark run between C calls reads the ivar from the table, through the
 *  collector's reader -- no dispatch, no Ruby -- for an object; anything
 *  else is refused) */
static VALUE ivar_read_unasked(VALUE obj, ID id) {
    int type = rb_type(obj);
    if (type != T_OBJECT && type != T_DATA)
        mr_fatal("a dmark read an instance variable of something that is not an object, with no C call in progress");
    long len = 0;
    const char *s = mr_id_name(id, &len);
    if (!s) mr_fatal("a dmark read an instance variable by an invalid ID");
    char *buffer = alloca((size_t)len + 16);
    if (len > 0 && s[0] == '@') { memcpy(buffer, s, (size_t)len); buffer[len] = 0; }
    else { memcpy(buffer, "@__capi_", 8); memcpy(buffer + 8, s, (size_t)len); buffer[len + 8] = 0; }
    mr_put_text(buffer);
    VALUE value = mr_up1(MR_IVAR_READ, obj);
    if (value == Qundef)
        mr_fatal("a dmark read an instance variable of a T_DATA the interpreter keeps no ivar table for (a Proc, a Binding), with no C call in progress");
    return value;
}
VALUE rb_ivar_get(VALUE obj, ID id) {
    if (mr_capi_mark_unasked()) return ivar_read_unasked(obj, id);
    return mr_callk(obj, "instance_variable_get", 1, ivar_name(id));
}
VALUE rb_ivar_set(VALUE obj, ID id, VALUE value) { mr_callk(obj, "instance_variable_set", 2, ivar_name(id), value); return value; }
VALUE rb_ivar_defined(VALUE obj, ID id) { return mr_callk(obj, "instance_variable_defined?", 1, ivar_name(id)); }
VALUE rb_attr_get(VALUE obj, ID id) { return rb_ivar_get(obj, id); }
/* A name that is no Symbol is no variable, and asking does not make it one
 * (ruby's rb_check_id_cstr). (A variable that is there -- set by a name the
 * lexer never read, instance_variable_set of a dynamic Symbol -- is still
 * asked for by its own name.) */
VALUE rb_iv_get(VALUE obj, const char *name) {
    long len = (long)strlen(name);
    ID id = rb_check_id_cstr(name, len, rb_usascii_encoding());
    if (id) return rb_ivar_get(obj, id);
    if (len > 1 && name[0] == '@' && RTEST(mr_callk(obj, "instance_variable_defined?", 1, rb_str_new(name, len))))
        return mr_callk(obj, "instance_variable_get", 1, rb_str_new(name, len));
    return Qnil;
}
VALUE rb_iv_set(VALUE obj, const char *name, VALUE value) { return rb_ivar_set(obj, rb_intern(name), value); }
VALUE rb_obj_instance_variables(VALUE obj) { return mr_callk(obj, "instance_variables", 0); }
VALUE rb_obj_remove_instance_variable(VALUE obj, VALUE name) { return mr_call(obj, "remove_instance_variable", 1, name); }
st_index_t rb_ivar_count(VALUE obj) { return (st_index_t)NUM2LONG(mr_call(rb_obj_instance_variables(obj), "size", 0)); }
VALUE rb_cvar_get(VALUE klass, ID id) { return mr_call(klass, "class_variable_get", 1, ID2SYM(id)); }
void rb_cvar_set(VALUE klass, ID id, VALUE value) { mr_call(klass, "class_variable_set", 2, ID2SYM(id), value); }
/* (CRuby's lookup reads the class's own table, where its instance variables
 *  are too: "@x" of the class or an ancestor answers as well as "@@x") */
VALUE rb_cvar_defined(VALUE klass, ID id) {
    const char *name = rb_id2name(id);
    if (name && name[0] == '@' && name[1] != '@')
        return mr_call(mr_ruby("->(k, n) { k.ancestors.any? { |m| m.instance_variable_defined?(n) } }"), "call", 2, klass, ID2SYM(id));
    return mr_call(klass, "class_variable_defined?", 1, ID2SYM(id));
}
VALUE rb_cv_get(VALUE klass, const char *name) { return rb_cvar_get(klass, rb_intern(name)); }
void rb_cv_set(VALUE klass, const char *name, VALUE value) { rb_cvar_set(klass, rb_intern(name), value); }
void rb_define_class_variable(VALUE klass, const char *name, VALUE value) { rb_cvar_set(klass, rb_intern(name), value); }

static VALUE global_name(const char *name) {
    if (name[0] == '$') return rb_str_new_cstr(name);
    VALUE s = rb_str_new_cstr("$");
    return rb_str_cat_cstr(s, name);
}
/* (the value travels as a block's argument, never through source text) */
VALUE rb_gv_get(const char *name) {
    /* ($~ is the Ruby frame's that called C -- rb_backref_get -- not the
     *  frame an eval here would have) */
    const char *bare = name[0] == '$' ? name + 1 : name;
    if (!strcmp(bare, "~")) return rb_backref_get();
    return mr_call(mr_ruby("->(n) { eval(n) }"), "call", 1, global_name(name));
}
VALUE rb_gv_set(const char *name, VALUE value) {
    mr_call(mr_ruby("->(n, v) { eval(\"#{n} = v\") }"), "call", 2, global_name(name), value);
    return value;
}

/* ---- objects ---------------------------------------------------------------- */
VALUE rb_obj_class(VALUE obj) { return mr_callk(obj, "class", 0); }
VALUE rb_class_of(VALUE obj);
/* The class an object is "of" to a reader: not the singleton class a
 * `def obj.x` hung on it. */
VALUE rb_class_real(VALUE klass) {
    if (NIL_P(klass) || klass == 0) return klass;
    while (RB_TYPE_P(klass, T_CLASS) && RTEST(mr_call(klass, "singleton_class?", 0))) klass = mr_call(klass, "superclass", 0);
    return klass;
}
const char *rb_class2name(VALUE klass) {
    VALUE name = mr_call(rb_class_real(klass), "to_s", 0);
    return StringValueCStr(name);
}
const char *rb_obj_classname(VALUE obj) { return rb_class2name(rb_obj_class(obj)); }
/* (class.c's: the path of the real class -- "#<Class:0x...>" for one with no name) */
VALUE rb_class_name(VALUE klass) { return rb_class_path(rb_class_real(klass)); }
VALUE rb_class_path(VALUE klass) { return mr_call(klass, "to_s", 0); }
VALUE rb_mod_name(VALUE module) { return mr_call(module, "name", 0); }
VALUE rb_class_superclass(VALUE klass) { return mr_call(klass, "superclass", 0); }
/* (RCLASS_SUPER: false where there is none -- BasicObject's, and a module's) */
VALUE rb_class_get_superclass(VALUE klass) {
    if (!RB_TYPE_P(klass, T_CLASS)) return Qfalse;
    VALUE s = mr_call(klass, "superclass", 0);
    return NIL_P(s) ? Qfalse : s;
}
VALUE rb_mod_ancestors(VALUE module) { return mr_call(module, "ancestors", 0); }
VALUE rb_class_inherited_p(VALUE module, VALUE other) {
    if (!RB_TYPE_P(module, T_CLASS) && !RB_TYPE_P(module, T_MODULE)) rb_raise(rb_eTypeError, "compared with non class/module");
    return mr_call(module, "<=", 1, other);
}
VALUE rb_obj_is_kind_of(VALUE obj, VALUE klass) { return mr_callk(obj, "is_a?", 1, klass); }
VALUE rb_obj_is_instance_of(VALUE obj, VALUE klass) { return mr_callk(obj, "instance_of?", 1, klass); }
int rb_respond_to(VALUE obj, ID id) { return RTEST(mr_call(obj, "respond_to?", 2, ID2SYM(id), Qtrue)); }
int rb_obj_respond_to(VALUE obj, ID id, int priv) { return RTEST(mr_call(obj, "respond_to?", 2, ID2SYM(id), priv ? Qtrue : Qfalse)); }
int rb_method_boundp(VALUE klass, ID id, int ex) {
    return RTEST(mr_call(klass, ex ? "public_method_defined?" : "method_defined?", 1, ID2SYM(id)))
        || (!ex && RTEST(mr_call(klass, "private_method_defined?", 1, ID2SYM(id))));
}
int rb_method_basic_definition_p(VALUE klass, ID id) {
    VALUE owner = mr_call(mr_call(klass, "instance_method", 1, ID2SYM(id)), "owner", 0);
    VALUE name = mr_call(owner, "name", 0);
    if (NIL_P(name)) return 0;
    const char *s = StringValueCStr(name);
    return !strcmp(s, "Object") || !strcmp(s, "Kernel") || !strcmp(s, "BasicObject") || !strcmp(s, "Module")
        || !strcmp(s, "Class") || !strcmp(s, "Comparable") || !strcmp(s, "Enumerable") || !strcmp(s, "String")
        || !strcmp(s, "Array") || !strcmp(s, "Hash") || !strcmp(s, "Integer") || !strcmp(s, "Float")
        || !strcmp(s, "Symbol") || !strcmp(s, "NilClass") || !strcmp(s, "Numeric");
}
/* (a String C freezes keeps its buffer: CRuby's OBJ_FREEZE sets the flag
 *  alone, and C may hold RSTRING_PTR across it. Freezing goes through the
 *  interpreter's String#freeze, which the mirror would take as
 *  rb_str_freeze's resize, so the mirror is told first.) */
VALUE rb_obj_freeze(VALUE obj) {
    if (!RB_SPECIAL_CONST_P(obj)) {
        /* (a String, an Array, a Hash: the flag, as RB_OBJ_FREEZE sets it --
         *  MR_FREEZE; anything else is sent #freeze, Kernel's) */
        VALUE done = MR_HANDLE_P(obj) && !mr_without("builtin") ? mr_up1(MR_FREEZE, obj) : 0;
        if (done == 2) mr_mirror_frozen_by_c(obj);
        if (!done) {
            if (MR_HANDLE_P(obj) && rb_type(obj) == T_STRING && !RB_OBJ_FROZEN_RAW(obj)) mr_mirror_frozen_by_c(obj);
            mr_callk(obj, "freeze", 0);
        }
        mr_mirror_forget(obj);
    }
    return obj;
}
extern int mr_vbig_raw_p(VALUE v);
void rb_obj_freeze_inline(VALUE obj) {
    /* (a raw Bignum is frozen as bignum.c freezes it, in its own flags) */
    if (!RB_SPECIAL_CONST_P(obj) && !MR_HANDLE_P(obj) && mr_vbig_raw_p(obj)) { RBASIC(obj)->flags |= RUBY_FL_FREEZE; return; }
    rb_obj_freeze(obj);
}
VALUE rb_obj_frozen_p(VALUE obj) { return RB_OBJ_FROZEN(obj) ? Qtrue : Qfalse; }
VALUE rb_equal(VALUE a, VALUE b) { return a == b ? Qtrue : (RTEST(mr_call(a, "==", 1, b)) ? Qtrue : Qfalse); }
int rb_eql(VALUE a, VALUE b) { return a == b || RTEST(mr_call(a, "eql?", 1, b)); }
VALUE rb_obj_equal(VALUE a, VALUE b) { return mr_call(a, "equal?", 1, b); }
VALUE rb_inspect(VALUE obj) { return mr_call(obj, "inspect", 0); }
VALUE rb_obj_as_string(VALUE obj) {
    if (RB_TYPE_P(obj, T_STRING)) return obj;
    VALUE s = mr_call(obj, "to_s", 0);
    return RB_TYPE_P(s, T_STRING) ? s : rb_any_to_s(obj);
}
VALUE rb_any_to_s(VALUE obj) { return mr_call(mr_call(mr_call(rb_mKernel, "instance_method", 1, ID2SYM(rb_intern("to_s"))), "bind", 1, obj), "call", 0); }
VALUE rb_obj_dup(VALUE obj) { return mr_callk(obj, "dup", 0); }
VALUE rb_obj_clone(VALUE obj) { return mr_callk(obj, "clone", 0); }
VALUE rb_obj_init_copy(VALUE obj, VALUE orig) { (void)orig; return obj; }
VALUE rb_obj_id(VALUE obj) { return mr_callk(obj, "object_id", 0); }
extern void mr_mirror_hide(VALUE obj, int hidden);
VALUE rb_obj_hide(VALUE obj) { mr_mirror_hide(obj, 1); return obj; }
VALUE rb_obj_reveal(VALUE obj, VALUE klass) { (void)klass; mr_mirror_hide(obj, 0); return obj; }
VALUE rb_obj_alloc(VALUE klass) { return mr_call(klass, "allocate", 0); }
VALUE rb_class_new_instance(int argc, const VALUE *argv, VALUE klass) { return mr_callv(klass, rb_intern("new"), argc, argv, Qnil, 0); }
VALUE rb_class_new_instance_kw(int argc, const VALUE *argv, VALUE klass, int kw) {
    /* (keywords passed are a Hash, or one by #to_hash: "no implicit
     *  conversion of Integer into Hash") */
    if (kw == RB_PASS_KEYWORDS && argc > 0 && !RB_TYPE_P(argv[argc - 1], T_HASH))
        rb_convert_type(argv[argc - 1], T_HASH, "Hash", "to_hash");
    return mr_callv(klass, rb_intern("new"), argc, argv, Qnil, mr_kw(kw));
}
VALUE rb_class_new_instance_pass_kw(int argc, const VALUE *argv, VALUE klass) { return rb_class_new_instance(argc, argv, klass); }
void rb_obj_call_init(VALUE obj, int argc, const VALUE *argv) { mr_callv(obj, rb_intern("initialize"), argc, argv, mr_frame_block(), 0); }
void rb_obj_call_init_kw(VALUE obj, int argc, const VALUE *argv, int kw) { mr_callv(obj, rb_intern("initialize"), argc, argv, mr_frame_block(), mr_kw(kw)); }
VALUE rb_obj_method(VALUE obj, VALUE name) { return mr_callk(obj, "method", 1, name); }
int rb_obj_method_arity(VALUE obj, ID id) { return NUM2INT(mr_call(mr_callk(obj, "method", 1, ID2SYM(id)), "arity", 0)); }
int rb_mod_method_arity(VALUE module, ID id) { return NUM2INT(mr_call(mr_call(module, "instance_method", 1, ID2SYM(id)), "arity", 0)); }
VALUE rb_obj_singleton_methods(int argc, const VALUE *argv, VALUE obj) { return mr_callv(obj, rb_intern("singleton_methods"), argc, argv, Qnil, 0); }

/* ---- types ---------------------------------------------------------------- */
static const char *type_name(int type) {
    switch (type) {
      case T_NIL: return "nil"; case T_OBJECT: return "Object"; case T_CLASS: return "Class";
      case T_MODULE: return "Module"; case T_FLOAT: return "Float"; case T_STRING: return "String";
      case T_REGEXP: return "Regexp"; case T_ARRAY: return "Array"; case T_FIXNUM: return "Integer";
      case T_HASH: return "Hash"; case T_STRUCT: return "Struct"; case T_BIGNUM: return "Integer";
      case T_FILE: return "File"; case T_TRUE: return "true"; case T_FALSE: return "false";
      case T_SYMBOL: return "Symbol"; case T_DATA: return "Data"; case T_MATCH: return "MatchData";
      case T_RATIONAL: return "Rational"; case T_COMPLEX: return "Complex";
    }
    return "unknown";
}
/* What a type error calls the value it was given: nil, true and false by
 * name, anything else by its class (a String, in the class name's encoding). */
static VALUE value_name(VALUE obj) {
    if (NIL_P(obj)) return rb_usascii_str_new_cstr("nil");
    if (obj == Qtrue) return rb_usascii_str_new_cstr("true");
    if (obj == Qfalse) return rb_usascii_str_new_cstr("false");
    return mr_call(rb_class_real(rb_obj_class(obj)), "to_s", 0);
}
void rb_unexpected_type(VALUE obj, int type) {
    rb_raise(rb_eTypeError, "wrong argument type %" PRIsVALUE " (expected %s)", value_name(obj), type_name(type));
}
void rb_check_type(VALUE obj, int type) {
    if (obj == Qundef) rb_bug("undef leaked to the Ruby space");
    if ((int)rb_type(obj) != type || (type == T_DATA && RTYPEDDATA_P(obj))) rb_unexpected_type(obj, type);
}
int rb_typeddata_inherited_p(const rb_data_type_t *child, const rb_data_type_t *parent) {
    for (; child; child = child->parent) if (child == parent) return 1;
    return 0;
}
int rb_typeddata_is_kind_of(VALUE obj, const rb_data_type_t *type) {
    if (RB_SPECIAL_CONST_P(obj) || !RB_TYPE_P(obj, T_DATA) || !RTYPEDDATA_P(obj)) return 0;
    return rb_typeddata_inherited_p(RTYPEDDATA_TYPE(obj), type);
}
int rb_typeddata_is_instance_of(VALUE obj, const rb_data_type_t *type) {
    return !RB_SPECIAL_CONST_P(obj) && RB_TYPE_P(obj, T_DATA) && RTYPEDDATA_P(obj) && RTYPEDDATA_TYPE(obj) == type;
}
void *rb_check_typeddata(VALUE obj, const rb_data_type_t *type) {
    if (RB_SPECIAL_CONST_P(obj) || !RB_TYPE_P(obj, T_DATA) || !RTYPEDDATA_P(obj))
        rb_raise(rb_eTypeError, "wrong argument type %" PRIsVALUE " (expected %s)", value_name(obj), type->wrap_struct_name);
    if (!rb_typeddata_inherited_p(RTYPEDDATA_TYPE(obj), type))
        rb_raise(rb_eTypeError, "wrong argument type %s (expected %s)", RTYPEDDATA_TYPE(obj)->wrap_struct_name, type->wrap_struct_name);
    return RTYPEDDATA_GET_DATA(obj);
}

/* ---- objects that wrap a C struct ------------------------------------------- */
static VALUE bare(VALUE klass) {
    if (NIL_P(klass) || klass == 0) klass = rb_cObject;
    return mr_up1(MR_OBJECT_NEW, klass);
}
#undef rb_data_object_wrap
VALUE rb_data_object_wrap(VALUE klass, void *data, RUBY_DATA_FUNC dmark, RUBY_DATA_FUNC dfree) {
    VALUE obj = bare(klass);
    mr_mirror_data(obj, 0, NULL, data, dmark, dfree, 0);
    return obj;
}
VALUE rb_data_object_zalloc(VALUE klass, size_t size, RUBY_DATA_FUNC dmark, RUBY_DATA_FUNC dfree) {
    void *data = ruby_xcalloc(1, size);
    return rb_data_object_wrap(klass, data, dmark, dfree);
}
VALUE rb_data_typed_object_wrap(VALUE klass, void *data, const rb_data_type_t *type) {
    VALUE obj = bare(klass);
    mr_mirror_data(obj, 1, type, data, NULL, NULL, 0);
    return obj;
}
VALUE rb_data_typed_object_zalloc(VALUE klass, size_t size, const rb_data_type_t *type) {
    if (type->flags & RUBY_TYPED_EMBEDDABLE) {
        VALUE obj = bare(klass);
        mr_mirror_data(obj, 1, type, NULL, NULL, NULL, size ? size : 1);
        return obj;
    }
    void *data = ruby_xcalloc(1, size);
    return rb_data_typed_object_wrap(klass, data, type);
}
/* ---- calling ----------------------------------------------------------------- */
#undef rb_funcall
#undef rb_funcallv
#undef rb_funcallv_public
#undef rb_funcall_passing_block
VALUE rb_funcallv(VALUE recv, ID mid, int argc, const VALUE *argv) { return mr_callv(recv, mid, argc, argv, Qnil, 0); }
VALUE rb_funcallv_kw(VALUE recv, ID mid, int argc, const VALUE *argv, int kw) { return mr_callv(recv, mid, argc, argv, Qnil, mr_kw(kw)); }
VALUE rb_funcallv_public(VALUE recv, ID mid, int argc, const VALUE *argv) { return mr_callv(recv, mid, argc, argv, Qnil, MR_SEND_PUBLIC); }
VALUE rb_funcallv_public_kw(VALUE recv, ID mid, int argc, const VALUE *argv, int kw) { return mr_callv(recv, mid, argc, argv, Qnil, MR_SEND_PUBLIC | (mr_kw(kw))); }
VALUE rb_funcall(VALUE recv, ID mid, int argc, ...) {
    VALUE *argv = argc > 0 ? alloca(sizeof(VALUE) * (size_t)argc) : NULL;
    va_list ap;
    va_start(ap, argc);
    for (int i = 0; i < argc; i++) argv[i] = va_arg(ap, VALUE);
    va_end(ap);
    return mr_callv(recv, mid, argc, argv, Qnil, 0);
}
VALUE rb_funcall_passing_block(VALUE recv, ID mid, int argc, const VALUE *argv) { return mr_callv(recv, mid, argc, argv, mr_frame_block(), MR_SEND_PUBLIC); }
VALUE rb_funcall_passing_block_kw(VALUE recv, ID mid, int argc, const VALUE *argv, int kw) { return mr_callv(recv, mid, argc, argv, mr_frame_block(), MR_SEND_PUBLIC | (mr_kw(kw))); }
VALUE rb_funcall_with_block(VALUE recv, ID mid, int argc, const VALUE *argv, VALUE block) { return mr_callv(recv, mid, argc, argv, block, MR_SEND_PUBLIC); }
VALUE rb_funcall_with_block_kw(VALUE recv, ID mid, int argc, const VALUE *argv, VALUE block, int kw) { return mr_callv(recv, mid, argc, argv, block, MR_SEND_PUBLIC | (mr_kw(kw))); }
VALUE rb_check_funcall(VALUE recv, ID mid, int argc, const VALUE *argv) {
    if (!rb_obj_respond_to(recv, mid, 1)) return Qundef;
    return mr_callv(recv, mid, argc, argv, Qnil, 0);
}
VALUE rb_call_super(int argc, const VALUE *argv) { return mr_callv(Qnil, 0, argc, argv, mr_frame_block(), MR_SEND_SUPER); }
VALUE rb_call_super_kw(int argc, const VALUE *argv, int kw) { return mr_callv(Qnil, 0, argc, argv, mr_frame_block(), MR_SEND_SUPER | (mr_kw(kw))); }
VALUE rb_current_receiver(void) { return mr_callv(Qnil, 0, 0, NULL, Qnil, MR_SEND_SUPER | 16); }
VALUE rb_apply(VALUE recv, ID mid, VALUE args) { return mr_callv(recv, mid, RARRAY_LENINT(args), RARRAY_CONST_PTR(args), Qnil, 0); }
