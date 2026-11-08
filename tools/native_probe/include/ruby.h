#ifndef NATIVE_PROBE_RUBY_H
#define NATIVE_PROBE_RUBY_H
#include <stdint.h>
#include <math.h>
typedef uint32_t VALUE;
typedef uint32_t ID;
typedef VALUE (*probe_method1)(VALUE, VALUE);
typedef VALUE (*probe_method2)(VALUE, VALUE, VALUE);
typedef VALUE (*probe_body)(VALUE);
#define Qnil ((VALUE)0)
ID rb_intern(const char *);
VALUE rb_funcall(VALUE, ID, int, ...);
VALUE rb_ensure(probe_body, VALUE, probe_body, VALUE);
VALUE rb_yield(VALUE);
_Noreturn void rb_exc_raise(VALUE);
void probe_define_module1(VALUE, const char *, probe_method1, int);
void probe_define_module2(VALUE, const char *, probe_method2, int);
#define rb_define_module_function(k,n,f,a) \
  _Generic((f), probe_method1: probe_define_module1, probe_method2: probe_define_module2)(k,n,f,a)
double probe_num2dbl(VALUE);
VALUE probe_dbl2num(double);
void rb_define_singleton_method(VALUE, const char *, probe_method2, int);
#define NUM2DBL(v) probe_num2dbl(v)
#define DBL2NUM(v) probe_dbl2num(v)
#ifdef PROBE_TYPED_API
#include "typed_probe.h"
#endif
#endif
