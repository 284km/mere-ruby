/* Integers to and from bytes: rb_integer_pack, rb_integer_unpack and the
 * rb_absint_* questions (ruby/internal/intern/bignum.h has their contract,
 * written out). An Integer's magnitude is asked of the interpreter as
 * hexadecimal digits, and everything else is done here on its bytes. */
#include "mr_capi.h"
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#define WORDORDER (INTEGER_PACK_MSWORD_FIRST | INTEGER_PACK_LSWORD_FIRST)
#define BYTEORDER (INTEGER_PACK_MSBYTE_FIRST | INTEGER_PACK_LSBYTE_FIRST | INTEGER_PACK_NATIVE_BYTE_ORDER)

/* |val| as bytes, least significant first; its sign; how many bits it has. */
struct magnitude { unsigned char *bytes; size_t len; int sign; size_t bits; };
static struct magnitude magnitude_of(VALUE val) {
    struct magnitude m = { NULL, 0, 0, 0 };
    val = rb_to_int(val);
    int negative = RTEST(mr_call(val, "<", 1, INT2FIX(0)));
    VALUE hex = mr_call(mr_call(val, "abs", 0), "to_s", 1, INT2FIX(16));
    const char *s = RSTRING_PTR(hex);
    size_t n = (size_t)RSTRING_LEN(hex);
    while (n > 1 && *s == '0') { s++; n--; }
    if (n == 1 && *s == '0') {
        m.bytes = ruby_xcalloc(1, 1);
        return m;
    }
    m.sign = negative ? -1 : 1;
    m.len = (n + 1) / 2;
    m.bytes = ruby_xcalloc(m.len + 1, 1);
    for (size_t i = 0; i < n; i++) {
        char c = s[n - 1 - i];
        unsigned digit = (unsigned)(c <= '9' ? c - '0' : (c | 0x20) - 'a' + 10);
        m.bytes[i / 2] |= (unsigned char)(digit << (4 * (i % 2)));
    }
    char top = s[0];
    unsigned first = (unsigned)(top <= '9' ? top - '0' : (top | 0x20) - 'a' + 10);
    int width = first >= 8 ? 4 : first >= 4 ? 3 : first >= 2 ? 2 : 1;
    m.bits = (n - 1) * 4 + (size_t)width;
    return m;
}
static int single_bit(const struct magnitude *m) {
    if (m->bits == 0) return 0;
    size_t top = (m->bits - 1) / 8;
    for (size_t i = 0; i < top; i++) if (m->bytes[i]) return 0;
    unsigned char b = m->bytes[top];
    return (b & (b - 1)) == 0;
}
/* `count` (at most 8) bits of a little-endian byte string, from bit `at`. */
static unsigned bits_at(const unsigned char *bytes, size_t len, size_t at, int count) {
    size_t i = at / 8;
    int shift = (int)(at % 8);
    unsigned v = 0;
    if (i < len) v = bytes[i];
    if (i + 1 < len) v |= (unsigned)bytes[i + 1] << 8;
    return (v >> shift) & ((1u << count) - 1);
}
static void put_bits(unsigned char *bytes, size_t len, size_t at, int count, unsigned value) {
    size_t i = at / 8;
    int shift = (int)(at % 8);
    unsigned v = (value & ((1u << count) - 1)) << shift;
    if (i < len) bytes[i] |= (unsigned char)(v & 0xff);
    if (i + 1 < len) bytes[i + 1] |= (unsigned char)(v >> 8);
}
static void validate(size_t numwords, size_t wordsize, size_t nails, int flags, int supported) {
    int wordorder = flags & WORDORDER, byteorder = flags & BYTEORDER;
    if (flags & ~supported) rb_raise(rb_eArgError, "unsupported flags specified");
    if (wordorder == 0) {
        if (1 < numwords) rb_raise(rb_eArgError, "word order not specified");
    }
    else if (wordorder != INTEGER_PACK_MSWORD_FIRST && wordorder != INTEGER_PACK_LSWORD_FIRST)
        rb_raise(rb_eArgError, "unexpected word order");
    if (byteorder == 0) rb_raise(rb_eArgError, "byte order not specified");
    else if (byteorder != INTEGER_PACK_MSBYTE_FIRST && byteorder != INTEGER_PACK_LSBYTE_FIRST && byteorder != INTEGER_PACK_NATIVE_BYTE_ORDER)
        rb_raise(rb_eArgError, "unexpected byte order");
    if (wordsize == 0) rb_raise(rb_eArgError, "invalid wordsize: %zu", wordsize);
    if (SSIZE_MAX < wordsize) rb_raise(rb_eArgError, "too big wordsize: %zu", wordsize);
    if (wordsize <= nails / CHAR_BIT) rb_raise(rb_eArgError, "too big nails: %zu", nails);
    if (SIZE_MAX / wordsize < numwords) rb_raise(rb_eArgError, "too big numwords * wordsize: %zu * %zu", numwords, wordsize);
}
/* Where byte `b` (0 the least significant) of word `w` (0 the least
 * significant) sits in the buffer. */
static size_t place(size_t w, size_t b, size_t numwords, size_t wordsize, int flags) {
    size_t word = (flags & INTEGER_PACK_MSWORD_FIRST) ? numwords - 1 - w : w;
    int msbyte = (flags & INTEGER_PACK_MSBYTE_FIRST) != 0;
#ifdef WORDS_BIGENDIAN
    if (flags & INTEGER_PACK_NATIVE_BYTE_ORDER) msbyte = 1;
#endif
    return word * wordsize + (msbyte ? wordsize - 1 - b : b);
}

int rb_integer_pack(VALUE val, void *words, size_t numwords, size_t wordsize, size_t nails, int flags) {
    validate(numwords, wordsize, nails, flags,
             WORDORDER | BYTEORDER | INTEGER_PACK_2COMP | INTEGER_PACK_FORCE_GENERIC_IMPLEMENTATION);
    struct magnitude m = magnitude_of(val);
    size_t wordbits = wordsize * CHAR_BIT - nails;
    size_t total = numwords * wordbits;
    int sign = m.sign;
    if (sign > 0 && m.bits > total) sign = 2;
    if (sign < 0) {
        if (flags & INTEGER_PACK_2COMP) {
            if (m.bits > total + 1 || (m.bits == total + 1 && !single_bit(&m))) sign = -2;
        }
        else if (m.bits > total) sign = -2;
    }
    /* the bits that go out: |val|, or its two's complement over `total` bits */
    size_t nbytes = total / 8 + 2;
    unsigned char *bits = ruby_xcalloc(nbytes, 1);
    memcpy(bits, m.bytes, m.len < nbytes ? m.len : nbytes);
    if (m.sign < 0 && (flags & INTEGER_PACK_2COMP)) {
        unsigned carry = 1;
        for (size_t i = 0; i < nbytes; i++) {
            unsigned v = (unsigned)(unsigned char)~bits[i] + carry;
            bits[i] = (unsigned char)v;
            carry = v >> 8;
        }
    }
    unsigned char *out = words;
    memset(out, 0, numwords * wordsize);
    for (size_t w = 0; w < numwords; w++) {
        for (size_t b = 0; b < wordsize; b++) {
            if (b * 8 >= wordbits) break;
            size_t left = wordbits - b * 8;
            int count = left >= 8 ? 8 : (int)left;
            out[place(w, b, numwords, wordsize, flags)] = (unsigned char)bits_at(bits, nbytes, w * wordbits + b * 8, count);
        }
    }
    ruby_xfree(bits);
    ruby_xfree(m.bytes);
    return sign;
}

/* An Integer from little-endian magnitude bytes and a sign. */
static VALUE integer_from(const unsigned char *bytes, size_t len, int negative) {
    while (len > 0 && bytes[len - 1] == 0) len--;
    if (len == 0) return INT2FIX(0);
    char *hex = ruby_xmalloc(len * 2 + 2);
    char *p = hex;
    if (negative) *p++ = '-';
    for (size_t i = len; i-- > 0; ) {
        *p++ = "0123456789abcdef"[bytes[i] >> 4];
        *p++ = "0123456789abcdef"[bytes[i] & 15];
    }
    *p = 0;
    mr_put_text(hex);
    ruby_xfree(hex);
    return mr_up1(MR_INT_NEW, 16);
}
VALUE rb_integer_unpack(const void *words, size_t numwords, size_t wordsize, size_t nails, int flags) {
    validate(numwords, wordsize, nails, flags,
             WORDORDER | BYTEORDER | INTEGER_PACK_2COMP | INTEGER_PACK_FORCE_BIGNUM | INTEGER_PACK_NEGATIVE
             | INTEGER_PACK_FORCE_GENERIC_IMPLEMENTATION);
    size_t wordbits = wordsize * CHAR_BIT - nails;
    size_t total = numwords * wordbits;
    size_t nbytes = total / 8 + 2;
    unsigned char *bits = ruby_xcalloc(nbytes, 1);
    const unsigned char *in = words;
    for (size_t w = 0; w < numwords; w++) {
        for (size_t b = 0; b < wordsize; b++) {
            if (b * 8 >= wordbits) break;
            size_t left = wordbits - b * 8;
            int count = left >= 8 ? 8 : (int)left;
            put_bits(bits, nbytes, w * wordbits + b * 8, count, in[place(w, b, numwords, wordsize, flags)]);
        }
    }
    int negative = 0;
    if (flags & INTEGER_PACK_2COMP) {
        int top = total > 0 && (bits[(total - 1) / 8] >> ((total - 1) % 8)) & 1;
        if ((flags & INTEGER_PACK_NEGATIVE) || top) {
            /* raw - 2**total: the magnitude is the two's complement, and
             * 2**total itself when every bit is 0 */
            negative = 1;
            unsigned carry = 1;
            for (size_t i = 0; i < nbytes; i++) {
                unsigned v = (unsigned)(unsigned char)~bits[i] + carry;
                bits[i] = (unsigned char)v;
                carry = v >> 8;
            }
            /* keep `total` bits, and the one above them when the rest are 0 */
            int zero = 1;
            for (size_t i = 0; i < nbytes; i++) {
                size_t lo = i * 8;
                if (lo >= total) bits[i] = 0;
                else if (lo + 8 > total) bits[i] &= (unsigned char)((1u << (total - lo)) - 1);
                if (bits[i]) zero = 0;
            }
            if (zero) bits[total / 8] |= (unsigned char)(1u << (total % 8));
        }
    }
    else if (flags & INTEGER_PACK_NEGATIVE) negative = 1;
    VALUE result = integer_from(bits, nbytes, negative);
    ruby_xfree(bits);
    return result;
}

size_t rb_absint_size(VALUE val, int *nlz_bits_ret) {
    struct magnitude m = magnitude_of(val);
    size_t bytes = (m.bits + 7) / 8;
    if (nlz_bits_ret) *nlz_bits_ret = (int)(bytes * 8 - m.bits);
    ruby_xfree(m.bytes);
    return bytes;
}
size_t rb_absint_numwords(VALUE val, size_t word_numbits, size_t *nlz_bits_ret) {
    struct magnitude m = magnitude_of(val);
    if (word_numbits == 0) { ruby_xfree(m.bytes); return (size_t)-1; }
    size_t words = (m.bits + word_numbits - 1) / word_numbits;
    if (nlz_bits_ret) *nlz_bits_ret = words * word_numbits - m.bits;
    ruby_xfree(m.bytes);
    return words;
}
int rb_absint_singlebit_p(VALUE val) {
    struct magnitude m = magnitude_of(val);
    int answer = single_bit(&m);
    ruby_xfree(m.bytes);
    return answer;
}
void rb_big_pack(VALUE val, unsigned long *buf, long num_longs) {
    rb_integer_pack(val, buf, (size_t)num_longs, sizeof(long), 0,
                    INTEGER_PACK_LSWORD_FIRST | INTEGER_PACK_NATIVE_BYTE_ORDER | INTEGER_PACK_2COMP);
}
VALUE rb_big_unpack(unsigned long *buf, long num_longs) {
    return rb_integer_unpack(buf, (size_t)num_longs, sizeof(long), 0,
                             INTEGER_PACK_LSWORD_FIRST | INTEGER_PACK_NATIVE_BYTE_ORDER | INTEGER_PACK_2COMP);
}
