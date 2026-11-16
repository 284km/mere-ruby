/* Functions real extensions turned out to need (bigdecimal, oj, json, date,
 * found by listing what each built library asks of the interpreter and does
 * not get): conversions by method name, hashing bytes, walking instance
 * variables, the regexp match of the calling frame, and two of util.c. */
#include "mr_capi.h"
#include "ruby/encoding.h"
#include "ruby/util.h"
#include <errno.h>
#include <limits.h>

/* ---- object.c's convert_type ---------------------------------------------- */
static const char *special_name(VALUE val) {
    if (NIL_P(val)) return "nil";
    if (val == Qtrue) return "true";
    if (val == Qfalse) return "false";
    return NULL;
}
NORETURN(static void conversion_mismatch(VALUE val, const char *tname, const char *method, VALUE result));
static void conversion_mismatch(VALUE val, const char *tname, const char *method, VALUE result) {
    const char *name = special_name(val);
    if (name) rb_raise(rb_eTypeError, "can't convert %s to %s (%s#%s gives %s)", name, tname, name, method, rb_obj_classname(result));
    rb_raise(rb_eTypeError, "can't convert %s to %s (%s#%s gives %s)", rb_obj_classname(val), tname, rb_obj_classname(val),
             method, rb_obj_classname(result));
}
VALUE rb_convert_type(VALUE val, int type, const char *tname, const char *method) {
    if (TYPE(val) == type) return val;
    VALUE v = rb_check_funcall(val, rb_intern(method), 0, 0);
    if (v == Qundef) {
        const char *name = special_name(val);
        if (name) rb_raise(rb_eTypeError, "can't convert %s into %s", name, tname);
        rb_raise(rb_eTypeError, "can't convert %s into %s", rb_obj_classname(val), tname);
    }
    if (TYPE(v) != type) conversion_mismatch(val, tname, method, v);
    return v;
}
VALUE rb_check_convert_type(VALUE val, int type, const char *tname, const char *method) {
    /* always convert T_DATA */
    if (TYPE(val) == type && type != T_DATA) return val;
    VALUE v = rb_check_funcall(val, rb_intern(method), 0, 0);
    if (v == Qundef || NIL_P(v)) return Qnil;
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
VALUE rb_backref_get(void) { return rb_eval_string("$~"); }
void rb_backref_set(VALUE match) {
    rb_gv_set("$__mere_capi_carry", match);
    rb_eval_string("$~ = $__mere_capi_carry");
    rb_gv_set("$__mere_capi_carry", Qnil);
}
void rb_lastline_set(VALUE line) {
    rb_gv_set("$__mere_capi_carry", line);
    rb_eval_string("$_ = $__mere_capi_carry");
    rb_gv_set("$__mere_capi_carry", Qnil);
}
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
