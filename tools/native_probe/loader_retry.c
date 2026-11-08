#include <ruby.h>
static int attempts;
static VALUE count(VALUE self) { (void)self; return INT2NUM(attempts); }
void Init_loader_retry(void) {
    attempts++;
    VALUE mod=rb_define_module("LoaderRetry");
    rb_define_singleton_method(mod,"attempts",count,0);
    if(attempts==1) rb_raise(rb_eRuntimeError,"retry initialization");
    rb_define_singleton_method(mod,"ready",count,0);
}
