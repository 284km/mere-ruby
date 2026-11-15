/* IDs and Symbols. An ID is this side's number for a name; the Symbol VALUE
 * is CRuby's static-symbol immediate made from it. The interpreter knows a
 * Symbol by its name, and asks here for the number (mr_capi_intern) and back
 * (mr_capi_id_name). A one-character operator's ID is the character, as in
 * CRuby (`rb_funcall(x, '+', 1, y)` is written against that). */
#include "mr_capi.h"
#include <stdlib.h>
#include <string.h>

#define ID_FIRST 1024
struct name { char *text; long len; uint64_t hash; };
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
static ID intern(const char *s, long n) {
    if (operator_char(s, n)) return (ID)(unsigned char)s[0];
    uint64_t h = hash_name(s, n);
    if (bucket_cap) {
        long at = (long)(h & (uint64_t)(bucket_cap - 1));
        while (buckets[at]) {
            struct name *e = &names[buckets[at] - 1];
            if (e->hash == h && e->len == n && !memcmp(e->text, s, (size_t)n)) return (ID)(ID_FIRST + buckets[at] - 1);
            at = (at + 1) & (bucket_cap - 1);
        }
    }
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
    name_count++;
    if (name_count * 2 > bucket_cap) rehash();
    else {
        long at = (long)(h & (uint64_t)(bucket_cap - 1));
        while (buckets[at]) at = (at + 1) & (bucket_cap - 1);
        buckets[at] = name_count;
    }
    return (ID)(ID_FIRST + name_count - 1);
}
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
int mr_capi_intern(const char *name) { return (int)intern(name, (long)strlen(name)); }
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
ID rb_sym2id(VALUE sym) {
    if (!RB_STATIC_SYM_P(sym)) rb_raise(rb_eTypeError, "wrong argument type %s (expected Symbol)", rb_obj_classname(sym));
    return (ID)(sym >> RUBY_SPECIAL_SHIFT);
}
VALUE rb_id2str(ID id) {
    long len = 0;
    const char *s = mr_id_name(id, &len);
    if (!s) return Qfalse;
    return rb_obj_freeze(rb_utf8_str_new(s, len));
}
VALUE rb_sym2str(VALUE sym) { return rb_id2str(rb_sym2id(sym)); }
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
/* The ID a name has when it is one already. Every name the interpreter has
 * seen is a Symbol there, and this side cannot ask "without making it": the
 * answer is the ID, made if need be. */
ID rb_check_id(volatile VALUE *namep) {
    VALUE name = *namep;
    if (RB_SYMBOL_P(name)) return rb_sym2id(name);
    VALUE str = rb_check_string_type(name);
    if (NIL_P(str)) rb_raise(rb_eTypeError, "%" PRIsVALUE " is not a symbol nor a string", rb_inspect(name));
    *namep = str;
    return rb_intern_str(str);
}
VALUE rb_check_symbol(volatile VALUE *namep) {
    ID id = rb_check_id(namep);
    return id ? rb_id2sym(id) : Qnil;
}
ID rb_check_id_cstr(const char *ptr, long len, rb_encoding *enc) { (void)enc; return intern(ptr, len); }
VALUE rb_check_symbol_cstr(const char *ptr, long len, rb_encoding *enc) { (void)enc; return rb_id2sym(intern(ptr, len)); }
ID rb_id_attrset(ID id) {
    long len = 0;
    const char *s = mr_id_name(id, &len);
    if (!s) rb_raise(rb_eNameError, "invalid ID");
    char *buffer = alloca((size_t)len + 2);
    memcpy(buffer, s, (size_t)len);
    buffer[len] = '=';
    return intern(buffer, len + 1);
}

static int first_is(ID id, int (*test)(const char *, long)) {
    long len = 0;
    const char *s = mr_id_name(id, &len);
    return s && len > 0 && test(s, len);
}
static int is_const(const char *s, long n) { (void)n; return s[0] >= 'A' && s[0] <= 'Z'; }
static int is_global(const char *s, long n) { (void)n; return s[0] == '$'; }
static int is_instance(const char *s, long n) { return s[0] == '@' && (n < 2 || s[1] != '@'); }
static int is_class(const char *s, long n) { return n > 1 && s[0] == '@' && s[1] == '@'; }
static int is_attrset(const char *s, long n) {
    return n > 1 && s[n - 1] == '=' && s[n - 2] != '=' && s[n - 2] != '!' && s[n - 2] != '<' && s[n - 2] != '>' && s[0] != '[';
}
static int is_junk(const char *s, long n) { (void)n; return !(s[0] == '_' || (s[0] >= 'a' && s[0] <= 'z') || (s[0] >= 'A' && s[0] <= 'Z') || (unsigned char)s[0] >= 0x80 || s[0] == '$' || s[0] == '@'); }
static int is_local(const char *s, long n) {
    return (s[0] == '_' || (s[0] >= 'a' && s[0] <= 'z') || (unsigned char)s[0] >= 0x80)
        && s[n - 1] != '=' && s[n - 1] != '?' && s[n - 1] != '!';
}
int rb_is_const_id(ID id) { return first_is(id, is_const); }
int rb_is_global_id(ID id) { return first_is(id, is_global); }
int rb_is_instance_id(ID id) { return first_is(id, is_instance); }
int rb_is_class_id(ID id) { return first_is(id, is_class); }
int rb_is_attrset_id(ID id) { return first_is(id, is_attrset); }
int rb_is_local_id(ID id) { return first_is(id, is_local); }
int rb_is_junk_id(ID id) { return first_is(id, is_junk); }
VALUE rb_sym_all_symbols(void) { return mr_call(rb_cSymbol, "all_symbols", 0); }
