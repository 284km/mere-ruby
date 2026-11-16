#include <ruby.h>
#include <stdio.h>
#include <stdlib.h>
/* What the dynamic loader does with this library, in order: one line per
 * constructor, Init_ and destructor, in the file LOADER_EVENTS names. */
static void event(const char *what) {
    const char *path = getenv("LOADER_EVENTS");
    FILE *f = path ? fopen(path, "a") : NULL;
    if (f) { fprintf(f, "%s\n", what); fclose(f); }
}
__attribute__((constructor)) static void loaded(void) { event("constructor"); }
__attribute__((destructor)) static void unloaded(void) { event("destructor"); }
static int inits;
typedef struct { VALUE value; } box;
static void mark(void *p) { rb_gc_mark(((box *)p)->value); }
static const rb_data_type_t type = {"loader_box", {mark,ruby_xfree,0},0,0,RUBY_TYPED_FREE_IMMEDIATELY};
static VALUE alloc(VALUE klass) { box *p; VALUE o=TypedData_Make_Struct(klass,box,&type,p); p->value=Qnil; return o; }
static VALUE initialize(VALUE self,VALUE v) { box *p; TypedData_Get_Struct(self,box,&type,p); p->value=v; return self; }
static VALUE value(VALUE self) { box *p; TypedData_Get_Struct(self,box,&type,p); return p->value; }
static VALUE receiver(VALUE self) { return self; }
static VALUE sum(VALUE self,VALUE a,VALUE b) { (void)self; return INT2NUM(NUM2INT(a)+NUM2INT(b)); }
static VALUE yielding(VALUE self,VALUE v) { (void)self; return rb_yield(v); }
static VALUE explode(VALUE self) { (void)self; rb_raise(rb_eRuntimeError,"native failure"); return Qnil; }
static VALUE count(VALUE self) { (void)self; return INT2NUM(inits); }
static VALUE echo(VALUE self,VALUE v) { (void)self; return v; }
void Init_loader_fixture(void) {
    event("Init"); inits++;
    VALUE mod=rb_define_module("LoaderFixture");
    VALUE klass=rb_define_class_under(mod,"Box",rb_cObject);
    rb_define_alloc_func(klass,alloc);
    rb_define_method(klass,"initialize",initialize,1);
    rb_define_method(klass,"value",value,0);
    rb_define_method(klass,"identity",receiver,0);
    rb_define_singleton_method(klass,"receiver",receiver,0);
    rb_define_method(klass,"sum",sum,2);
    rb_define_method(klass,"[]",sum,2);
    rb_define_method(klass,"yielding",yielding,1);
    rb_define_method(klass,"explode",explode,0);
    rb_define_singleton_method(mod,"init_count",count,0);
    rb_define_module_function(mod,"echo",echo,1);
    rb_define_module_function(mod,"count",count,0);
}
