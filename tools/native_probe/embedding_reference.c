#include <ruby.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static long last_exit=0;
static VALUE eval_in_binding(VALUE source) { return rb_funcall(rb_const_get(rb_cObject,rb_intern("TOPLEVEL_BINDING")),rb_intern("eval"),1,source); }
static void check(const char *source,int expected,const char *klass) {
 int state=0; rb_protect(eval_in_binding,rb_str_new_cstr(source),&state);
 if (!!state != expected) { fprintf(stderr,"state mismatch:%s error:%s\n",source, state ? rb_obj_classname(rb_errinfo()) : "none"); if(state) rb_p(rb_errinfo()); exit(91); }
 if(state) {
  VALUE e=rb_errinfo(); const char *actual=rb_obj_classname(e);
  if(strcmp(actual,klass)) { fprintf(stderr,"class:%s expected:%s\n",actual,klass); exit(92); }
  if(!strcmp(actual,"SystemExit")) last_exit=NUM2LONG(rb_funcall(e,rb_intern("status"),0));
  rb_set_errinfo(Qnil);
 }
}
int main(int argc,char **argv) {
 ruby_sysinit(&argc,&argv); RUBY_INIT_STACK;
 setvbuf(stdout,NULL,_IOLBF,0);
 if(ruby_setup()) return 10;
 char *options[]={"embedded","--disable=gems","-e",""};
 void *node=ruby_options(4,options);
 if(ruby_exec_node(node)) return 11;
  check("$stdout.sync=true; $lifetime=40; local_value=7; at_exit { puts 'cleanup_hook' }; KEEP=Object.new; $keep=KEEP",0,"");
  puts("between_evals");
  check("raise 'state' unless $lifetime==40 && local_value==7 && KEEP.equal?($keep); $lifetime+=2",0,"");
  check("raise 'runtime'",1,"RuntimeError");
  check("raise 'pending leaked' unless $!.nil?; raise 'state lost' unless $lifetime==42",0,"");
  check("def broken(",1,"SyntaxError");
  check("exit 7",1,"SystemExit");
  if(last_exit!=7) return 15;
  check("exit 0",1,"SystemExit");
  if(last_exit!=0) return 16;
  check("BEGIN { raise 'begin' }",1,"RuntimeError");
  check("raise ArgumentError, 'arg'",1,"ArgumentError");
  check("Object.this_method_does_not_exist",1,"NoMethodError");
  check("GC.start; raise 'gc lost state' unless $lifetime==42 && local_value==7 && KEEP.equal?($keep)",0,"");
  check("at_exit { GC.start; raise 'closure lost' unless local_value==7 && KEEP.equal?($keep); at_exit { GC.start; puts 'nested_hook' } }; END { puts 'end_hook' }",0,"");
  check("def nested_failure; raise 'nested'; end; nested_failure",1,"RuntimeError");
  check("raise 'cleanup happened' unless $!.nil?; puts 'state_preserved'",0,"");
 for(int i=0;i<20;i++) check("GC.start; raise 'persistent binding lost' unless TOPLEVEL_BINDING.eval('local_value')==7 && KEEP.equal?($keep)",0,"");
 puts("before_cleanup");
 int status=ruby_cleanup(0); if(status) return status;
 puts("host_survived"); return 0;
}
