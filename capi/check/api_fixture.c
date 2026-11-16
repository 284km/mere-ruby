/* Shared test extension: points of the C API where what C does must not
 * depend on what Ruby code around it did. Compiled for both runtimes. */
#include <ruby.h>
#include <ruby/encoding.h>
#include <ruby/onigmo.h>
#include <ruby/io.h>
#include <sys/stat.h>

/* A pointer C took before the block it yields to gave up the Fiber: the
 * write through it, after the Fiber is resumed, is a write to the String. */
static VALUE ptr_after_yield(VALUE self, VALUE str) {
    char *p = RSTRING_PTR(str);
    (void)self;
    rb_yield(Qnil);
    p[0] = 'X';
    return str;
}
static VALUE ary_ptr_after_yield(VALUE self, VALUE ary) {
    VALUE *p = RARRAY_PTR(ary);
    (void)self;
    rb_yield(Qnil);
    p[0] = INT2FIX(99);
    return ary;
}
static VALUE noop(VALUE self) { (void)self; return Qnil; }

/* The primitives are ruby's own operations, whatever a subclass defines
 * under the same name. */
static VALUE push(VALUE self, VALUE ary, VALUE item) { (void)self; rb_ary_push(ary, item); return Qnil; }
static VALUE append(VALUE self, VALUE str, VALUE other) { (void)self; rb_str_append(str, other); return Qnil; }
static VALUE length(VALUE self, VALUE str) { (void)self; return LONG2NUM(rb_str_strlen(str)); }
static VALUE freeze(VALUE self, VALUE obj) { (void)self; rb_obj_freeze(obj); return Qnil; }
static VALUE aset(VALUE self, VALUE hash, VALUE key, VALUE value) { (void)self; rb_hash_aset(hash, key, value); return Qnil; }
static VALUE kind_of(VALUE self, VALUE obj, VALUE klass) { (void)self; return rb_obj_is_kind_of(obj, klass); }

/* rb_get_kwargs with the keywords :a and :b. */
static VALUE kwargs(VALUE self, VALUE hash, VALUE required, VALUE optional, VALUE with_values) {
    ID table[2];
    VALUE values[2] = { Qnil, Qnil };
    (void)self;
    table[0] = rb_intern("a");
    table[1] = rb_intern("b");
    int found = rb_get_kwargs(hash, table, NUM2INT(required), NUM2INT(optional), RTEST(with_values) ? values : NULL);
    VALUE undef = ID2SYM(rb_intern("undef"));
    return rb_ary_new_from_args(3, INT2FIX(found), values[0] == Qundef ? undef : values[0],
                                values[1] == Qundef ? undef : values[1]);
}

/* rb_proc_new: a Proc whose body is a C function. */
static VALUE proc_body(RB_BLOCK_CALL_FUNC_ARGLIST(yielded, data)) {
    (void)blockarg;
    return rb_ary_new_from_args(3, yielded, INT2FIX(argc), data);
}
static VALUE new_proc(VALUE self) { (void)self; return rb_proc_new(proc_body, ID2SYM(rb_intern("data"))); }

/* What real gems asked for (capi/needed.c). */
static VALUE convert(VALUE self, VALUE val, VALUE check) {
    (void)self;
    return RTEST(check) ? rb_check_convert_type(val, T_HASH, "Hash", "to_hash") : rb_convert_type(val, T_HASH, "Hash", "to_hash");
}
static VALUE memhash_equal(VALUE self, VALUE a, VALUE b) {
    (void)self;
    return rb_memhash(RSTRING_PTR(a), RSTRING_LEN(a)) == rb_memhash(RSTRING_PTR(b), RSTRING_LEN(b)) ? Qtrue : Qfalse;
}
static int each_ivar(ID name, VALUE value, st_data_t arg) {
    rb_ary_push((VALUE)arg, rb_assoc_new(ID2SYM(name), value));
    return ST_CONTINUE;
}
static VALUE ivars(VALUE self, VALUE obj) {
    VALUE pairs = rb_ary_new();
    (void)self;
    rb_ivar_foreach(obj, each_ivar, (st_data_t)pairs);
    return pairs;
}
static VALUE last_match(VALUE self, VALUE nth) { (void)self; return rb_reg_nth_match(NUM2INT(nth), rb_backref_get()); }
static VALUE set_match(VALUE self, VALUE match) { (void)self; rb_backref_set(match); return Qnil; }
static VALUE strtoul_of(VALUE self, VALUE str, VALUE base) {
    char *end;
    const char *s = StringValueCStr(str);
    (void)self;
    unsigned long n = ruby_strtoul(s, &end, NUM2INT(base));
    return rb_ary_new_from_args(2, ULONG2NUM(n), LONG2NUM(end - s));
}
#include <ruby/io.h>
#include <ruby/util.h>
static VALUE io_facts(VALUE self, VALUE io) {
    rb_io_t *fptr;
    (void)self;
    RB_IO_POINTER(io, fptr);
    rb_io_check_readable(fptr);
    return rb_ary_new_from_args(3, INT2FIX(fptr->fd == rb_io_descriptor(io)), (fptr->mode & FMODE_READABLE) ? Qtrue : Qfalse,
                                (fptr->mode & FMODE_WRITABLE) ? Qtrue : Qfalse);
}

/* A block function is told whether it was yielded keywords, and
 * rb_yield_block hands them on as keywords. */
static VALUE kw_body(RB_BLOCK_CALL_FUNC_ARGLIST(yielded, data)) {
    (void)yielded; (void)data; (void)blockarg; (void)argv;
    return rb_ary_new_from_args(2, INT2FIX(argc), rb_keyword_given_p() ? Qtrue : Qfalse);
}
static VALUE block_keywords(VALUE self, VALUE obj, VALUE name) {
    (void)self;
    return rb_block_call(obj, SYM2ID(name), 0, 0, kw_body, Qnil);
}
static VALUE yield_through(VALUE self, VALUE obj, VALUE name) {
    (void)self;
    return rb_block_call(obj, SYM2ID(name), 0, 0, rb_yield_block, Qnil);
}

/* rb_stat_new: a File::Stat of what stat(2) answered to C. */
static VALUE stat_new(VALUE self, VALUE path) {
    struct stat st;
    (void)self;
    if (stat(StringValueCStr(path), &st) != 0) rb_sys_fail_str(path);
    return rb_stat_new(&st);
}

/* The regexp parser's nesting bound, read and set from C. */
static VALUE parse_depth(VALUE self) { (void)self; return UINT2NUM(onig_get_parse_depth_limit()); }
static VALUE set_parse_depth(VALUE self, VALUE depth) {
    (void)self;
    return INT2FIX(onig_set_parse_depth_limit(NUM2UINT(depth)));
}

static VALUE ospath(VALUE self, VALUE path) { (void)self; return rb_str_encode_ospath(path); }

void Init_api_fixture(void) {
    VALUE mod = rb_define_module("ApiFixture");
    rb_define_singleton_method(mod, "ptr_after_yield", ptr_after_yield, 1);
    rb_define_singleton_method(mod, "ary_ptr_after_yield", ary_ptr_after_yield, 1);
    rb_define_singleton_method(mod, "noop", noop, 0);
    rb_define_singleton_method(mod, "push", push, 2);
    rb_define_singleton_method(mod, "append", append, 2);
    rb_define_singleton_method(mod, "length", length, 1);
    rb_define_singleton_method(mod, "freeze", freeze, 1);
    rb_define_singleton_method(mod, "aset", aset, 3);
    rb_define_singleton_method(mod, "kind_of", kind_of, 2);
    rb_define_singleton_method(mod, "kwargs", kwargs, 4);
    rb_define_singleton_method(mod, "new_proc", new_proc, 0);
    rb_define_singleton_method(mod, "convert", convert, 2);
    rb_define_singleton_method(mod, "memhash_equal", memhash_equal, 2);
    rb_define_singleton_method(mod, "ivars", ivars, 1);
    rb_define_singleton_method(mod, "last_match", last_match, 1);
    rb_define_singleton_method(mod, "set_match", set_match, 1);
    rb_define_singleton_method(mod, "strtoul", strtoul_of, 2);
    rb_define_singleton_method(mod, "io_facts", io_facts, 1);
    rb_define_singleton_method(mod, "block_keywords", block_keywords, 2);
    rb_define_singleton_method(mod, "yield_through", yield_through, 2);
    rb_define_singleton_method(mod, "stat_new", stat_new, 1);
    rb_define_singleton_method(mod, "parse_depth", parse_depth, 0);
    rb_define_singleton_method(mod, "set_parse_depth", set_parse_depth, 1);
    rb_define_singleton_method(mod, "ospath", ospath, 1);
    /* classes under a module under a module, all of them made here: a class
     * C defines is a class by that name like any other */
    VALUE mid = rb_define_module_under(mod, "Mid");
    VALUE base = rb_define_class_under(mid, "Base", rb_cObject);
    VALUE leaf = rb_define_class_under(mid, "Leaf", base);
    /* (from C, undefining says nothing on stderr and a missing name is not an error) */
    rb_undef_method(rb_singleton_class(leaf), "new");
    rb_undef_method(leaf, "initialize");
    rb_undef_method(leaf, "no_such_method_anywhere");
}
