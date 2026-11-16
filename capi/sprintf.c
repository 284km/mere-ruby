/* rb_sprintf and its family: C's printf conversions, plus CRuby's own --
 * `%"PRIsVALUE"` takes a VALUE and prints its to_s (`%+"PRIsVALUE"` its
 * inspect). PRIsVALUE is "li" followed by a vertical tab: the tab after a
 * long conversion is what says "this argument is a VALUE". */
#include "mr_capi.h"
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* ruby/subst.h renames these to the two functions at the end of this file. */
#undef snprintf
#undef vsnprintf

struct out { char *p; size_t len, cap; };
static void out_bytes(struct out *o, const char *s, size_t n) {
    if (o->len + n + 1 > o->cap) {
        size_t cap = o->cap ? o->cap : 128;
        while (cap < o->len + n + 1) cap *= 2;
        o->p = realloc(o->p, cap);
        if (!o->p) mr_fatal("out of memory");
        o->cap = cap;
    }
    if (n) memcpy(o->p + o->len, s, n);
    o->len += n;
    o->p[o->len] = 0;
}
static void out_pad(struct out *o, char c, long n) {
    for (; n > 0; n--) out_bytes(o, &c, 1);
}

static VALUE quote_unprintable(void) {
    return mr_ruby("->(s) { (s.valid_encoding? && s !~ /[^[:print:]]/) ? s : s.inspect[1..-2].gsub(/\\\\([\"\\\\#])/) { $1 } }");
}

/* Format into a malloc'd buffer. `carried` is set to the first VALUE string
 * printed into it (its encoding is the result's when none was given). */
static char *format(const char *fmt, va_list ap, size_t *len, VALUE *carried) {
    struct out o = { NULL, 0, 0 };
    out_bytes(&o, "", 0);
    for (const char *f = fmt; *f; ) {
        if (*f != '%') {
            const char *e = strchr(f, '%');
            size_t n = e ? (size_t)(e - f) : strlen(f);
            out_bytes(&o, f, n);
            f += n;
            continue;
        }
        const char *start = f++;
        if (*f == '%') { out_bytes(&o, "%", 1); f++; continue; }
        char spec[64];
        size_t sn = 0;
        spec[sn++] = '%';
        int left = 0, plus = 0, space = 0;
        long width = -1, precision = -1;
        for (; *f && strchr("-+ #0'", *f); f++) {
            if (*f == '-') left = 1;
            if (*f == '+') plus = 1;
            if (*f == ' ') space = 1;
            if (sn < 40) spec[sn++] = *f;
        }
        if (*f == '*') { width = va_arg(ap, int); if (width < 0) { left = 1; width = -width; } f++; }
        else if (*f >= '0' && *f <= '9') { width = 0; while (*f >= '0' && *f <= '9') width = width * 10 + (*f++ - '0'); }
        if (*f == '.') {
            f++;
            precision = 0;
            if (*f == '*') { precision = va_arg(ap, int); f++; }
            else while (*f >= '0' && *f <= '9') precision = precision * 10 + (*f++ - '0');
        }
        enum { L_NONE, L_HH, L_H, L_L, L_LL, L_BIGL, L_Z, L_T, L_J } length = L_NONE;
        if (*f == 'h') { f++; length = L_H; if (*f == 'h') { f++; length = L_HH; } }
        else if (*f == 'l') { f++; length = L_L; if (*f == 'l') { f++; length = L_LL; } }
        else if (*f == 'q') { f++; length = L_LL; }
        else if (*f == 'L') { f++; length = L_BIGL; }
        else if (*f == 'z') { f++; length = L_Z; }
        else if (*f == 't') { f++; length = L_T; }
        else if (*f == 'j') { f++; length = L_J; }
        char conv = *f;
        if (!conv) { out_bytes(&o, start, strlen(start)); break; }
        f++;
        /* a VALUE: to_s, or inspect under `+` */
        if ((conv == 'i' || conv == 'd') && length == L_L && *f == '\v') {
            f++;
            VALUE value = va_arg(ap, VALUE);
            VALUE str = plus ? rb_inspect(value) : rb_obj_as_string(value);
            /* (`% ` prints it escaped when it holds what cannot be printed) */
            if (space && !plus) str = mr_call(quote_unprintable(), "call", 1, str);
            if (carried && *carried == Qundef && !rb_enc_str_asciionly_p(str)) *carried = str;
            long n = RSTRING_LEN(str);
            if (precision >= 0 && n > precision) n = precision;
            if (!left && width > n) out_pad(&o, ' ', width - n);
            out_bytes(&o, RSTRING_PTR(str), (size_t)n);
            if (left && width > n) out_pad(&o, ' ', width - n);
            continue;
        }
        char number[32];
        if (width >= 0) { int k = snprintf(number, sizeof(number), "%ld", width); memcpy(spec + sn, number, (size_t)k); sn += (size_t)k; }
        if (precision >= 0) { int k = snprintf(number, sizeof(number), ".%ld", precision); memcpy(spec + sn, number, (size_t)k); sn += (size_t)k; }
        const char *mod = length == L_HH ? "hh" : length == L_H ? "h" : length == L_L ? "l" : length == L_LL ? "ll"
                        : length == L_BIGL ? "L" : length == L_Z ? "z" : length == L_T ? "t" : length == L_J ? "j" : "";
        memcpy(spec + sn, mod, strlen(mod)); sn += strlen(mod);
        spec[sn++] = conv;
        spec[sn] = 0;
        char small[512], *buffer = small;
        int n = 0;
#define PRINT(arg) do { \
            n = snprintf(small, sizeof(small), spec, arg); \
            if (n >= (int)sizeof(small)) { buffer = malloc((size_t)n + 1); if (!buffer) mr_fatal("out of memory"); snprintf(buffer, (size_t)n + 1, spec, arg); } \
        } while (0)
        switch (conv) {
          case 'd': case 'i':
            if (length == L_LL) PRINT(va_arg(ap, long long));
            else if (length == L_L) PRINT(va_arg(ap, long));
            else if (length == L_Z) PRINT(va_arg(ap, ssize_t));
            else if (length == L_T) PRINT(va_arg(ap, ptrdiff_t));
            else if (length == L_J) PRINT(va_arg(ap, intmax_t));
            else PRINT(va_arg(ap, int));
            break;
          case 'u': case 'o': case 'x': case 'X':
            if (length == L_LL) PRINT(va_arg(ap, unsigned long long));
            else if (length == L_L) PRINT(va_arg(ap, unsigned long));
            else if (length == L_Z) PRINT(va_arg(ap, size_t));
            else if (length == L_T) PRINT(va_arg(ap, ptrdiff_t));
            else if (length == L_J) PRINT(va_arg(ap, uintmax_t));
            else PRINT(va_arg(ap, unsigned int));
            break;
          case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A':
            if (length == L_BIGL) PRINT(va_arg(ap, long double));
            else PRINT(va_arg(ap, double));
            break;
          case 'c': PRINT(va_arg(ap, int)); break;
          case 'p': PRINT(va_arg(ap, void *)); break;
          case 's': {
            const char *s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            size_t sl = precision >= 0 ? strnlen(s, (size_t)precision) : strlen(s);
            if (!left && width > (long)sl) out_pad(&o, ' ', width - (long)sl);
            out_bytes(&o, s, sl);
            if (left && width > (long)sl) out_pad(&o, ' ', width - (long)sl);
            continue;
          }
          default:
            /* not a conversion C or CRuby knows: printed as written */
            out_bytes(&o, start, (size_t)(f - start));
            continue;
        }
#undef PRINT
        if (n > 0) out_bytes(&o, buffer, (size_t)n);
        if (buffer != small) free(buffer);
    }
    *len = o.len;
    return o.p;
}

VALUE rb_enc_vsprintf(rb_encoding *enc, const char *fmt, va_list ap) {
    size_t len = 0;
    VALUE carried = Qundef;
    char *p = format(fmt, ap, &len, &carried);
    VALUE str;
    /* (a String printed into it that is not ASCII alone gives the result its
     *  encoding, as CRuby's does when the two are compatible) */
    if (carried != Qundef) str = rb_enc_str_new(p, (long)len, rb_enc_get(carried));
    else if (enc) str = rb_enc_str_new(p, (long)len, enc);
    else str = rb_usascii_str_new(p, (long)len);
    free(p);
    return str;
}
VALUE rb_vsprintf(const char *fmt, va_list ap) { return rb_enc_vsprintf(NULL, fmt, ap); }
VALUE rb_sprintf(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    VALUE str = rb_vsprintf(fmt, ap);
    va_end(ap);
    return str;
}
VALUE rb_enc_sprintf(rb_encoding *enc, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    VALUE str = rb_enc_vsprintf(enc, fmt, ap);
    va_end(ap);
    return str;
}
VALUE rb_str_vcatf(VALUE str, const char *fmt, va_list ap) {
    size_t len = 0;
    char *p = format(fmt, ap, &len, NULL);
    rb_str_cat(str, p, (long)len);
    free(p);
    return str;
}
VALUE rb_str_catf(VALUE str, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    rb_str_vcatf(str, fmt, ap);
    va_end(ap);
    return str;
}
VALUE rb_str_format(int argc, const VALUE *argv, VALUE fmt) {
    VALUE args = rb_ary_new_from_values(argc, argv);
    return mr_call(fmt, "%", 1, args);
}
VALUE rb_f_sprintf(int argc, const VALUE *argv) { return mr_callv(mr_main(), rb_intern("sprintf"), argc, argv, Qnil, 0); }
int ruby_snprintf(char *str, size_t n, char const *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int r = vsnprintf(str, n, fmt, ap);
    va_end(ap);
    return r;
}
int ruby_vsnprintf(char *str, size_t n, char const *fmt, va_list ap) { return vsnprintf(str, n, fmt, ap); }
