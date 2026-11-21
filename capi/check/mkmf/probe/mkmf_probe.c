/* Says what extconf.rb found, so that the answers of mkmf's questions are
 * read in the built library and not in mkmf's output. */
#include <ruby.h>
#include <math.h>
static VALUE answers(VALUE self) {
    VALUE hash = rb_hash_new();
    (void)self;
#ifdef HAVE_STDINT_H
    rb_hash_aset(hash, rb_str_new_cstr("stdint.h"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("stdint.h"), Qfalse);
#endif
#ifdef HAVE_NO_SUCH_HEADER_ANYWHERE_H
    rb_hash_aset(hash, rb_str_new_cstr("no_such_header_anywhere.h"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("no_such_header_anywhere.h"), Qfalse);
#endif
#ifdef HAVE_STRLEN
    rb_hash_aset(hash, rb_str_new_cstr("strlen"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("strlen"), Qfalse);
#endif
#ifdef HAVE_NO_SUCH_FUNCTION_ANYWHERE
    rb_hash_aset(hash, rb_str_new_cstr("no_such_function_anywhere"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("no_such_function_anywhere"), Qfalse);
#endif
#ifdef HAVE_RB_ARY_NEW
    rb_hash_aset(hash, rb_str_new_cstr("rb_ary_new"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("rb_ary_new"), Qfalse);
#endif
#ifdef HAVE_RB_NO_SUCH_FUNCTION_ANYWHERE
    rb_hash_aset(hash, rb_str_new_cstr("rb_no_such_function_anywhere"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("rb_no_such_function_anywhere"), Qfalse);
#endif
#ifdef HAVE_RB_TRACEPOINT_NEW
    rb_hash_aset(hash, rb_str_new_cstr("rb_tracepoint_new"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("rb_tracepoint_new"), Qfalse);
#endif
#ifdef MKMF_PROBE_STDC
    rb_hash_aset(hash, rb_str_new_cstr("__STDC__"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("__STDC__"), Qfalse);
#endif
#ifdef MKMF_PROBE_NO_MACRO
    rb_hash_aset(hash, rb_str_new_cstr("NO_SUCH_MACRO_ANYWHERE"), Qtrue);
#else
    rb_hash_aset(hash, rb_str_new_cstr("NO_SUCH_MACRO_ANYWHERE"), Qfalse);
#endif
#ifdef SIZEOF_LONG
    rb_hash_aset(hash, rb_str_new_cstr("sizeof(long)"), INT2FIX(SIZEOF_LONG));
#endif
    rb_hash_aset(hash, rb_str_new_cstr("note"), INT2FIX(MKMF_PROBE_NOTE));
    return hash;
}
static VALUE floor_of(VALUE self, VALUE x) { (void)self; return DBL2NUM(floor(NUM2DBL(x))); }
void Init_mkmf_probe(void) {
    VALUE mod = rb_define_module("MkmfProbe");
    rb_define_singleton_method(mod, "answers", answers, 0);
    rb_define_singleton_method(mod, "floor", floor_of, 1);
}
