/* IDs and Symbols. An ID is this side's number for a name; the Symbol VALUE
 * is CRuby's static-symbol immediate made from it. The interpreter knows a
 * Symbol by its name, and asks here for the number (mr_capi_intern) and back
 * (mr_capi_id_name). A one-character operator's ID is the character, as in
 * CRuby (`rb_funcall(x, '+', 1, y)` is written against that). */
#include "mr_capi.h"
#include <stdlib.h>
#include <string.h>

#define ID_FIRST 1024
/* `pinned`: C has used the name as an ID (rb_intern, rb_sym2id ...), which
 * pins it down. A name that only came over as a Symbol of the interpreter's
 * is not: that Symbol may be a dynamic one (String#to_sym), and whether it is
 * pinned is the interpreter's to say (MR_SYM_STATE). */
struct name { char *text; long len; uint64_t hash; int pinned; };
static struct name *names;
static long name_count, name_cap;
static long *buckets;       /* open addressing: index + 1, 0 empty */
static long bucket_cap;

static uint64_t hash_name(const char *s, long n) {
    uint64_t h = 1469598103934665603ULL;
    for (long i = 0; i < n; i++) h = (h ^ (unsigned char)s[i]) * 1099511628211ULL;
    return h;
}
static int operator_char(const char *s, long n) {
    return n == 1 && strchr("+-*/%<>!~^&|`", s[0]) != NULL;
}
static void rehash(void) {
    long cap = bucket_cap ? bucket_cap * 2 : 1024;
    long *fresh = calloc((size_t)cap, sizeof(long));
    if (!fresh) mr_fatal("out of memory");
    for (long i = 0; i < name_count; i++) {
        long at = (long)(names[i].hash & (uint64_t)(cap - 1));
        while (fresh[at]) at = (at + 1) & (cap - 1);
        fresh[at] = i + 1;
    }
    free(buckets);
    buckets = fresh;
    bucket_cap = cap;
}
/* The ID a name has here already, or 0. */
static ID find(const char *s, long n) {
    if (operator_char(s, n)) return (ID)(unsigned char)s[0];
    if (!bucket_cap) return 0;
    uint64_t h = hash_name(s, n);
    long at = (long)(h & (uint64_t)(bucket_cap - 1));
    while (buckets[at]) {
        struct name *e = &names[buckets[at] - 1];
        if (e->hash == h && e->len == n && !memcmp(e->text, s, (size_t)n)) return (ID)(ID_FIRST + buckets[at] - 1);
        at = (at + 1) & (bucket_cap - 1);
    }
    return 0;
}
static ID intern_as(const char *s, long n, int pin) {
    ID found = find(s, n);
    if (found) {
        if (pin && found >= ID_FIRST) names[found - ID_FIRST].pinned = 1;
        return found;
    }
    uint64_t h = hash_name(s, n);
    if (name_count == name_cap) {
        name_cap = name_cap ? name_cap * 2 : 512;
        names = realloc(names, sizeof(*names) * (size_t)name_cap);
        if (!names) mr_fatal("out of memory");
    }
    char *copy = malloc((size_t)n + 1);
    if (!copy) mr_fatal("out of memory");
    memcpy(copy, s, (size_t)n);
    copy[n] = 0;
    names[name_count].text = copy;
    names[name_count].len = n;
    names[name_count].hash = h;
    names[name_count].pinned = pin;
    name_count++;
    if (name_count * 2 > bucket_cap) rehash();
    else {
        long at = (long)(h & (uint64_t)(bucket_cap - 1));
        while (buckets[at]) at = (at + 1) & (bucket_cap - 1);
        buckets[at] = name_count;
    }
    return (ID)(ID_FIRST + name_count - 1);
}
static ID intern(const char *s, long n) { return intern_as(s, n, 1); }
static int pinned(ID id) { return id < ID_FIRST || names[id - ID_FIRST].pinned; }
const char *mr_id_name(ID id, long *len) {
    static char op[2];
    if (id < ID_FIRST) {
        if (id > 0 && id < 128) { op[0] = (char)id; op[1] = 0; if (len) *len = 1; return op; }
        return NULL;
    }
    long i = (long)(id - ID_FIRST);
    if (i >= name_count) return NULL;
    if (len) *len = names[i].len;
    return names[i].text;
}
/* (a Symbol of the interpreter's on its way to C: having a number here pins
 *  nothing down) */
int mr_capi_intern(const char *name) { return (int)intern_as(name, (long)strlen(name), 0); }
char *mr_capi_id_name(int id) {
    const char *s = mr_id_name((ID)id, NULL);
    return s ? (char *)s : (char *)"";
}

#undef rb_intern
#undef rb_intern2
#undef rb_intern_const
ID rb_intern2(const char *name, long len) { return intern(name, len); }
ID rb_intern(const char *name) { return intern(name, (long)strlen(name)); }
ID rb_intern3(const char *name, long len, rb_encoding *enc) { (void)enc; return intern(name, len); }
ID rb_intern_str(VALUE str) { return intern(RSTRING_PTR(str), RSTRING_LEN(str)); }
const char *rb_id2name(ID id) { return mr_id_name(id, NULL); }
VALUE rb_id2sym(ID id) { return ((VALUE)id << RUBY_SPECIAL_SHIFT) | RUBY_SYMBOL_FLAG; }
/* (C taking a Symbol's ID pins it down, as ruby's rb_sym2id does a dynamic
 *  Symbol's) */
ID rb_sym2id(VALUE sym) {
    if (!RB_STATIC_SYM_P(sym)) rb_raise(rb_eTypeError, "wrong argument type %s (expected Symbol)", rb_obj_classname(sym));
    ID id = (ID)(sym >> RUBY_SPECIAL_SHIFT);
    if (!pinned(id) && mr_id_name(id, NULL)) names[id - ID_FIRST].pinned = 1;
    return id;
}
/* The String a Symbol is the name of: the interpreter's own, one object per
 * Symbol (Symbol#name). */
VALUE rb_id2str(ID id) {
    if (!mr_id_name(id, NULL)) return Qfalse;
    return mr_call(rb_id2sym(id), "name", 0);
}
VALUE rb_sym2str(VALUE sym) {
    if (!RB_STATIC_SYM_P(sym)) rb_raise(rb_eTypeError, "wrong argument type %s (expected Symbol)", rb_obj_classname(sym));
    return rb_id2str((ID)(sym >> RUBY_SPECIAL_SHIFT));
}
VALUE rb_to_symbol(VALUE name) {
    if (RB_SYMBOL_P(name)) return name;
    VALUE str = rb_check_string_type(name);
    if (NIL_P(str)) rb_raise(rb_eTypeError, "%" PRIsVALUE " is not a symbol nor a string", rb_inspect(name));
    return rb_id2sym(rb_intern_str(str));
}
ID rb_to_id(VALUE name) { return rb_sym2id(rb_to_symbol(name)); }
VALUE rb_str_intern(VALUE str) { return rb_id2sym(rb_intern_str(str)); }
VALUE rb_sym_to_s(VALUE sym) { return mr_call(sym, "to_s", 0); }
VALUE rb_sym_proc(VALUE sym) { return mr_call(sym, "to_proc", 0); }
/* The ID a name has when it is a Symbol already, and 0 when it is not: the
 * asking must not make it one. A name C has used as an ID is one. Any other
 * is asked of the interpreter, which knows the Symbols a program has made and
 * which of them are pinned down (MR_SYM_STATE: 0 none, 1 dynamic, 2 pinned).
 * rb_check_id counts a pinned one only, as ruby's does: a dynamic Symbol (a
 * String#to_sym that nothing has used as an ID since) answers 0, and *namep
 * becomes its name. rb_check_symbol finds either kind.
 * (A Symbol the interpreter has without having noted it -- a method's name
 *  it made from an identifier -- is one ruby's parser would have pinned.) */
static int sym_state(VALUE name) { return (int)(long)mr_up(MR_SYM_STATE, name, 0, 0, 0, 0); }
static VALUE check_string(volatile VALUE *namep) {
    VALUE str = rb_check_string_type(*namep);
    if (NIL_P(str)) rb_raise(rb_eTypeError, "%" PRIsVALUE " is not a symbol nor a string", rb_inspect(*namep));
    *namep = str;
    return str;
}
ID rb_check_id(volatile VALUE *namep) {
    VALUE name = *namep;
    if (RB_STATIC_SYM_P(name)) {
        ID id = (ID)(name >> RUBY_SPECIAL_SHIFT);
        if (pinned(id) || !mr_id_name(id, NULL)) return id;
        if (sym_state(name) != 1) { names[id - ID_FIRST].pinned = 1; return id; }
        *namep = rb_id2str(id);
        return 0;
    }
    VALUE str = check_string(namep);
    ID id = find(RSTRING_PTR(str), RSTRING_LEN(str));
    if (id && pinned(id)) return id;
    int state = sym_state(str);
    if (state == 2 || (id && state == 0)) return rb_intern_str(str);
    return 0;
}
VALUE rb_check_symbol(volatile VALUE *namep) {
    VALUE name = *namep;
    if (RB_STATIC_SYM_P(name)) return name;
    VALUE str = check_string(namep);
    ID id = find(RSTRING_PTR(str), RSTRING_LEN(str));
    if (id) return rb_id2sym(id);
    if (!sym_state(str)) return Qnil;
    return rb_id2sym(intern_as(RSTRING_PTR(str), RSTRING_LEN(str), 0));
}
ID rb_check_id_cstr(const char *ptr, long len, rb_encoding *enc) {
    ID id = find(ptr, len);
    if (id && pinned(id)) return id;
    int state = sym_state(rb_enc_str_new(ptr, len, enc));
    if (state == 2 || (id && state == 0)) return intern(ptr, len);
    return 0;
}
VALUE rb_check_symbol_cstr(const char *ptr, long len, rb_encoding *enc) {
    ID id = find(ptr, len);
    if (id) return rb_id2sym(id);
    if (!sym_state(rb_enc_str_new(ptr, len, enc))) return Qnil;
    return rb_id2sym(intern_as(ptr, len, 0));
}
/* What kind of name an ID is, as the parser would read it. */
enum kind { K_NONE, K_LOCAL, K_CONST, K_GLOBAL, K_INSTANCE, K_CLASS, K_ATTRSET, K_JUNK };
static int ident_char(unsigned char c) {
    return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c >= 0x80;
}
static int ident_start(unsigned char c) { return ident_char(c) && !(c >= '0' && c <= '9'); }
static int identifier(const char *s, long n) {
    if (n <= 0 || !ident_start((unsigned char)s[0])) return 0;
    for (long i = 1; i < n; i++) if (!ident_char((unsigned char)s[i])) return 0;
    return 1;
}
static enum kind kind_of(const char *s, long n, int attrset_ok) {
    if (n <= 0) return K_NONE;
    if (attrset_ok && n > 1 && s[n - 1] == '=') {
        enum kind base = kind_of(s, n - 1, 0);
        if (base == K_LOCAL || base == K_CONST || base == K_GLOBAL || base == K_INSTANCE || base == K_CLASS || base == K_JUNK)
            return K_ATTRSET;
        return K_NONE;
    }
    if (s[0] == '$') {
        if (n == 2 && strchr("~*$?!@/\\;,.=:<>\"&`'+0", s[1])) return K_GLOBAL;
        if (n == 3 && s[1] == '-' && ident_char((unsigned char)s[2])) return K_GLOBAL;
        if (n > 1 && s[1] >= '0' && s[1] <= '9') {
            for (long i = 1; i < n; i++) if (!(s[i] >= '0' && s[i] <= '9')) return K_NONE;
            return K_GLOBAL;
        }
        return identifier(s + 1, n - 1) ? K_GLOBAL : K_NONE;
    }
    if (s[0] == '@') {
        if (n > 1 && s[1] == '@') return identifier(s + 2, n - 2) ? K_CLASS : K_NONE;
        return identifier(s + 1, n - 1) ? K_INSTANCE : K_NONE;
    }
    if (!ident_start((unsigned char)s[0])) return K_NONE;
    int upper = s[0] >= 'A' && s[0] <= 'Z';
    if (s[n - 1] == '?' || s[n - 1] == '!') return identifier(s, n - 1) ? K_JUNK : K_NONE;
    if (!identifier(s, n)) return K_NONE;
    return upper ? K_CONST : K_LOCAL;
}
static enum kind kind_of_id(ID id) {
    long len = 0;
    const char *s = mr_id_name(id, &len);
    return s ? kind_of(s, len, 1) : K_NONE;
}
int rb_is_const_id(ID id) { return kind_of_id(id) == K_CONST; }
int rb_is_global_id(ID id) { return kind_of_id(id) == K_GLOBAL; }
int rb_is_instance_id(ID id) { return kind_of_id(id) == K_INSTANCE; }
int rb_is_class_id(ID id) { return kind_of_id(id) == K_CLASS; }
int rb_is_attrset_id(ID id) { return kind_of_id(id) == K_ATTRSET; }
int rb_is_local_id(ID id) { return kind_of_id(id) == K_LOCAL; }
int rb_is_junk_id(ID id) { return kind_of_id(id) == K_JUNK; }
ID rb_id_attrset(ID id) {
    long len = 0;
    const char *s = mr_id_name(id, &len);
    if (!s) rb_raise(rb_eNameError, "invalid ID");
    if (kind_of(s, len, 1) == K_ATTRSET) return id;
    char *buffer = alloca((size_t)len + 2);
    memcpy(buffer, s, (size_t)len);
    buffer[len] = '=';
    return intern(buffer, len + 1);
}
VALUE rb_sym_all_symbols(void) { return mr_call(rb_cSymbol, "all_symbols", 0); }
