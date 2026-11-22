/* CRuby's own bignum.c (capi/vendor), compiled as it is: the multiplication,
 * division and radix conversion algorithms an extension can name
 * (rb_big_mul_karatsuba, rb_big_mul_toom3, rb_big2str_generic, ...) run as
 * CRuby runs them.
 *
 * bignum.c works on struct RBignum: it makes one with NEWOBJ_OF and turns
 * the pointer into its VALUE (`bigv = (VALUE)big`), and reads one through a
 * cast (RBIGNUM). A handle is no address, so a Bignum it makes is a C struct
 * of its own -- a RAW Bignum, whose VALUE is the struct's address:
 *
 *   - made by NEWOBJ_OF (capi/standin/internal/gc.h) and listed here, with
 *     the C call that made it;
 *   - RBASIC() answers the struct itself (rb_mere_basic, mirror.c), so its
 *     type, sign and length are read as bignum.c writes them;
 *   - where it reaches the interpreter -- an argument of an up-call, a word
 *     of the transit buffer, what the C call returns (core.c) -- it becomes
 *     the Integer its digits say (mr_vbig_out);
 *   - it is freed when the C call that made it ends, unless bignum.c keeps it
 *     for good (its power cache: rb_vm_register_global_object).
 *
 * The other way, an Integer the interpreter has is a handle (or a Fixnum),
 * which bignum.c cannot read: the entry points below hand it a raw Bignum
 * with the same digits (mr_vbig_in).
 *
 * Every function bignum.c defines is renamed (mr_vbig_*), before any header,
 * so that it calls its own and nothing else in this C API is replaced. Only
 * the algorithms by name are given under ruby's names, below; the C API's
 * own Integer functions (capi/numeric.c, capi/bignum.c) are unchanged. */
#define RUBY_EXPORT 1
#define Init_Bignum mr_vbig_Init_Bignum
#define rb_absint_numwords mr_vbig_rb_absint_numwords
#define rb_absint_singlebit_p mr_vbig_rb_absint_singlebit_p
#define rb_absint_size mr_vbig_rb_absint_size
#define rb_big_2comp mr_vbig_rb_big_2comp
#define rb_big_abs mr_vbig_rb_big_abs
#define rb_big_and mr_vbig_rb_big_and
#define rb_big_aref mr_vbig_rb_big_aref
#define rb_big_aref2 mr_vbig_rb_big_aref2
#define rb_big_bit_length mr_vbig_rb_big_bit_length
#define rb_big_clone mr_vbig_rb_big_clone
#define rb_big_cmp mr_vbig_rb_big_cmp
#define rb_big_comp mr_vbig_rb_big_comp
#define rb_big_div mr_vbig_rb_big_div
#define rb_big_divmod mr_vbig_rb_big_divmod
#define rb_big_divrem_normal mr_vbig_rb_big_divrem_normal
#define rb_big_eq mr_vbig_rb_big_eq
#define rb_big_eql mr_vbig_rb_big_eql
#define rb_big_even_p mr_vbig_rb_big_even_p
#define rb_big_fdiv mr_vbig_rb_big_fdiv
#define rb_big_fdiv_double mr_vbig_rb_big_fdiv_double
#define rb_big_ge mr_vbig_rb_big_ge
#define rb_big_gt mr_vbig_rb_big_gt
#define rb_big_hash mr_vbig_rb_big_hash
#define rb_big_idiv mr_vbig_rb_big_idiv
#define rb_big_isqrt mr_vbig_rb_big_isqrt
#define rb_big_le mr_vbig_rb_big_le
#define rb_big_lshift mr_vbig_rb_big_lshift
#define rb_big_lt mr_vbig_rb_big_lt
#define rb_big_minus mr_vbig_rb_big_minus
#define rb_big_modulo mr_vbig_rb_big_modulo
#define rb_big_mul mr_vbig_rb_big_mul
#define rb_big_mul_balance mr_vbig_rb_big_mul_balance
#define rb_big_mul_karatsuba mr_vbig_rb_big_mul_karatsuba
#define rb_big_mul_normal mr_vbig_rb_big_mul_normal
#define rb_big_mul_toom3 mr_vbig_rb_big_mul_toom3
#define rb_big_new mr_vbig_rb_big_new
#define rb_big_norm mr_vbig_rb_big_norm
#define rb_big_odd_p mr_vbig_rb_big_odd_p
#define rb_big_or mr_vbig_rb_big_or
#define rb_big_pack mr_vbig_rb_big_pack
#define rb_big_plus mr_vbig_rb_big_plus
#define rb_big_pow mr_vbig_rb_big_pow
#define rb_big_remainder mr_vbig_rb_big_remainder
#define rb_big_resize mr_vbig_rb_big_resize
#define rb_big_rshift mr_vbig_rb_big_rshift
#define rb_big_sign mr_vbig_rb_big_sign
#define rb_big_size mr_vbig_rb_big_size
#define rb_big_size_m mr_vbig_rb_big_size_m
#define rb_big_sq_fast mr_vbig_rb_big_sq_fast
#define rb_big_uminus mr_vbig_rb_big_uminus
#define rb_big_unpack mr_vbig_rb_big_unpack
#define rb_big_xor mr_vbig_rb_big_xor
#define rb_big2dbl mr_vbig_rb_big2dbl
#define rb_big2ll mr_vbig_rb_big2ll
#define rb_big2long mr_vbig_rb_big2long
#define rb_big2str mr_vbig_rb_big2str
#define rb_big2str_generic mr_vbig_rb_big2str_generic
#define rb_big2str_poweroftwo mr_vbig_rb_big2str_poweroftwo
#define rb_big2ull mr_vbig_rb_big2ull
#define rb_big2ulong mr_vbig_rb_big2ulong
#define rb_bigzero_p mr_vbig_rb_bigzero_p
#define rb_cmpint mr_vbig_rb_cmpint
#define rb_cstr_to_inum mr_vbig_rb_cstr_to_inum
#define rb_cstr2inum mr_vbig_rb_cstr2inum
#define rb_dbl2big mr_vbig_rb_dbl2big
#define rb_int_parse_cstr mr_vbig_rb_int_parse_cstr
#define rb_int_powm mr_vbig_rb_int_powm
#define rb_int128t2big mr_vbig_rb_int128t2big
#define rb_int2big mr_vbig_rb_int2big
#define rb_int2inum mr_vbig_rb_int2inum
#define rb_integer_float_cmp mr_vbig_rb_integer_float_cmp
#define rb_integer_float_eq mr_vbig_rb_integer_float_eq
#define rb_integer_pack mr_vbig_rb_integer_pack
#define rb_integer_unpack mr_vbig_rb_integer_unpack
#define rb_ll2big mr_vbig_rb_ll2big
#define rb_ll2inum mr_vbig_rb_ll2inum
#define rb_str_convert_to_inum mr_vbig_rb_str_convert_to_inum
#define rb_str_to_inum mr_vbig_rb_str_to_inum
#define rb_str2big_karatsuba mr_vbig_rb_str2big_karatsuba
#define rb_str2big_normal mr_vbig_rb_str2big_normal
#define rb_str2big_poweroftwo mr_vbig_rb_str2big_poweroftwo
#define rb_str2inum mr_vbig_rb_str2inum
#define rb_uint128t2big mr_vbig_rb_uint128t2big
#define rb_uint2big mr_vbig_rb_uint2big
#define rb_uint2inum mr_vbig_rb_uint2inum
#define rb_ull2big mr_vbig_rb_ull2big
#define rb_ull2inum mr_vbig_rb_ull2inum
#define ruby_digitmap mr_vbig_ruby_digitmap
#include "mr_capi.h"
#include <float.h>
#include <math.h>
#include "internal/bits.h"
#include "internal/bignum.h"

struct mr_transit { VALUE *words; long nwords; mere_bytes *bytes; char *text; double dbl; };
extern void mr_transit_save(struct mr_transit *, long);
extern void mr_transit_restore(struct mr_transit *);
extern const void *mr_capi_frame(void);

/* ---- raw Bignums ------------------------------------------------------- */
struct vbig { VALUE obj; size_t size; const void *owner; };
struct vlist { struct vbig *at; long count, cap; };
/* (temporaries, freed when their C call ends; and the ones kept for good,
 *  apart, so that the end of every C call does not walk them) */
static struct vlist temps, kept;
long mr_vbig_live;   /* how many there are: 0 is the fast path everywhere */

static struct vbig *find_in(struct vlist *l, VALUE v) {
    for (long i = l->count - 1; i >= 0; i--) if (l->at[i].obj == v) return &l->at[i];
    return NULL;
}
static struct vbig *find(VALUE v) {
    struct vbig *b = find_in(&temps, v);
    return b ? b : find_in(&kept, v);
}
static void push(struct vlist *l, struct vbig b) {
    if (l->count == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 64;
        l->at = realloc(l->at, sizeof(*l->at) * (size_t)l->cap);
        if (!l->at) mr_fatal("out of memory");
    }
    l->at[l->count++] = b;
    mr_vbig_live = temps.count + kept.count;
}
int mr_vbig_raw_p(VALUE v) { return mr_vbig_live && find(v) != NULL; }

VALUE mr_vbig_newobj(VALUE klass, VALUE flags, size_t size) {
    if (size < sizeof(struct RBignum)) size = sizeof(struct RBignum);
    struct RBignum *big = calloc(1, size);
    if (!big) rb_memerror();
    big->basic.flags = flags;
    memcpy((void *)&big->basic.klass, &klass, sizeof(VALUE));
    struct vbig b = { (VALUE)big, size, mr_capi_frame() };
    push(&temps, b);
    return (VALUE)big;
}
bool rb_gc_size_allocatable_p(size_t size) { return size <= 640; }
size_t rb_gc_obj_slot_size(VALUE obj) {
    struct vbig *b = find(obj);
    return b ? b->size : sizeof(struct RBignum);
}
/* (kept for the life of the process: the power cache of radix conversion) */
void rb_vm_register_global_object(VALUE obj) {
    struct vbig *b = find_in(&temps, obj);
    if (!b) { if (!find_in(&kept, obj)) rb_gc_register_mark_object(obj); return; }
    struct vbig copy = *b;
    *b = temps.at[--temps.count];
    push(&kept, copy);
}
static void raw_free(VALUE obj) {
    if (!BIGNUM_EMBED_P(obj)) ruby_xfree(RBIGNUM(obj)->as.heap.digits);
    free((void *)obj);
}
/* The C call `frame` ends: the raw Bignums it made are gone (whatever of
 * them reached the interpreter is an Integer there by now). */
void mr_vbig_leave(const void *frame) {
    if (!temps.count) return;
    long left = 0;
    for (long i = 0; i < temps.count; i++) {
        if (temps.at[i].owner == frame) raw_free(temps.at[i].obj);
        else temps.at[left++] = temps.at[i];
    }
    temps.count = left;
    mr_vbig_live = temps.count + kept.count;
}

/* A raw Bignum as the Integer its digits say; anything else as it is. */
VALUE mr_vbig_out(VALUE v) {
    if (!mr_vbig_live || RB_SPECIAL_CONST_P(v) || MR_HANDLE_P(v) || !find(v)) return v;
    size_t len = BIGNUM_LEN(v);
    const BDIGIT *ds = BIGNUM_DIGITS(v);
    while (len > 0 && ds[len - 1] == 0) len--;
    char *text = ruby_xmalloc2(len * SIZEOF_BDIGIT * 2 + 3, 1);
    char *p = text;
    if (len == 0) { *p++ = '0'; }
    else {
        if (BIGNUM_NEGATIVE_P(v)) *p++ = '-';
        p += sprintf(p, "%llx", (unsigned long long)ds[len - 1]);
        for (size_t i = len - 1; i > 0; i--)
            p += sprintf(p, "%0*llx", SIZEOF_BDIGIT * 2, (unsigned long long)ds[i - 1]);
    }
    *p = '\0';
    /* (what the caller has in transit stays: this runs inside its up-call) */
    struct mr_transit saved;
    mr_transit_save(&saved, -1);
    mr_put_text(text);
    ruby_xfree(text);
    VALUE made = mr_up1(MR_INT_NEW, (VALUE)16);
    mr_transit_restore(&saved);
    return made;
}
/* An Integer as a raw Bignum bignum.c can read (a raw one as it is). */
static VALUE vbig_in(VALUE v) {
    if (FIXNUM_P(v)) return rb_int2big(FIX2LONG(v));
    if (!RB_SPECIAL_CONST_P(v) && !MR_HANDLE_P(v)) return v;
    if (!RB_INTEGER_TYPE_P(v)) rb_raise(rb_eTypeError, "can't convert %"PRIsVALUE" into Bignum", rb_obj_class(v));
    VALUE hex = rb_funcall(v, rb_intern("to_s"), 1, INT2FIX(16));
    VALUE big = rb_str_to_inum(hex, 16, TRUE);
    return FIXNUM_P(big) ? rb_int2big(FIX2LONG(big)) : big;
}

/* ---- what bignum.c asks of the rest of CRuby, in the public API's terms -- */
static VALUE int_result(VALUE v) { return RB_INTEGER_TYPE_P(v) && !FIXNUM_P(v) ? vbig_in(v) : v; }
#define INT_OP2(name, op) VALUE name(VALUE x, VALUE y) { return int_result(rb_funcall(x, rb_intern(op), 1, y)); }
INT_OP2(rb_int_plus, "+") INT_OP2(rb_int_minus, "-") INT_OP2(rb_int_mul, "*") INT_OP2(rb_int_idiv, "div")
INT_OP2(rb_int_modulo, "%") INT_OP2(rb_int_pow, "**") INT_OP2(rb_int_and, "&") INT_OP2(rb_int_xor, "^")
INT_OP2(rb_int_lshift, "<<") INT_OP2(rb_int_rshift, ">>") INT_OP2(rb_int_gt, ">")
VALUE rb_int_uminus(VALUE x) { return int_result(rb_funcall(x, rb_intern("-@"), 0)); }
VALUE rb_int_zero_p(VALUE x) { return rb_funcall(x, rb_intern("zero?"), 0); }
VALUE rb_int_odd_p(VALUE x) { return rb_funcall(x, rb_intern("odd?"), 0); }
int rb_int_positive_p(VALUE x) { return RTEST(rb_funcall(x, rb_intern(">"), 1, INT2FIX(0))); }
int rb_int_negative_p(VALUE x) { return RTEST(rb_funcall(x, rb_intern("<"), 1, INT2FIX(0))); }
VALUE rb_flo_div_flo(VALUE x, VALUE y) { return rb_funcall(x, rb_intern("/"), 1, y); }
VALUE rb_dbl_complex_new_polar_pi(double abs, double ang) {
    (void)abs; (void)ang;
    mr_unsupported("rb_dbl_complex_new_polar_pi (a negative Bignum to a fractional power)");
}
/* numeric.c's DEFINE_INT_SQRT for unsigned long, as it is there */
unsigned long rb_ulong_isqrt(unsigned long n) {
    if (!(n < (1UL << DBL_MANT_DIG))) {
        unsigned int b = bit_length(n);
        unsigned long t;
        unsigned long x = (unsigned long)(n >> (b/2+1));
        x |= ((unsigned long)1LU << (b-1)/2);
        while ((t = n/x) < (unsigned long)x) x = (unsigned long)((x + t) >> 1);
        return x;
    }
    unsigned long x = (unsigned long)sqrt((double)n);
    if (x * x > n) x--;
    return x;
}

#include "vendor/bignum.c"

/* ---- the algorithms by name ---------------------------------------------- */
#undef rb_big_mul_normal
VALUE rb_big_mul_normal(VALUE x, VALUE y) { return mr_vbig_rb_big_mul_normal(vbig_in(x), vbig_in(y)); }
#undef rb_big_mul_balance
VALUE rb_big_mul_balance(VALUE x, VALUE y) { return mr_vbig_rb_big_mul_balance(vbig_in(x), vbig_in(y)); }
#undef rb_big_mul_karatsuba
VALUE rb_big_mul_karatsuba(VALUE x, VALUE y) { return mr_vbig_rb_big_mul_karatsuba(vbig_in(x), vbig_in(y)); }
#undef rb_big_mul_toom3
VALUE rb_big_mul_toom3(VALUE x, VALUE y) { return mr_vbig_rb_big_mul_toom3(vbig_in(x), vbig_in(y)); }
#undef rb_big_divrem_normal
VALUE rb_big_divrem_normal(VALUE x, VALUE y) { return mr_vbig_rb_big_divrem_normal(vbig_in(x), vbig_in(y)); }
#undef rb_big_sq_fast
VALUE rb_big_sq_fast(VALUE x) { return mr_vbig_rb_big_sq_fast(vbig_in(x)); }
#undef rb_big2str_poweroftwo
VALUE rb_big2str_poweroftwo(VALUE x, int base) { return mr_vbig_rb_big2str_poweroftwo(vbig_in(x), base); }
#undef rb_big2str_generic
VALUE rb_big2str_generic(VALUE x, int base) { return mr_vbig_rb_big2str_generic(vbig_in(x), base); }
#undef rb_str2big_poweroftwo
VALUE rb_str2big_poweroftwo(VALUE arg, int base, int badcheck) { return mr_vbig_rb_str2big_poweroftwo(arg, base, badcheck); }
#undef rb_str2big_normal
VALUE rb_str2big_normal(VALUE arg, int base, int badcheck) { return mr_vbig_rb_str2big_normal(arg, base, badcheck); }
#undef rb_str2big_karatsuba
VALUE rb_str2big_karatsuba(VALUE arg, int base, int badcheck) { return mr_vbig_rb_str2big_karatsuba(arg, base, badcheck); }
#undef rb_big_new
VALUE rb_big_new(size_t len, int sign) { return mr_vbig_rb_big_new(len, sign); }
