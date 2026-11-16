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
}
