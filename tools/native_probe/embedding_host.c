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
static void handled(const char *source, const char *klass) {
 check(source,1,klass);
 /* Inspection leaves the error pending, so another eval must be refused. */
 check("raise 'must not execute'",2,klass);
 if(simple(mere_embedding_clear_error)) exit(93);
}
static void host_signal(int sig) { (void)sig; }
int main(int argc,char **argv) {
 setvbuf(stdout,NULL,_IOLBF,0);
 struct sigaction action={0}, observed={0}; action.sa_handler=host_signal; sigemptyset(&action.sa_mask); sigaction(SIGPIPE,&action,NULL);
 mere_lib_init();
 check("puts 'must_not_run'",2,"");
 if(argc>1 && !strcmp(argv[1],"setup-failure")) {
  if(simple(mere_embedding_setup)!=1) return 30;
  if(simple(mere_embedding_setup)!=2) return 31;
  mere_buf input={(const unsigned char *)"puts 'must_not_run'",19},err={0};
  long long status=0;
  mere_status result=mere_embedding_eval_source(input,&status,&err);
  boundary(result,err);
  if(status!=2 || simple(mere_embedding_clear_error)!=2) return 32;
  if(simple(mere_embedding_cleanup)!=1 || simple(mere_embedding_cleanup)!=1) return 33;
  mere_lib_shutdown(); puts("failed_setup_cleanup_passed"); return 0;
 }
 if(simple(mere_embedding_setup)) return 10;
 if(simple(mere_embedding_setup)) return 11;
 if(argc>1 && !strcmp(argv[1],"method-gc")) {
  check("def collect_inside; GC.start; 42; end; raise 'active body lost' unless collect_inside == 42",0,"");
  check("raise 'retained body lost' unless collect_inside == 42; $gc_block = proc { GC.start; 43 }; raise 'active block lost' unless $gc_block.call == 43",0,"");
  handled("def collect_then_raise; GC.start; raise 'after collection'; end; collect_then_raise","RuntimeError");
  check("raise 'recovery failed' unless collect_inside == 42; at_exit { raise 'cleanup body lost' unless collect_inside == 42 && $gc_block.call == 43 }",0,"");
  if(simple(mere_embedding_cleanup)) return 40;
  mere_lib_shutdown(); puts("method_gc_passed"); return 0;
 }
 if(argc>1 && !strcmp(argv[1],"local-call-before-assignment")) {
  check("def read_before_assign; :method; end; $before_assignment = read_before_assign; read_before_assign = 7; raise 'method shadowed' unless $before_assignment == :method; raise 'assignment lost' unless read_before_assign == 7",0,"");
  check("def conditional_local; :conditional_method; end; $before_conditional = conditional_local; conditional_local = 1 if false; raise 'conditional shadowed' unless $before_conditional == :conditional_method",0,"");
  check("GC.start; raise 'completed local lost' unless conditional_local.nil? && read_before_assign == 7",0,"");
  if(simple(mere_embedding_cleanup)) return 39;
  mere_lib_shutdown(); puts("local_call_order_passed"); return 0;
 }
 if(argc>1 && !strcmp(argv[1],"locals-after-error")) {
  check("kept = 42",0,"");
  handled("raise 'failed'; after_failure = 1; kept = 99","RuntimeError");
  check("GC.start; raise 'names lost' unless TOPLEVEL_BINDING.local_variables == [:after_failure, :kept]; raise 'reflection lost' unless TOPLEVEL_BINDING.local_variable_get(:after_failure).nil?; raise 'local lost' unless after_failure.nil?; raise 'value changed' unless kept == 42",0,"");
  check("after_failure = 7",0,"");
  check("raise 'assignment lost' unless after_failure == 7 && kept == 42",0,"");
  if(simple(mere_embedding_cleanup)) return 38;
  mere_lib_shutdown(); puts("locals_after_error_passed"); return 0;
 }
 if(argc>1 && !strcmp(argv[1],"persistent-locals")) {
  check("kept = 42; never = 1 if false",0,"");
  check("raise 'names lost' unless TOPLEVEL_BINDING.local_variables == [:kept, :never]; raise 'unassigned lost' unless TOPLEVEL_BINDING.local_variable_get(:never).nil?",0,"");
  check("later = 7; kept = 43",0,"");
  check("GC.start; raise 'binding order' unless TOPLEVEL_BINDING.local_variables == [:later, :kept, :never]; raise 'values lost' unless kept == 43 && later == 7",0,"");
  if(simple(mere_embedding_cleanup)) return 34;
  mere_lib_shutdown(); puts("persistent_locals_passed"); return 0;
 }
 if(argc>1 && (!strcmp(argv[1],"bad-inspect-pending") || !strcmp(argv[1],"bad-inspect-clear") || !strcmp(argv[1],"bad-inspect-hook") || !strcmp(argv[1],"primitive-pending"))) {
  const char *mode=argv[1];
  check("class BadInspect < StandardError; def inspect; raise 'inspect failed'; end; end; $original = BadInspect.new('original')",0,"");
  if(!strcmp(mode,"primitive-pending")) {
   check("at_exit { raise 'pending lost' unless $!.is_a?(ArgumentError) && $!.message.include?('invalid') }; Integer('bad')",1,"ArgumentError");
  } else if(!strcmp(mode,"bad-inspect-hook")) {
   check("at_exit { puts 'after_bad_inspect' }; at_exit { raise $original }",0,"");
  } else {
   if(!strcmp(mode,"bad-inspect-pending")) check("at_exit { raise 'identity lost' unless $!.equal?($original) }",0,"");
   check("raise $original",1,"BadInspect");
   if(!strcmp(mode,"bad-inspect-clear")) {
    if(simple(mere_embedding_clear_error)) return 35;
    check("GC.start; raise 'clear failed' unless $!.nil?; puts 'recovered'",0,"");
   }
  }
  int expected=!strcmp(mode,"bad-inspect-clear") ? 0 : 1;
  if(simple(mere_embedding_cleanup)!=expected || simple(mere_embedding_cleanup)!=expected) return 36;
  check("puts 'must_not_run'",2,!strcmp(mode,"primitive-pending") ? "ArgumentError" : expected ? "BadInspect" : "");
  if(expected) {
   mere_buf diagnostics={0},err={0};
   mere_status result=mere_embedding_error_diagnostics(&diagnostics,&err); boundary(result,err);
   if(diagnostics.len==0) return 37;
   mere_lib_free((void*)diagnostics.ptr);
  }
  mere_lib_shutdown(); puts("protected_reporting_passed"); return 0;
 }
 if(argc>1 && (strstr(argv[1],"pending-") == argv[1] || strstr(argv[1],"hooks-") == argv[1] || !strcmp(argv[1],"handled-runtime") || !strcmp(argv[1],"runtime-status-ivar") || !strcmp(argv[1],"exit-subclass"))) {
  const char *mode=argv[1]; int expected=0;
  if(!strcmp(mode,"pending-runtime-hook-exit")) {check("at_exit { exit 9 }",0,""); expected=9;}
  if(!strcmp(mode,"pending-exit-hook-error")) {check("at_exit { raise 'hook_error' }",0,""); expected=1;}
  if(!strcmp(mode,"pending-exit-hook-exit")) {check("at_exit { exit 9 }",0,""); expected=9;}
  if(!strcmp(mode,"pending-runtime-normal-hook")) {check("at_exit { raise 'pending invisible' unless $!.is_a?(RuntimeError) }",0,""); expected=1;}
  if(!strcmp(mode,"hooks-exit-then-error")) {check("at_exit { raise 'hook_error' }; at_exit { exit 9 }",0,""); expected=1;}
  if(!strcmp(mode,"hooks-error-then-exit")) {check("at_exit { exit 9 }; at_exit { raise 'hook_error' }",0,""); expected=9;}
  if(strstr(mode,"pending-runtime")==mode) {check("raise 'pending_runtime'",1,"RuntimeError");if(!expected)expected=1;}
  if(strstr(mode,"pending-exit")==mode) {check("exit 7",1,"SystemExit");if(!expected)expected=7;}
  if(!strcmp(mode,"handled-runtime")) handled("raise 'handled'","RuntimeError");
  if(!strcmp(mode,"runtime-status-ivar")) {
   check("e = RuntimeError.new('status'); e.instance_variable_set(:@__status, 7); raise e",1,"RuntimeError");
   if(simple(mere_embedding_exception_status)!=1) return 26;
   expected=1;
  }
  if(!strcmp(mode,"exit-subclass")) {
   check("class EmbeddedExit < SystemExit; end; raise EmbeddedExit.new(7)",1,"EmbeddedExit");
   if(simple(mere_embedding_exception_status)!=7) return 27;
   expected=7;
  }
  if(simple(mere_embedding_cleanup)!=expected || simple(mere_embedding_cleanup)!=expected) return 23;
  mere_buf diagnostics={0},err={0};
  mere_status result=mere_embedding_error_diagnostics(&diagnostics,&err);
  boundary(result,err);
  if((strstr(mode,"pending-runtime")==mode || strstr(mode,"hook-error") || strstr(mode,"hooks-")) && diagnostics.len==0) return 24;
  if(!strcmp(mode,"runtime-status-ivar") && diagnostics.len==0) return 28;
  if(!strcmp(mode,"exit-subclass") && diagnostics.len!=0) return 29;
  mere_lib_free((void*)diagnostics.ptr);
  if(simple(mere_embedding_clear_error)!=2) return 25;
  mere_lib_shutdown(); puts("cleanup_contract_passed"); return 0;
 } else if(argc>1 && !strcmp(argv[1],"cleanup-error")) {
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
  handled("raise 'runtime'","RuntimeError");
  check("raise 'pending leaked' unless $!.nil?; raise 'state lost' unless $lifetime==42",0,"");
  handled("def broken(","SyntaxError");
  check("exit 7",1,"SystemExit");
  if(simple(mere_embedding_exception_status)!=7) return 15;
  if(simple(mere_embedding_clear_error)) return 21;
  check("exit 0",1,"SystemExit");
  if(simple(mere_embedding_exception_status)!=0) return 16;
  if(simple(mere_embedding_clear_error)) return 22;
  handled("BEGIN { raise 'begin' }","RuntimeError");
  handled("raise ArgumentError, 'arg'","ArgumentError");
  handled("Object.this_method_does_not_exist","NoMethodError");
  check("GC.start; raise 'gc lost state' unless $lifetime==42 && local_value==7 && KEEP.equal?($keep)",0,"");
  check("at_exit { GC.start; raise 'closure lost' unless local_value==7 && KEEP.equal?($keep); at_exit { GC.start; puts 'nested_hook' } }; END { puts 'end_hook' }",0,"");
  handled("def nested_failure; raise 'nested'; end; nested_failure","RuntimeError");
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
