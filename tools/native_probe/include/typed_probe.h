#ifndef TYPED_PROBE_H
#define TYPED_PROBE_H
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
typedef VALUE (*probe_method0)(VALUE);
typedef struct rb_data_type_struct rb_data_type_t;
struct rb_data_type_struct {
    const char *wrap_struct_name;
    struct {
        void (*dmark)(void *);
        void (*dfree)(void *);
        size_t (*dsize)(const void *);
        void (*dcompact)(void *);
        void *reserved[1];
    } function;
    const rb_data_type_t *parent;
    void *data;
    VALUE flags;
};
#define RUBY_TYPED_FREE_IMMEDIATELY 1
#define RUBY_TYPED_WB_PROTECTED 2
#define RUBY_TYPED_EMBEDDABLE 4
#define RUBY_DEFAULT_FREE ruby_xfree
#define PROBE_CLASS_TAG ((VALUE)0x80000000U)
#define rb_cObject (PROBE_CLASS_TAG | 1)
#define rb_eStandardError (PROBE_CLASS_TAG | 2)
#define rb_eRuntimeError (PROBE_CLASS_TAG | 3)
#define rb_eLoadError (PROBE_CLASS_TAG | 4)
#define rb_eArgError (PROBE_CLASS_TAG | 5)
/* Loader rejects prebuilt extensions using a different VALUE ABI. */
__attribute__((weak,visibility("default"))) const unsigned mere_extension_abi = 0x4d520002U;
_Noreturn void rb_raise(VALUE, const char *, ...);
VALUE rb_require(const char *);
void ruby_xfree(void *);
#define xfree ruby_xfree
#define ALLOC(type) ((type *)calloc(1, sizeof(type)))
VALUE rb_define_module(const char *);
VALUE rb_define_module_under(VALUE, const char *);
VALUE rb_define_class(const char *, VALUE);
VALUE rb_define_class_under(VALUE, const char *, VALUE);
void rb_define_alloc_func(VALUE, probe_method0);
void probe_typed_define0(VALUE, const char *, probe_method0, int);
void probe_typed_define1(VALUE, const char *, probe_method1, int);
void probe_typed_define2(VALUE, const char *, probe_method2, int);
#undef rb_define_singleton_method
#define rb_define_singleton_method(k,n,f,a) \
    _Generic((f), probe_method0: probe_typed_define0, probe_method1: probe_typed_define1, probe_method2: probe_typed_define2)(k,n,f,a)
void probe_typed_instance0(VALUE, const char *, probe_method0, int);
void probe_typed_instance1(VALUE, const char *, probe_method1, int);
void probe_typed_instance2(VALUE, const char *, probe_method2, int);
void probe_typed_module0(VALUE, const char *, probe_method0, int);
void probe_typed_module1(VALUE, const char *, probe_method1, int);
void probe_typed_module2(VALUE, const char *, probe_method2, int);
#define rb_define_method(k,n,f,a) \
    _Generic((f), probe_method0: probe_typed_instance0, probe_method1: probe_typed_instance1, probe_method2: probe_typed_instance2)(k,n,f,a)
#undef rb_define_module_function
#define rb_define_module_function(k,n,f,a) \
    _Generic((f), probe_method0: probe_typed_module0, probe_method1: probe_typed_module1, probe_method2: probe_typed_module2)(k,n,f,a)
void rb_gc_mark(VALUE);
VALUE rb_str_new_cstr(const char *);
VALUE probe_typed_wrap(VALUE, const rb_data_type_t *, void *, size_t);
void *probe_typed_malloc(size_t);
void *probe_typed_data(VALUE);
#define RTYPEDDATA_DATA(v) probe_typed_data(v)
void *rb_check_typeddata(VALUE, const rb_data_type_t *);
#define TypedData_Wrap_Struct(k,t,p) probe_typed_wrap(k,t,p,0)
#define TypedData_Make_Struct(k,s,t,p) \
    ((p) = (s *)probe_typed_malloc(sizeof(s)), probe_typed_wrap(k,t,p,sizeof(s)))
#define TypedData_Get_Struct(v,s,t,p) ((p) = (s *)rb_check_typeddata(v,t))
#define Check_TypedStruct rb_check_typeddata
int probe_typed_num(VALUE);
VALUE probe_typed_int(int);
#define NUM2UINT(v) ((unsigned)probe_typed_num(v))
#define NUM2INT(v) probe_typed_num(v)
#define INT2NUM(v) probe_typed_int(v)
double probe_typed_num2dbl(VALUE);
VALUE probe_typed_dbl2num(double);
#undef NUM2DBL
#undef DBL2NUM
#define NUM2DBL(v) probe_typed_num2dbl(v)
#define DBL2NUM(v) probe_typed_dbl2num(v)
#endif
