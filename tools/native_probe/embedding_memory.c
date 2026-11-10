#define main lifecycle_fixture_main
#include "embedding_host.c"
#undef main
#include <unistd.h>
#ifdef __APPLE__
#include <mach/mach.h>
#endif
static unsigned long long resident_bytes(void) {
#ifdef __APPLE__
 struct mach_task_basic_info info; mach_msg_type_number_t n=MACH_TASK_BASIC_INFO_COUNT;
 if(task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&info,&n)!=KERN_SUCCESS) exit(93);
 return info.resident_size;
#else
 unsigned long long pages,total; FILE *f=fopen("/proc/self/statm","r");
 if(!f||fscanf(f,"%llu %llu",&total,&pages)!=2) exit(93);
 fclose(f);return pages*(unsigned long long)sysconf(_SC_PAGESIZE);
#endif
}
static void sample(const char *stage,int iteration) {
 printf("{\"stage\":\"%s\",\"iteration\":%d,\"rss_bytes\":%llu}\n",stage,iteration,resident_bytes());
}
int main(int argc,char **argv) {
 setvbuf(stdout,NULL,_IOLBF,0); int count=argc>2?atoi(argv[2]):10000;
 const char *mode=argc>1?argv[1]:"scalar";
 const char *source=!strcmp(mode,"churn") ? "scratch = 'x' * 1024; scratch = nil" : "1";
 mere_lib_init();if(simple(mere_embedding_setup))return 10;
 check("$persistent = Object.new; KEEP = $persistent; local_value = 42",0,"");
 sample("setup",0);
 for(int i=1;i<=count;i++) {
  check(source,0,"");
  if(i%100==0) {
   check("GC.start; raise 'persistent state lost' unless KEEP.equal?($persistent) && local_value == 42",0,"");
   sample("eval",i);
  }
 }
 if(simple(mere_embedding_cleanup)) return 11;
 sample("cleanup",count);mere_lib_shutdown();sample("shutdown",count);
 return 0;
}
