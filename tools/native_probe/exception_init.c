#include <ruby.h>
void Init_ensured(VALUE);
void Init_dataerror(VALUE);
void Init_exception(void) {
    VALUE mod=rb_define_module_under(rb_define_module("Bug"),"Exception");
    Init_ensured(mod);
    Init_dataerror(mod);
}
