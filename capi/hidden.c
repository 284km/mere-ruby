/* Constants whose names are no constant's ("platform_tty", "_INVALID").
 *
 * CRuby keeps such a constant under an ID that `constants` and Ruby's
 * const_get do not see, and C finds it again: io-console defines and
 * prepends IO::platform_tty this way (rb_define_module_under), and
 * rb_const_set / rb_const_get take any name. Here they are kept on this side,
 * in a table nothing Ruby-visible holds: outer module (by identity) -> name ->
 * value. The table is a root of the collector, so what it holds lives as long
 * as CRuby's constant would. (Used by capi/object.c.) */
#include "mr_capi.h"

static VALUE table = Qnil;

/* Is this a name Ruby takes as a constant's: an uppercase ASCII letter
 * first, or a character past ASCII? */
int mr_const_name_p(const char *name) {
    return name && ((name[0] >= 'A' && name[0] <= 'Z') || (unsigned char)name[0] >= 0x80);
}

static VALUE bucket(VALUE outer, int create) {
    if (NIL_P(table)) {
        if (!create) return Qnil;
        rb_gc_register_address(&table);
        table = mr_call(rb_hash_new(), "compare_by_identity", 0);
    }
    VALUE b = rb_hash_lookup2(table, outer, Qnil);
    if (NIL_P(b) && create) {
        b = rb_hash_new();
        rb_hash_aset(table, outer, b);
    }
    return b;
}

/* The value kept under `name` in `outer`, and whether there is one. */
VALUE mr_hidden_const_get(VALUE outer, const char *name, int *found) {
    VALUE b = bucket(outer, 0);
    VALUE key = rb_str_new_cstr(name);
    if (NIL_P(b) || !RTEST(rb_funcall(b, rb_intern("key?"), 1, key))) { *found = 0; return Qnil; }
    *found = 1;
    return rb_hash_aref(b, key);
}

void mr_hidden_const_set(VALUE outer, const char *name, VALUE value) {
    rb_hash_aset(bucket(outer, 1), rb_str_new_cstr(name), value);
}

VALUE mr_hidden_const_remove(VALUE outer, const char *name, int *found) {
    rb_check_frozen(outer);
    VALUE value = mr_hidden_const_get(outer, name, found);
    if (*found) rb_hash_delete(bucket(outer, 0), rb_str_new_cstr(name));
    return value;
}
