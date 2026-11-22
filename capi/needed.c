/* Functions real extensions turned out to need (bigdecimal, oj, json, date,
 * found by listing what each built library asks of the interpreter and does
 * not get): conversions by method name, hashing bytes, walking instance
 * variables, the regexp match of the calling frame, and two of util.c. */
#include "mr_capi.h"
#include "ruby/encoding.h"
#include "ruby/util.h"
#include <errno.h>
#include <limits.h>
#include <string.h>

/* ---- object.c's convert_type ----------------------------------------------
 * As in 4.0: the seven conversions ruby makes on its own (to_int, to_ary,
 * to_str, to_sym, to_hash, to_proc, to_io) are refused as "no implicit
 * conversion of X into T", any other as "can't convert X into T"; a method
 * that answers the wrong type is "can't convert X to T (X#m gives Y)". */
static int implicit_conversion(const char *method) {
    static const char *const names[] = { "to_int", "to_ary", "to_str", "to_sym", "to_hash", "to_proc", "to_io" };
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++)
        if (!strcmp(names[i], method)) return 1;
    return 0;
}
static VALUE convert_by(VALUE val, const char *tname, const char *method, int raise) {
    VALUE r = rb_check_funcall(val, rb_intern(method), 0, 0);
    if (r != Qundef) return r;
    if (!raise) return Qnil;
    const char *msg = implicit_conversion(method) ? "no implicit conversion of" : "can't convert";
    const char *cname = NIL_P(val) ? "nil" : val == Qtrue ? "true" : val == Qfalse ? "false" : NULL;
    if (cname) rb_raise(rb_eTypeError, "%s %s into %s", msg, cname, tname);
    rb_raise(rb_eTypeError, "%s %" PRIsVALUE " into %s", msg, rb_obj_class(val), tname);
}
NORETURN(static void conversion_mismatch(VALUE val, const char *tname, const char *method, VALUE result));
static void conversion_mismatch(VALUE val, const char *tname, const char *method, VALUE result) {
    VALUE cname = rb_obj_class(val);
    rb_raise(rb_eTypeError, "can't convert %" PRIsVALUE " to %s (%" PRIsVALUE "#%s gives %" PRIsVALUE ")",
             cname, tname, cname, method, rb_obj_class(result));
}
VALUE rb_convert_type(VALUE val, int type, const char *tname, const char *method) {
    if (TYPE(val) == type) return val;
    VALUE v = convert_by(val, tname, method, 1);
    if (TYPE(v) != type) conversion_mismatch(val, tname, method, v);
    return v;
}
VALUE rb_check_convert_type(VALUE val, int type, const char *tname, const char *method) {
    /* always convert T_DATA */
    if (TYPE(val) == type && type != T_DATA) return val;
    VALUE v = convert_by(val, tname, method, 0);
    if (NIL_P(v)) return Qnil;
    if (TYPE(v) != type) conversion_mismatch(val, tname, method, v);
    return v;
}

/* ---- bytes and encodings ------------------------------------------------------ */
/* A hash of bytes, different from process to process (as ruby's is seeded). */
st_index_t rb_memhash(const void *ptr, long len) {
    static char anchor;
    return st_hash(ptr, (size_t)len, (st_index_t)(uintptr_t)&anchor);
}
void rb_must_asciicompat(VALUE str) {
    rb_encoding *enc = rb_enc_get(str);
    if (!rb_enc_asciicompat(enc)) rb_raise(rb_eEncCompatError, "ASCII incompatible encoding: %s", rb_enc_name(enc));
}

/* ---- instance variables -------------------------------------------------------- */
void rb_ivar_foreach(VALUE obj, int (*func)(ID name, VALUE val, st_data_t arg), st_data_t arg) {
    if (RB_SPECIAL_CONST_P(obj)) return;
    VALUE names = rb_obj_instance_variables(obj);
    for (long i = 0; i < RARRAY_LEN(names); i++) {
        ID id = SYM2ID(rb_ary_entry(names, i));
        if (func(id, rb_ivar_get(obj, id), arg) == ST_STOP) break;
    }
}
void rb_copy_generic_ivar(VALUE clone, VALUE obj) {
    if (RB_SPECIAL_CONST_P(obj) || RB_SPECIAL_CONST_P(clone)) return;
    VALUE names = rb_obj_instance_variables(obj);
    for (long i = 0; i < RARRAY_LEN(names); i++) {
        ID id = SYM2ID(rb_ary_entry(names, i));
        rb_ivar_set(clone, id, rb_ivar_get(obj, id));
    }
}

/* ---- the last match and the last line, of the Ruby frame that called C --------- */
/* (`$~` is kept per method frame, and a C method has a frame of its own:
 *  what C reads and writes is the one of the Ruby frame that called it) */
VALUE rb_backref_get(void) { return mr_up(MR_BACKREF, 0, 0, 0, 0, 0); }
void rb_backref_set(VALUE match) { mr_up(MR_BACKREF, 1, match, 0, 0, 0); }
void rb_lastline_set(VALUE line) { rb_gv_set("$_", line); }
/* (ruby marks a match "busy" so that the next match does not reuse its
 *  object; a match here is never reused) */
void rb_match_busy(VALUE match) { (void)match; }
VALUE rb_reg_nth_match(int nth, VALUE match) {
    if (NIL_P(match)) return Qnil;
    return mr_call(match, "[]", 1, INT2FIX(nth));
}
VALUE rb_reg_new(const char *source, long len, int options) {
    return mr_call(rb_cRegexp, "new", 2, rb_str_new(source, len), INT2FIX(options));
}
VALUE rb_marshal_load(VALUE port) { return mr_call(mr_const("Marshal"), "load", 1, port); }

/* ---- util.c: digits of a base up to 36 ------------------------------------------
 * ruby_scan_digits and ruby_strtoul as CRuby's util.c has them (Ruby's
 * licence: capi/include/COPYING, BSDL). */
unsigned long ruby_scan_digits(const char *str, ssize_t len, int base, size_t *retlen, int *overflow) {
    const char *start = str;
    unsigned long ret = 0, x;
    unsigned long mul_overflow = (~(unsigned long)0) / base;

    *overflow = 0;
    if (!len) {
        *retlen = 0;
        return 0;
    }
    do {
        int d = ruby_digit36_to_number_table[(unsigned char)*str++];
        if (d == -1 || base <= d) {
            --str;
            break;
        }
        if (mul_overflow < ret) *overflow = 1;
        ret *= base;
        x = ret;
        ret += d;
        if (ret < x) *overflow = 1;
    } while (len < 0 || --len);
    *retlen = str - start;
    return ret;
}
unsigned long ruby_strtoul(const char *str, char **endptr, int base) {
    int c, b, overflow;
    int sign = 0;
    size_t len;
    unsigned long ret;
    const char *subject_found = str;

    if (base < 0 || base == 1 || 36 < base) {
        errno = EINVAL;
        return 0;
    }
    while ((c = *str) && ISSPACE(c)) str++;
    if (c == '+') {
        sign = 1;
        str++;
    }
    else if (c == '-') {
        sign = -1;
        str++;
    }
    if (str[0] == '0') {
        subject_found = str + 1;
        if (base == 0 || base == 16) {
            if (str[1] == 'x' || str[1] == 'X') {
                b = 16;
                str += 2;
            }
            else {
                b = base == 0 ? 8 : 16;
                str++;
            }
        }
        else {
            b = base;
            str++;
        }
    }
    else {
        b = base == 0 ? 10 : base;
    }
    ret = ruby_scan_digits(str, -1, b, &len, &overflow);
    if (0 < len) subject_found = str + len;
    if (endptr) *endptr = (char *)subject_found;
    if (overflow) {
        errno = ERANGE;
        return ULONG_MAX;
    }
    if (sign < 0) ret = (unsigned long)(-(long)ret);
    return ret;
}

/* ======================================================================
 * What ruby/spec's optional/capi extensions asked for: each of its
 * *_spec.c files is one library, and one function missing kept the whole
 * file's examples from running.
 * ====================================================================== */
#include "ruby/io.h"
#include "ruby/thread.h"
#include <sys/select.h>

/* ---- blocks ---------------------------------------------------------------------- */
extern VALUE mr_frame_set_block(VALUE block);
extern VALUE mr_block_function(rb_block_call_func_t func, VALUE data);
/* rb_iterate: func1(data1), with the C function `proc` as its block. */
struct iterate { VALUE (*func)(VALUE); VALUE data; };
static VALUE iterate_body(VALUE p) { struct iterate *it = (struct iterate *)p; return it->func(it->data); }
static VALUE iterate_restore(VALUE old) { mr_frame_set_block(old); return Qnil; }
VALUE rb_iterate(VALUE (*func1)(VALUE), VALUE data1, rb_block_call_func_t proc, VALUE data2) {
    struct iterate it = { func1, data1 };
    VALUE old = mr_frame_set_block(mr_block_function(proc, data2));
    return rb_ensure(iterate_body, (VALUE)&it, iterate_restore, old);
}

/* ---- classes ----------------------------------------------------------------------- */
VALUE rb_class_instance_methods(int argc, const VALUE *argv, VALUE mod) { return rb_funcallv(mod, rb_intern("instance_methods"), argc, argv); }
VALUE rb_class_public_instance_methods(int argc, const VALUE *argv, VALUE mod) { return rb_funcallv(mod, rb_intern("public_instance_methods"), argc, argv); }
VALUE rb_class_protected_instance_methods(int argc, const VALUE *argv, VALUE mod) { return rb_funcallv(mod, rb_intern("protected_instance_methods"), argc, argv); }
VALUE rb_class_private_instance_methods(int argc, const VALUE *argv, VALUE mod) { return rb_funcallv(mod, rb_intern("private_instance_methods"), argc, argv); }
void rb_free_generic_ivar(VALUE obj) {
    if (RB_SPECIAL_CONST_P(obj)) return;
    VALUE names = rb_obj_instance_variables(obj);
    for (long i = 0; i < RARRAY_LEN(names); i++) rb_funcall(obj, rb_intern("remove_instance_variable"), 1, rb_ary_entry(names, i));
}

/* ---- exceptions and where the program is ------------------------------------------- */
/* What `raise` makes of its arguments (eval.c's rb_make_exception). */
VALUE rb_make_exception(int argc, const VALUE *argv) {
    return mr_callv(mr_ruby(
        "->(*a) {\n"
        "  case a.size\n"
        "  when 0 then nil\n"
        "  when 1 then next nil if a[0].nil?\n"
        "    next RuntimeError.new(a[0]) if a[0].is_a?(String)\n"
        "    raise TypeError, 'exception class/object expected' unless a[0].respond_to?(:exception)\n"
        "    e = a[0].exception\n"
        "    raise TypeError, 'exception object expected' unless e.is_a?(Exception)\n"
        "    e\n"
        "  when 2, 3\n"
        "    raise TypeError, 'exception class/object expected' unless a[0].respond_to?(:exception)\n"
        "    e = a[0].exception(a[1])\n"
        "    raise TypeError, 'exception object expected' unless e.is_a?(Exception)\n"
        "    e.set_backtrace(a[2]) if a.size == 3\n"
        "    e\n"
        "  else raise ArgumentError, \"wrong number of arguments (given #{a.size}, expected 0..3)\"\n"
        "  end }"), rb_intern("call"), argc, argv, Qnil, 0);
}
VALUE rb_make_backtrace(void) { return rb_eval_string("caller(0)"); }
const char *rb_sourcefile(void) {
    VALUE path = rb_eval_string("caller_locations(0, 1).first&.path");
    return NIL_P(path) ? NULL : StringValueCStr(path);
}
int rb_sourceline(void) {
    VALUE line = rb_eval_string("caller_locations(0, 1).first&.lineno");
    return NIL_P(line) ? 0 : NUM2INT(line);
}
VALUE rb_lastline_get(void) { return rb_gv_get("$_"); }
VALUE rb_f_global_variables(void) { return rb_funcall(mr_main(), rb_intern("global_variables"), 0); }
VALUE rb_gc_latest_gc_info(VALUE key) { return rb_funcall(mr_const("GC"), rb_intern("latest_gc_info"), 1, key); }
VALUE rb_marshal_dump(VALUE obj, VALUE port) {
    if (NIL_P(port)) return rb_funcall(mr_const("Marshal"), rb_intern("dump"), 1, obj);
    return rb_funcall(mr_const("Marshal"), rb_intern("dump"), 2, obj, port);
}
int ruby_native_thread_p(void) { return 1; }
int ruby_thread_has_gvl_p(void) { return 1; }

/* ---- hashing ------------------------------------------------------------------------- */
st_index_t rb_hash_start(st_index_t h) {
    static char anchor;
    return st_hash_start((st_index_t)(uintptr_t)&anchor + h);
}

/* ---- Fiber ---------------------------------------------------------------------------- */
VALUE rb_fiber_new(rb_block_call_func_t func, VALUE obj) { return rb_block_call(mr_const("Fiber"), rb_intern("new"), 0, NULL, func, obj); }
VALUE rb_fiber_resume(VALUE fiber, int argc, const VALUE *argv) { return rb_funcallv(fiber, rb_intern("resume"), argc, argv); }
VALUE rb_fiber_yield(int argc, const VALUE *argv) { return rb_funcallv(mr_const("Fiber"), rb_intern("yield"), argc, argv); }
VALUE rb_fiber_current(void) { return rb_funcall(mr_const("Fiber"), rb_intern("current"), 0); }
VALUE rb_fiber_alive_p(VALUE fiber) { return rb_funcall(fiber, rb_intern("alive?"), 0); }
VALUE rb_fiber_raise(VALUE fiber, int argc, VALUE *argv) { return rb_funcallv(fiber, rb_intern("raise"), argc, argv); }

/* ---- Regexp --------------------------------------------------------------------------- */
int rb_memcicmp(const void *s1, const void *s2, long n) {
    const unsigned char *p1 = s1, *p2 = s2;
    while (n-- > 0) {
        int c1 = *p1++, c2 = *p2++;
        if (c1 >= 'A' && c1 <= 'Z') c1 += 'a' - 'A';
        if (c2 >= 'A' && c2 <= 'Z') c2 += 'a' - 'A';
        if (c1 != c2) return c1 < c2 ? -1 : 1;
    }
    return 0;
}
/* (re =~ str: the position, and `$~` of the Ruby frame that called C) */
VALUE rb_reg_match(VALUE re, VALUE str) {
    if (NIL_P(str)) { rb_backref_set(Qnil); return Qnil; }
    VALUE match = rb_funcall(re, rb_intern("match"), 1, str);
    rb_backref_set(match);
    return NIL_P(match) ? Qnil : rb_funcall(match, rb_intern("begin"), 1, INT2FIX(0));
}
int rb_reg_options(VALUE re) { return NUM2INT(rb_funcall(re, rb_intern("options"), 0)); }
VALUE rb_reg_regcomp(VALUE str) { return rb_funcall(rb_cRegexp, rb_intern("new"), 1, str); }

/* ---- Set (the C API 4.0 added) ----------------------------------------------------------- */
VALUE rb_set_new(void) { return rb_funcall(mr_const("Set"), rb_intern("new"), 0); }
VALUE rb_set_new_capa(size_t capa) { (void)capa; return rb_set_new(); }
/* What set.c does to a Set's table, without asking the Set: an override of
 * add?, include?, delete?, size, each or to_a -- in a subclass or a
 * singleton -- does not change what C adds, finds, removes, counts or walks.
 * A Set here is its table, the Hash in @hash (the interpreter's set.rb), and
 * the Hash functions are the C API's own (Hash's operations, not its
 * overrides). A frozen Set refuses as ruby's does. */
static VALUE set_table(VALUE set) {
    VALUE table = rb_ivar_get(set, rb_intern("@hash"));
    if (!RB_TYPE_P(table, T_HASH))
        rb_raise(rb_eTypeError, "wrong argument type %" PRIsVALUE " (expected Set)", rb_obj_class(set));
    return table;
}
bool rb_set_lookup(VALUE set, VALUE element) { return rb_hash_lookup2(set_table(set), element, Qundef) != Qundef; }
bool rb_set_add(VALUE set, VALUE element) {
    rb_check_frozen(set);
    VALUE table = set_table(set);
    if (rb_hash_lookup2(table, element, Qundef) != Qundef) return false;
    rb_hash_aset(table, element, Qtrue);
    return true;
}
bool rb_set_delete(VALUE set, VALUE element) {
    rb_check_frozen(set);
    VALUE table = set_table(set);
    if (rb_hash_lookup2(table, element, Qundef) == Qundef) return false;
    rb_hash_delete(table, element);
    return true;
}
VALUE rb_set_clear(VALUE set) {
    rb_check_frozen(set);
    rb_hash_clear(set_table(set));
    return set;
}
size_t rb_set_size(VALUE set) { return rb_hash_size_num(set_table(set)); }
void rb_set_foreach(VALUE set, int (*func)(VALUE element, VALUE arg), VALUE arg) {
    VALUE elements = mr_callh(set_table(set), "keys", 0);
    for (long i = 0; i < RARRAY_LEN(elements); i++)
        if (func(rb_ary_entry(elements, i), arg) == ST_STOP) break;
}

/* ---- Strings and encodings ---------------------------------------------------------------- */
/* (ruby frees the buffer; here the struct C sees is the interpreter's to drop) */
void rb_str_free(VALUE str) { (void)str; }
int rb_uv_to_utf8(char buf[6], unsigned long uv) {
    if (uv <= 0x7f) { buf[0] = (char)uv; return 1; }
    if (uv <= 0x7ff) { buf[0] = (char)(0xc0 | (uv >> 6)); buf[1] = (char)(0x80 | (uv & 0x3f)); return 2; }
    if (uv <= 0xffff) {
        buf[0] = (char)(0xe0 | (uv >> 12)); buf[1] = (char)(0x80 | ((uv >> 6) & 0x3f)); buf[2] = (char)(0x80 | (uv & 0x3f));
        return 3;
    }
    if (uv <= 0x1fffff) {
        buf[0] = (char)(0xf0 | (uv >> 18)); buf[1] = (char)(0x80 | ((uv >> 12) & 0x3f));
        buf[2] = (char)(0x80 | ((uv >> 6) & 0x3f)); buf[3] = (char)(0x80 | (uv & 0x3f));
        return 4;
    }
    if (uv <= 0x3ffffff) {
        buf[0] = (char)(0xf8 | (uv >> 24)); buf[1] = (char)(0x80 | ((uv >> 18) & 0x3f)); buf[2] = (char)(0x80 | ((uv >> 12) & 0x3f));
        buf[3] = (char)(0x80 | ((uv >> 6) & 0x3f)); buf[4] = (char)(0x80 | (uv & 0x3f));
        return 5;
    }
    if (uv <= 0x7fffffff) {
        buf[0] = (char)(0xfc | (uv >> 30)); buf[1] = (char)(0x80 | ((uv >> 24) & 0x3f)); buf[2] = (char)(0x80 | ((uv >> 18) & 0x3f));
        buf[3] = (char)(0x80 | ((uv >> 12) & 0x3f)); buf[4] = (char)(0x80 | ((uv >> 6) & 0x3f)); buf[5] = (char)(0x80 | (uv & 0x3f));
        return 6;
    }
    rb_raise(rb_eRangeError, "pack(U): value out of range");
}

/* ---- IO -------------------------------------------------------------------------------------- */
VALUE rb_io_closed_p(VALUE io) { return rb_funcall(io, rb_intern("closed?"), 0); }
int rb_io_mode(VALUE io) {
    rb_io_t *fptr;
    RB_IO_POINTER(io, fptr);
    return fptr->mode;
}
VALUE rb_io_path(VALUE io) {
    if (!rb_respond_to(io, rb_intern("path"))) return Qnil;
    return rb_funcall(io, rb_intern("path"), 0);
}
/* An IO of class `klass` on a descriptor the caller opened. */
VALUE rb_io_open_descriptor(VALUE klass, int descriptor, int mode, VALUE path, VALUE timeout, struct rb_io_encoding *encoding) {
    (void)path; (void)encoding;
    const char *how = (mode & FMODE_READWRITE) == FMODE_READWRITE ? "r+" : (mode & FMODE_WRITABLE) ? ((mode & FMODE_APPEND) ? "a" : "w") : "r";
    /* (FMODE_EXTERNAL: the descriptor stays the caller's -- the IO does not
     *  close it, at #close or when it is collected) */
    VALUE args[3] = { INT2NUM(descriptor), rb_str_new_cstr(how), Qnil };
    int argc = 2, flags = 0;
    if (mode & FMODE_EXTERNAL) {
        args[2] = rb_hash_new();
        rb_hash_aset(args[2], ID2SYM(rb_intern("autoclose")), Qfalse);
        argc = 3;
        flags = MR_SEND_KW;
    }
    VALUE io = mr_callv(klass, rb_intern("for_fd"), argc, args, Qnil, flags);
    if (mode & FMODE_BINMODE) rb_funcall(io, rb_intern("binmode"), 0);
    if (mode & FMODE_SYNC) rb_funcall(io, rb_intern("sync="), 1, Qtrue);
    if (!NIL_P(timeout)) rb_funcall(io, rb_intern("timeout="), 1, timeout);
    return io;
}

/* The descriptor sets of thread.c, for more descriptors than FD_SETSIZE:
 * as CRuby has them (Ruby's licence: capi/include/COPYING, BSDL). */
#ifndef howmany
# define howmany(x, y) (((x) + ((y) - 1)) / (y))
#endif
void rb_fd_init(rb_fdset_t *fds) {
    fds->maxfd = 0;
    fds->fdset = ALLOC(fd_set);
    FD_ZERO(fds->fdset);
}
void rb_fd_term(rb_fdset_t *fds) {
    xfree(fds->fdset);
    fds->maxfd = 0;
    fds->fdset = 0;
}
void rb_fd_zero(rb_fdset_t *fds) {
    if (fds->fdset) MEMZERO(fds->fdset, fd_mask, howmany(fds->maxfd, NFDBITS));
}
static void fd_resize(int n, rb_fdset_t *fds) {
    size_t m = howmany(n + 1, NFDBITS) * sizeof(fd_mask);
    size_t o = howmany(fds->maxfd, NFDBITS) * sizeof(fd_mask);
    if (m < sizeof(fd_set)) m = sizeof(fd_set);
    if (o < sizeof(fd_set)) o = sizeof(fd_set);
    if (m > o) {
        fds->fdset = xrealloc(fds->fdset, m);
        memset((char *)fds->fdset + o, 0, m - o);
    }
    if (n >= fds->maxfd) fds->maxfd = n + 1;
}
void rb_fd_set(int n, rb_fdset_t *fds) {
    fd_resize(n, fds);
    FD_SET(n, fds->fdset);
}
void rb_fd_clr(int n, rb_fdset_t *fds) {
    if (n >= fds->maxfd) return;
    FD_CLR(n, fds->fdset);
}
int rb_fd_isset(int n, const rb_fdset_t *fds) {
    if (n >= fds->maxfd) return 0;
    return FD_ISSET(n, fds->fdset) != 0;
}
void rb_fd_copy(rb_fdset_t *dst, const fd_set *src, int max) {
    size_t size = howmany(max, NFDBITS) * sizeof(fd_mask);
    if (size < sizeof(fd_set)) size = sizeof(fd_set);
    dst->maxfd = max;
    dst->fdset = xrealloc(dst->fdset, size);
    memcpy(dst->fdset, src, size);
}
void rb_fd_dup(rb_fdset_t *dst, const rb_fdset_t *src) {
    size_t size = howmany(rb_fd_max(src), NFDBITS) * sizeof(fd_mask);
    if (size < sizeof(fd_set)) size = sizeof(fd_set);
    dst->maxfd = src->maxfd;
    dst->fdset = xrealloc(dst->fdset, size);
    memcpy(dst->fdset, src->fdset, size);
}
int rb_fd_select(int n, rb_fdset_t *readfds, rb_fdset_t *writefds, rb_fdset_t *exceptfds, struct timeval *timeout) {
    fd_set *r = NULL, *w = NULL, *e = NULL;
    if (readfds) { fd_resize(n - 1, readfds); r = rb_fd_ptr(readfds); }
    if (writefds) { fd_resize(n - 1, writefds); w = rb_fd_ptr(writefds); }
    if (exceptfds) { fd_resize(n - 1, exceptfds); e = rb_fd_ptr(exceptfds); }
    return select(n, r, w, e, timeout);
}
/* Waiting on descriptors, with the other threads running meanwhile: threads
 * here take turns on one native thread, so a select(2) of C's own would stop
 * them all. The wait is the interpreter's (IO.select, on IOs that name the
 * descriptors and do not close them), and its answer is put back into the
 * sets. */
static VALUE fd_ios(int nfds, rb_fdset_t *set) {
    VALUE ios = rb_ary_new();
    if (!set) return ios;
    for (int fd = 0; fd < nfds; fd++)
        if (rb_fd_isset(fd, set))
            rb_ary_push(ios, rb_funcall(mr_ruby("->(fd) { IO.for_fd(fd, autoclose: false) }"), rb_intern("call"), 1, INT2NUM(fd)));
    return ios;
}
static int fd_answer(rb_fdset_t *set, VALUE asked, VALUE ready) {
    int count = 0;
    if (!set) return 0;
    for (long i = 0; i < RARRAY_LEN(asked); i++) {
        VALUE io = rb_ary_entry(asked, i);
        int fd = NUM2INT(rb_funcall(io, rb_intern("fileno"), 0));
        if (!NIL_P(ready) && RTEST(rb_funcall(ready, rb_intern("include?"), 1, io))) count++;
        else rb_fd_clr(fd, set);
    }
    return count;
}
int rb_thread_fd_select(int nfds, rb_fdset_t *rfds, rb_fdset_t *wfds, rb_fdset_t *efds, struct timeval *timeout) {
    VALUE r = fd_ios(nfds, rfds), w = fd_ios(nfds, wfds), e = fd_ios(nfds, efds);
    VALUE wait = timeout ? DBL2NUM((double)timeout->tv_sec + (double)timeout->tv_usec / 1e6) : Qnil;
    VALUE ready = rb_funcall(rb_cIO, rb_intern("select"), 4, r, w, e, wait);
    int count = 0;
    count += fd_answer(rfds, r, NIL_P(ready) ? Qnil : rb_ary_entry(ready, 0));
    count += fd_answer(wfds, w, NIL_P(ready) ? Qnil : rb_ary_entry(ready, 1));
    count += fd_answer(efds, e, NIL_P(ready) ? Qnil : rb_ary_entry(ready, 2));
    return count;
}
static int wait_one(int fd, int writable) {
    if (fd < 0) rb_raise(rb_eIOError, "closed stream");
    VALUE io = rb_funcall(mr_ruby("->(fd) { IO.for_fd(fd, autoclose: false) }"), rb_intern("call"), 1, INT2NUM(fd));
    VALUE ios = rb_ary_new_from_args(1, io), none = rb_ary_new();
    rb_funcall(rb_cIO, rb_intern("select"), 3, writable ? none : ios, writable ? ios : none, none);
    return 1;
}
int rb_thread_wait_fd(int fd) { return wait_one(fd, 0); }
int rb_thread_fd_writable(int fd) { return wait_one(fd, 1); }

/* ---- allocators and encodings ----------------------------------------------------------- */
extern void *mr_registered_function(long number);
/* The C function that allocates a class's instances, its own or inherited. */
/* (...and for a class no C allocator was defined on, ruby's own: a function
 *  that makes an instance of the class it is given the builtin way. NULL is
 *  for a class whose allocator was taken away, rb_undef_alloc_func.) */
static VALUE default_allocator(VALUE klass) { return mr_up(MR_OBJECT_NEW, klass, 1, 0, 0, 0); }
rb_alloc_func_t rb_get_alloc_func(VALUE klass) {
    long number = (long)(intptr_t)mr_up(MR_DEFINE_ALLOC, klass, (VALUE)-2L, 0, 0, 0);
    if (number == -2) return NULL;
    return number < 0 ? default_allocator : (rb_alloc_func_t)mr_registered_function(number);
}
/* The first byte of the character that `s` is in (or is the first byte of). */
OnigUChar *onigenc_get_left_adjust_char_head(OnigEncoding enc, const OnigUChar *start, const OnigUChar *s, const OnigUChar *end) {
    const char *p = (const char *)start;
    if (s <= start) return (OnigUChar *)s;
    while (p < (const char *)s) {
        int n = rb_enc_mbclen(p, (const char *)end, enc);
        if (n < 1) n = 1;
        if (p + n > (const char *)s) break;
        p += n;
    }
    return (OnigUChar *)p;
}

/* ---- global variables whose value C keeps -------------------------------------------------
 * rb_define_variable ties `$name` to a C VALUE; the hooked and virtual kinds
 * tie it to a pair of C functions. The interpreter calls one registered
 * function for every such variable (gvar_access) with the name, whether it
 * is a write, and the value; the record found by the name says which C
 * getter or setter that is. variable.c's defaults are here as ruby has
 * them. */
struct kept_global { ID id; VALUE *data; rb_gvar_getter_t *getter; rb_gvar_setter_t *setter; };
static struct kept_global *kept_globals;
static long kept_count, kept_cap;
VALUE rb_gvar_undef_getter(ID id, VALUE *data) { (void)id; (void)data; return Qnil; }
void rb_gvar_undef_setter(VALUE val, ID id, VALUE *data) { (void)val; (void)id; (void)data; }
void rb_gvar_undef_marker(VALUE *var) { (void)var; }
VALUE rb_gvar_val_getter(ID id, VALUE *data) { (void)id; return (VALUE)data; }
void rb_gvar_val_setter(VALUE val, ID id, VALUE *data) { (void)val; (void)id; (void)data; }
void rb_gvar_val_marker(VALUE *var) { if (var) rb_gc_mark((VALUE)var); }
VALUE rb_gvar_var_getter(ID id, VALUE *var) { (void)id; return var ? *var : Qnil; }
void rb_gvar_var_setter(VALUE val, ID id, VALUE *var) { (void)id; *var = val; }
void rb_gvar_var_marker(VALUE *var) { if (var) rb_gc_mark(*var); }
void rb_gvar_readonly_setter(VALUE val, ID id, VALUE *data) {
    (void)val; (void)data;
    rb_name_error(id, "%" PRIsVALUE " is a read-only variable", rb_id2str(id));
}
static VALUE gvar_access(VALUE self, VALUE slot, VALUE write, VALUE value) {
    (void)self;
    VALUE name = rb_str_plus(rb_str_new_cstr("$"), slot);
    ID id = rb_intern_str(name);
    for (long i = 0; i < kept_count; i++) {
        struct kept_global *g = &kept_globals[i];
        if (g->id != id) continue;
        if (!RTEST(write)) return g->getter(id, g->data);
        g->setter(value, id, g->data);
        return value;
    }
    rb_bug("a global variable C keeps has no record: %s", RSTRING_PTR(name));
}
/* The record is kept under the name the interpreter keeps the variable
 * under, which it answers: for a name aliased before C defines it
 * (`alias $dest $src`), the original's -- that is the name gvar_access is
 * called with. */
static void keep_global(const char *name, VALUE *data, rb_gvar_getter_t *getter, rb_gvar_setter_t *setter) {
    static long access = -1;
    if (access < 0) access = mr_register_function((void *)gvar_access, 3);
    const char *bare = name[0] == '$' ? name + 1 : name;
    mr_put_text(bare);
    VALUE slot = mr_up(MR_DEFINE_GVAR, (VALUE)access, 0, 0, 0, 0);
    ID id = rb_intern_str(rb_str_plus(rb_str_new_cstr("$"), slot));
    for (long i = 0; i < kept_count; i++)
        if (kept_globals[i].id == id) { kept_globals[i] = (struct kept_global){ id, data, getter, setter }; return; }
    if (kept_count == kept_cap) {
        kept_cap = kept_cap ? kept_cap * 2 : 8;
        kept_globals = realloc(kept_globals, sizeof(*kept_globals) * (size_t)kept_cap);
        if (!kept_globals) rb_memerror();
    }
    kept_globals[kept_count++] = (struct kept_global){ id, data, getter, setter };
}
void rb_define_hooked_variable(const char *name, VALUE *var, rb_gvar_getter_t *getter, rb_gvar_setter_t *setter) {
    /* (the VALUE C holds in the variable lives as long as the process does) */
    if (var) rb_gc_register_address(var);
    keep_global(name, var, getter ? getter : rb_gvar_var_getter, setter ? setter : rb_gvar_var_setter);
}
void rb_define_variable(const char *name, VALUE *var) { rb_define_hooked_variable(name, var, 0, 0); }
void rb_define_readonly_variable(const char *name, const VALUE *var) {
    rb_define_hooked_variable(name, (VALUE *)var, 0, rb_gvar_readonly_setter);
}
void rb_define_virtual_variable(const char *name, rb_gvar_getter_t *getter, rb_gvar_setter_t *setter) {
    keep_global(name, 0, getter ? getter : rb_gvar_val_getter, setter ? setter : rb_gvar_readonly_setter);
}

/* What io-console and prism asked for (the default gems Rails' lock pins). */

/* the version this interpreter reports as RUBY_VERSION -- a contract in
 * capi/check/api.rb compares the two, so they cannot drift apart */
const char ruby_version[] = "4.0.9";

/* the IO that writes for io: io itself, unless it is a duplex stream whose
 * writing goes to a descriptor of its own (a popen "r+": @__io_wfd), which
 * ruby keeps as a separate IO -- made once, for that descriptor, and kept on
 * io so that the same one comes back */
VALUE rb_io_get_write_io(VALUE io) {
    VALUE wfd = rb_ivar_get(io, rb_intern("@__io_wfd"));
    if (NIL_P(wfd)) return io;
    VALUE w = rb_ivar_get(io, rb_intern("@__capi_wio"));
    if (NIL_P(w)) {
        VALUE kw = rb_hash_new();
        rb_hash_aset(kw, ID2SYM(rb_intern("autoclose")), Qfalse);
        VALUE argv[3] = { wfd, rb_str_new_cstr("w"), kw };
        w = rb_funcallv_kw(rb_cIO, rb_intern("for_fd"), 3, argv, RB_PASS_KEYWORDS);
        rb_ivar_set(io, rb_intern("@__capi_wio"), w);
    }
    return w;
}

/* bytes already read from the descriptor and not yet handed out: the IO's
 * own read buffer (@__io_rbuf), which a read takes from before the kernel */
int rb_io_read_pending(rb_io_t *fptr) {
    if (!fptr) return 0;
    VALUE buf = rb_ivar_get(fptr->self, rb_intern("@__io_rbuf"));
    return RB_TYPE_P(buf, T_STRING) ? (int)RSTRING_LEN(buf) : 0;
}
