/* String. Its bytes live in the interpreter; RSTRING() gives C a buffer of
 * them (mirror.c), and what C writes there goes back at the next crossing.
 * The functions that only build or grow a String through C pointers
 * (rb_str_cat, rb_str_resize, rb_str_set_len) work on that buffer alone. */
#include "mr_capi.h"
#include <string.h>

/* ---- making ---------------------------------------------------------------- */
static VALUE make(const char *ptr, long len, int enc) {
    if (len < 0) rb_raise(rb_eArgError, "negative string size (or size too big)");
    if (ptr) mr_put_bytes(ptr, len);
    else {
        char *zeros = ruby_xcalloc(1, (size_t)len + 1);
        mr_put_bytes(zeros, len);
        ruby_xfree(zeros);
    }
    mr_put_text(mr_enc_name_of_index(enc));
    return mr_up1(MR_STR_NEW, (VALUE)enc);
}
#undef rb_str_new
#undef rb_str_new_cstr
#undef rb_usascii_str_new
#undef rb_usascii_str_new_cstr
#undef rb_utf8_str_new
#undef rb_utf8_str_new_cstr
#undef rb_str_new_static
#undef rb_usascii_str_new_static
#undef rb_utf8_str_new_static
#undef rb_external_str_new_cstr
#undef rb_locale_str_new_cstr
#undef rb_str_buf_new_cstr
#undef rb_str_cat_cstr
#undef rb_str_buf_cat
#undef rb_str_cat2
#undef rb_str_buf_cat2
#undef rb_str_dup_frozen
#undef rb_tainted_str_new_cstr
#undef rb_enc_str_new
#undef rb_enc_str_new_cstr
#undef rb_str_new_frozen
#undef rb_str_dup_frozen
VALUE rb_str_new(const char *ptr, long len) { return make(ptr, len, rb_ascii8bit_encindex()); }
VALUE rb_str_new_cstr(const char *ptr) {
    if (!ptr) rb_raise(rb_eArgError, "NULL pointer given");
    return make(ptr, (long)strlen(ptr), rb_ascii8bit_encindex());
}
VALUE rb_str_new_static(const char *ptr, long len) { return make(ptr, len, rb_ascii8bit_encindex()); }
VALUE rb_usascii_str_new(const char *ptr, long len) { return make(ptr, len, rb_usascii_encindex()); }
VALUE rb_usascii_str_new_cstr(const char *ptr) { return make(ptr, (long)strlen(ptr), rb_usascii_encindex()); }
VALUE rb_usascii_str_new_static(const char *ptr, long len) { return make(ptr, len, rb_usascii_encindex()); }
VALUE rb_utf8_str_new(const char *ptr, long len) { return make(ptr, len, rb_utf8_encindex()); }
VALUE rb_utf8_str_new_cstr(const char *ptr) { return make(ptr, (long)strlen(ptr), rb_utf8_encindex()); }
VALUE rb_utf8_str_new_static(const char *ptr, long len) { return make(ptr, len, rb_utf8_encindex()); }
VALUE rb_enc_str_new(const char *ptr, long len, rb_encoding *enc) { return make(ptr, len, enc ? rb_enc_to_index(enc) : rb_ascii8bit_encindex()); }
VALUE rb_enc_str_new_cstr(const char *ptr, rb_encoding *enc) { return rb_enc_str_new(ptr, (long)strlen(ptr), enc); }
VALUE rb_enc_str_new_static(const char *ptr, long len, rb_encoding *enc) { return rb_enc_str_new(ptr, len, enc); }
VALUE rb_external_str_new(const char *ptr, long len) { return rb_enc_str_new(ptr, len, rb_default_external_encoding()); }
VALUE rb_external_str_new_cstr(const char *ptr) { return rb_external_str_new(ptr, (long)strlen(ptr)); }
VALUE rb_external_str_new_with_enc(const char *ptr, long len, rb_encoding *enc) { return rb_enc_str_new(ptr, len, enc); }
VALUE rb_locale_str_new(const char *ptr, long len) { return rb_enc_str_new(ptr, len, rb_locale_encoding()); }
VALUE rb_locale_str_new_cstr(const char *ptr) { return rb_locale_str_new(ptr, (long)strlen(ptr)); }
VALUE rb_filesystem_str_new(const char *ptr, long len) { return rb_enc_str_new(ptr, len, rb_filesystem_encoding()); }
VALUE rb_filesystem_str_new_cstr(const char *ptr) { return rb_filesystem_str_new(ptr, (long)strlen(ptr)); }
VALUE rb_str_buf_new(long capa) {
    VALUE str = make("", 0, rb_ascii8bit_encindex());
    if (capa > 0) mr_string_reserve(str, capa);
    return str;
}
VALUE rb_str_buf_new_cstr(const char *ptr) { return rb_str_new_cstr(ptr); }
VALUE rb_str_tmp_new(long len) { return rb_str_new(NULL, len); }
VALUE rb_str_new_with_class(VALUE obj, const char *ptr, long len) {
    VALUE str = rb_enc_str_new(ptr, len, rb_enc_get(obj));
    VALUE klass = rb_obj_class(obj);
    return klass == rb_cString ? str : mr_call(klass, "new", 1, str);
}
VALUE rb_interned_str(const char *ptr, long len) { return mr_call(rb_usascii_str_new(ptr, len), "-@", 0); }
VALUE rb_interned_str_cstr(const char *ptr) { return rb_interned_str(ptr, (long)strlen(ptr)); }
VALUE rb_enc_interned_str(const char *ptr, long len, rb_encoding *enc) { return mr_call(rb_enc_str_new(ptr, len, enc), "-@", 0); }
VALUE rb_enc_interned_str_cstr(const char *ptr, rb_encoding *enc) { return rb_enc_interned_str(ptr, (long)strlen(ptr), enc); }
VALUE rb_str_to_interned_str(VALUE str) { return mr_calls(str, "-@", 0); }

/* ---- through the buffer ------------------------------------------------------ */
void rb_str_modify(VALUE str) {
    if (RB_OBJ_FROZEN(str)) rb_error_frozen_object(str);
}
void rb_str_modify_expand(VALUE str, long expand) {
    if (expand < 0) rb_raise(rb_eArgError, "negative expanding string size");
    rb_str_modify(str);
    long len = RSTRING_LEN(str);
    if (expand >= LONG_MAX - len) rb_raise(rb_eArgError, "string size too big");
    if (expand > 0) mr_string_reserve(str, len + expand);
}
size_t rb_str_capacity(VALUE str) { return (size_t)mr_string_capacity(str); }
void rb_str_set_len(VALUE str, long len) {
    rb_str_modify(str);
    long capa = mr_string_capacity(str);
    if (len > capa || len < 0) rb_bug("probable buffer overflow: %ld for %ld", len, capa);
    RSTRING(str)->len = len;
    memset(RSTRING_PTR(str) + len, 0, (size_t)mr_string_terminator(str));
}
VALUE rb_str_resize(VALUE str, long len) {
    if (len < 0) rb_raise(rb_eArgError, "negative string size (or size too big)");
    rb_str_modify(str);
    mr_string_resize(str, len);
    return str;
}
VALUE rb_str_cat(VALUE str, const char *ptr, long len) {
    if (len < 0) rb_raise(rb_eArgError, "negative string size (or size too big)");
    if (len == 0) { rb_str_modify(str); return str; }
    rb_str_modify(str);
    long old = RSTRING_LEN(str);
    if (old > LONG_MAX - len) rb_raise(rb_eArgError, "string sizes too big");
    /* (ptr may point into this very buffer, which the growing can move) */
    const char *base = RSTRING_PTR(str);
    long inside = (ptr >= base && ptr <= base + old) ? (long)(ptr - base) : -1;
    mr_string_grow(str, old + len);
    char *p = RSTRING_PTR(str);
    if (inside >= 0) ptr = p + inside;
    memmove(p + old, ptr, (size_t)len);
    RSTRING(str)->len = old + len;
    memset(p + old + len, 0, (size_t)mr_string_terminator(str));
    return str;
}
VALUE rb_str_cat_cstr(VALUE str, const char *ptr) { return rb_str_cat(str, ptr, (long)strlen(ptr)); }
VALUE rb_str_cat2(VALUE str, const char *ptr) { return rb_str_cat(str, ptr, (long)strlen(ptr)); }
VALUE rb_str_buf_cat(VALUE str, const char *ptr, long len) { return rb_str_cat(str, ptr, len); }
VALUE rb_str_buf_cat2(VALUE str, const char *ptr) { return rb_str_cat(str, ptr, (long)strlen(ptr)); }
VALUE rb_str_buf_cat_ascii(VALUE str, const char *ptr) { return rb_str_cat(str, ptr, (long)strlen(ptr)); }
VALUE rb_enc_str_buf_cat(VALUE str, const char *ptr, long len, rb_encoding *enc) {
    VALUE piece = rb_enc_str_new(ptr, len, enc);
    return rb_str_append(str, piece);
}

/* ---- by way of the interpreter ------------------------------------------------- */
static VALUE changed(VALUE str) { mr_mirror_forget(str); return str; }
VALUE rb_str_append(VALUE str, VALUE other) {
    StringValue(other);
    mr_calls(str, "<<", 1, other);
    return changed(str);
}
VALUE rb_str_buf_append(VALUE str, VALUE other) { return rb_str_append(str, other); }
VALUE rb_str_concat(VALUE str, VALUE other) { mr_calls(str, "<<", 1, other); return changed(str); }
VALUE rb_str_replace(VALUE str, VALUE other) { mr_calls(str, "replace", 1, other); return changed(str); }
void rb_str_update(VALUE str, long beg, long len, VALUE val) { mr_calls(str, "[]=", 3, LONG2NUM(beg), LONG2NUM(len), val); changed(str); }
VALUE rb_str_dup(VALUE str) { return mr_calls(str, "dup", 0); }
VALUE rb_str_resurrect(VALUE str) { return mr_calls(str, "+@", 0); }
VALUE rb_str_plus(VALUE a, VALUE b) { return mr_calls(a, "+", 1, b); }
VALUE rb_str_times(VALUE str, VALUE n) { return mr_calls(str, "*", 1, n); }
VALUE rb_str_length(VALUE str) { return mr_calls(str, "length", 0); }
long rb_str_strlen(VALUE str) { return NUM2LONG(mr_calls(str, "length", 0)); }
VALUE rb_str_substr(VALUE str, long beg, long len) { return mr_calls(str, "[]", 2, LONG2NUM(beg), LONG2NUM(len)); }
VALUE rb_str_subseq(VALUE str, long beg, long len) { return mr_calls(str, "byteslice", 2, LONG2NUM(beg), LONG2NUM(len)); }
long rb_str_offset(VALUE str, long pos) {
    VALUE head = mr_calls(str, "[]", 2, INT2FIX(0), LONG2NUM(pos));
    return NIL_P(head) ? RSTRING_LEN(str) : RSTRING_LEN(head);
}
long rb_str_sublen(VALUE str, long pos) { return rb_str_strlen(mr_calls(str, "byteslice", 2, INT2FIX(0), LONG2NUM(pos))); }
int rb_str_cmp(VALUE a, VALUE b) { return NUM2INT(mr_calls(a, "<=>", 1, b)); }
VALUE rb_str_equal(VALUE a, VALUE b) { return RTEST(mr_calls(a, "==", 1, b)) ? Qtrue : Qfalse; }
st_index_t rb_str_hash(VALUE str) { return (st_index_t)NUM2LONG(mr_calls(str, "hash", 0)); }
int rb_str_hash_cmp(VALUE a, VALUE b) { return !RTEST(mr_calls(a, "eql?", 1, b)); }
VALUE rb_str_inspect(VALUE str) { return mr_calls(str, "inspect", 0); }
VALUE rb_str_dump(VALUE str) { return mr_calls(str, "dump", 0); }
VALUE rb_str_split(VALUE str, const char *sep) { return mr_calls(str, "split", 1, rb_str_new_cstr(sep)); }
VALUE rb_str_freeze(VALUE str) { return rb_obj_freeze(str); }
VALUE rb_str_new_frozen(VALUE str) {
    if (RB_OBJ_FROZEN(str)) return str;
    return rb_obj_freeze(rb_str_dup(str));
}
VALUE rb_str_dup_frozen(VALUE str) { return rb_str_new_frozen(str); }
VALUE rb_str_new_shared(VALUE str) { return rb_str_dup(str); }
VALUE rb_str_succ(VALUE str) { return mr_calls(str, "succ", 0); }
VALUE rb_str_scrub(VALUE str, VALUE repl) { return NIL_P(repl) ? mr_calls(str, "scrub", 0) : mr_calls(str, "scrub", 1, repl); }
VALUE rb_str_ellipsize(VALUE str, long len) {
    if (len < 0) rb_raise(rb_eIndexError, "negative length %ld", len);
    return mr_call(mr_ruby("->(s, n) { d = '...'.encode(s.encoding); s.length <= n ? s : n <= 3 ? d[0, n] : s[0, n - 3] + d }"), "call", 2, str, LONG2NUM(len));
}
VALUE rb_str_drop_bytes(VALUE str, long len) { mr_calls(str, "replace", 1, mr_calls(str, "byteslice", 2, LONG2NUM(len), LONG2NUM(RSTRING_LEN(str)))); return changed(str); }
VALUE rb_str_locktmp(VALUE str) { return str; }
VALUE rb_str_unlocktmp(VALUE str) { return str; }
VALUE rb_str_export(VALUE str) { return str; }
VALUE rb_str_export_locale(VALUE str) { return str; }
VALUE rb_str_encode(VALUE str, VALUE to, int ecflags, VALUE ecopts) {
    (void)ecflags;
    if (NIL_P(ecopts)) return mr_calls(str, "encode", 1, to);
    VALUE argv[2] = { to, ecopts };
    return mr_callv(str, rb_intern("encode"), 2, argv, Qnil, MR_SEND_KW);
}
/* string.c's rb_str_conv_enc: the same object when there is nothing to
 * convert, a relabelled copy when it is ASCII alone, and the String itself
 * when the conversion cannot be done. */
VALUE rb_str_conv_enc(VALUE str, rb_encoding *from, rb_encoding *to) {
    if (!to) return str;
    if (!from) from = rb_enc_get(str);
    if (from == to) return str;
    /* (ASCII alone as `from` reads it: 7-bit bytes of an ASCII-compatible encoding) */
    int ascii = rb_enc_asciicompat(from);
    if (ascii) {
        const char *p = RSTRING_PTR(str);
        for (long i = 0, n = RSTRING_LEN(str); i < n; i++) if ((unsigned char)p[i] >= 0x80) { ascii = 0; break; }
    }
    if ((rb_enc_asciicompat(to) && ascii) || to == rb_ascii8bit_encoding()) {
        if (rb_enc_get(str) != to) {
            str = rb_str_dup(str);
            rb_enc_associate(str, to);
        }
        return str;
    }
    VALUE args[3] = { str, rb_enc_from_encoding(to), rb_enc_from_encoding(from) };
    return mr_callv(mr_ruby("->(s, to, from) { s.encode(to, from) rescue s }"), rb_intern("call"), 3, args, Qnil, 0);
}
VALUE rb_str_conv_enc_opts(VALUE str, rb_encoding *from, rb_encoding *to, int ecflags, VALUE ecopts) {
    (void)ecflags; (void)ecopts;
    return rb_str_conv_enc(str, from, to);
}
/* file.c's rb_str_encode_ospath: a path as the OS takes it. On macOS that is
 * UTF-8 unless the String is binary; elsewhere the bytes as they are. */
VALUE rb_str_encode_ospath(VALUE path) {
#ifdef __APPLE__
    rb_encoding *enc = rb_enc_get(path);
    if (enc != rb_ascii8bit_encoding() && enc != rb_utf8_encoding())
        path = rb_str_conv_enc(path, enc, rb_utf8_encoding());
#endif
    return path;
}

/* ---- conversion ------------------------------------------------------------------ */
VALUE rb_check_string_type(VALUE obj) {
    if (RB_TYPE_P(obj, T_STRING)) return obj;
    if (RB_SPECIAL_CONST_P(obj) || !rb_respond_to(obj, rb_intern("to_str"))) return Qnil;
    VALUE s = mr_call(obj, "to_str", 0);
    if (NIL_P(s)) return Qnil;
    if (!RB_TYPE_P(s, T_STRING)) rb_raise(rb_eTypeError, "can't convert %s to String (%s#to_str gives %s)", rb_obj_classname(obj), rb_obj_classname(obj), rb_obj_classname(s));
    return s;
}
VALUE rb_str_to_str(VALUE obj) {
    VALUE s = rb_check_string_type(obj);
    if (NIL_P(s)) {
        const char *name = NIL_P(obj) ? "nil" : obj == Qtrue ? "true" : obj == Qfalse ? "false" : rb_obj_classname(obj);
        rb_raise(rb_eTypeError, "no implicit conversion of %s into String", name);
    }
    return s;
}
VALUE rb_String(VALUE obj) { return mr_call(mr_main(), "String", 1, obj); }
VALUE rb_string_value(volatile VALUE *ptr) {
    VALUE s = *ptr;
    if (!RB_TYPE_P(s, T_STRING)) { s = rb_str_to_str(s); *ptr = s; }
    return s;
}
char *rb_string_value_ptr(volatile VALUE *ptr) { return RSTRING_PTR(rb_string_value(ptr)); }
/* A String as a C string: no NUL character inside it -- a NUL as wide as the
 * encoding's narrowest character, at a character boundary of that width. */
char *rb_string_value_cstr(volatile VALUE *ptr) {
    VALUE str = rb_string_value(ptr);
    char *s = RSTRING_PTR(str);
    long len = RSTRING_LEN(str);
    int width = rb_enc_mbminlen(rb_enc_get(str));
    if (width <= 1) {
        if (memchr(s, 0, (size_t)len)) rb_raise(rb_eArgError, "string contains null byte");
    }
    else {
        for (long i = 0; i + width <= len; i += width) {
            int zero = 1;
            for (int k = 0; k < width; k++) if (s[i + k]) { zero = 0; break; }
            if (zero) rb_raise(rb_eArgError, "string contains null char");
        }
    }
    /* (...and it ends in its terminator, whatever C wrote there since: a C
     *  string is asked for) */
    memset(s + len, 0, (size_t)mr_string_terminator(str));
    return s;
}
VALUE rb_str_export_to_enc(VALUE str, rb_encoding *enc) { return rb_str_conv_enc(str, rb_enc_get(str), enc); }
VALUE rb_obj_encoding(VALUE obj) { return mr_call(obj, "encoding", 0); }
VALUE rb_str_tmp_frozen_acquire(VALUE str) { return rb_str_new_frozen(str); }
void rb_str_tmp_frozen_release(VALUE str, VALUE tmp) { (void)str; (void)tmp; }
