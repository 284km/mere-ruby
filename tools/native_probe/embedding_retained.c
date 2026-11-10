#define main lifecycle_fixture_main
#include "embedding_host.c"
#undef main
int main(void) {
 mere_lib_init();if(simple(mere_embedding_setup))return 10;
 check("local = 'captured'; def retained_method; 'method survives'; end; $retained_proc = proc { local }; class RetainedClass; def value; 'class survives'; end; end",0,"");
 for(int i=0;i<100;i++) {
  check("GC.start; scratch = 'x' * 10000; scratch = nil",0,"");
  check("raise 'retained state lost' unless retained_method == 'method survives' && $retained_proc.call == 'captured' && RetainedClass.new.value == 'class survives'",0,"");
 }
 if(simple(mere_embedding_cleanup))return 11;
 mere_lib_shutdown();puts("methods, captured blocks and classes survive evaluation regions");return 0;
}
