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
static void diagnostics_equal(const char *expected) {
 mere_buf diagnostics={0},err={0};
 mere_status result=mere_embedding_error_diagnostics(&diagnostics,&err); boundary(result,err);
 size_t length=strlen(expected);
 if(diagnostics.len!=(long long)length || (length && memcmp(diagnostics.ptr,expected,length))) {
  fprintf(stderr,"diagnostics:%.*s expected:%s\n",(int)diagnostics.len,diagnostics.ptr,expected);
  exit(94);
 }
 mere_lib_free((void*)diagnostics.ptr);
}
static void handled(const char *source, const char *klass) {
 check(source,1,klass);
 /* Inspection leaves the error pending, so another eval must be refused. */
 check("raise 'must not execute'",2,klass);
 if(simple(mere_embedding_clear_error)) exit(93);
}
/* Native provider storage outlives Mere regions. Inspect its existing ABI
 * directly, including while no VM exists, rather than relying on Ruby GC. */
struct mere_bytes { long long len; unsigned char data[]; };
extern struct mere_bytes *mr_ossl_call(const char *, struct mere_bytes *);
extern int mr_ossl_clear_result(void);
extern int mr_ossl_valid(int);
extern int mr_ossl_release(int);
extern long long mr_nkf_owned_allocations(void);
extern const struct mere_bytes *mr_nkf_result(void);
static unsigned long wire_u32(const unsigned char *p) {
 return ((unsigned long)p[0]<<24)|((unsigned long)p[1]<<16)|((unsigned long)p[2]<<8)|p[3];
}
static struct mere_bytes *native_empty(const char *operation, int nil_arg) {
 struct mere_bytes *input=malloc(sizeof(*input)+6);
 if(!input) exit(50);
 input->len=nil_arg?6:5;
 const unsigned char payload[6]={'a',0,0,0,0,'n'};
 memcpy(input->data,payload,(size_t)input->len); input->data[4]=(unsigned char)nil_arg;
 struct mere_bytes *result=mr_ossl_call(operation,input); free(input); return result;
}
static long long native_live(void) {
 struct mere_bytes *r=native_empty("object.stats",0);
 if(!r || r->len<10 || r->data[0]!='a' || wire_u32(r->data+1)!=3 || r->data[5]!='i') exit(50);
 unsigned long n=wire_u32(r->data+6); char text[32],*end=NULL;
 if(n==0 || n>=sizeof(text) || (unsigned long long)r->len<10+n) exit(50);
 memcpy(text,r->data+10,n); text[n]=0;
 long long count=strtoll(text,&end,10); if(*end || count<0) exit(50);
 mr_ossl_clear_result(); return count;
}
static int native_lifetimes(const char *mode) {
 long long initial=native_live();
 struct mere_bytes *outside=native_empty("xcert.new",1);
 if(!outside || outside->len<5 || outside->data[0]!='h') return 50;
 int sentinel=(int)wire_u32(outside->data+1); mr_ossl_clear_result();
 long long baseline=native_live();
 if(baseline!=initial+1 || !mr_ossl_valid(sentinel)) return 50;
 for(int cycle=0;cycle<3;cycle++) {
  mere_lib_init(); if(simple(mere_embedding_setup)) return 51;
  check("require 'nkf'; raise 'nkf conversion' unless NKF.nkf('-w', 'abc')=='abc'",0,"");
  if(mr_nkf_owned_allocations()!=7 || mr_nkf_result()!=NULL) return 55;
  check("require 'openssl'; $held_ssl = Array.new(32) { OpenSSL::X509::Certificate.new }; GC.start",0,"");
  check("$ssl_ready=Queue.new; $ssl_worker=Thread.new { begin; $thread_ssl=OpenSSL::X509::Certificate.new; $ssl_ready << true; sleep; ensure; raise 'native owner lost before thread teardown' unless $thread_ssl.version==0; $thread_end_ssl=OpenSSL::X509::Certificate.new; end }; $ssl_ready.pop",0,"");
  check("at_exit { raise 'native owner lost before hooks' unless $held_ssl.all? { |cert| cert.version==0 }; $hook_ssl=OpenSSL::X509::Certificate.new }",0,"");
  check("at_exit { raise 'nkf lost before hooks' unless NKF.nkf('-s', 'abc')=='abc' }; $nkf_ready=Queue.new; $nkf_worker=Thread.new { begin; $nkf_ready << true; sleep; ensure; raise 'nkf lost before thread teardown' unless NKF.nkf('-w', 'abc')=='abc'; end }; $nkf_ready.pop",0,"");
  int expected=0;
  if(!strcmp(mode,"native-ownership-error")) { check("raise 'pending_native'",1,"RuntimeError"); expected=1; }
  if(!strcmp(mode,"native-ownership-hook-error")) { check("at_exit { $error_ssl=OpenSSL::X509::Certificate.new; raise 'native_hook' }",0,""); expected=1; }
  if(!strcmp(mode,"native-ownership-exit")) { check("at_exit { $exit_ssl=OpenSSL::X509::Certificate.new; exit 7 }",0,""); expected=7; }
  if(!strcmp(mode,"native-ownership-failure")) expected=1;
  long long status=simple(mere_embedding_cleanup);
  if(status!=expected || simple(mere_embedding_cleanup)!=expected) return 51;
  if(mr_nkf_owned_allocations()!=0 || mr_nkf_result()!=NULL) return 56;
  long long live=native_live();
  if(live!=baseline || !mr_ossl_valid(sentinel)) {
   fprintf(stderr,"native live after cleanup cycle %d: %lld baseline:%lld\n",cycle,live,baseline); return 52;
  }
  mere_lib_shutdown();
  if(native_live()!=baseline || !mr_ossl_valid(sentinel)) return 53;
 }
 if(mr_ossl_release(sentinel)!=1 || native_live()!=initial) return 54;
 puts("native_ownership_cleanup_passed"); return 0;
}
static void host_signal(int sig) { (void)sig; }
int main(int argc,char **argv) {
 setvbuf(stdout,NULL,_IOLBF,0);
 struct sigaction action={0}, observed={0}; action.sa_handler=host_signal; sigemptyset(&action.sa_mask); sigaction(SIGPIPE,&action,NULL);
 if(argc>1 && !strncmp(argv[1],"native-ownership",16)) return native_lifetimes(argv[1]);
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
 if(argc>1 && (!strcmp(argv[1],"object-message") || !strcmp(argv[1],"object-spoof-message") || !strcmp(argv[1],"object-hook-message"))) {
  const char *mode=argv[1];
  if(!strcmp(mode,"object-hook-message")) {
   check("at_exit { e = RuntimeError.new('hook_original'); e.instance_variable_set(:@message, 'spoofed'); raise e }",0,"");
   diagnostics_equal("");
  } else {
   check(!strcmp(mode,"object-spoof-message") ?
     "e = RuntimeError.new('original'); e.instance_variable_set(:@message, 'spoofed'); GC.start; raise e" :
     "e = RuntimeError.new('original'); GC.start; raise e",1,"RuntimeError");
   diagnostics_equal("RuntimeError: original\n");
  }
  if(simple(mere_embedding_cleanup)!=1 || simple(mere_embedding_cleanup)!=1) return 41;
  diagnostics_equal(!strcmp(mode,"object-hook-message") ? "RuntimeError: hook_original\n" : "RuntimeError: original\n");
  check("puts 'must_not_run'",2,"RuntimeError");
  mere_lib_shutdown(); puts("object_diagnostics_passed"); return 0;
 }
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
   diagnostics_equal("BadInspect: original\n");
   if(!strcmp(mode,"bad-inspect-clear")) {
    if(simple(mere_embedding_clear_error)) return 35;
    check("GC.start; raise 'clear failed' unless $!.nil?; puts 'recovered'",0,"");
   }
  }
  int expected=!strcmp(mode,"bad-inspect-clear") ? 0 : 1;
  if(simple(mere_embedding_cleanup)!=expected || simple(mere_embedding_cleanup)!=expected) return 36;
  check("puts 'must_not_run'",2,!strcmp(mode,"primitive-pending") ? "ArgumentError" : expected ? "BadInspect" : "");
  if(strcmp(mode,"primitive-pending")) diagnostics_equal(expected ? "BadInspect: original\n" : "");
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
