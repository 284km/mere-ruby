/* A file name as macOS writes it back (file.c's rb_str_normalize_ospath,
 * which CRuby has on Apple's platforms only): HFS+ and APFS hand names out
 * decomposed, and Ruby composes them again -- NFC -- except in the ranges
 * HFS+ never decomposes (U+2000..U+2FFF, U+F900..U+FAFF, U+2F800..U+2FAFF),
 * which are copied as they are. A byte that is not UTF-8 becomes U+FFFD.
 *
 * CRuby composes with CoreFoundation's CFStringNormalize; the composition
 * here is the interpreter's String#unicode_normalize(:nfc), the same Unicode
 * algorithm on the same segments. */
#include "mr_capi.h"
#include "ruby/encoding.h"

#ifdef __APPLE__
static void append_normalized(VALUE str, const char *ptr, long len) {
    if (len <= 0) return;
    VALUE part = rb_enc_str_new(ptr, len, rb_utf8_encoding());
    VALUE nfc = mr_call(part, "unicode_normalize", 1, ID2SYM(rb_intern("nfc")));
    rb_str_buf_append(str, nfc);
}

VALUE rb_str_normalize_ospath(const char *ptr, long len) {
    const char *p = ptr, *e = ptr + len, *p1 = p;
    rb_encoding *enc = rb_utf8_encoding();
    VALUE str = rb_enc_str_new(NULL, 0, enc);
    while (p < e) {
        int r = rb_enc_precise_mbclen(p, e, enc);
        if (!MBCLEN_CHARFOUND_P(r)) {
            static const char invalid[3] = "\xEF\xBF\xBD";
            append_normalized(str, p1, p - p1);
            rb_str_cat(str, invalid, sizeof(invalid));
            p += 1;
            p1 = p;
            continue;
        }
        int l = MBCLEN_CHARFOUND_LEN(r);
        unsigned int c = rb_enc_mbc_to_codepoint(p, e, enc);
        if ((0x2000 <= c && c <= 0x2FFF) || (0xF900 <= c && c <= 0xFAFF) || (0x2F800 <= c && c <= 0x2FAFF)) {
            append_normalized(str, p1, p - p1);
            rb_str_cat(str, p, l);
            p += l;
            p1 = p;
        }
        else p += l;
    }
    append_normalized(str, p1, p - p1);
    return str;
}
#endif
