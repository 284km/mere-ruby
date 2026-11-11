/* Generated fixture data comes from the pinned reference and explicit bounds policy. */
#define MR_NKF_TEST 1
#include "../tools/nkf_engine.c"
#include <assert.h>
typedef struct {const char *option;const unsigned char *input;size_t size;const unsigned char *output;size_t output_size;int status;const char *encoding;} check;
#include "nkf_cases.h"
static nkf_bytes *input_wire(const unsigned char *data,size_t length) {
 nkf_bytes *p=malloc(sizeof(*p)+length);assert(p);p->len=(nkf_wire_length)length;
 if(length)memcpy(p->data,data,length);return p;
}
static int invoke(const char *option,const unsigned char *data,size_t length) {
 int status=(int)mr_nkf_reset(0);
 if(!status)status=(int)mr_nkf_options(option);
 nkf_bytes *p=input_wire(data,length);
 if(!status)status=(int)mr_nkf_convert(p);
 free(p);return status;
}
static void assert_recovery(void) {
 assert(invoke("-w",(const unsigned char*)"\343\201\202",3)==0);
 const nkf_bytes *out=mr_nkf_result();assert(out&&out->len==3);
 assert(!memcmp(out->data,"\343\201\202",3));
 mr_nkf_clear_result();mr_nkf_cleanup();assert(mr_nkf_test_allocations()==0);
}
int main(void) {
 size_t count=sizeof(cases)/sizeof(cases[0]);
 for(size_t i=0;i<count;i++) {
  const check *p=cases+i;int status=invoke(p->option,p->input,p->size);
  assert(status==p->status);
  if(!status) {
   const nkf_bytes *out=mr_nkf_result();assert(out);
   assert((size_t)out->len==p->output_size);
   assert(!memcmp(out->data,p->output,p->output_size));
   const char *encoding=mr_nkf_encoding();
   if(!strcmp(encoding,"ASCII"))encoding="US-ASCII";
   if(!strcmp(encoding,"eucJP-nkf"))encoding=mr_nkf_base_encoding();
   assert(!strcmp(encoding,p->encoding));
  }
  mr_nkf_clear_result();assert(mr_nkf_test_allocations()==7);
 }
 mr_nkf_cleanup();assert(!mr_nkf_test_allocations());
 size_t failures=0;
 for(int at=0;at<24;at++) {
  mr_nkf_test_fail_after(at);
  unsigned char data[2000];memset(data,'A',sizeof(data));
  int status=invoke("-w -MB",data,sizeof(data));assert(status==0||status==NKF_NO_MEMORY);
  if(status==NKF_NO_MEMORY) {failures++;assert(!mr_nkf_result());assert(!mr_nkf_test_allocations());}
  mr_nkf_test_fail_after(-1);mr_nkf_cleanup();assert(!mr_nkf_test_allocations());
  assert_recovery();
 }
 assert(failures>=8);
 unsigned char mime[4096];const char *word="=?UTF-8?B?44GC?=";size_t n=strlen(word);
 memcpy(mime,word,n);memset(mime+n,' ',2000);memcpy(mime+n+2000,word,n);
 size_t total=n*2+2000;
 for(int at=0;at<40;at++) {
  mr_nkf_test_fail_after(at);int status=invoke("-w",mime,total);
  assert(status==0||status==NKF_NO_MEMORY);
  if(status==NKF_NO_MEMORY){assert(!mr_nkf_result());assert(!mr_nkf_test_allocations());}
  mr_nkf_test_fail_after(-1);mr_nkf_cleanup();assert(!mr_nkf_test_allocations());assert_recovery();
 }
 /* Reject impossible lengths before reading a byte, then remain usable. */
 nkf_bytes *bad=input_wire(NULL,0);
 bad->len=-1;assert(mr_nkf_reset(0)==0);assert(mr_nkf_options("-w")==0);
 assert(mr_nkf_convert(bad)==NKF_TOO_LARGE);
 bad->len=(long long)INT_MAX+1;assert(mr_nkf_convert(bad)==NKF_TOO_LARGE);
 free(bad);assert_recovery();
 /* Deterministic malformed bytes exercise the conversion core's boundaries.
  * These are sanitizer checks, not compatibility oracles for invalid input. */
 uint32_t seed=0x4e4b4630;
 const char *fuzz_options[]={"-j","-e","-s","-w","-w16L","-w32B",
                            "-w -mB","-w -mQ","-w -MB","-w -MQ"};
 for(size_t i=0;i<2000;i++) {
  unsigned char data[129];size_t length=i%sizeof(data);
  for(size_t j=0;j<length;j++){seed=seed*1664525u+1013904223u;data[j]=(unsigned char)(seed>>24);}
  assert(invoke(fuzz_options[i%10],data,length)==0);
  assert(mr_nkf_result()&&mr_nkf_encoding_bytes()&&mr_nkf_base_encoding_bytes());
  mr_nkf_clear_result();
 }
 for(int i=0;i<1000;i++)assert_recovery();
 mr_nkf_cleanup();mr_nkf_cleanup();assert(!mr_nkf_test_allocations());
 printf("%zu conversions, 24 output-allocation controls, 40 MIME-allocation controls and 1000 cleanup/recovery cycles passed\n",count);
 return 0;
}
