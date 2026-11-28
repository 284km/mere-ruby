/* Shared test extension: points of the C API where what C does must not
 * depend on what Ruby code around it did. Compiled for both runtimes. */
#include <ruby.h>
#include <ruby/encoding.h>
#include <ruby/onigmo.h>
#include <ruby/io.h>
#include <ruby/version.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>

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
/* rb_check_id: is the name an ID already (true), without making it one */
static VALUE check_id(VALUE self, VALUE name) { (void)self; return rb_check_id(&name) ? Qtrue : Qfalse; }
static VALUE check_symbol(VALUE self, VALUE name) { (void)self; return rb_check_symbol(&name); }

/* The primitives are ruby's own operations, whatever a subclass defines
 * under the same name. */
static VALUE push(VALUE self, VALUE ary, VALUE item) { (void)self; rb_ary_push(ary, item); return Qnil; }
static VALUE aref(VALUE self, VALUE ary, VALUE index) { (void)self; return rb_ary_aref(1, &index, ary); }
static VALUE append(VALUE self, VALUE str, VALUE other) { (void)self; rb_str_append(str, other); return Qnil; }
static VALUE length(VALUE self, VALUE str) { (void)self; return LONG2NUM(rb_str_strlen(str)); }
static VALUE freeze(VALUE self, VALUE obj) { (void)self; rb_obj_freeze(obj); return Qnil; }
static VALUE store(VALUE self, VALUE ary, VALUE index, VALUE value) { (void)self; rb_ary_store(ary, NUM2LONG(index), value); return ary; }
/* What sqlite3's callback frame asks on every prepare and step. */
static VALUE thread_current(VALUE self) { (void)self; return rb_thread_current(); }
/* Strings of a megabyte and more: their buffers are mapped (core.c's big
 * buffers), made, written, resized and let go as any other */
static VALUE big_new(VALUE self, VALUE n, VALUE ch) {
    (void)self;
    long len = NUM2LONG(n);
    VALUE s = rb_str_new(NULL, len);
    memset(RSTRING_PTR(s), NUM2INT(ch), (size_t)len);
    return s;
}
/* rb_str_new(NULL, n) of a big n: the String is made in its struct and
 * reaches Ruby when C has written it. C writes the first half, lets Ruby read
 * it (`peek`), writes the second half, and then resizes, sets the length or
 * modifies as `how` says; Ruby must see each state as C left it. */
static VALUE zeroed_steps(VALUE self, VALUE n, VALUE peek, VALUE how) {
    (void)self;
    long len = NUM2LONG(n);
    VALUE s = rb_str_new(NULL, len);
    memset(RSTRING_PTR(s), 'a', (size_t)(len / 2));
    VALUE seen = rb_funcall(peek, rb_intern("call"), 1, s);
    memset(RSTRING_PTR(s) + len / 2, 'b', (size_t)(len - len / 2));
    VALUE again = rb_funcall(peek, rb_intern("call"), 1, s);
    ID h = SYM2ID(how);
    if (h == rb_intern("resize")) { rb_str_resize(s, len / 4); RSTRING_PTR(s)[0] = 'r'; }
    else if (h == rb_intern("set_len")) { rb_str_set_len(s, len - 1); RSTRING_PTR(s)[len - 2] = 's'; }
    else if (h == rb_intern("modify")) { rb_str_modify(s); RSTRING_PTR(s)[1] = 'm'; }
    return rb_ary_new3(3, seen, again, s);
}
/* ...and one a data object holds alone, marked by its dmark */
struct zeroed_holder { VALUE str; };
static void zeroed_holder_mark(void *p) { rb_gc_mark(((struct zeroed_holder *)p)->str); }
static const rb_data_type_t zeroed_holder_type = { "ApiFixture::ZeroedHolder", { zeroed_holder_mark, RUBY_TYPED_DEFAULT_FREE, NULL }, 0, 0, 0 };
static VALUE zeroed_holder(VALUE self, VALUE n, VALUE ch) {
    (void)self;
    struct zeroed_holder *h;
    VALUE obj = TypedData_Make_Struct(rb_cObject, struct zeroed_holder, &zeroed_holder_type, h);
    long len = NUM2LONG(n);
    h->str = rb_str_new(NULL, len);
    memset(RSTRING_PTR(h->str), NUM2INT(ch), (size_t)len);
    return obj;
}
static VALUE zeroed_held(VALUE self, VALUE obj) {
    (void)self;
    struct zeroed_holder *h;
    TypedData_Get_Struct(obj, struct zeroed_holder, &zeroed_holder_type, h);
    return h->str;
}
/* A String C builds 32 KiB at a time with rb_str_cat, calling `peek` with it
 * and the step after each piece (so each piece crosses), from `str` or from
 * an empty one. At step `at` C itself writes it first, by `how`: :middle
 * (a byte in what was already there), :set_len (cut by 1000), :resize (to
 * half), or nothing. Big enough that later pieces go to the interpreter as
 * the tail alone (mirror.c MR_STR_CAT). */
static VALUE cat_steps(VALUE self, VALUE str, VALUE steps, VALUE peek, VALUE at, VALUE how) {
    (void)self;
    VALUE s = NIL_P(str) ? rb_str_buf_new(0) : str;
    static char chunk[32 * 1024];
    ID h = SYM2ID(how);
    for (long i = 0; i < NUM2LONG(steps); i++) {
        if (i == NUM2LONG(at)) {
            if (h == rb_intern("middle")) { rb_str_modify(s); if (RSTRING_LEN(s) > 100) RSTRING_PTR(s)[100] = 'M'; }
            /* (rb_str_modify first: in ruby the String may share its bytes with
             *  the `s.b` peek made, and rb_str_set_len refuses a shared one) */
            else if (h == rb_intern("set_len") && RSTRING_LEN(s) > 1000) { rb_str_modify(s); rb_str_set_len(s, RSTRING_LEN(s) - 1000); }
            else if (h == rb_intern("resize")) rb_str_resize(s, RSTRING_LEN(s) / 2);
        }
        memset(chunk, 'a' + (int)(i % 26), sizeof chunk);
        rb_str_cat(s, chunk, (long)sizeof chunk);
        rb_funcall(peek, rb_intern("call"), 2, s, LONG2NUM(i));
    }
    return s;
}
/* C keeps the String's struct and buffer across a call into Ruby (`peek`,
 * which changes a byte of it in place), then appends 4 KiB through them and
 * sets the length in the struct itself, with no function to fetch it again.
 * In ruby the buffer is the one Ruby wrote: its byte stays, and C's bytes
 * follow it. (Room is made first, so that neither side moves the buffer.) */
static VALUE cat_kept(VALUE self, VALUE str, VALUE peek) {
    (void)self;
    rb_str_modify_expand(str, 4096);
    struct RString *r = RSTRING(str);
    char *p = RSTRING_PTR(str);
    long len = RSTRING_LEN(str);
    rb_funcall(peek, rb_intern("call"), 1, str);
    memset(p + len, 't', 4096);
    p[len + 4096] = '\0';
    r->len = len + 4096;
    /* ...and then reads it through RSTRING_PTR, which sees Ruby's byte, and
     * writes its first byte */
    char seen = RSTRING_PTR(str)[5];
    RSTRING_PTR(str)[0] = 'W';
    return INT2FIX(seen);
}
/* ...and one a data object holds alone, marked by its dmark, appended to
 * in later calls */
static VALUE cat_holder(VALUE self, VALUE n) {
    (void)self;
    struct zeroed_holder *h;
    VALUE obj = TypedData_Make_Struct(rb_cObject, struct zeroed_holder, &zeroed_holder_type, h);
    h->str = rb_str_buf_new(0);
    char chunk[4096];
    for (long i = 0; i < NUM2LONG(n); i++) { memset(chunk, 'k', sizeof chunk); rb_str_cat(h->str, chunk, (long)sizeof chunk); }
    return obj;
}
static VALUE cat_held_more(VALUE self, VALUE obj, VALUE n, VALUE ch) {
    (void)self;
    struct zeroed_holder *h;
    TypedData_Get_Struct(obj, struct zeroed_holder, &zeroed_holder_type, h);
    char chunk[4096];
    memset(chunk, NUM2INT(ch), sizeof chunk);
    for (long i = 0; i < NUM2LONG(n); i++) { rb_str_cat(h->str, chunk, (long)sizeof chunk); if (i % 8 == 7) rb_funcall(rb_mGC, rb_intern("count"), 0); }
    return h->str;
}
static VALUE big_fill(VALUE self, VALUE str, VALUE ch) {
    (void)self;
    memset(RSTRING_PTR(str), NUM2INT(ch), (size_t)RSTRING_LEN(str));
    return str;
}
static VALUE big_resize(VALUE self, VALUE str, VALUE n, VALUE ch) {
    (void)self;
    long was = RSTRING_LEN(str), len = NUM2LONG(n);
    rb_str_resize(str, len);
    if (len > was) memset(RSTRING_PTR(str) + was, NUM2INT(ch), (size_t)(len - was));
    return str;
}
static VALUE big_cat(VALUE self, VALUE str, VALUE times) {
    (void)self;
    char chunk[4096];
    memset(chunk, 'c', sizeof chunk);
    for (long i = 0; i < NUM2LONG(times); i++) rb_str_cat(str, chunk, (long)sizeof chunk);
    return str;
}
static VALUE thread_aref(VALUE self, VALUE thread, VALUE key) { (void)self; return rb_thread_local_aref(thread, SYM2ID(key)); }
/* A row as sqlite3's step makes one: an Array of the capacity, its elements
 * stored in order, a String frozen with rb_obj_freeze, the row frozen; and
 * what C reads of it after (its length, its last element, its flags). */
static VALUE row(VALUE self, VALUE n) {
    (void)self;
    long len = NUM2LONG(n);
    VALUE list = rb_ary_new2(len);
    for (long i = 0; i < len; i++) {
        VALUE v = (i % 2) ? rb_str_new_cstr("text") : LONG2NUM(i);
        if (i % 2) rb_obj_freeze(v);
        rb_ary_store(list, i, v);
    }
    rb_obj_freeze(list);
    return rb_ary_new_from_args(4, list, LONG2NUM(RARRAY_LEN(list)), len ? RARRAY_AREF(list, len - 1) : Qnil,
                                OBJ_FROZEN(list) ? Qtrue : Qfalse);
}
/* What rb_default_internal_encoding answers now (nil: none). */
static VALUE default_internal(VALUE self) {
    (void)self;
    rb_encoding *e = rb_default_internal_encoding();
    return e ? rb_enc_from_encoding(e) : Qnil;
}
/* Read the proxy flag directly, including after C/Ruby changes the owner. */
static VALUE frozen_flags(VALUE self, VALUE obj, VALUE operation) {
    (void)self;
    if (NUM2INT(operation) == 1) rb_obj_freeze(obj);
    if (NUM2INT(operation) == 2) rb_yield(obj);
    return RB_OBJ_FROZEN(obj) ? Qtrue : Qfalse;
}
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
/* A class variable read through CLASS_OF, as cgi/escape reads @@accept_charset. */
static VALUE cvar_of_class_of(VALUE self, VALUE obj, VALUE name) { (void)self; return rb_cvar_get(CLASS_OF(obj), rb_intern_str(name)); }
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
/* OBJ_FREEZE keeps the buffer (string.c resizes only in rb_str_freeze): a
 * pointer C took before still reads the bytes, and the room is still there.
 * rb_str_freeze resizes to the length. */
static VALUE freeze_keeps_room(VALUE self) {
    (void)self;
    VALUE s = rb_str_buf_new(1024);
    rb_str_cat(s, "abc", 3);
    const char *p = RSTRING_PTR(s);
    OBJ_FREEZE(s);
    long len = RSTRING_LEN(s);
    VALUE seen = rb_str_new(p, len);
    long room = (long)rb_str_capacity(s);
    VALUE t = rb_str_buf_new(1024);
    rb_str_cat(t, "abc", 3);
    rb_str_freeze(t);
    return rb_ary_new3(4, seen, LONG2NUM(room), LONG2NUM((long)rb_str_capacity(t)), RB_OBJ_FROZEN(t) ? Qtrue : Qfalse);
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

/* VALUEs held ONLY in C locals across many requests that allocate: a String
 * C made and an Array C filled, then Strings made and dropped and calls
 * that make their answers, and the two read back at the end. A collection
 * can run at any of those requests (mr_up's safepoint); the stack is all
 * that roots the two. With a block, it is yielded to halfway -- a Fiber's
 * body can pause there, in the middle of this call, while the program
 * collects -- and the loop goes on when it comes back. */
static VALUE hold_locals(VALUE self, VALUE times) {
    (void)self;
    static char junk[4096];
    long n = NUM2LONG(times);
    VALUE held = rb_str_new_cstr("held-string");
    VALUE ary = rb_ary_new();
    for (int i = 0; i < 8; i++) {
        char name[8];
        snprintf(name, sizeof name, "e%d", i);
        rb_ary_push(ary, rb_str_new_cstr(name));
    }
    long sum = 0;
    for (long i = 0; i < n; i++) {
        rb_str_new(junk, (long)sizeof(junk));
        VALUE text = rb_funcall(LONG2NUM(i), rb_intern("to_s"), 0);
        sum += RSTRING_LEN(text);
        if (i == n / 2 && rb_block_given_p()) rb_yield(LONG2NUM(i));
    }
    return rb_ary_new3(3, held, ary, LONG2NUM(sum));
}

/* C writes into a FROZEN String's buffer -- frozen is what rb_str_modify
 * refuses, not the bytes -- and then calls the interpreter, which sees them
 * (puma's parser upcases the header names of a frozen request in place). */
static VALUE write_frozen(VALUE self, VALUE str) {
    (void)self;
    char *p = RSTRING_PTR(str);
    p[0] = 'Z';
    VALUE seen = rb_funcall(str, rb_intern("dup"), 0);
    return rb_ary_new3(2, seen, str);
}

/* A long C call that only calls back through the C API -- no Ruby method in
 * between -- and makes garbage as it goes: puma's HTTP parser joining a
 * repeated header (rb_hash_aref, then rb_str_cat2 and rb_str_cat on the
 * String it found), with a 64 KB String made and dropped each turn. Answers the
 * joined String and how many collections ran while it went on. */
static VALUE join_in_c(VALUE self, VALUE times) {
    (void)self;
    static char junk[65536];
    long n = NUM2LONG(times);
    VALUE hash = rb_hash_new();
    VALUE key = rb_str_new_cstr("HTTP_X_TEST");
    rb_hash_aset(hash, key, rb_str_new_cstr("test"));
    size_t before = rb_gc_count();
    for (long i = 1; i < n; i++) {
        VALUE v = rb_hash_aref(hash, key);
        rb_str_cat2(v, ", ");
        rb_str_cat(v, "test", 4);
        rb_str_new(junk, (long)sizeof(junk));
    }
    return rb_ary_new3(2, rb_hash_aref(hash, key), SIZET2NUM(rb_gc_count() - before));
}

/* What C was lent and what it holds only in its locals, across collections
 * in the middle of the one C call: RSTRING_PTR's pointer is taken first,
 * then the call makes 64 KB Strings and calls a method, over and over (a
 * collection can run at any of those requests -- mr_up's safepoint; under
 * MERE_RUBY_GC_STRESS=1 one runs every 16th of them -- and rb_gc runs one
 * every 100 turns). After them the pointer
 * is the one RSTRING_PTR answers again, the bytes under it are the String's
 * (no collection moved, freed or rewrote what C was lent), a byte C writes
 * through it reaches the interpreter, and the String and the Array C made
 * and held only in locals are still those values. Answers [the same pointer,
 * the bytes intact, the String, the Array, the String as the interpreter
 * sees it, how many collections ran]. */
static VALUE lent_across_collections(VALUE self, VALUE str, VALUE times) {
    (void)self;
    static char junk[65536];
    long n = NUM2LONG(times);
    char *p = RSTRING_PTR(str);
    long len = RSTRING_LEN(str);
    char *copy = malloc(len > 0 ? (size_t)len : 1);
    if (!copy) rb_memerror();
    memcpy(copy, p, (size_t)len);
    VALUE held = rb_str_new_cstr("held-only-in-c");
    VALUE ary = rb_ary_new_from_args(2, rb_str_new_cstr("a"), rb_str_new_cstr("b"));
    size_t before = rb_gc_count();
    for (long i = 0; i < n; i++) {
        rb_str_new(junk, (long)sizeof(junk));
        rb_funcall(LONG2NUM(i), rb_intern("to_s"), 0);
        /* (and a collection for certain every 100th turn, on both sides:
         *  whether the garbage alone brings one about depends on the
         *  collector's limits and on the load) */
        if (i % 100 == 50) rb_gc();
    }
    size_t collections = rb_gc_count() - before;
    int same = RSTRING_PTR(str) == p;
    int intact = memcmp(p, copy, (size_t)len) == 0;
    free(copy);
    if (len > 0) p[0] = 'W';
    VALUE seen = rb_funcall(str, rb_intern("dup"), 0);
    return rb_ary_new_from_args(6, same ? Qtrue : Qfalse, intact ? Qtrue : Qfalse, held, ary, seen, SIZET2NUM(collections));
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
/* rb_protect around the block: the state it gives for each way out of it
 * (TAG_RETURN 1, TAG_BREAK 2, TAG_RAISE 6, TAG_THROW 7; 0 for a value),
 * kept for last_protect_state, and the flow then goes on with rb_jump_tag */
static int last_protect_state;
static VALUE yield_nil(VALUE arg) { (void)arg; return rb_yield(Qnil); }
static VALUE protect_state(VALUE self) {
    (void)self;
    int state = 0;
    VALUE result = rb_protect(yield_nil, Qnil, &state);
    last_protect_state = state;
    if (state) rb_jump_tag(state);
    return result;
}
static VALUE last_state(VALUE self) { (void)self; return INT2FIX(last_protect_state); }
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
/* (a function without the GVL: other Ruby threads run meanwhile; it may
 *  come back with rb_thread_call_with_gvl; a kill ends a blocking read
 *  through RUBY_UBF_IO) */
#include <ruby/thread.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
static void *nap(void *ms) {
    struct timespec t = { 0, (long)(*(long *)ms) * 1000000L };
    nanosleep(&t, NULL);
    return NULL;
}
static VALUE nogvl_nap(VALUE self, VALUE ms) {
    (void)self;
    long n = NUM2LONG(ms);
    rb_thread_call_without_gvl(nap, &n, RUBY_UBF_IO, NULL);
    return Qtrue;
}
static void *push_one(void *ary) { rb_ary_push((VALUE)ary, INT2FIX(1)); return ary; }
static void *call_back(void *ary) { return rb_thread_call_with_gvl(push_one, ary); }
static VALUE nogvl_call_back(VALUE self, VALUE ary) {
    (void)self;
    return (VALUE)rb_thread_call_without_gvl(call_back, (void *)ary, RUBY_UBF_IO, NULL);
}
/* (a function that does not end for its unblocking function: it naps to the
 *  end whatever comes) */
static void *stubborn_nap(void *ms) {
    struct timespec t = { 0, (long)(*(long *)ms) * 1000000L }, left;
    while (nanosleep(&t, &left) != 0 && errno == EINTR) t = left;
    return NULL;
}
static VALUE nogvl_stubborn(VALUE self, VALUE ms) {
    (void)self;
    long n = NUM2LONG(ms);
    rb_thread_call_without_gvl(stubborn_nap, &n, NULL, NULL);
    return Qtrue;
}
static void *raise_in_ruby(void *arg) { (void)arg; rb_raise(rb_eRuntimeError, "from with_gvl"); return NULL; }
static void *call_raising(void *arg) { return rb_thread_call_with_gvl(raise_in_ruby, arg); }
static VALUE nogvl_call_raise(VALUE self) {
    (void)self;
    rb_thread_call_without_gvl(call_raising, NULL, RUBY_UBF_IO, NULL);
    return Qfalse;
}
/* (a function that reads a __thread variable C set before the call: with no
 *  other Ruby thread alive it runs on the caller's native thread) */
static __thread int tls_slot;
static void *read_tls(void *arg) { (void)arg; return (void *)(long)tls_slot; }
static VALUE nogvl_tls(VALUE self) {
    (void)self;
    tls_slot = 42;
    return LONG2NUM((long)rb_thread_call_without_gvl(read_tls, NULL, RUBY_UBF_IO, NULL));
}
/* (errno as the function left it, read by C after the call) */
static void *read_closed(void *arg) {
    char c;
    (void)arg;
    errno = 0;
    return (void *)(long)read(-1, &c, 1);
}
static VALUE nogvl_errno(VALUE self) {
    (void)self;
    errno = 0;
    long n = (long)rb_thread_call_without_gvl(read_closed, NULL, RUBY_UBF_IO, NULL);
    return rb_ary_new_from_args(2, LONG2NUM(n), INT2FIX(errno == EBADF));
}
static void *read_one(void *fd) {
    char c;
    return (void *)(long)read(*(int *)fd, &c, 1);
}
static VALUE nogvl_read(VALUE self, VALUE fd) {
    (void)self;
    int f = NUM2INT(fd);
    return LONG2NUM((long)rb_thread_call_without_gvl(read_one, &f, RUBY_UBF_IO, NULL));
}
static VALUE hidden_const_api(VALUE self, VALUE klass, VALUE name, VALUE operation, VALUE value) {
    (void)self;
    ID id = rb_to_id(name);
    switch (NUM2INT(operation)) {
      case 0: rb_const_set(klass, id, value); return value;
      case 1: return rb_const_get(klass, id);
      case 2: return rb_const_get_at(klass, id);
      case 3: return rb_const_get_from(klass, id);
      case 4: return rb_const_defined(klass, id) ? Qtrue : Qfalse;
      case 5: return rb_const_defined_at(klass, id) ? Qtrue : Qfalse;
      case 6: return rb_const_defined_from(klass, id) ? Qtrue : Qfalse;
      case 7: return rb_const_remove(klass, id);
      default: rb_raise(rb_eArgError, "unknown constant operation");
    }
}
static VALUE native_mixin(VALUE self, VALUE target, VALUE module, VALUE operation) {
    (void)self;
    switch (NUM2INT(operation)) {
      case 0: rb_include_module(target, module); break;
      case 1: rb_prepend_module(target, module); break;
      case 2: rb_extend_object(target, module); break;
      default: rb_raise(rb_eArgError, "unknown mixin operation");
    }
    return target;
}
void Init_api_fixture(void) {
    VALUE mod = rb_define_module("ApiFixture");
    rb_define_singleton_method(mod, "native_mixin", native_mixin, 3);
    rb_define_singleton_method(mod, "frozen_flags", frozen_flags, 2);
    rb_define_singleton_method(mod, "hidden_const_api", hidden_const_api, 4);
    rb_define_singleton_method(mod, "nogvl_nap", nogvl_nap, 1);
    rb_define_singleton_method(mod, "nogvl_call_back", nogvl_call_back, 1);
    rb_define_singleton_method(mod, "nogvl_read", nogvl_read, 1);
    rb_define_singleton_method(mod, "nogvl_tls", nogvl_tls, 0);
    rb_define_singleton_method(mod, "nogvl_errno", nogvl_errno, 0);
    rb_define_singleton_method(mod, "nogvl_stubborn", nogvl_stubborn, 1);
    rb_define_singleton_method(mod, "nogvl_call_raise", nogvl_call_raise, 0);
    rb_define_singleton_method(mod, "funcall_public", funcall_public, 2);
    rb_define_singleton_method(mod, "enc_index_of", enc_index_of, 1);
    rb_define_singleton_method(mod, "define_dummy", define_dummy, 1);
    rb_define_singleton_method(mod, "fs_value", fs_value, 0);
    rb_define_singleton_method(mod, "binding_of", binding_of, 1);
    rb_define_singleton_method(mod, "null_typed", null_typed, 0);
    rb_define_singleton_method(mod, "protect_and_return", protect_and_return, 0);
    rb_define_singleton_method(mod, "protect_state", protect_state, 0);
    rb_define_singleton_method(mod, "last_state", last_state, 0);
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
    rb_define_singleton_method(mod, "check_id", check_id, 1);
    rb_define_singleton_method(mod, "check_symbol", check_symbol, 1);
    rb_define_singleton_method(mod, "push", push, 2);
    rb_define_singleton_method(mod, "append", append, 2);
    rb_define_singleton_method(mod, "length", length, 1);
    rb_define_singleton_method(mod, "aref", aref, 2);
    rb_define_singleton_method(mod, "freeze", freeze, 1);
    rb_define_singleton_method(mod, "store", store, 3);
    rb_define_singleton_method(mod, "row", row, 1);
    rb_define_singleton_method(mod, "thread_current", thread_current, 0);
    rb_define_singleton_method(mod, "big_new", big_new, 2);
    rb_define_singleton_method(mod, "zeroed_steps", zeroed_steps, 3);
    rb_define_singleton_method(mod, "zeroed_holder", zeroed_holder, 2);
    rb_define_singleton_method(mod, "zeroed_held", zeroed_held, 1);
    rb_define_singleton_method(mod, "cat_steps", cat_steps, 5);
    rb_define_singleton_method(mod, "cat_kept", cat_kept, 2);
    rb_define_singleton_method(mod, "cat_holder", cat_holder, 1);
    rb_define_singleton_method(mod, "cat_held_more", cat_held_more, 3);
    rb_define_singleton_method(mod, "big_fill", big_fill, 2);
    rb_define_singleton_method(mod, "big_resize", big_resize, 3);
    rb_define_singleton_method(mod, "big_cat", big_cat, 2);
    rb_define_singleton_method(mod, "thread_aref", thread_aref, 2);
    rb_define_singleton_method(mod, "default_internal", default_internal, 0);
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
    rb_define_singleton_method(mod, "cvar_of_class_of", cvar_of_class_of, 2);
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
    rb_define_singleton_method(mod, "freeze_keeps_room", freeze_keeps_room, 0);
    rb_define_singleton_method(mod, "resize_out_and_back", resize_out_and_back, 1);
    rb_define_singleton_method(mod, "join_in_c", join_in_c, 1);
    rb_define_singleton_method(mod, "write_frozen", write_frozen, 1);
    rb_define_singleton_method(mod, "hold_locals", hold_locals, 1);
    rb_define_singleton_method(mod, "lent_across_collections", lent_across_collections, 2);
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
