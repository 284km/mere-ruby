/* Array, Hash, Range and Struct. */
#include "mr_capi.h"
#include <stdarg.h>

static VALUE changed(VALUE obj) { mr_mirror_forget(obj); return obj; }

/* ---- Array -------------------------------------------------------------------- */
VALUE rb_ary_new_from_values(long n, const VALUE *elts) {
    if (n < 0) rb_raise(rb_eArgError, "negative array size (or size too big)");
    mr_put_words(n, elts);
    return mr_up1(MR_ARY_NEW, (VALUE)n);
}
#undef rb_ary_new_from_args
VALUE rb_ary_new_from_args(long n, ...) {
    VALUE *elts = n > 0 ? alloca(sizeof(VALUE) * (size_t)n) : NULL;
    va_list ap;
    va_start(ap, n);
    for (long i = 0; i < n; i++) elts[i] = va_arg(ap, VALUE);
    va_end(ap);
    return rb_ary_new_from_values(n, elts);
}
VALUE rb_ary_new(void) { return rb_ary_new_from_values(0, NULL); }
VALUE rb_ary_new_capa(long capa) {
    if (capa < 0) rb_raise(rb_eArgError, "negative array size (or size too big)");
    return rb_ary_new_from_values(0, NULL);
}
VALUE rb_ary_hidden_new(long capa) { return rb_ary_new_capa(capa); }
VALUE rb_assoc_new(VALUE a, VALUE b) { VALUE pair[2] = { a, b }; return rb_ary_new_from_values(2, pair); }
VALUE rb_check_array_type(VALUE obj) {
    if (RB_TYPE_P(obj, T_ARRAY)) return obj;
    if (RB_SPECIAL_CONST_P(obj) || !rb_respond_to(obj, rb_intern("to_ary"))) return Qnil;
    VALUE a = mr_call(obj, "to_ary", 0);
    if (NIL_P(a)) return Qnil;
    if (!RB_TYPE_P(a, T_ARRAY)) rb_raise(rb_eTypeError, "can't convert %s to Array (%s#to_ary gives %s)", rb_obj_classname(obj), rb_obj_classname(obj), rb_obj_classname(a));
    return a;
}
VALUE rb_Array(VALUE obj) { return mr_call(mr_main(), "Array", 1, obj); }
VALUE rb_ary_to_ary(VALUE obj) {
    VALUE a = rb_check_array_type(obj);
    return NIL_P(a) ? rb_ary_new_from_values(1, &obj) : a;
}
VALUE rb_ary_push(VALUE ary, VALUE item) { mr_calla(ary, "push", 1, item); return changed(ary); }
VALUE rb_ary_cat(VALUE ary, const VALUE *items, long n) {
    mr_calla(ary, "concat", 1, rb_ary_new_from_values(n, items));
    return changed(ary);
}
VALUE rb_ary_pop(VALUE ary) { VALUE v = mr_calla(ary, "pop", 0); changed(ary); return v; }
VALUE rb_ary_shift(VALUE ary) { VALUE v = mr_calla(ary, "shift", 0); changed(ary); return v; }
VALUE rb_ary_unshift(VALUE ary, VALUE item) { mr_calla(ary, "unshift", 1, item); return changed(ary); }
void rb_ary_store(VALUE ary, long index, VALUE value) { mr_calla(ary, "[]=", 2, LONG2NUM(index), value); changed(ary); }
VALUE rb_ary_entry(VALUE ary, long index) {
    long len = RARRAY_LEN(ary);
    if (index < 0) index += len;
    if (index < 0 || index >= len) return Qnil;
    return RARRAY_CONST_PTR(ary)[index];
}
VALUE rb_ary_aref(int argc, const VALUE *argv, VALUE ary) {
    return mr_callv(ary, rb_intern("[]"), argc, argv, Qnil, mr_without("builtin") ? 0 : MR_SEND_ARRAY);
}
VALUE rb_ary_subseq(VALUE ary, long beg, long len) { return mr_calla(ary, "[]", 2, LONG2NUM(beg), LONG2NUM(len)); }
VALUE rb_ary_dup(VALUE ary) { return mr_calla(ary, "dup", 0); }
VALUE rb_ary_clear(VALUE ary) { mr_calla(ary, "clear", 0); return changed(ary); }
VALUE rb_ary_concat(VALUE ary, VALUE other) { mr_calla(ary, "concat", 1, other); return changed(ary); }
VALUE rb_ary_plus(VALUE a, VALUE b) { return mr_calla(a, "+", 1, b); }
VALUE rb_ary_join(VALUE ary, VALUE sep) { return mr_calla(ary, "join", 1, sep); }
VALUE rb_ary_reverse(VALUE ary) { mr_calla(ary, "reverse!", 0); return changed(ary); }
VALUE rb_ary_rotate(VALUE ary, long n) { mr_calla(ary, "rotate!", 1, LONG2NUM(n)); return changed(ary); }
VALUE rb_ary_sort(VALUE ary) { return mr_calla(ary, "sort", 0); }
VALUE rb_ary_sort_bang(VALUE ary) { mr_calla(ary, "sort!", 0); return changed(ary); }
VALUE rb_ary_includes(VALUE ary, VALUE item) { return mr_calla(ary, "include?", 1, item); }
VALUE rb_ary_delete(VALUE ary, VALUE item) { VALUE v = mr_calla(ary, "delete", 1, item); changed(ary); return v; }
VALUE rb_ary_delete_at(VALUE ary, long index) { VALUE v = mr_calla(ary, "delete_at", 1, LONG2NUM(index)); changed(ary); return v; }
VALUE rb_ary_to_s(VALUE ary) { return mr_calla(ary, "to_s", 0); }
VALUE rb_ary_cmp(VALUE a, VALUE b) { return mr_calla(a, "<=>", 1, b); }
VALUE rb_ary_replace(VALUE ary, VALUE other) { mr_calla(ary, "replace", 1, other); return changed(ary); }
VALUE rb_ary_assoc(VALUE ary, VALUE key) { return mr_calla(ary, "assoc", 1, key); }
VALUE rb_ary_rassoc(VALUE ary, VALUE value) { return mr_calla(ary, "rassoc", 1, value); }
VALUE rb_ary_freeze(VALUE ary) { return rb_obj_freeze(ary); }
VALUE rb_ary_each(VALUE ary) { return mr_callv(ary, rb_intern("each"), 0, NULL, mr_frame_block(), 0); }
VALUE rb_ary_resize(VALUE ary, long len) {
    if (len < 0) rb_raise(rb_eIndexError, "index %ld too small for array; minimum: -%ld", len, RARRAY_LEN(ary));
    mr_call(mr_ruby("->(a, n) { n < a.size ? a.slice!(n, a.size - n) : a.fill(nil, a.size, n - a.size); a }"), "call", 2, ary, LONG2NUM(len));
    return changed(ary);
}
VALUE rb_ary_shared_with_p(VALUE a, VALUE b) { (void)a; (void)b; return Qfalse; }
VALUE rb_get_values_at(VALUE obj, long olen, int argc, const VALUE *argv, VALUE (*func)(VALUE, long)) {
    VALUE result = rb_ary_new();
    for (int i = 0; i < argc; i++) {
        if (RB_FIXNUM_P(argv[i])) { rb_ary_push(result, func(obj, FIX2LONG(argv[i]))); continue; }
        long beg, len;
        VALUE in_range = rb_range_beg_len(argv[i], &beg, &len, olen, 1);
        if (in_range == Qfalse) { rb_ary_push(result, func(obj, NUM2LONG(argv[i]))); continue; }
        if (NIL_P(in_range)) continue;
        for (long j = beg; j < beg + len; j++) rb_ary_push(result, func(obj, j));
    }
    return result;
}
VALUE *rb_ary_ptr_use_start(VALUE ary) { return (VALUE *)RARRAY(ary)->as.heap.ptr; }
void rb_ary_ptr_use_end(VALUE ary) { (void)ary; }
void rb_ary_detransient(VALUE ary) { (void)ary; }
void rb_mem_clear(VALUE *mem, long n) { while (n-- > 0) *mem++ = Qnil; }

/* ---- Hash --------------------------------------------------------------------- */
VALUE rb_hash_new(void) { return mr_call(rb_cHash, "new", 0); }
/* (a capacity is a size: a negative one is st.c's "st_table too big") */
VALUE rb_hash_new_capa(long capa) {
    if (capa < 0) rb_raise(rb_eRuntimeError, "st_table too big");
    return rb_hash_new();
}
VALUE rb_ident_hash_new(void) { return mr_call(rb_hash_new(), "compare_by_identity", 0); }
VALUE rb_check_hash_type(VALUE obj) {
    if (RB_TYPE_P(obj, T_HASH)) return obj;
    if (RB_SPECIAL_CONST_P(obj) || !rb_respond_to(obj, rb_intern("to_hash"))) return Qnil;
    VALUE h = mr_call(obj, "to_hash", 0);
    if (NIL_P(h)) return Qnil;
    if (!RB_TYPE_P(h, T_HASH)) rb_raise(rb_eTypeError, "can't convert %s to Hash (%s#to_hash gives %s)", rb_obj_classname(obj), rb_obj_classname(obj), rb_obj_classname(h));
    return h;
}
VALUE rb_Hash(VALUE obj) { return mr_call(mr_main(), "Hash", 1, obj); }
VALUE rb_hash_aset(VALUE hash, VALUE key, VALUE value) { mr_callh(hash, "[]=", 2, key, value); return value; }
VALUE rb_hash_aref(VALUE hash, VALUE key) { return mr_callh(hash, "[]", 1, key); }
VALUE rb_hash_lookup2(VALUE hash, VALUE key, VALUE fallback) {
    return RTEST(mr_callh(hash, "key?", 1, key)) ? mr_callh(hash, "fetch", 1, key) : fallback;
}
VALUE rb_hash_lookup(VALUE hash, VALUE key) { return rb_hash_lookup2(hash, key, Qnil); }
VALUE rb_hash_fetch(VALUE hash, VALUE key) { return mr_callh(hash, "fetch", 1, key); }
VALUE rb_hash_delete(VALUE hash, VALUE key) { return mr_callh(hash, "delete", 1, key); }
VALUE rb_hash_delete_if(VALUE hash) { return mr_callv(hash, rb_intern("delete_if"), 0, NULL, mr_frame_block(), 0); }
VALUE rb_hash_clear(VALUE hash) { return mr_callh(hash, "clear", 0); }
VALUE rb_hash_size(VALUE hash) { return mr_callh(hash, "size", 0); }
size_t rb_hash_size_num(VALUE hash) { return (size_t)NUM2LONG(mr_callh(hash, "size", 0)); }
VALUE rb_hash_keys(VALUE hash) { return mr_callh(hash, "keys", 0); }
VALUE rb_hash_values(VALUE hash) { return mr_callh(hash, "values", 0); }
VALUE rb_hash_has_key(VALUE hash, VALUE key) { return mr_callh(hash, "key?", 1, key); }
VALUE rb_hash_dup(VALUE hash) { return mr_callh(hash, "dup", 0); }
VALUE rb_hash_freeze(VALUE hash) { return rb_obj_freeze(hash); }
VALUE rb_hash_set_ifnone(VALUE hash, VALUE ifnone) { mr_callh(hash, "default=", 1, ifnone); return hash; }
VALUE rb_hash_update_by(VALUE hash, VALUE other, rb_hash_update_func *func) {
    if (func) mr_unsupported("rb_hash_update_by with a function");
    return mr_callh(hash, "update", 1, other);
}
void rb_hash_bulk_insert(long argc, const VALUE *argv, VALUE hash) {
    for (long i = 0; i + 1 < argc; i += 2) rb_hash_aset(hash, argv[i], argv[i + 1]);
}
/* hash.c's: #hash, made a Fixnum -- a Bignum by its low word (with the sign
 * kept in the top bit), anything else through #to_int */
VALUE rb_hash(VALUE obj) {
    VALUE hval = mr_call(obj, "hash", 0);
    while (!FIXNUM_P(hval)) {
        if (RB_TYPE_P(hval, T_BIGNUM)) {
            unsigned long ul;
            int sign = rb_integer_pack(hval, &ul, 1, sizeof(ul), 0, INTEGER_PACK_LSWORD_FIRST | INTEGER_PACK_NATIVE_BYTE_ORDER);
            hval = sign < 0 ? LONG2FIX((long)(ul | (unsigned long)FIXNUM_MIN)) : LONG2FIX((long)(ul & (unsigned long)FIXNUM_MAX));
        }
        else hval = rb_to_int(hval);
    }
    return hval;
}
void rb_hash_foreach(VALUE hash, int (*func)(VALUE, VALUE, VALUE), VALUE arg) {
    VALUE pairs = mr_callh(hash, "to_a", 0);
    long n = RARRAY_LEN(pairs);
    for (long i = 0; i < n; i++) {
        VALUE pair = rb_ary_entry(pairs, i);
        VALUE key = rb_ary_entry(pair, 0), value = rb_ary_entry(pair, 1);
        int r = func(key, value, arg);
        if (r == ST_DELETE) rb_hash_delete(hash, key);
        else if (r == ST_STOP) break;
    }
}
struct st_table *rb_hash_tbl(VALUE hash, const char *file, int line) { (void)hash; (void)file; (void)line; mr_unsupported("rb_hash_tbl (a Hash's st_table)"); }
VALUE rb_env_clear(void) { return mr_call(mr_const("ENV"), "clear", 0); }

/* ---- Range -------------------------------------------------------------------- */
VALUE rb_range_new(VALUE beg, VALUE end, int exclude_end) { return mr_call(rb_cRange, "new", 3, beg, end, exclude_end ? Qtrue : Qfalse); }
int rb_range_values(VALUE range, VALUE *begp, VALUE *endp, int *exclp) {
    if (!RTEST(rb_obj_is_kind_of(range, rb_cRange))) {
        if (RB_SPECIAL_CONST_P(range) || !rb_respond_to(range, rb_intern("begin")) || !rb_respond_to(range, rb_intern("end"))
            || !rb_respond_to(range, rb_intern("exclude_end?"))) return (int)Qfalse;
    }
    *begp = mr_call(range, "begin", 0);
    *endp = mr_call(range, "end", 0);
    *exclp = RTEST(mr_call(range, "exclude_end?", 0));
    return (int)Qtrue;
}
/* range.c's rb_range_component_beg_len and rb_range_beg_len, as they are in
 * 4.0: the bounds are clipped when err is 0 or 2, and err says whether out of
 * range is nil or a RangeError. */
static VALUE range_component_beg_len(VALUE b, VALUE e, int excl, long *begp, long *lenp, long len, int err) {
    long beg = NIL_P(b) ? 0 : NUM2LONG(b);
    long end = NIL_P(e) ? -1 : NUM2LONG(e);
    if (NIL_P(e)) excl = 0;
    if (beg < 0) {
        beg += len;
        if (beg < 0) return Qnil;
    }
    if (end < 0) end += len;
    if (!excl) end++;
    if (err == 0 || err == 2) {
        if (beg > len) return Qnil;
        if (end > len) end = len;
    }
    len = end - beg;
    if (len < 0) len = 0;
    *begp = beg;
    *lenp = len;
    return Qtrue;
}
VALUE rb_range_beg_len(VALUE range, long *begp, long *lenp, long len, int err) {
    VALUE b, e;
    int excl;
    if (!rb_range_values(range, &b, &e, &excl)) return Qfalse;
    VALUE res = range_component_beg_len(b, e, excl, begp, lenp, len, err);
    if (NIL_P(res) && err) rb_raise(rb_eRangeError, "%+" PRIsVALUE " out of range", range);
    return res;
}

/* ---- Struct ------------------------------------------------------------------- */
VALUE rb_struct_define(const char *name, ...) {
    VALUE members = rb_ary_new();
    va_list ap;
    va_start(ap, name);
    const char *member;
    while ((member = va_arg(ap, const char *)) != NULL) rb_ary_push(members, ID2SYM(rb_intern(member)));
    va_end(ap);
    if (name) rb_ary_unshift(members, rb_str_new_cstr(name));
    return mr_callv(rb_cStruct, rb_intern("new"), RARRAY_LENINT(members), RARRAY_CONST_PTR(members), Qnil, 0);
}
VALUE rb_struct_define_under(VALUE outer, const char *name, ...) {
    VALUE members = rb_ary_new();
    va_list ap;
    va_start(ap, name);
    const char *member;
    while ((member = va_arg(ap, const char *)) != NULL) rb_ary_push(members, ID2SYM(rb_intern(member)));
    va_end(ap);
    VALUE klass = mr_callv(rb_cStruct, rb_intern("new"), RARRAY_LENINT(members), RARRAY_CONST_PTR(members), Qnil, 0);
    rb_define_const(outer, name, klass);
    return klass;
}
VALUE rb_struct_new(VALUE klass, ...) {
    long n = NUM2LONG(mr_call(mr_call(klass, "members", 0), "size", 0));
    VALUE *argv = n > 0 ? alloca(sizeof(VALUE) * (size_t)n) : NULL;
    va_list ap;
    va_start(ap, klass);
    for (long i = 0; i < n; i++) argv[i] = va_arg(ap, VALUE);
    va_end(ap);
    return mr_callv(klass, rb_intern("new"), (int)n, argv, Qnil, 0);
}
VALUE rb_struct_alloc(VALUE klass, VALUE values) { return mr_callv(klass, rb_intern("new"), RARRAY_LENINT(values), RARRAY_CONST_PTR(values), Qnil, 0); }
/* struct.c's: the values by position -- for a Data instance too, whose own
 * #initialize takes keywords: the members named, a missing one nil, one too
 * many "struct size differs" -- and a Data instance frozen after. */
VALUE rb_struct_initialize(VALUE self, VALUE values) {
    if (!RTEST(rb_obj_is_kind_of(self, mr_const("Data")))) {
        mr_callv(self, rb_intern("initialize"), RARRAY_LENINT(values), RARRAY_CONST_PTR(values), Qnil, 0);
        return Qnil;
    }
    VALUE members = mr_call(rb_obj_class(self), "members", 0);
    long n = RARRAY_LEN(members), given = RARRAY_LEN(values);
    if (given > n) rb_raise(rb_eArgError, "struct size differs");
    VALUE kw = rb_hash_new();
    for (long i = 0; i < n; i++) rb_hash_aset(kw, RARRAY_AREF(members, i), i < given ? RARRAY_AREF(values, i) : Qnil);
    mr_callv(self, rb_intern("initialize"), 1, &kw, Qnil, MR_SEND_KW);
    rb_obj_freeze(self);
    return Qnil;
}
VALUE rb_struct_aref(VALUE s, VALUE index) { return mr_call(s, "[]", 1, index); }
VALUE rb_struct_aset(VALUE s, VALUE index, VALUE value) { return mr_call(s, "[]=", 2, index, value); }
VALUE rb_struct_getmember(VALUE s, ID id) {
    VALUE sym = ID2SYM(id);
    if (!RTEST(mr_call(mr_call(s, "members", 0), "include?", 1, sym)))
        rb_exc_raise(mr_call(rb_eNameError, "new", 2, rb_sprintf("'%" PRIsVALUE "' is not a struct member", rb_sym2str(sym)), sym));
    return mr_call(s, "[]", 1, sym);
}
VALUE rb_struct_members(VALUE s) { return mr_call(s, "members", 0); }
VALUE rb_struct_s_members(VALUE klass) { return mr_call(klass, "members", 0); }
VALUE rb_struct_size(VALUE s) { return mr_call(s, "size", 0); }
VALUE rb_struct_define_without_accessor(const char *name, VALUE super, rb_alloc_func_t alloc, ...) {
    (void)name; (void)super; (void)alloc;
    mr_unsupported("rb_struct_define_without_accessor");
}
VALUE rb_hash_delete_entry(VALUE hash, VALUE key) {
    if (!RTEST(mr_callh(hash, "key?", 1, key))) return Qundef;
    return mr_callh(hash, "delete", 1, key);
}
VALUE rb_data_define(VALUE super, ...) {
    VALUE members = rb_ary_new();
    va_list ap;
    va_start(ap, super);
    const char *member;
    while ((member = va_arg(ap, const char *)) != NULL) rb_ary_push(members, ID2SYM(rb_intern(member)));
    va_end(ap);
    VALUE base = (super == 0 || NIL_P(super)) ? mr_const("Data") : super;
    if (!RB_TYPE_P(base, T_CLASS)) rb_raise(rb_eTypeError, "wrong argument type %s (expected Class)", rb_obj_classname(base));
    return mr_callv(base, rb_intern("define"), RARRAY_LENINT(members), RARRAY_CONST_PTR(members), Qnil, 0);
}

/* ---- Enumerator ------------------------------------------------------------------ */
VALUE rb_enumeratorize(VALUE obj, VALUE meth, int argc, const VALUE *argv) {
    VALUE args = rb_ary_new_from_values(argc, argv);
    rb_ary_unshift(args, meth);
    return mr_callv(obj, rb_intern("enum_for"), RARRAY_LENINT(args), RARRAY_CONST_PTR(args), Qnil, 0);
}
/* (the size function is C's and takes the receiver, the arguments and the
 *  enumerator: the Enumerator made here answers size as nil -- "not known" --
 *  rather than ask a function this side cannot hand to it) */
#undef rb_enumeratorize_with_size
#undef rb_enumeratorize_with_size_kw
VALUE rb_enumeratorize_with_size(VALUE obj, VALUE meth, int argc, const VALUE *argv, rb_enumerator_size_func *size) {
    (void)size;
    return rb_enumeratorize(obj, meth, argc, argv);
}
VALUE rb_enumeratorize_with_size_kw(VALUE obj, VALUE meth, int argc, const VALUE *argv, rb_enumerator_size_func *size, int kw) {
    (void)size;
    VALUE args = rb_ary_new_from_values(argc, argv);
    rb_ary_unshift(args, meth);
    return mr_callv(obj, rb_intern("enum_for"), RARRAY_LENINT(args), RARRAY_CONST_PTR(args), Qnil, mr_kw(kw));
}
int rb_arithmetic_sequence_extract(VALUE obj, rb_arithmetic_sequence_components_t *component) {
    if (RTEST(rb_obj_is_kind_of(obj, mr_const("Enumerator::ArithmeticSequence")))) {
        component->begin = mr_call(obj, "begin", 0);
        component->end = mr_call(obj, "end", 0);
        component->step = mr_call(obj, "step", 0);
        component->exclude_end = RTEST(mr_call(obj, "exclude_end?", 0));
        return 1;
    }
    if (RTEST(rb_obj_is_kind_of(obj, rb_cRange))) {
        component->begin = mr_call(obj, "begin", 0);
        component->end = mr_call(obj, "end", 0);
        component->step = INT2FIX(1);
        component->exclude_end = RTEST(mr_call(obj, "exclude_end?", 0));
        return 1;
    }
    return 0;
}
/* enumerator.c's rb_arithmetic_sequence_beg_len_step: what `ary[seq]` reads. */
VALUE rb_arithmetic_sequence_beg_len_step(VALUE obj, long *begp, long *lenp, long *stepp, long len, int err) {
    rb_arithmetic_sequence_components_t aseq;
    if (!rb_arithmetic_sequence_extract(obj, &aseq)) return Qfalse;
    long step = NIL_P(aseq.step) ? 1 : NUM2LONG(aseq.step);
    *stepp = step;
    if (step < 0) {
        if (aseq.exclude_end && !NIL_P(aseq.end)) {
            /* Handle exclusion before range reversal */
            aseq.end = LONG2NUM(NUM2LONG(aseq.end) + 1);
            /* Don't exclude the previous beginning */
            aseq.exclude_end = 0;
        }
        VALUE tmp = aseq.begin;
        aseq.begin = aseq.end;
        aseq.end = tmp;
    }
    if (err == 0 && (step < -1 || step > 1)) {
        if (range_component_beg_len(aseq.begin, aseq.end, aseq.exclude_end, begp, lenp, len, 1) == Qtrue) {
            if (*begp > len) goto out_of_range;
            if (*lenp > len) goto out_of_range;
            return Qtrue;
        }
    }
    else {
        return range_component_beg_len(aseq.begin, aseq.end, aseq.exclude_end, begp, lenp, len, err);
    }
  out_of_range:
    rb_raise(rb_eRangeError, "%+" PRIsVALUE " out of range", obj);
    return Qnil;
}
