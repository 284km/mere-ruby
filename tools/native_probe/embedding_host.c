#include "embedding.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
static void boundary(mere_status s, mere_buf err) {
 if (s != MERE_OK) { fprintf(stderr,"boundary:%.*s\n",(int)err.len,err.ptr); exit(90); }
 mere_lib_free((void *)err.ptr);
}
static long long simple(mere_status (*f)(long long *,mere_buf *)) {
 long long value=-999; mere_buf err={0}; mere_status s=f(&value,&err); boundary(s,err); return value;
}
static void check(const char *code, int status, const char *klass) {
 mere_buf in={(const unsigned char *)code,(long long)strlen(code)},err={0},cl={0}; long long value=-999;
 mere_status s=mere_embedding_eval_source(in,&value,&err); boundary(s,err);
 if(value!=status) { fprintf(stderr,"status:%lld expected:%d source:%s\n",value,status,code); exit(91); }
 err=(mere_buf){0}; s=mere_embedding_error_class(&cl,&err); boundary(s,err);
 if(cl.len!=(long long)strlen(klass)||memcmp(cl.ptr,klass,(size_t)cl.len)) { fprintf(stderr,"class:%.*s expected:%s source:%s\n",(int)cl.len,cl.ptr,klass,code); exit(92); }
 mere_lib_free((void*)cl.ptr);
}
static void host_signal(int sig) { (void)sig; }
int main(int argc,char **argv) {
 setvbuf(stdout,NULL,_IOLBF,0);
 struct sigaction action={0}, observed={0}; action.sa_handler=host_signal; sigemptyset(&action.sa_mask); sigaction(SIGPIPE,&action,NULL);
 mere_lib_init();
 check("puts 'must_not_run'",2,"");
 if(simple(mere_embedding_setup)) return 10;
 if(simple(mere_embedding_setup)) return 11;
 if(argc>1 && !strcmp(argv[1],"cleanup-error")) {
  check("at_exit { puts 'last_hook' }; at_exit { raise 'hook_error' }; at_exit { puts 'first_hook' }",0,"");
  puts("before_cleanup");
  if(simple(mere_embedding_cleanup)!=1) return 12;
  if(simple(mere_embedding_cleanup)!=1) return 13;
 } else if(argc>1 && !strcmp(argv[1],"cleanup-exit")) {
  check("at_exit { puts 'cleanup_hook'; exit 7 }",0,"");
  if(simple(mere_embedding_cleanup)!=7) return 14;
 } else {
  check("$stdout.sync=true; $lifetime=40; local_value=7; at_exit { puts 'cleanup_hook' }; KEEP=Object.new; $keep=KEEP",0,"");
  puts("between_evals");
  check("raise 'state' unless $lifetime==40 && local_value==7 && KEEP.equal?($keep); $lifetime+=2",0,"");
  check("raise 'runtime'",1,"RuntimeError");
  check("raise 'pending leaked' unless $!.nil?; raise 'state lost' unless $lifetime==42",0,"");
  check("def broken(",1,"SyntaxError");
  check("exit 7",1,"SystemExit");
  if(simple(mere_embedding_exception_status)!=7) return 15;
  check("exit 0",1,"SystemExit");
  if(simple(mere_embedding_exception_status)!=0) return 16;
  check("BEGIN { raise 'begin' }",1,"RuntimeError");
  check("raise ArgumentError, 'arg'",1,"ArgumentError");
  check("Object.this_method_does_not_exist",1,"NoMethodError");
  check("GC.start; raise 'gc lost state' unless $lifetime==42 && local_value==7 && KEEP.equal?($keep)",0,"");
  check("at_exit { GC.start; raise 'closure lost' unless local_value==7 && KEEP.equal?($keep); at_exit { GC.start; puts 'nested_hook' } }; END { puts 'end_hook' }",0,"");
  check("def nested_failure; raise 'nested'; end; nested_failure",1,"RuntimeError");
  check("raise 'cleanup happened' unless $!.nil?; puts 'state_preserved'",0,"");
  for(int i=0;i<20;i++) check("GC.start; raise 'persistent binding lost' unless TOPLEVEL_BINDING.eval('local_value')==7 && KEEP.equal?($keep)",0,"");
  puts("before_cleanup");
  if(simple(mere_embedding_cleanup)) return 17;
  if(simple(mere_embedding_cleanup)) return 18;
 }
 check("puts 'must_not_run'",2,argc>1 && !strcmp(argv[1],"cleanup-error") ? "RuntimeError" : "");
 if(simple(mere_embedding_setup)!=2) return 19;
 sigaction(SIGPIPE,NULL,&observed); if(observed.sa_handler!=host_signal) return 20;
 mere_lib_shutdown(); puts("host_survived"); return 0;
}
