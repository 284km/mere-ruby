#include <ruby.h>
void Init_loader_nested(void) {
    rb_require("loader_fixture");
    rb_require("loader_nested");
    rb_define_module("LoaderNested");
}
