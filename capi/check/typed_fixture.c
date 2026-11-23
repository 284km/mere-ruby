/* Shared test extension: ordinary Ruby C APIs, compiled for both runtimes. */
#include <ruby.h>
#include <stdint.h>
static int freed, created, duplicate_frees;
static unsigned char free_seen[10000];
typedef struct { VALUE value; int serial; } native_box;
static void box_mark(void *ptr) { rb_gc_mark(((native_box *)ptr)->value); }
static void box_free(void *ptr) {
    native_box *box = ptr;
    if (free_seen[box->serial]++) duplicate_frees++;
    freed++; ruby_xfree(ptr);
}
static size_t box_size(const void *ptr) { (void)ptr; return sizeof(native_box); }
static const rb_data_type_t box_type = {
    "native_box", {box_mark, box_free, box_size}, 0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};
static VALUE box_alloc(VALUE klass) {
    native_box *box;
    VALUE object = TypedData_Make_Struct(klass, native_box, &box_type, box);
    box->serial = ++created;
    if (created >= 10000) abort();
    box->value = rb_str_new_cstr("native-only-box-payload");
    return object;
}
static VALUE box_get(VALUE self) {
    native_box *box; TypedData_Get_Struct(self, native_box, &box_type, box);
    return box->value;
}
static VALUE box_set(VALUE self, VALUE value) {
    native_box *box; TypedData_Get_Struct(self, native_box, &box_type, box);
    box->value = value; return value;
}
static VALUE box_get_after_gc(VALUE self) {
    rb_funcall(self, rb_intern("ruby_gc"), 0);
    return box_get(self);
}
static VALUE box_freed(VALUE self) { (void)self; return INT2NUM(freed); }
static VALUE error_payload(VALUE self) { return (VALUE)(uintptr_t)RTYPEDDATA_DATA(self); }
static VALUE box_duplicates(VALUE self) { (void)self; return INT2NUM(duplicate_frees); }
/* A dmark that READS what it marks, as sqlite3's database_mark and its
 * aggregator pin do: an Array's length and elements (RARRAY_LEN /
 * RARRAY_AREF) and an internal ivar (rb_ivar_get of an ID with no `@`), from
 * a collection that runs with no C call in progress. The child is held by
 * C alone, and marked only when the holder's "enabled" says so: a wrong
 * answer to the ivar read loses it. */
typedef struct { VALUE list; VALUE holder; VALUE child; VALUE gate; VALUE gated_child; } reading_box;
static ID id_items, id_enabled;   /* (interned at Init: a dmark must not allocate) */
static void reading_mark(void *ptr) {
    reading_box *box = ptr;
    /* (a collection inside the allocation sees the struct still zeroed) */
    if (RTEST(box->list)) {
        rb_gc_mark(box->list);
        for (long i = 0; i < RARRAY_LEN(box->list); i++) rb_gc_mark(RARRAY_AREF(box->list, i));
    }
    if (RTEST(box->holder)) {
        rb_gc_mark(box->holder);
        rb_gc_mark(rb_ivar_get(box->holder, id_items));
        if (RTEST(rb_ivar_get(box->holder, id_enabled))) rb_gc_mark(box->child);
    }
    /* (an Array C handed to Ruby, which Ruby changes between C calls: the
     *  length read here has to be the current one) */
    if (RTEST(box->gate)) {
        rb_gc_mark(box->gate);
        if (RARRAY_LEN(box->gate) > 0) rb_gc_mark(box->gated_child);
    }
}
static size_t reading_size(const void *ptr) { (void)ptr; return sizeof(reading_box); }
static const rb_data_type_t reading_type = {
    "reading_box", {reading_mark, RUBY_TYPED_DEFAULT_FREE, reading_size}, 0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};
static VALUE reading_alloc(VALUE klass) {
    reading_box *box;
    VALUE object = TypedData_Make_Struct(klass, reading_box, &reading_type, box);
    box->list = rb_ary_new();
    for (int i = 0; i < 4; i++) rb_ary_push(box->list, rb_sprintf("item-%d", i));
    box->holder = rb_obj_alloc(rb_cObject);
    rb_ivar_set(box->holder, id_items, rb_ary_new_from_args(1, rb_str_new_cstr("held")));
    rb_ivar_set(box->holder, id_enabled, Qtrue);
    box->child = rb_str_new_cstr("native-child");
    box->gate = rb_ary_new();
    if (RARRAY_LEN(box->gate) != 0) abort();   /* C has read it, empty */
    box->gated_child = Qnil;
    return object;
}
static VALUE reading_list(VALUE self) {
    reading_box *box; TypedData_Get_Struct(self, reading_box, &reading_type, box);
    return box->list;
}
static VALUE reading_held(VALUE self) {
    reading_box *box; TypedData_Get_Struct(self, reading_box, &reading_type, box);
    return rb_ivar_get(box->holder, id_items);
}
static VALUE reading_gate(VALUE self) {
    reading_box *box; TypedData_Get_Struct(self, reading_box, &reading_type, box);
    return box->gate;
}
/* (made once Ruby has filled the gate: from then on only the dmark's read of
 *  the gate's length keeps it) */
static VALUE reading_arm(VALUE self) {
    reading_box *box; TypedData_Get_Struct(self, reading_box, &reading_type, box);
    box->gated_child = rb_str_new_cstr("gated-child");
    return Qnil;
}
static VALUE reading_gated_child(VALUE self) {
    reading_box *box; TypedData_Get_Struct(self, reading_box, &reading_type, box);
    return box->gated_child;
}
static VALUE reading_child(VALUE self) {
    reading_box *box; TypedData_Get_Struct(self, reading_box, &reading_type, box);
    return box->child;
}
extern void Init_typeddata(void);
extern void Init_dataerror(VALUE);
void Init_typed_probe(void) {
    Init_typeddata();
    VALUE bug = rb_define_module("Bug");
    Init_dataerror(rb_define_module_under(bug, "Exception"));
    VALUE error = rb_define_class_under(rb_define_module_under(bug, "Exception"), "DataError", rb_eStandardError);
    rb_define_method(error, "__payload", error_payload, 0);
    VALUE klass = rb_define_class_under(bug, "NativeBox", rb_cObject);
    rb_define_alloc_func(klass, box_alloc);
    rb_define_method(klass, "value", box_get, 0);
    rb_define_method(klass, "value=", box_set, 1);
    rb_define_method(klass, "value_after_gc", box_get_after_gc, 0);
    rb_define_singleton_method(klass, "freed", box_freed, 0);
    rb_define_singleton_method(klass, "duplicate_frees", box_duplicates, 0);
    id_items = rb_intern("items");
    id_enabled = rb_intern("enabled");
    VALUE reading = rb_define_class_under(bug, "ReadingBox", rb_cObject);
    rb_define_alloc_func(reading, reading_alloc);
    rb_define_method(reading, "list", reading_list, 0);
    rb_define_method(reading, "held", reading_held, 0);
    rb_define_method(reading, "child", reading_child, 0);
    rb_define_method(reading, "gate", reading_gate, 0);
    rb_define_method(reading, "gated_child", reading_gated_child, 0);
    rb_define_method(reading, "arm", reading_arm, 0);
}
