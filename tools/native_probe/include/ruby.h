#ifndef NATIVE_PROBE_RUBY_H
#define NATIVE_PROBE_RUBY_H
#include <stdint.h>
#include <math.h>
typedef uint32_t VALUE;
typedef VALUE (*probe_method2)(VALUE, VALUE, VALUE);
double probe_num2dbl(VALUE);
VALUE probe_dbl2num(double);
void rb_define_singleton_method(VALUE, const char *, probe_method2, int);
#define NUM2DBL(v) probe_num2dbl(v)
#define DBL2NUM(v) probe_dbl2num(v)
#endif
