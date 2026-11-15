/* Integer, Float, Rational and Complex. A Fixnum and a flonum are CRuby's
 * immediates; a bigger Integer or a Float that does not fit one is a handle,
 * and its digits or its double are asked of the interpreter. */
#include "mr_capi.h"
#include <errno.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---- Float -------------------------------------------------------------- */
static VALUE flonum(double d) {
    union { double d; VALUE v; } t;
    t.d = d;
    int bits = (int)((VALUE)(t.v >> 60) & 0x7);
    if (t.v != 0x3000000000000000ULL && !((bits - 3) & ~0x01)) {
        t.v = (t.v << 3) | (t.v >> 61);
        return (t.v & ~(VALUE)0x01) | 0x02;
    }
    if (t.v == 0) return 0x8000000000000002ULL;
    return 0;
}
static double flonum_value(VALUE v) {
    if (v == 0x8000000000000002ULL) return 0.0;
    union { double d; VALUE v; } t;
    VALUE b63 = v >> 63;
    VALUE w = (2 - b63) | (v & ~(VALUE)0x03);
    t.v = (w >> 3) | (w << 61);
    return t.d;
}
CapiWord mr_capi_flonum(double d) {
    CapiWord w = { (long long)flonum(d) };
    return w;
}
double mr_capi_flonum_value(CapiWord w) { return flonum_value((VALUE)w.mu_w); }

VALUE rb_float_new_in_heap(double d) {
    mr_put_dbl(d);
    return mr_up1(MR_FLOAT_NEW, 0);
}
VALUE rb_float_new(double d) {
    VALUE v = flonum(d);
    return v ? v : rb_float_new_in_heap(d);
}
double rb_float_value(VALUE v) {
    if (RB_FLONUM_P(v)) return flonum_value(v);
    mr_up1(MR_FLOAT_GET, v);
    return mr_got_dbl();
}

/* ---- Integer ------------------------------------------------------------- */
static VALUE int_from_text(const char *digits, int base) {
    mr_put_text(digits);
    return mr_up1(MR_INT_NEW, (VALUE)base);
}
VALUE rb_int2big(intptr_t n) {
    char buffer[32];
    snprintf(buffer, sizeof(buffer), "%ld", (long)n);
    return int_from_text(buffer, 10);
}
VALUE rb_uint2big(uintptr_t n) {
    char buffer[32];
    snprintf(buffer, sizeof(buffer), "%lu", (unsigned long)n);
    return int_from_text(buffer, 10);
}
VALUE rb_int2inum(intptr_t n) { return RB_FIXABLE(n) ? RB_LONG2FIX(n) : rb_int2big(n); }
VALUE rb_uint2inum(uintptr_t n) { return RB_POSFIXABLE(n) ? RB_LONG2FIX((long)n) : rb_uint2big(n); }
VALUE rb_ll2inum(LONG_LONG n) { return rb_int2inum((intptr_t)n); }
VALUE rb_ull2inum(unsigned LONG_LONG n) { return rb_uint2inum((uintptr_t)n); }
VALUE rb_int128t2big(__int128 n) {
    char buffer[48], *p = buffer + sizeof(buffer);
    unsigned __int128 u = n < 0 ? -(unsigned __int128)n : (unsigned __int128)n;
    *--p = 0;
    do { *--p = (char)('0' + (int)(u % 10)); u /= 10; } while (u);
    if (n < 0) *--p = '-';
    return int_from_text(p, 10);
}

/* The magnitude and sign of an Integer that is not a Fixnum. `fits` is 0
 * when it is past 128 bits. */
static int big_parts(VALUE v, unsigned __int128 *magnitude, int *negative) {
    mr_up2(MR_INT_GET, v, 10);
    const char *s = mr_got_text();
    *negative = (*s == '-');
    if (*s == '-' || *s == '+') s++;
    unsigned __int128 m = 0;
    for (; *s; s++) {
        if (m > (~(unsigned __int128)0 - 9) / 10) return 0;
        m = m * 10 + (unsigned)(*s - '0');
    }
    *magnitude = m;
    return 1;
}
static const char *class_for_message(VALUE v) {
    if (NIL_P(v)) return "nil";
    if (v == Qtrue) return "true";
    if (v == Qfalse) return "false";
    return rb_obj_classname(v);
}
static VALUE to_integer(VALUE v) {
    if (RB_FIXNUM_P(v)) return v;
    if (NIL_P(v)) rb_raise(rb_eTypeError, "no implicit conversion from nil to integer");
    if (RB_TYPE_P(v, T_BIGNUM)) return v;
    if (v == Qtrue || v == Qfalse || !rb_respond_to(v, rb_intern("to_int")))
        rb_raise(rb_eTypeError, "no implicit conversion of %s into Integer", class_for_message(v));
    VALUE r = mr_call(v, "to_int", 0);
    if (!RB_INTEGER_TYPE_P(r))
        rb_raise(rb_eTypeError, "can't convert %s to Integer (%s#to_int gives %s)", class_for_message(v), class_for_message(v), class_for_message(r));
    return r;
}
static void float_range(double d, double lo, double hi, const char *type) {
    if (isnan(d) || d <= lo || d >= hi) {
        char buffer[64];
        snprintf(buffer, sizeof(buffer), "%-.10g", d);
        rb_raise(rb_eRangeError, "float %s out of range of %s", buffer, type);
    }
}
long rb_num2long(VALUE v) {
    if (RB_FIXNUM_P(v)) return RB_FIX2LONG(v);
    if (RB_FLOAT_TYPE_P(v)) {
        double d = rb_float_value(v);
        float_range(d, -9223372036854777856.0, 9223372036854775808.0, "integer");
        return (long)d;
    }
    v = to_integer(v);
    if (RB_FIXNUM_P(v)) return RB_FIX2LONG(v);
    return rb_big2long(v);
}
unsigned long rb_num2ulong(VALUE v) {
    if (RB_FIXNUM_P(v)) return (unsigned long)RB_FIX2LONG(v);
    if (RB_FLOAT_TYPE_P(v)) {
        double d = rb_float_value(v);
        float_range(d, -9223372036854777856.0, 18446744073709551616.0, "integer");
        return d < 0 ? (unsigned long)(long)d : (unsigned long)d;
    }
    v = to_integer(v);
    if (RB_FIXNUM_P(v)) return (unsigned long)RB_FIX2LONG(v);
    return rb_big2ulong(v);
}
long rb_big2long(VALUE v) {
    unsigned __int128 m; int negative;
    if (!big_parts(v, &m, &negative) || m > (unsigned __int128)LONG_MAX + (negative ? 1 : 0))
        rb_raise(rb_eRangeError, "bignum too big to convert into 'long'");
    return negative ? (long)(-(__int128)m) : (long)m;
}
unsigned long rb_big2ulong(VALUE v) {
    unsigned __int128 m; int negative;
    int fits = big_parts(v, &m, &negative);
    if (negative) {
        if (!fits || m > (unsigned __int128)LONG_MAX + 1) rb_raise(rb_eRangeError, "bignum out of range of unsigned long");
        return (unsigned long)(-(__int128)m);
    }
    if (!fits || m > ULONG_MAX) rb_raise(rb_eRangeError, "bignum too big to convert into 'unsigned long'");
    return (unsigned long)m;
}
LONG_LONG rb_big2ll(VALUE v) {
    unsigned __int128 m; int negative;
    if (!big_parts(v, &m, &negative) || m > (unsigned __int128)LLONG_MAX + (negative ? 1 : 0))
        rb_raise(rb_eRangeError, "bignum too big to convert into 'long long'");
    return negative ? (LONG_LONG)(-(__int128)m) : (LONG_LONG)m;
}
unsigned LONG_LONG rb_big2ull(VALUE v) {
    unsigned __int128 m; int negative;
    int fits = big_parts(v, &m, &negative);
    if (negative) {
        if (!fits || m > (unsigned __int128)LLONG_MAX + 1) rb_raise(rb_eRangeError, "bignum out of range of unsigned long long");
        return (unsigned LONG_LONG)(-(__int128)m);
    }
    if (!fits || m > ULLONG_MAX) rb_raise(rb_eRangeError, "bignum too big to convert into 'unsigned long long'");
    return (unsigned LONG_LONG)m;
}
LONG_LONG rb_num2ll(VALUE v) { return (LONG_LONG)rb_num2long(v); }
unsigned LONG_LONG rb_num2ull(VALUE v) { return (unsigned LONG_LONG)rb_num2ulong(v); }

static void int_range(long n) {
    if (n < INT_MIN || n > INT_MAX)
        rb_raise(rb_eRangeError, "integer %ld too %s to convert to 'int'", n, n < 0 ? "small" : "big");
}
long rb_num2int(VALUE v) { long n = rb_num2long(v); int_range(n); return n; }
long rb_fix2int(VALUE v) { long n = RB_FIXNUM_P(v) ? RB_FIX2LONG(v) : rb_num2long(v); int_range(n); return n; }
static int negative_p(VALUE v) {
    if (RB_FIXNUM_P(v)) return RB_FIX2LONG(v) < 0;
    if (RB_FLOAT_TYPE_P(v)) return rb_float_value(v) < 0.0;
    return RTEST(mr_call(v, "<", 1, INT2FIX(0)));
}
/* (a negative number given for an unsigned type is taken as its two's
 *  complement, as CRuby takes it, when it fits the signed type) */
unsigned long rb_num2uint(VALUE v) {
    int negative = negative_p(v);
    unsigned long n = rb_num2ulong(v);
    if (negative) {
        if ((long)n < INT_MIN) rb_raise(rb_eRangeError, "integer %ld too small to convert to 'unsigned int'", (long)n);
    }
    else if (n > UINT_MAX) rb_raise(rb_eRangeError, "integer %lu too big to convert to 'unsigned int'", n);
    return n;
}
unsigned long rb_fix2uint(VALUE v) { return rb_num2uint(v); }
short rb_num2short(VALUE v) {
    long n = rb_num2long(v);
    if (n < SHRT_MIN || n > SHRT_MAX) rb_raise(rb_eRangeError, "integer %ld too %s to convert to 'short'", n, n < 0 ? "small" : "big");
    return (short)n;
}
short rb_fix2short(VALUE v) { return rb_num2short(v); }
unsigned short rb_num2ushort(VALUE v) {
    int negative = negative_p(v);
    unsigned long n = rb_num2ulong(v);
    if (negative) {
        if ((long)n < SHRT_MIN) rb_raise(rb_eRangeError, "integer %ld too small to convert to 'unsigned short'", (long)n);
    }
    else if (n > USHRT_MAX) rb_raise(rb_eRangeError, "integer %lu too big to convert to 'unsigned short'", n);
    return (unsigned short)n;
}
unsigned short rb_fix2ushort(VALUE v) { return rb_num2ushort(v); }
VALUE rb_num2fix(VALUE v) {
    long n = rb_num2long(v);
    if (!RB_FIXABLE(n)) rb_raise(rb_eRangeError, "integer %ld out of range of fixnum", n);
    return RB_LONG2FIX(n);
}
VALUE rb_fix2str(VALUE v, int base) { return mr_call(v, "to_s", 1, INT2FIX(base)); }

double rb_num2dbl(VALUE v) {
    if (RB_FIXNUM_P(v)) return (double)RB_FIX2LONG(v);
    if (RB_FLONUM_P(v)) return flonum_value(v);
    if (NIL_P(v)) rb_raise(rb_eTypeError, "no implicit conversion to float from nil");
    if (v == Qtrue) rb_raise(rb_eTypeError, "no implicit conversion to float from true");
    if (v == Qfalse) rb_raise(rb_eTypeError, "no implicit conversion to float from false");
    if (RB_SYMBOL_P(v)) rb_raise(rb_eTypeError, "can't convert Symbol into Float");
    switch (rb_type(v)) {
      case T_FLOAT: return rb_float_value(v);
      case T_STRING: rb_raise(rb_eTypeError, "no implicit conversion to float from string");
      case T_BIGNUM: case T_RATIONAL: return rb_float_value(mr_call(v, "to_f", 0));
      default: break;
    }
    /* (anything else is asked for its to_f, whatever its class) */
    if (!rb_respond_to(v, rb_intern("to_f"))) rb_raise(rb_eTypeError, "can't convert %s into Float", class_for_message(v));
    VALUE f = mr_call(v, "to_f", 0);
    if (!RB_FLOAT_TYPE_P(f))
        rb_raise(rb_eTypeError, "can't convert %s to Float (%s#to_f gives %s)", class_for_message(v), class_for_message(v), class_for_message(f));
    return rb_float_value(f);
}
VALUE rb_to_float(VALUE v) {
    if (RB_FLOAT_TYPE_P(v)) return v;
    if (!RTEST(rb_obj_is_kind_of(v, rb_cNumeric)) || !rb_respond_to(v, rb_intern("to_f")))
        rb_raise(rb_eTypeError, "can't convert %s into Float", class_for_message(v));
    VALUE r = mr_call(v, "to_f", 0);
    if (!RB_FLOAT_TYPE_P(r)) rb_raise(rb_eTypeError, "can't convert %s into Float (%s#to_f gives %s)", class_for_message(v), class_for_message(v), class_for_message(r));
    return r;
}
VALUE rb_check_to_float(VALUE v) {
    if (RB_FLOAT_TYPE_P(v)) return v;
    if (!RTEST(rb_obj_is_kind_of(v, rb_cNumeric)) || !rb_respond_to(v, rb_intern("to_f"))) return Qnil;
    VALUE r = mr_call(v, "to_f", 0);
    return RB_FLOAT_TYPE_P(r) ? r : Qnil;
}
VALUE rb_to_int(VALUE v) { return to_integer(v); }
VALUE rb_check_to_int(VALUE v) {
    if (RB_INTEGER_TYPE_P(v)) return v;
    if (RB_SPECIAL_CONST_P(v) && !RB_FLONUM_P(v)) return Qnil;
    if (!rb_respond_to(v, rb_intern("to_int"))) return Qnil;
    VALUE r = mr_call(v, "to_int", 0);
    return RB_INTEGER_TYPE_P(r) ? r : Qnil;
}
VALUE rb_check_to_integer(VALUE v, const char *method) {
    if (RB_INTEGER_TYPE_P(v)) return v;
    if (!rb_respond_to(v, rb_intern(method))) return Qnil;
    VALUE r = mr_callv(v, rb_intern(method), 0, NULL, Qnil, 0);
    return RB_INTEGER_TYPE_P(r) ? r : Qnil;
}
VALUE rb_Integer(VALUE v) { return mr_call(mr_main(), "Integer", 1, v); }
VALUE rb_Float(VALUE v) { return mr_call(mr_main(), "Float", 1, v); }
VALUE rb_dbl2big(double d) {
    if (isnan(d) || isinf(d)) rb_raise(rb_eFloatDomainError, "%s", isnan(d) ? "NaN" : d < 0 ? "-Infinity" : "Infinity");
    return mr_call(rb_float_new(d), "to_i", 0);
}
double rb_big2dbl(VALUE v) { return rb_float_value(mr_call(v, "to_f", 0)); }
VALUE rb_big2str(VALUE v, int base) { return mr_call(v, "to_s", 1, INT2FIX(base)); }
VALUE rb_big_norm(VALUE v) { return v; }
VALUE rb_big_cmp(VALUE a, VALUE b) { return mr_call(a, "<=>", 1, b); }
VALUE rb_big_eq(VALUE a, VALUE b) { return mr_call(a, "==", 1, b); }
VALUE rb_big_eql(VALUE a, VALUE b) { return mr_call(a, "eql?", 1, b); }
VALUE rb_big_plus(VALUE a, VALUE b) { return mr_call(a, "+", 1, b); }
VALUE rb_big_minus(VALUE a, VALUE b) { return mr_call(a, "-", 1, b); }
VALUE rb_big_mul(VALUE a, VALUE b) { return mr_call(a, "*", 1, b); }
VALUE rb_big_div(VALUE a, VALUE b) { return mr_call(a, "/", 1, b); }
VALUE rb_big_idiv(VALUE a, VALUE b) { return mr_call(a, "div", 1, b); }
VALUE rb_big_modulo(VALUE a, VALUE b) { return mr_call(a, "%", 1, b); }
VALUE rb_big_divmod(VALUE a, VALUE b) { return mr_call(a, "divmod", 1, b); }
VALUE rb_big_pow(VALUE a, VALUE b) { return mr_call(a, "**", 1, b); }
VALUE rb_big_and(VALUE a, VALUE b) { return mr_call(a, "&", 1, b); }
VALUE rb_big_or(VALUE a, VALUE b) { return mr_call(a, "|", 1, b); }
VALUE rb_big_xor(VALUE a, VALUE b) { return mr_call(a, "^", 1, b); }
VALUE rb_big_lshift(VALUE a, VALUE b) { return mr_call(a, "<<", 1, b); }
VALUE rb_big_rshift(VALUE a, VALUE b) { return mr_call(a, ">>", 1, b); }
VALUE rb_big_hash(VALUE a) { return mr_call(a, "hash", 0); }
int rb_big_sign(VALUE v) { return !RTEST(mr_call(v, "negative?", 0)); }
int rb_bigzero_p(VALUE v) { return RTEST(mr_call(v, "zero?", 0)); }
VALUE rb_int_positive_pow(long x, unsigned long y) { return mr_call(LONG2NUM(x), "**", 1, ULONG2NUM(y)); }
VALUE rb_cstr_to_inum(const char *str, int base, int badcheck) {
    VALUE s = rb_str_new_cstr(str);
    return rb_str_to_inum(s, base, badcheck);
}
VALUE rb_str_to_inum(VALUE str, int base, int badcheck) {
    if (badcheck) return mr_call(mr_main(), "Integer", 2, str, INT2FIX(base));
    return mr_call(str, "to_i", 1, INT2FIX(base < 0 ? -base : base));
}
VALUE rb_cstr2inum(const char *str, int base) { return rb_cstr_to_inum(str, base, base == 2); }
VALUE rb_str2inum(VALUE str, int base) { return rb_str_to_inum(str, base, base == 2); }
double rb_cstr_to_dbl(const char *str, int badcheck) {
    VALUE s = rb_str_new_cstr(str);
    return rb_str_to_dbl(s, badcheck);
}
double rb_str_to_dbl(VALUE str, int badcheck) {
    return rb_float_value(badcheck ? mr_call(mr_main(), "Float", 1, str) : mr_call(str, "to_f", 0));
}

void rb_cmperr(VALUE a, VALUE b) {
    VALUE shown = (RB_SPECIAL_CONST_P(b) || RB_FLOAT_TYPE_P(b)) ? rb_inspect(b) : rb_obj_class(b);
    rb_raise(rb_eArgError, "comparison of %" PRIsVALUE " with %" PRIsVALUE " failed", rb_obj_class(a), shown);
}
int rb_cmpint(VALUE val, VALUE a, VALUE b) {
    if (NIL_P(val)) rb_cmperr(a, b);
    if (RB_FIXNUM_P(val)) {
        long n = RB_FIX2LONG(val);
        return n > 0 ? 1 : n < 0 ? -1 : 0;
    }
    if (RB_TYPE_P(val, T_BIGNUM)) return rb_big_sign(val) ? 1 : -1;
    if (RTEST(mr_call(val, ">", 1, INT2FIX(0)))) return 1;
    if (RTEST(mr_call(val, "<", 1, INT2FIX(0)))) return -1;
    return 0;
}
void rb_num_zerodiv(void) { rb_raise(rb_eZeroDivError, "divided by 0"); }
static VALUE coerced(VALUE x, VALUE y, ID op) {
    VALUE pair = mr_call(y, "coerce", 1, x);
    if (!RB_TYPE_P(pair, T_ARRAY) || RARRAY_LEN(pair) != 2) rb_raise(rb_eTypeError, "coerce must return [x, y]");
    VALUE a = rb_ary_entry(pair, 0), b = rb_ary_entry(pair, 1);
    return mr_callv(a, op, 1, &b, Qnil, 0);
}
VALUE rb_num_coerce_bin(VALUE x, VALUE y, ID op) { return coerced(x, y, op); }
VALUE rb_num_coerce_cmp(VALUE x, VALUE y, ID op) {
    if (!rb_respond_to(y, rb_intern("coerce"))) return Qnil;
    return coerced(x, y, op);
}
VALUE rb_num_coerce_relop(VALUE x, VALUE y, ID op) {
    if (!rb_respond_to(y, rb_intern("coerce"))) rb_cmperr(x, y);
    VALUE r = coerced(x, y, op);
    if (NIL_P(r)) rb_cmperr(x, y);
    return r;
}
VALUE rb_num_coerce_bit(VALUE x, VALUE y, ID op) { return coerced(x, y, op); }

/* ---- Rational and Complex --------------------------------------------------- */
VALUE rb_Rational(VALUE num, VALUE den) { return mr_call(mr_main(), "Rational", 2, num, den); }
VALUE rb_rational_new(VALUE num, VALUE den) { return mr_call(mr_main(), "Rational", 2, num, den); }
VALUE rb_rational_raw(VALUE num, VALUE den) { return mr_call(mr_main(), "Rational", 2, num, den); }
VALUE rb_rational_num(VALUE r) { return mr_call(r, "numerator", 0); }
VALUE rb_rational_den(VALUE r) { return mr_call(r, "denominator", 0); }
VALUE rb_flt_rationalize(VALUE f) { return mr_call(f, "rationalize", 0); }
VALUE rb_flt_rationalize_with_prec(VALUE f, VALUE prec) { return mr_call(f, "rationalize", 1, prec); }
VALUE rb_Complex(VALUE real, VALUE imag) { return mr_call(mr_main(), "Complex", 2, real, imag); }
VALUE rb_complex_new(VALUE real, VALUE imag) { return mr_call(mr_main(), "Complex", 2, real, imag); }
VALUE rb_complex_raw(VALUE real, VALUE imag) { return mr_call(mr_main(), "Complex", 2, real, imag); }
VALUE rb_complex_new_polar(VALUE abs, VALUE arg) { return mr_call(rb_cComplex, "polar", 2, abs, arg); }
VALUE rb_complex_real(VALUE z) { return mr_call(z, "real", 0); }
VALUE rb_complex_imag(VALUE z) { return mr_call(z, "imaginary", 0); }
VALUE rb_complex_plus(VALUE a, VALUE b) { return mr_call(a, "+", 1, b); }
VALUE rb_complex_minus(VALUE a, VALUE b) { return mr_call(a, "-", 1, b); }
VALUE rb_complex_mul(VALUE a, VALUE b) { return mr_call(a, "*", 1, b); }
VALUE rb_complex_div(VALUE a, VALUE b) { return mr_call(a, "/", 1, b); }
VALUE rb_complex_abs(VALUE z) { return mr_call(z, "abs", 0); }
VALUE rb_complex_arg(VALUE z) { return mr_call(z, "arg", 0); }
VALUE rb_complex_conjugate(VALUE z) { return mr_call(z, "conjugate", 0); }
VALUE rb_dbl_complex_new(double real, double imag) { return rb_Complex(rb_float_new(real), rb_float_new(imag)); }
void rb_out_of_int(SIGNED_VALUE n) {
    rb_raise(rb_eRangeError, "integer %ld too %s to convert to 'int'", (long)n, n < 0 ? "small" : "big");
}
void rb_out_of_short(SIGNED_VALUE n) {
    rb_raise(rb_eRangeError, "integer %ld too %s to convert to 'short'", (long)n, n < 0 ? "small" : "big");
}
