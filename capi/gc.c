/* What C tells the collector, and C's own memory. */
#include "mr_capi.h"
#include <stdlib.h>
#include <string.h>

extern void mr_mark_value(VALUE v);

/* ---- roots ---------------------------------------------------------------- */
static VALUE **addresses;
static long address_count, address_cap;
static VALUE *objects;
static long object_count, object_cap;

void rb_gc_register_address(VALUE *address) {
    if (address_count == address_cap) {
        address_cap = address_cap ? address_cap * 2 : 64;
        addresses = realloc(addresses, sizeof(*addresses) * (size_t)address_cap);
        if (!addresses) mr_fatal("out of memory");
    }
    addresses[address_count++] = address;
}
void rb_global_variable(VALUE *address) { rb_gc_register_address(address); }
void rb_gc_unregister_address(VALUE *address) {
    for (long i = 0; i < address_count; i++)
        if (addresses[i] == address) { addresses[i] = addresses[--address_count]; return; }
}
/* (a raw Bignum CRuby's bignum.c made -- capi/bignum_cruby.c -- kept past
 *  the C call that made it: registered or marked, it is not freed then) */
extern void mr_vbig_keep(VALUE v);
void rb_gc_register_mark_object(VALUE obj) {
    if (!MR_HANDLE_P(obj)) { mr_vbig_keep(obj); return; }
    if (object_count == object_cap) {
        object_cap = object_cap ? object_cap * 2 : 64;
        objects = realloc(objects, sizeof(*objects) * (size_t)object_cap);
        if (!objects) mr_fatal("out of memory");
    }
    objects[object_count++] = obj;
}
int mr_capi_roots(closure_int_int visit) {
    for (long i = 0; i < address_count; i++) {
        VALUE v = *addresses[i];
        if (MR_HANDLE_P(v)) visit.fn(visit.env, (long long)v);
    }
    for (long i = 0; i < object_count; i++) visit.fn(visit.env, (long long)objects[i]);
    return 0;
}
void rb_gc_mark(VALUE v) { mr_vbig_keep(v); mr_mark_value(v); }
void rb_gc_mark_movable(VALUE v) { mr_vbig_keep(v); mr_mark_value(v); }
void rb_gc_mark_maybe(VALUE v) { mr_vbig_keep(v); mr_mark_value(v); }
/* What every registered address (rb_gc_register_address,
 * rb_global_variable) holds now, each handed to `visit` -- read once, for a
 * caller with many values to ask about. */
void mr_gc_each_address_value(void (*visit)(VALUE)) {
    for (long i = 0; i < address_count; i++) visit(*addresses[i]);
}
void rb_gc_mark_locations(const VALUE *start, const VALUE *end) {
    for (; start < end; start++) mr_mark_value(*start);
}
VALUE rb_gc_location(VALUE v) { return v; }
void rb_gc_writebarrier(VALUE a, VALUE b) { (void)a; (void)b; }
void rb_gc_writebarrier_unprotect(VALUE obj) { (void)obj; }
void rb_gc_adjust_memory_usage(ssize_t diff) { (void)diff; }
void rb_gc_copy_finalizer(VALUE dest, VALUE obj) { (void)dest; (void)obj; }
int rb_during_gc(void) { return 0; }
void rb_gc(void) { mr_up1(MR_GC, 0); }
VALUE rb_gc_start(void) { mr_up1(MR_GC, 0); return Qnil; }
VALUE rb_gc_enable(void) { return mr_up1(MR_GC, 3); }
VALUE rb_gc_disable(void) { return mr_up1(MR_GC, 4); }
size_t rb_gc_count(void) { return (size_t)mr_up1(MR_GC, 5); }
VALUE rb_define_finalizer(VALUE obj, VALUE block) { return mr_call(mr_const("ObjectSpace"), "define_finalizer", 2, obj, block); }
VALUE rb_undefine_finalizer(VALUE obj) { return mr_call(mr_const("ObjectSpace"), "undefine_finalizer", 1, obj); }
void rb_ext_ractor_safe(bool flag) { (void)flag; }

/* ---- memory ----------------------------------------------------------------- */
static void *checked(void *p, size_t size) {
    if (!p && size) rb_memerror();
    return p;
}
void *ruby_xmalloc(size_t size) { return checked(malloc(size ? size : 1), 1); }
void *ruby_xmalloc2(size_t n, size_t size) {
    size_t total;
    if (__builtin_mul_overflow(n, size, &total)) rb_raise(rb_eArgError, "malloc: possible integer overflow (%zu*%zu)", n, size);
    return ruby_xmalloc(total);
}
void *ruby_xcalloc(size_t n, size_t size) {
    size_t total;
    if (__builtin_mul_overflow(n, size, &total)) rb_raise(rb_eArgError, "calloc: possible integer overflow (%zu*%zu)", n, size);
    return checked(calloc(n ? n : 1, size ? size : 1), 1);
}
void *ruby_xrealloc(void *p, size_t size) { return checked(realloc(p, size ? size : 1), 1); }
void *ruby_xrealloc2(void *p, size_t n, size_t size) {
    size_t total;
    if (__builtin_mul_overflow(n, size, &total)) rb_raise(rb_eArgError, "realloc: possible integer overflow (%zu*%zu)", n, size);
    return ruby_xrealloc(p, total);
}
void ruby_xfree(void *p) { free(p); }
void *rb_xmalloc_mul_add(size_t x, size_t y, size_t z) {
    size_t total;
    if (__builtin_mul_overflow(x, y, &total) || __builtin_add_overflow(total, z, &total)) rb_raise(rb_eArgError, "malloc: possible integer overflow");
    return ruby_xmalloc(total);
}

/* A temporary buffer (ALLOCV): C memory whose words a collection reads as
 * VALUEs for as long as the variable that names it is on the stack. */
struct tmp_buffer { size_t size; };
static void tmp_mark(void *p) {
    struct tmp_buffer *b = p;
    VALUE *words = (VALUE *)(b + 1);
    for (size_t i = 0; i + sizeof(VALUE) <= b->size; i += sizeof(VALUE)) mr_mark_value(words[i / sizeof(VALUE)]);
}
static const rb_data_type_t tmp_buffer_type = { "tmpbuf", { tmp_mark, RUBY_DEFAULT_FREE, 0, 0, { 0 } }, 0, 0, 0 };
void *rb_alloc_tmp_buffer(volatile VALUE *store, long len) {
    if (len < 0) rb_raise(rb_eArgError, "negative buffer size (or size too big)");
    struct tmp_buffer *b = ruby_xcalloc(1, sizeof(*b) + (size_t)len + sizeof(VALUE));
    b->size = (size_t)len;
    *store = rb_data_typed_object_wrap(0, b, &tmp_buffer_type);
    return b + 1;
}
void *rb_alloc_tmp_buffer_with_count(volatile VALUE *store, size_t len, size_t count) {
    (void)count;
    return rb_alloc_tmp_buffer(store, (long)len);
}
void rb_free_tmp_buffer(volatile VALUE *store) {
    VALUE obj = *store;
    *store = 0;
    if (!obj) return;
    struct tmp_buffer *b = RTYPEDDATA_GET_DATA(obj);
    RTYPEDDATA(obj)->data = NULL;
    ruby_xfree(b);
}

/* ---- errno ------------------------------------------------------------------ */
/* ruby.h makes `errno` this function's result; the C library's own is behind
 * the name it is declared by. */
#undef errno
#ifdef __APPLE__
extern int *__error(void);
#define SYSTEM_ERRNO (*__error())
#else
extern int *__errno_location(void);
#define SYSTEM_ERRNO (*__errno_location())
#endif
int *rb_errno_ptr(void) { return &SYSTEM_ERRNO; }
int rb_errno(void) { return SYSTEM_ERRNO; }
void rb_errno_set(int e) { SYSTEM_ERRNO = e; }
