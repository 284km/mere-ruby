/* Shared test extension: points of the C API where what C does must not
 * depend on what Ruby code around it did. Compiled for both runtimes. */
#include <ruby.h>
#include <ruby/encoding.h>
#include <ruby/onigmo.h>
#include <ruby/io.h>
#include <ruby/version.h>
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
/* The same, with the byte to write given: two calls holding pointers into
 * one String, each in its own stopped Fiber. */
static VALUE byte_after_yield(VALUE self, VALUE str, VALUE byte) {
    char c = (char)NUM2INT(byte);
    char *p = RSTRING_PTR(str);
    (void)self;
    rb_yield(Qnil);
    p[0] = c;
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
static VALUE aref(VALUE self, VALUE ary, VALUE index) { (void)self; return rb_ary_aref(1, &index, ary); }
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
static VALUE class_of(VALUE self, VALUE obj) { (void)self; return CLASS_OF(obj); }
static VALUE version_text(VALUE self) { (void)self; return rb_str_new_cstr(ruby_version); }
static VALUE write_io_of(VALUE self, VALUE io) { (void)self; return rb_io_get_write_io(io); }
/* (the descriptor C writes on -- io-console's way to it) */
static VALUE write_descriptor(VALUE self, VALUE io) { (void)self; return INT2FIX(rb_io_descriptor(rb_io_get_write_io(io))); }
static VALUE read_pending(VALUE self, VALUE io) { (void)self; rb_io_t *fptr; GetOpenFile(io, fptr); return INT2NUM(rb_io_read_pending(fptr)); }
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
/* The directions an IO's struct says, without a check in front. */
static VALUE io_mode(VALUE self, VALUE io) {
    rb_io_t *fptr;
    (void)self;
    RB_IO_POINTER(io, fptr);
    return rb_ary_new_from_args(3, (fptr->mode & FMODE_READABLE) ? Qtrue : Qfalse, (fptr->mode & FMODE_WRITABLE) ? Qtrue : Qfalse,
                                (fptr->mode & FMODE_APPEND) ? Qtrue : Qfalse);
}
static VALUE io_check_writable(VALUE self, VALUE io) {
    rb_io_t *fptr;
    (void)self;
    RB_IO_POINTER(io, fptr);
    rb_io_check_writable(fptr);
    return Qtrue;
}
/* An IO on a descriptor C opened; FMODE_EXTERNAL keeps the descriptor C's. */
static VALUE open_descriptor(VALUE self, VALUE fd, VALUE external) {
    (void)self;
    return rb_io_open_descriptor(rb_cIO, NUM2INT(fd), FMODE_READABLE | (RTEST(external) ? FMODE_EXTERNAL : 0), Qnil, Qnil, NULL);
}
/* A global C keeps, defined under a name Ruby may have aliased already. */
static VALUE kept_value = Qnil;
static VALUE keep_variable(VALUE self, VALUE name) {
    (void)self;
    rb_define_variable(StringValueCStr(name), &kept_value);
    return Qnil;
}
static VALUE kept_get(VALUE self) { (void)self; return kept_value; }
static VALUE kept_set(VALUE self, VALUE v) { (void)self; kept_value = v; return v; }
/* The Set functions: what C adds, finds, removes, counts and walks. */
static int set_collect(VALUE element, VALUE into) { rb_ary_push(into, element); return ST_CONTINUE; }
static VALUE set_ops(VALUE self, VALUE set) {
    (void)self;
    VALUE walked = rb_ary_new();
    VALUE added = rb_set_add(set, INT2FIX(2)) ? Qtrue : Qfalse;
    VALUE again = rb_set_add(set, INT2FIX(2)) ? Qtrue : Qfalse;
    VALUE found = rb_set_lookup(set, INT2FIX(2)) ? Qtrue : Qfalse;
    VALUE missing = rb_set_lookup(set, INT2FIX(9)) ? Qtrue : Qfalse;
    VALUE size = SIZET2NUM(rb_set_size(set));
    VALUE removed = rb_set_delete(set, INT2FIX(1)) ? Qtrue : Qfalse;
    VALUE absent = rb_set_delete(set, INT2FIX(1)) ? Qtrue : Qfalse;
    rb_set_foreach(set, set_collect, walked);
    return rb_ary_new_from_args(8, added, again, found, missing, size, removed, absent, walked);
}
static VALUE set_clear(VALUE self, VALUE set) { (void)self; rb_set_clear(set); return SIZET2NUM(rb_set_size(set)); }
static VALUE set_add(VALUE self, VALUE set, VALUE v) { (void)self; return rb_set_add(set, v) ? Qtrue : Qfalse; }

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

/* rb_stat_new of a struct C made up, its times below the second (and on
 * macOS its birth time); and of NULL. */
#include <string.h>
static VALUE stat_made_up(VALUE self, VALUE mtime_nsec) {
    struct stat st;
    (void)self;
    memset(&st, 0, sizeof(st));
    st.st_mode = S_IFREG | 0644;
    st.st_size = 42;
    st.st_nlink = 1;
#ifdef __APPLE__
    st.st_atimespec.tv_sec = 100; st.st_atimespec.tv_nsec = 111222333;
    st.st_mtimespec.tv_sec = 200; st.st_mtimespec.tv_nsec = NUM2LONG(mtime_nsec);
    st.st_ctimespec.tv_sec = 300; st.st_ctimespec.tv_nsec = 777888999;
    st.st_birthtimespec.tv_sec = 50; st.st_birthtimespec.tv_nsec = 123456789;
#else
    st.st_atim.tv_sec = 100; st.st_atim.tv_nsec = 111222333;
    st.st_mtim.tv_sec = 200; st.st_mtim.tv_nsec = NUM2LONG(mtime_nsec);
    st.st_ctim.tv_sec = 300; st.st_ctim.tv_nsec = 777888999;
#endif
    return rb_stat_new(&st);
}
static VALUE stat_null(VALUE self) { (void)self; return rb_stat_new(NULL); }

/* The regexp parser's nesting bound, read and set from C. */
static VALUE parse_depth(VALUE self) { (void)self; return UINT2NUM(onig_get_parse_depth_limit()); }
static VALUE set_parse_depth(VALUE self, VALUE depth) {
    (void)self;
    return INT2FIX(onig_set_parse_depth_limit(NUM2UINT(depth)));
}

static VALUE ospath(VALUE self, VALUE path) { (void)self; return rb_str_encode_ospath(path); }
/* Where a String's bytes are -- in the struct while they fit there, in a
 * buffer of their own after -- is CRuby's business, and nothing C does
 * through the API may see it change under it. */
static VALUE capacity(VALUE self, VALUE str) { (void)self; return LONG2NUM((long)rb_str_capacity(str)); }
/* the String grows in Ruby between two looks from C */
static VALUE grown_by_ruby(VALUE self, VALUE str, VALUE more) {
    char first = RSTRING_PTR(str)[0];
    (void)self;
    rb_funcall(str, rb_intern("<<"), 1, more);
    return rb_ary_new3(2, INT2FIX(first), rb_str_new(RSTRING_PTR(str), RSTRING_LEN(str)));
}
/* rb_str_cat of the String's own bytes, out of the struct into a buffer */
static VALUE cat_self(VALUE self, VALUE str, VALUE times) {
    (void)self;
    for (int i = 0; i < NUM2INT(times); i++) rb_str_cat(str, RSTRING_PTR(str), RSTRING_LEN(str));
    return str;
}
/* a buffer from rb_str_buf_new, filled through the pointer */
static VALUE buf_fill(VALUE self, VALUE n) {
    long len = NUM2LONG(n);
    VALUE s = rb_str_buf_new(len);
    (void)self;
    long capa = (long)rb_str_capacity(s);
    memset(RSTRING_PTR(s), 'z', (size_t)len);
    rb_str_set_len(s, len);
    return rb_ary_new3(2, capa >= len ? Qtrue : Qfalse, s);
}
/* rb_str_modify_expand: room for exactly that much more */
static VALUE expand_room(VALUE self, VALUE str, VALUE n) {
    (void)self;
    rb_str_modify_expand(str, NUM2LONG(n));
    return LONG2NUM((long)rb_str_capacity(str) - RSTRING_LEN(str));
}
/* rb_str_resize out to a buffer and back into the struct */
static VALUE resize_out_and_back(VALUE self, VALUE str) {
    (void)self;
    rb_str_resize(str, 200);
    RSTRING_PTR(str)[199] = 'q';
    VALUE far = rb_str_new(RSTRING_PTR(str) + 199, 1);
    rb_str_resize(str, 2);
    return rb_ary_new3(2, far, str);
}

/* (rb_funcallv_public by name; an encoding's index as C reads it; a dummy
 *  encoding defined here; what C's rb_fs holds) */
static VALUE funcall_public(VALUE self, VALUE obj, VALUE name) {
    (void)self;
    return rb_funcallv_public(obj, rb_sym2id(name), 0, NULL);
}
static VALUE enc_index_of(VALUE self, VALUE str) { (void)self; return INT2FIX(rb_enc_get_index(str)); }
static VALUE define_dummy(VALUE self, VALUE name) { (void)self; return INT2FIX(rb_define_dummy_encoding(StringValueCStr(name))); }
static VALUE fs_value(VALUE self) { (void)self; return rb_fs; }
/* (#binding sent from C; a typed data wrapping NULL whose dsize reads its
 *  pointer; rb_errinfo after an rb_protect that returned normally) */
static VALUE binding_of(VALUE self, VALUE obj) { (void)self; return rb_funcall(obj, rb_intern("binding"), 0); }
static size_t reading_dsize(const void *p) { return *(const size_t *)p; }
static const rb_data_type_t reading_type = { "ApiFixture::Reading", { NULL, RUBY_TYPED_DEFAULT_FREE, reading_dsize }, 0, 0, 0 };
static VALUE null_typed(VALUE self) { (void)self; return TypedData_Wrap_Struct(rb_cObject, &reading_type, NULL); }
static VALUE raise_arg(VALUE arg) { (void)arg; rb_raise(rb_eArgError, "caught by rb_protect"); return Qnil; }
static VALUE protect_and_return(VALUE self) { (void)self; int state = 0; rb_protect(raise_arg, Qnil, &state); return INT2FIX(state); }
static VALUE errinfo_now(VALUE self) { (void)self; return rb_errinfo(); }
/* (Bignums C keeps past the call that made them -- public API both ways:
 *  rb_gc_register_mark_object, and a static variable registered first) */
static VALUE kept_marked, kept_static;
static VALUE kept_bignums(VALUE self) {
    (void)self;
    return rb_ary_new_from_args(2, kept_marked, kept_static);
}
/* (...and one a registered slot held when its call ended, which a later
 *  call takes out into a local, empties the slot, and uses after a nested
 *  C call -- a method, or a C block: the local still has it, as CRuby's
 *  collection sees the C stack) */
static VALUE swap_slot;
static VALUE slot_fill(VALUE self) { (void)self; swap_slot = rb_big_new(5, 1); return Qnil; }
static VALUE slot_block(RB_BLOCK_CALL_FUNC_ARGLIST(x, data)) { (void)data; return x; }
static VALUE slot_swap(VALUE self, VALUE by_block) {
    volatile VALUE old = swap_slot;
    swap_slot = Qnil;
    if (RTEST(by_block)) rb_block_call(rb_ary_new_from_args(1, INT2FIX(1)), rb_intern("each"), 0, 0, slot_block, Qnil);
    else rb_funcall(self, rb_intern("noop"), 0);
    return old;
}
/* (...and one whose nested call is a yield, which a Fiber may pause in) */
static VALUE slot_swap_yield(VALUE self) {
    (void)self;
    volatile VALUE old = swap_slot;
    swap_slot = Qnil;
    rb_yield(Qnil);
    return old;
}
void Init_api_fixture(void) {
    VALUE mod = rb_define_module("ApiFixture");
    rb_define_singleton_method(mod, "funcall_public", funcall_public, 2);
    rb_define_singleton_method(mod, "enc_index_of", enc_index_of, 1);
    rb_define_singleton_method(mod, "define_dummy", define_dummy, 1);
    rb_define_singleton_method(mod, "fs_value", fs_value, 0);
    rb_define_singleton_method(mod, "binding_of", binding_of, 1);
    rb_define_singleton_method(mod, "null_typed", null_typed, 0);
    rb_define_singleton_method(mod, "protect_and_return", protect_and_return, 0);
    rb_define_singleton_method(mod, "errinfo_now", errinfo_now, 0);
    kept_marked = rb_big_new(3, 1);
    rb_gc_register_mark_object(kept_marked);
    rb_gc_register_address(&kept_static);
    kept_static = rb_big_new(4, 0);
    rb_define_singleton_method(mod, "kept_bignums", kept_bignums, 0);
    rb_gc_register_address(&swap_slot);
    rb_define_singleton_method(mod, "slot_fill", slot_fill, 0);
    rb_define_singleton_method(mod, "slot_swap", slot_swap, 1);
    rb_define_singleton_method(mod, "slot_swap_yield", slot_swap_yield, 0);
    rb_define_singleton_method(mod, "ptr_after_yield", ptr_after_yield, 1);
    rb_define_singleton_method(mod, "ary_ptr_after_yield", ary_ptr_after_yield, 1);
    rb_define_singleton_method(mod, "byte_after_yield", byte_after_yield, 2);
    rb_define_singleton_method(mod, "noop", noop, 0);
    rb_define_singleton_method(mod, "push", push, 2);
    rb_define_singleton_method(mod, "append", append, 2);
    rb_define_singleton_method(mod, "length", length, 1);
    rb_define_singleton_method(mod, "aref", aref, 2);
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
    rb_define_singleton_method(mod, "class_of", class_of, 1);
    rb_define_singleton_method(mod, "version_text", version_text, 0);
    rb_define_singleton_method(mod, "write_io_of", write_io_of, 1);
    rb_define_singleton_method(mod, "write_descriptor", write_descriptor, 1);
    rb_define_singleton_method(mod, "read_pending", read_pending, 1);
    rb_define_singleton_method(mod, "strtoul", strtoul_of, 2);
    rb_define_singleton_method(mod, "io_facts", io_facts, 1);
    rb_define_singleton_method(mod, "io_mode", io_mode, 1);
    rb_define_singleton_method(mod, "io_check_writable", io_check_writable, 1);
    rb_define_singleton_method(mod, "open_descriptor", open_descriptor, 2);
    rb_define_singleton_method(mod, "keep_variable", keep_variable, 1);
    rb_define_singleton_method(mod, "kept_get", kept_get, 0);
    rb_define_singleton_method(mod, "kept_set", kept_set, 1);
    rb_define_singleton_method(mod, "set_ops", set_ops, 1);
    rb_define_singleton_method(mod, "set_clear", set_clear, 1);
    rb_define_singleton_method(mod, "set_add", set_add, 2);
    rb_define_singleton_method(mod, "block_keywords", block_keywords, 2);
    rb_define_singleton_method(mod, "yield_through", yield_through, 2);
    rb_define_singleton_method(mod, "stat_new", stat_new, 1);
    rb_define_singleton_method(mod, "stat_made_up", stat_made_up, 1);
    rb_define_singleton_method(mod, "stat_null", stat_null, 0);
    rb_define_singleton_method(mod, "parse_depth", parse_depth, 0);
    rb_define_singleton_method(mod, "set_parse_depth", set_parse_depth, 1);
    rb_define_singleton_method(mod, "ospath", ospath, 1);
    rb_define_singleton_method(mod, "capacity", capacity, 1);
    rb_define_singleton_method(mod, "grown_by_ruby", grown_by_ruby, 2);
    rb_define_singleton_method(mod, "cat_self", cat_self, 2);
    rb_define_singleton_method(mod, "buf_fill", buf_fill, 1);
    rb_define_singleton_method(mod, "expand_room", expand_room, 2);
    rb_define_singleton_method(mod, "resize_out_and_back", resize_out_and_back, 1);
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
