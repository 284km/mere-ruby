/* Encodings. C knows an encoding as an `rb_encoding *` (Onigmo's struct: a
 * name, the least and most bytes of a character, and functions that walk
 * characters) and as a small index kept in a String's flags; the
 * interpreter knows it by name. This file holds the table between them.
 *
 * The character functions are written here for the encodings whose rules
 * are stated below (single-byte, UTF-8, UTF-16, UTF-32, EUC-JP, Shift_JIS).
 * For any other multi-byte encoding the table has its name and its widths
 * and the functions raise NotImplementedError: nothing answers by guess. */
#include "mr_capi.h"
#include <stdlib.h>
#include <string.h>

#define ENC_DUMMY_FLAG (1 << 24)
#define ENC_INDEX_MASK (~(~0U << 24))
enum family { F_SINGLE, F_UTF8, F_UTF16BE, F_UTF16LE, F_UTF32BE, F_UTF32LE, F_EUCJP, F_SJIS, F_OTHER };
struct known { const char *name; int min, max; enum family family; int dummy; };
/* The first twelve are in CRuby's own order (its fixed indexes). */
static const struct known known[] = {
    { "ASCII-8BIT", 1, 1, F_SINGLE, 0 }, { "UTF-8", 1, 4, F_UTF8, 0 }, { "US-ASCII", 1, 1, F_SINGLE, 0 },
    { "UTF-16BE", 2, 4, F_UTF16BE, 0 }, { "UTF-16LE", 2, 4, F_UTF16LE, 0 },
    { "UTF-32BE", 4, 4, F_UTF32BE, 0 }, { "UTF-32LE", 4, 4, F_UTF32LE, 0 },
    { "UTF-16", 2, 4, F_UTF16BE, 1 }, { "UTF-32", 4, 4, F_UTF32BE, 1 },
    { "UTF8-MAC", 1, 4, F_UTF8, 0 }, { "EUC-JP", 1, 3, F_EUCJP, 0 }, { "Windows-31J", 1, 2, F_SJIS, 0 },
    { "Shift_JIS", 1, 2, F_SJIS, 0 }, { "MacJapanese", 1, 2, F_SJIS, 0 }, { "SJIS-DoCoMo", 1, 2, F_SJIS, 0 },
    { "SJIS-KDDI", 1, 2, F_SJIS, 0 }, { "SJIS-SoftBank", 1, 2, F_SJIS, 0 },
    { "eucJP-ms", 1, 3, F_EUCJP, 0 }, { "CP51932", 1, 3, F_EUCJP, 0 }, { "EUC-JIS-2004", 1, 3, F_EUCJP, 0 },
    { "stateless-ISO-2022-JP", 1, 3, F_EUCJP, 0 }, { "stateless-ISO-2022-JP-KDDI", 1, 3, F_EUCJP, 0 },
    { "UTF8-DoCoMo", 1, 4, F_UTF8, 0 }, { "UTF8-KDDI", 1, 4, F_UTF8, 0 }, { "UTF8-SoftBank", 1, 4, F_UTF8, 0 },
    { "CESU-8", 1, 6, F_OTHER, 0 }, { "EUC-KR", 1, 2, F_OTHER, 0 }, { "CP949", 1, 2, F_OTHER, 0 },
    { "EUC-TW", 1, 4, F_OTHER, 0 }, { "Big5", 1, 2, F_OTHER, 0 }, { "Big5-HKSCS", 1, 2, F_OTHER, 0 },
    { "Big5-UAO", 1, 2, F_OTHER, 0 }, { "CP950", 1, 2, F_OTHER, 0 }, { "CP951", 1, 2, F_OTHER, 0 },
    { "GB2312", 1, 2, F_OTHER, 0 }, { "GBK", 1, 2, F_OTHER, 0 }, { "CP936", 1, 2, F_OTHER, 0 },
    { "GB12345", 1, 2, F_OTHER, 0 }, { "GB18030", 1, 4, F_OTHER, 0 }, { "Emacs-Mule", 1, 4, F_OTHER, 0 },
    { "UTF-7", 1, 1, F_SINGLE, 1 }, { "ISO-2022-JP", 1, 1, F_SINGLE, 1 }, { "ISO-2022-JP-2", 1, 1, F_SINGLE, 1 },
    { "ISO-2022-JP-KDDI", 1, 1, F_SINGLE, 1 }, { "CP50220", 1, 1, F_SINGLE, 1 }, { "CP50221", 1, 1, F_SINGLE, 1 },
    { "IBM037", 1, 1, F_SINGLE, 1 },
};
struct entry { OnigEncodingType type; enum family family; };
static struct entry **entries;
static int entry_count, entry_cap;

/* ---- walking characters ------------------------------------------------------- */
#define FOUND(n) ONIGENC_CONSTRUCT_MBCLEN_CHARFOUND(n)
#define INVALID ONIGENC_CONSTRUCT_MBCLEN_INVALID()
#define NEEDMORE(n) ONIGENC_CONSTRUCT_MBCLEN_NEEDMORE(n)
static enum family family_of(OnigEncoding enc) { return ((const struct entry *)(const void *)enc)->family; }
static RBIMPL_ATTR_NORETURN() void no_rules(OnigEncoding enc) {
    rb_raise(rb_eNotImpError, "mere-ruby's C API has no character rules for %s", enc->name);
}
static int utf8_len(const OnigUChar *p, const OnigUChar *e) {
    unsigned c = p[0];
    int n, need;
    if (c < 0x80) return FOUND(1);
    if (c < 0xc2) return INVALID;
    else if (c < 0xe0) n = 2;
    else if (c < 0xf0) n = 3;
    else if (c < 0xf5) n = 4;
    else return INVALID;
    need = n - (int)(e - p);
    for (int i = 1; i < n && p + i < e; i++) {
        unsigned t = p[i];
        if ((t & 0xc0) != 0x80) return INVALID;
        if (i == 1) {
            if (c == 0xe0 && t < 0xa0) return INVALID;
            if (c == 0xed && t > 0x9f) return INVALID;
            if (c == 0xf0 && t < 0x90) return INVALID;
            if (c == 0xf4 && t > 0x8f) return INVALID;
        }
    }
    return need > 0 ? NEEDMORE(need) : FOUND(n);
}
static int precise_len(const OnigUChar *p, const OnigUChar *e, OnigEncoding enc) {
    if (p >= e) return NEEDMORE(1);
    long left = (long)(e - p);
    switch (family_of(enc)) {
      case F_SINGLE: return FOUND(1);
      case F_UTF8: return utf8_len(p, e);
      case F_UTF16BE: case F_UTF16LE: {
        if (left < 2) return NEEDMORE(2 - (int)left);
        unsigned hi = family_of(enc) == F_UTF16BE ? p[0] : p[1];
        if (hi >= 0xdc && hi <= 0xdf) return INVALID;
        if (hi >= 0xd8 && hi <= 0xdb) {
            if (left < 4) return NEEDMORE(4 - (int)left);
            unsigned lo = family_of(enc) == F_UTF16BE ? p[2] : p[3];
            return (lo >= 0xdc && lo <= 0xdf) ? FOUND(4) : INVALID;
        }
        return FOUND(2);
      }
      case F_UTF32BE: case F_UTF32LE: {
        if (left < 4) return NEEDMORE(4 - (int)left);
        unsigned long c = family_of(enc) == F_UTF32BE
            ? ((unsigned long)p[0] << 24 | (unsigned long)p[1] << 16 | (unsigned long)p[2] << 8 | p[3])
            : ((unsigned long)p[3] << 24 | (unsigned long)p[2] << 16 | (unsigned long)p[1] << 8 | p[0]);
        return (c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) ? INVALID : FOUND(4);
      }
      case F_EUCJP: {
        unsigned c = p[0];
        if (c < 0x80) return FOUND(1);
        int n = c == 0x8f ? 3 : (c == 0x8e || (c >= 0xa1 && c <= 0xfe)) ? 2 : 0;
        if (!n) return INVALID;
        for (int i = 1; i < n && i < left; i++) {
            unsigned t = p[i];
            if (c == 0x8e ? !(t >= 0xa1 && t <= 0xdf) : !(t >= 0xa1 && t <= 0xfe)) return INVALID;
        }
        return left < n ? NEEDMORE(n - (int)left) : FOUND(n);
      }
      case F_SJIS: {
        unsigned c = p[0];
        if (c < 0x80 || (c >= 0xa1 && c <= 0xdf)) return FOUND(1);
        if (!((c >= 0x81 && c <= 0x9f) || (c >= 0xe0 && c <= 0xfc))) return INVALID;
        if (left < 2) return NEEDMORE(1);
        unsigned t = p[1];
        return ((t >= 0x40 && t <= 0x7e) || (t >= 0x80 && t <= 0xfc)) ? FOUND(2) : INVALID;
      }
      case F_OTHER: break;
    }
    no_rules(enc);
}
static OnigCodePoint to_code(const OnigUChar *p, const OnigUChar *e, OnigEncoding enc) {
    int r = precise_len(p, e, enc);
    int n = r > 0 ? r : 1;
    switch (family_of(enc)) {
      case F_SINGLE: return p[0];
      case F_UTF8:
        if (n == 1) return p[0];
        if (n == 2) return ((OnigCodePoint)(p[0] & 0x1f) << 6) | (p[1] & 0x3f);
        if (n == 3) return ((OnigCodePoint)(p[0] & 0x0f) << 12) | ((OnigCodePoint)(p[1] & 0x3f) << 6) | (p[2] & 0x3f);
        return ((OnigCodePoint)(p[0] & 0x07) << 18) | ((OnigCodePoint)(p[1] & 0x3f) << 12) | ((OnigCodePoint)(p[2] & 0x3f) << 6) | (p[3] & 0x3f);
      case F_UTF16BE: case F_UTF16LE: {
        int be = family_of(enc) == F_UTF16BE;
        OnigCodePoint a = be ? ((OnigCodePoint)p[0] << 8 | p[1]) : ((OnigCodePoint)p[1] << 8 | p[0]);
        if (n < 4) return a;
        OnigCodePoint b = be ? ((OnigCodePoint)p[2] << 8 | p[3]) : ((OnigCodePoint)p[3] << 8 | p[2]);
        return 0x10000 + ((a - 0xd800) << 10) + (b - 0xdc00);
      }
      case F_UTF32BE: return (OnigCodePoint)p[0] << 24 | (OnigCodePoint)p[1] << 16 | (OnigCodePoint)p[2] << 8 | p[3];
      case F_UTF32LE: return (OnigCodePoint)p[3] << 24 | (OnigCodePoint)p[2] << 16 | (OnigCodePoint)p[1] << 8 | p[0];
      case F_EUCJP: case F_SJIS: {
        OnigCodePoint c = 0;
        for (int i = 0; i < n; i++) c = (c << 8) | p[i];
        return c;
      }
      case F_OTHER: break;
    }
    no_rules(enc);
}
static int code_len(OnigCodePoint c, OnigEncoding enc) {
    switch (family_of(enc)) {
      case F_SINGLE: return c < 0x100 ? 1 : ONIGERR_INVALID_CODE_POINT_VALUE;
      case F_UTF8: return c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : c < 0x110000 ? 4 : ONIGERR_INVALID_CODE_POINT_VALUE;
      case F_UTF16BE: case F_UTF16LE: return c < 0x10000 ? 2 : 4;
      case F_UTF32BE: case F_UTF32LE: return 4;
      case F_EUCJP: return c < 0x100 ? 1 : c < 0x10000 ? 2 : 3;
      case F_SJIS: return c < 0x100 ? 1 : 2;
      case F_OTHER: break;
    }
    no_rules(enc);
}
static int code_to_bytes(OnigCodePoint c, OnigUChar *buf, OnigEncoding enc) {
    int n = code_len(c, enc);
    if (n < 0) return n;
    switch (family_of(enc)) {
      case F_SINGLE: buf[0] = (OnigUChar)c; break;
      case F_UTF8:
        if (n == 1) buf[0] = (OnigUChar)c;
        else if (n == 2) { buf[0] = (OnigUChar)(0xc0 | (c >> 6)); buf[1] = (OnigUChar)(0x80 | (c & 0x3f)); }
        else if (n == 3) { buf[0] = (OnigUChar)(0xe0 | (c >> 12)); buf[1] = (OnigUChar)(0x80 | ((c >> 6) & 0x3f)); buf[2] = (OnigUChar)(0x80 | (c & 0x3f)); }
        else { buf[0] = (OnigUChar)(0xf0 | (c >> 18)); buf[1] = (OnigUChar)(0x80 | ((c >> 12) & 0x3f)); buf[2] = (OnigUChar)(0x80 | ((c >> 6) & 0x3f)); buf[3] = (OnigUChar)(0x80 | (c & 0x3f)); }
        break;
      case F_UTF16BE: case F_UTF16LE: {
        int be = family_of(enc) == F_UTF16BE;
        OnigCodePoint units[2] = { c, 0 };
        if (n == 4) { units[0] = 0xd800 + ((c - 0x10000) >> 10); units[1] = 0xdc00 + ((c - 0x10000) & 0x3ff); }
        for (int i = 0; i < n / 2; i++) {
            buf[2 * i + (be ? 0 : 1)] = (OnigUChar)(units[i] >> 8);
            buf[2 * i + (be ? 1 : 0)] = (OnigUChar)(units[i] & 0xff);
        }
        break;
      }
      case F_UTF32BE: buf[0] = (OnigUChar)(c >> 24); buf[1] = (OnigUChar)(c >> 16); buf[2] = (OnigUChar)(c >> 8); buf[3] = (OnigUChar)c; break;
      case F_UTF32LE: buf[3] = (OnigUChar)(c >> 24); buf[2] = (OnigUChar)(c >> 16); buf[1] = (OnigUChar)(c >> 8); buf[0] = (OnigUChar)c; break;
      case F_EUCJP: case F_SJIS:
        for (int i = 0; i < n; i++) buf[i] = (OnigUChar)(c >> (8 * (n - 1 - i)));
        break;
      case F_OTHER: no_rules(enc);
    }
    return n;
}
static int is_newline(const OnigUChar *p, const OnigUChar *e, OnigEncoding enc) {
    if (p >= e) return 0;
    return to_code(p, e, enc) == 0x0a;
}
/* (the ASCII range only: what a character past it is, is the interpreter's to say) */
static int is_ctype(OnigCodePoint c, OnigCtype ctype, OnigEncoding enc) {
    (void)enc;
    if (c >= 0x80) return 0;
    switch (ctype) {
      case ONIGENC_CTYPE_NEWLINE: return c == '\n';
      case ONIGENC_CTYPE_ALPHA: return (c | 0x20) >= 'a' && (c | 0x20) <= 'z';
      case ONIGENC_CTYPE_BLANK: return c == ' ' || c == '\t';
      case ONIGENC_CTYPE_CNTRL: return c < 0x20 || c == 0x7f;
      case ONIGENC_CTYPE_DIGIT: return c >= '0' && c <= '9';
      case ONIGENC_CTYPE_GRAPH: return c > 0x20 && c < 0x7f;
      case ONIGENC_CTYPE_LOWER: return c >= 'a' && c <= 'z';
      case ONIGENC_CTYPE_PRINT: return c >= 0x20 && c < 0x7f;
      case ONIGENC_CTYPE_PUNCT: return c > 0x20 && c < 0x7f && !((c | 0x20) >= 'a' && (c | 0x20) <= 'z') && !(c >= '0' && c <= '9');
      case ONIGENC_CTYPE_SPACE: return c == ' ' || (c >= 0x09 && c <= 0x0d);
      case ONIGENC_CTYPE_UPPER: return c >= 'A' && c <= 'Z';
      case ONIGENC_CTYPE_XDIGIT: return (c >= '0' && c <= '9') || ((c | 0x20) >= 'a' && (c | 0x20) <= 'f');
      case ONIGENC_CTYPE_WORD: return ((c | 0x20) >= 'a' && (c | 0x20) <= 'z') || (c >= '0' && c <= '9') || c == '_';
      case ONIGENC_CTYPE_ALNUM: return ((c | 0x20) >= 'a' && (c | 0x20) <= 'z') || (c >= '0' && c <= '9');
      case ONIGENC_CTYPE_ASCII: return 1;
    }
    return 0;
}
static OnigUChar *char_head(const OnigUChar *start, const OnigUChar *p, const OnigUChar *e, OnigEncoding enc) {
    if (p <= start) return (OnigUChar *)p;
    switch (family_of(enc)) {
      case F_SINGLE: return (OnigUChar *)p;
      case F_UTF8: {
        const OnigUChar *q = p;
        while (q > start && (*q & 0xc0) == 0x80) q--;
        return (OnigUChar *)q;
      }
      case F_UTF16BE: case F_UTF16LE: {
        const OnigUChar *q = start + (((p - start) / 2) * 2);
        if (q > start && q + 1 < e) {
            unsigned hi = family_of(enc) == F_UTF16BE ? q[0] : q[1];
            if (hi >= 0xdc && hi <= 0xdf) q -= 2;
        }
        return (OnigUChar *)q;
      }
      case F_UTF32BE: case F_UTF32LE: return (OnigUChar *)(start + (((p - start) / 4) * 4));
      default: {
        /* walk from the start: the only sure way where a trail byte can look like a lead */
        const OnigUChar *q = start;
        while (q < p) {
            int r = precise_len(q, e, enc);
            int n = r > 0 ? r : 1;
            if (q + n > p) break;
            q += n;
        }
        return (OnigUChar *)q;
      }
    }
}
static int unsupported_fold(OnigCaseFoldType f, const OnigUChar **pp, const OnigUChar *e, OnigUChar *to, OnigEncoding enc) { (void)f; (void)pp; (void)e; (void)to; no_rules(enc); }
static int unsupported_all_fold(OnigCaseFoldType f, OnigApplyAllCaseFoldFunc fn, void *arg, OnigEncoding enc) { (void)f; (void)fn; (void)arg; no_rules(enc); }
static int unsupported_fold_codes(OnigCaseFoldType f, const OnigUChar *p, const OnigUChar *e, OnigCaseFoldCodeItem acs[], OnigEncoding enc) { (void)f; (void)p; (void)e; (void)acs; no_rules(enc); }
static int unsupported_property(OnigEncoding enc, const OnigUChar *p, const OnigUChar *e) { (void)p; (void)e; no_rules(enc); }
static int unsupported_range(OnigCtype c, OnigCodePoint *sb, const OnigCodePoint *ranges[], OnigEncoding enc) { (void)c; (void)sb; (void)ranges; no_rules(enc); }
static int reverse_ok(const OnigUChar *p, const OnigUChar *e, OnigEncoding enc) { (void)p; (void)e; (void)enc; return 1; }
static int unsupported_case_map(OnigCaseFoldType *f, const OnigUChar **pp, const OnigUChar *e, OnigUChar *to, OnigUChar *to_end, OnigEncoding enc) { (void)f; (void)pp; (void)e; (void)to; (void)to_end; no_rules(enc); }

/* ---- the table ------------------------------------------------------------------ */
static int add(const char *name, int min, int max, enum family family, int dummy) {
    if (entry_count == entry_cap) {
        entry_cap = entry_cap ? entry_cap * 2 : 128;
        entries = realloc(entries, sizeof(*entries) * (size_t)entry_cap);
        if (!entries) mr_fatal("out of memory");
    }
    struct entry *e = calloc(1, sizeof(*e));
    if (!e) mr_fatal("out of memory");
    e->family = family;
    e->type.precise_mbc_enc_len = precise_len;
    e->type.name = strdup(name);
    e->type.max_enc_len = max;
    e->type.min_enc_len = min;
    e->type.is_mbc_newline = is_newline;
    e->type.mbc_to_code = to_code;
    e->type.code_to_mbclen = code_len;
    e->type.code_to_mbc = code_to_bytes;
    e->type.mbc_case_fold = unsupported_fold;
    e->type.apply_all_case_fold = unsupported_all_fold;
    e->type.get_case_fold_codes_by_str = unsupported_fold_codes;
    e->type.property_name_to_ctype = unsupported_property;
    e->type.is_code_ctype = is_ctype;
    e->type.get_ctype_code_range = unsupported_range;
    e->type.left_adjust_char_head = char_head;
    e->type.is_allowed_reverse_match = reverse_ok;
    e->type.case_map = unsupported_case_map;
    e->type.ruby_encoding_index = entry_count | (dummy ? ENC_DUMMY_FLAG : 0);
    e->type.flags = (family >= F_UTF8 && family <= F_UTF32LE) ? ONIGENC_FLAG_UNICODE : ONIGENC_FLAG_NONE;
    entries[entry_count] = e;
    return entry_count++;
}
static void fill(void) {
    if (entry_count) return;
    for (size_t i = 0; i < 12; i++) add(known[i].name, known[i].min, known[i].max, known[i].family, known[i].dummy);
}
static int same_name(const char *a, const char *b) {
    for (; *a && *b; a++, b++) {
        int x = *a, y = *b;
        if (x >= 'A' && x <= 'Z') x += 32;
        if (y >= 'A' && y <= 'Z') y += 32;
        if (x != y) return 0;
    }
    return *a == *b;
}
/* The index of an encoding by the name the interpreter has for it. A name
 * not in the multi-byte list above is one of CRuby's single-byte encodings. */
int mr_enc_index_of_name(const char *name) {
    fill();
    if (same_name(name, "BINARY")) name = "ASCII-8BIT";
    for (int i = 0; i < entry_count; i++) if (same_name(entries[i]->type.name, name)) return i;
    for (size_t i = 12; i < sizeof(known) / sizeof(known[0]); i++)
        if (same_name(known[i].name, name)) return add(known[i].name, known[i].min, known[i].max, known[i].family, known[i].dummy);
    return add(name, 1, 1, F_SINGLE, 0);
}
const char *mr_enc_name_of_index(int index) {
    fill();
    return index >= 0 && index < entry_count ? entries[index]->type.name : NULL;
}
int mr_capi_enc_index(const char *name) { return mr_enc_index_of_name(name); }

/* The encoding the interpreter means by a name or an alias: asked of it, so
 * an unknown name is refused as Ruby refuses it. */
static int index_by_lookup(const char *name) {
    fill();
    for (int i = 0; i < entry_count; i++) if (same_name(entries[i]->type.name, name)) return i;
    VALUE found = mr_call(mr_ruby("->(n) { (Encoding.find(n).name rescue nil) }"), "call", 1, rb_str_new_cstr(name));
    if (NIL_P(found)) return -1;
    return mr_enc_index_of_name(StringValueCStr(found));
}

int rb_ascii8bit_encindex(void) { return 0; }
int rb_utf8_encindex(void) { return 1; }
int rb_usascii_encindex(void) { return 2; }
rb_encoding *rb_enc_from_index(int index) { fill(); return index >= 0 && index < entry_count ? &entries[index]->type : NULL; }
rb_encoding *rb_ascii8bit_encoding(void) { return rb_enc_from_index(0); }
rb_encoding *rb_utf8_encoding(void) { return rb_enc_from_index(1); }
rb_encoding *rb_usascii_encoding(void) { return rb_enc_from_index(2); }
int rb_enc_to_index(rb_encoding *enc) { return enc ? (int)(enc->ruby_encoding_index & ENC_INDEX_MASK) : 0; }
int rb_enc_dummy_p(rb_encoding *enc) { return (enc->ruby_encoding_index & ENC_DUMMY_FLAG) != 0; }
int rb_enc_find_index(const char *name) { return index_by_lookup(name); }
rb_encoding *rb_enc_find(const char *name) {
    int i = index_by_lookup(name);
    return i < 0 ? rb_ascii8bit_encoding() : rb_enc_from_index(i);
}
static int index_of_object(VALUE encoding) {
    VALUE name = mr_call(encoding, "name", 0);
    return mr_enc_index_of_name(StringValueCStr(name));
}
VALUE rb_enc_from_encoding(rb_encoding *enc) {
    if (!enc) return Qnil;
    return mr_call(rb_cEncoding, "find", 1, rb_str_new_cstr(enc->name));
}
int rb_to_encoding_index(VALUE obj) {
    if (RTEST(rb_obj_is_kind_of(obj, rb_cEncoding))) return index_of_object(obj);
    VALUE name = rb_check_string_type(obj);
    if (NIL_P(name)) return -1;
    return index_by_lookup(StringValueCStr(name));
}
rb_encoding *rb_to_encoding(VALUE obj) {
    if (RTEST(rb_obj_is_kind_of(obj, rb_cEncoding))) return rb_enc_from_index(index_of_object(obj));
    VALUE name = rb_str_to_str(obj);
    int i = index_by_lookup(StringValueCStr(name));
    if (i < 0) rb_raise(rb_eArgError, "unknown encoding name - %" PRIsVALUE, name);
    return rb_enc_from_index(i);
}
rb_encoding *rb_find_encoding(VALUE obj) {
    if (RTEST(rb_obj_is_kind_of(obj, rb_cEncoding))) return rb_enc_from_index(index_of_object(obj));
    VALUE name = rb_check_string_type(obj);
    if (NIL_P(name)) return NULL;
    int i = index_by_lookup(StringValueCStr(name));
    return i < 0 ? NULL : rb_enc_from_index(i);
}
int rb_enc_get_index(VALUE obj) {
    if (RB_SPECIAL_CONST_P(obj)) {
        if (!RB_SYMBOL_P(obj)) return -1;
        return index_of_object(mr_call(obj, "encoding", 0));
    }
    switch (rb_type(obj)) {
      case T_STRING: case T_REGEXP:
        return (int)((RBASIC(obj)->flags >> RUBY_ENCODING_SHIFT) & RUBY_ENCODING_INLINE_MAX);
      default: break;
    }
    if (RTEST(rb_obj_is_kind_of(obj, rb_cEncoding))) return index_of_object(obj);
    if (rb_respond_to(obj, rb_intern("external_encoding"))) {
        VALUE e = mr_call(obj, "internal_encoding", 0);
        if (NIL_P(e)) e = mr_call(obj, "external_encoding", 0);
        return NIL_P(e) ? -1 : index_of_object(e);
    }
    return -1;
}
rb_encoding *rb_enc_get(VALUE obj) { return rb_enc_from_index(rb_enc_get_index(obj)); }
static VALUE encoding_object(int index) {
    const char *name = mr_enc_name_of_index(index);
    if (!name) rb_raise(rb_eEncodingError, "encoding index out of bound: %d", index);
    return mr_call(rb_cEncoding, "find", 1, rb_str_new_cstr(name));
}
VALUE rb_enc_associate_index(VALUE obj, int index) {
    rb_check_frozen(obj);
    mr_call(obj, "force_encoding", 1, encoding_object(index));
    mr_mirror_forget(obj);
    return obj;
}
VALUE rb_enc_associate(VALUE obj, rb_encoding *enc) { return rb_enc_associate_index(obj, rb_enc_to_index(enc)); }
void rb_enc_set_index(VALUE obj, int index) { rb_enc_associate_index(obj, index); }
void rb_enc_copy(VALUE dst, VALUE src) { rb_enc_associate_index(dst, rb_enc_get_index(src)); }
rb_encoding *rb_enc_compatible(VALUE a, VALUE b) {
    VALUE e = mr_call(rb_cEncoding, "compatible?", 2, a, b);
    return NIL_P(e) ? NULL : rb_enc_from_index(index_of_object(e));
}
rb_encoding *rb_enc_check(VALUE a, VALUE b) {
    rb_encoding *enc = rb_enc_compatible(a, b);
    if (!enc) rb_raise(rb_eEncCompatError, "incompatible character encodings: %s and %s", rb_enc_get(a)->name, rb_enc_get(b)->name);
    return enc;
}
static rb_encoding *encoding_or_null(VALUE e) { return NIL_P(e) ? NULL : rb_enc_from_index(index_of_object(e)); }
VALUE rb_enc_default_external(void) { return mr_call(rb_cEncoding, "default_external", 0); }
VALUE rb_enc_default_internal(void) { return mr_call(rb_cEncoding, "default_internal", 0); }
rb_encoding *rb_default_external_encoding(void) { return encoding_or_null(rb_enc_default_external()); }
rb_encoding *rb_default_internal_encoding(void) { return encoding_or_null(rb_enc_default_internal()); }
void rb_enc_set_default_external(VALUE encoding) { mr_call(rb_cEncoding, "default_external=", 1, encoding); }
void rb_enc_set_default_internal(VALUE encoding) { mr_call(rb_cEncoding, "default_internal=", 1, encoding); }
rb_encoding *rb_locale_encoding(void) { return encoding_or_null(mr_call(rb_cEncoding, "find", 1, rb_str_new_cstr("locale"))); }
int rb_locale_encindex(void) { return rb_enc_to_index(rb_locale_encoding()); }
rb_encoding *rb_filesystem_encoding(void) { return encoding_or_null(mr_call(rb_cEncoding, "find", 1, rb_str_new_cstr("filesystem"))); }
int rb_filesystem_encindex(void) { return rb_enc_to_index(rb_filesystem_encoding()); }
int rb_define_dummy_encoding(const char *name) {
    fill();
    for (int i = 0; i < entry_count; i++)
        if (same_name(entries[i]->type.name, name)) rb_raise(rb_eArgError, "encoding %s is already registered", name);
    mr_unsupported("rb_define_dummy_encoding (a new Encoding made from C)");
}

/* ---- characters ------------------------------------------------------------------- */
int rb_enc_precise_mbclen(const char *p, const char *e, rb_encoding *enc) {
    if (e <= p) return ONIGENC_CONSTRUCT_MBCLEN_NEEDMORE(1);
    int n = enc->precise_mbc_enc_len((const OnigUChar *)p, (const OnigUChar *)e, enc);
    if (ONIGENC_MBCLEN_CHARFOUND_P(n) && n > e - p) return ONIGENC_CONSTRUCT_MBCLEN_NEEDMORE(n - (int)(e - p));
    return n;
}
int rb_enc_mbclen(const char *p, const char *e, rb_encoding *enc) {
    int n = rb_enc_precise_mbclen(p, e, enc);
    if (ONIGENC_MBCLEN_CHARFOUND_P(n) && n <= e - p) return n;
    int min = enc->min_enc_len;
    return min <= e - p ? min : (int)(e - p);
}
int rb_enc_ascget(const char *p, const char *e, int *len, rb_encoding *enc) {
    if (e <= p) return -1;
    if (enc->min_enc_len == 1 && !rb_enc_dummy_p(enc)) {
        unsigned char c = (unsigned char)*p;
        if (c >= 0x80) return -1;
        if (len) *len = 1;
        return c;
    }
    int l = rb_enc_precise_mbclen(p, e, enc);
    if (!ONIGENC_MBCLEN_CHARFOUND_P(l)) return -1;
    unsigned int c = enc->mbc_to_code((const OnigUChar *)p, (const OnigUChar *)e, enc);
    if (c >= 0x80) return -1;
    if (len) *len = l;
    return (int)c;
}
unsigned int rb_enc_codepoint_len(const char *p, const char *e, int *len, rb_encoding *enc) {
    if (e <= p) rb_raise(rb_eArgError, "empty string");
    int r = rb_enc_precise_mbclen(p, e, enc);
    if (!ONIGENC_MBCLEN_CHARFOUND_P(r)) rb_raise(rb_eArgError, "invalid byte sequence in %s", enc->name);
    if (len) *len = r;
    return enc->mbc_to_code((const OnigUChar *)p, (const OnigUChar *)e, enc);
}
int rb_enc_codelen(int c, rb_encoding *enc) {
    int n = enc->code_to_mbclen((OnigCodePoint)c, enc);
    if (n <= 0) rb_raise(rb_eArgError, "invalid codepoint 0x%x in %s", (unsigned)c, enc->name);
    return n;
}
VALUE rb_enc_uint_chr(unsigned int code, rb_encoding *enc) { return mr_call(UINT2NUM(code), "chr", 1, rb_enc_from_encoding(enc)); }
int rb_enc_toupper(int c, rb_encoding *enc) { (void)enc; return (c >= 'a' && c <= 'z') ? c - 32 : c; }
int rb_enc_tolower(int c, rb_encoding *enc) { (void)enc; return (c >= 'A' && c <= 'Z') ? c + 32 : c; }
long rb_enc_strlen(const char *p, const char *e, rb_encoding *enc) {
    long n = 0;
    while (p < e) { p += rb_enc_mbclen(p, e, enc); n++; }
    return n;
}
char *rb_enc_nth(const char *p, const char *e, long nth, rb_encoding *enc) {
    while (p < e && nth-- > 0) p += rb_enc_mbclen(p, e, enc);
    return (char *)(p > e ? e : p);
}
int rb_enc_str_coderange(VALUE str) {
    if (RTEST(mr_call(str, "ascii_only?", 0))) return RUBY_ENC_CODERANGE_7BIT;
    return RTEST(mr_call(str, "valid_encoding?", 0)) ? RUBY_ENC_CODERANGE_VALID : RUBY_ENC_CODERANGE_BROKEN;
}
int rb_enc_str_asciionly_p(VALUE str) { return RTEST(mr_call(str, "ascii_only?", 0)); }
int rb_enc_symname_p(const char *name, rb_encoding *enc) { return rb_enc_symname2_p(name, (long)strlen(name), enc); }
int rb_enc_symname2_p(const char *name, long len, rb_encoding *enc) {
    VALUE s = rb_enc_str_new(name, len, enc);
    return RTEST(mr_call(mr_ruby("->(s) { s.to_sym.inspect !~ /\\A:\"/ }"), "call", 1, s));
}
int rb_enc_unicode_p(rb_encoding *enc) { return (enc->flags & ONIGENC_FLAG_UNICODE) != 0; }
long rb_str_coderange_scan_restartable(const char *s, const char *e, rb_encoding *enc, int *cr) {
    const char *p = s;
    int seen_high = 0;
    while (p < e) {
        int n = rb_enc_precise_mbclen(p, e, enc);
        if (!ONIGENC_MBCLEN_CHARFOUND_P(n)) { *cr = ONIGENC_MBCLEN_INVALID_P(n) ? RUBY_ENC_CODERANGE_BROKEN : RUBY_ENC_CODERANGE_UNKNOWN; return (long)(p - s); }
        if (n > 1 || (unsigned char)*p >= 0x80) seen_high = 1;
        p += n;
    }
    *cr = seen_high ? RUBY_ENC_CODERANGE_VALID : RUBY_ENC_CODERANGE_7BIT;
    return (long)(e - s);
}

/* The width of the smallest character of a String's encoding (its code unit
 * for UTF-16 and UTF-32): what its terminator is as wide as. */
int mr_encoding_unit(VALUE str) {
    rb_encoding *enc = rb_enc_get(str);
    return enc ? rb_enc_mbminlen(enc) : 1;
}

/* How deep a pattern's groups and character classes may nest before it is
 * refused ("parse depth limit over"): the regexp engine's limit, which is
 * the interpreter's parser's here. 0 puts ruby's default (4096) back. */
#include "ruby/onigmo.h"
unsigned int onig_get_parse_depth_limit(void) { return (unsigned int)(uintptr_t)mr_up(MR_RX_DEPTH, 0, 0, 0, 0, 0); }
int onig_set_parse_depth_limit(unsigned int depth) {
    mr_up(MR_RX_DEPTH, 1, (VALUE)depth, 0, 0, 0);
    return 0;
}
