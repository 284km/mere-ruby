/* Native registration and synchronous TypedData prototype. Libraries remain
 * resident once Init has run: Ruby definitions and payload callbacks may outlive
 * a failed Init. A missing symbol/ABI failure is closed before running code. */
#define PROBE_TYPED_API
#include "include/ruby.h"
#include "exception_api.h"
#include <assert.h>
#include <ctype.h>
#include <dlfcn.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>

extern VALUE probe_dispatch(int, VALUE, ID, int, VALUE, VALUE);
static char names[512][256] = {"", "Object", "StandardError", "RuntimeError", "LoadError", "ArgumentError"};
static int class_count = 6;
static struct {
    char name[128]; int klass, arity, kind;
    union { probe_method0 zero; probe_method1 one; probe_method2 two; } fn;
} methods[4096];
static int method_count;
static struct { char path[4096]; void *handle; void (*init)(void); int calls; } libraries[128];
static int library_count, open_failures;
static char error[512];
static _Thread_local const char *text;
static _Thread_local double number;
static _Thread_local closure_int_int marker;
static _Thread_local int marking;
struct payload { const rb_data_type_t *type; void *data; size_t owned; int next; };
static struct payload *entries;
static int capacity, high, free_head;
static int live_count, free_count, mark_count, payload_count;
static size_t payload_bytes;

_Noreturn void rb_raise(VALUE klass, const char *format, ...) {
    char message[1024]; va_list ap; va_start(ap,format);
    vsnprintf(message,sizeof(message),format,ap); va_end(ap);
    text=message; probe_dispatch(18,klass,0,0,0,0); abort();
}
VALUE rb_require(const char *path) {
    const char *previous=text; text=path;
    VALUE result=probe_dispatch(19,0,0,0,0,0); text=previous; return result;
}
static int class_id(VALUE klass) {
    if(klass & PROBE_CLASS_TAG) {
        int id=(int)(klass & ~PROBE_CLASS_TAG);
        if(id>0 && id<class_count) return id;
        rb_raise(rb_eArgError,"invalid native class VALUE");
    }
    return (int)probe_dispatch(16,klass,0,0,0,0);
}
int mr_typed_class_index(const char *name) {
    for(int i=1;i<class_count;i++) if(!strcmp(names[i],name)) return i;
    if(class_count==512 || strlen(name)>=sizeof(names[0])) return 0;
    strcpy(names[class_count],name); return class_count++;
}
VALUE rb_define_module(const char *name) { return rb_define_module_under(0,name); }
VALUE rb_define_module_under(VALUE parent, const char *name) {
    int p=parent ? class_id(parent) : 0;
    char full[256]; int n=snprintf(full,sizeof(full),"%s%s%s",p==1?"":names[p],p>1?"::":"",name);
    if(n<0 || n>=(int)sizeof(full)) rb_raise(rb_eArgError,"native class name too long");
    int id=mr_typed_class_index(full); if(!id) rb_raise(rb_eLoadError,"native class capacity exhausted");
    probe_dispatch(20,(VALUE)id,1,0,0,0); return PROBE_CLASS_TAG | (VALUE)id;
}
VALUE rb_define_class(const char *name, VALUE super) { return rb_define_class_under(0,name,super); }
VALUE rb_define_class_under(VALUE parent, const char *name, VALUE super) {
    int p=parent ? class_id(parent) : 0;
    char full[256]; int n=snprintf(full,sizeof(full),"%s%s%s",p==1?"":names[p],p>1?"::":"",name);
    if(n<0 || n>=(int)sizeof(full)) rb_raise(rb_eArgError,"native class name too long");
    int id=mr_typed_class_index(full); if(!id) rb_raise(rb_eLoadError,"native class capacity exhausted");
    probe_dispatch(20,(VALUE)id,0,class_id(super),0,0); return PROBE_CLASS_TAG | (VALUE)id;
}
char *mr_typed_class_name(int id) { return id>0 && id<class_count ? names[id] : "Object"; }
char *mr_typed_method_name(int id) { return id>=0 && id<method_count ? methods[id].name : ""; }
int mr_typed_method_info(int id,int field) {
    if(id<0 || id>=method_count) return -1;
    return field==0 ? methods[id].klass : field==1 ? methods[id].arity : methods[id].kind;
}
static int reg(VALUE klass,const char *name,int arity,int kind) {
    if(method_count==4096 || strlen(name)>=sizeof(methods[0].name)) rb_raise(rb_eLoadError,"native method capacity exhausted");
    if(arity<0 || arity>2) rb_raise(rb_eArgError,"native arity is outside 0..2");
    int i=method_count++; strcpy(methods[i].name,name);
    methods[i].klass=class_id(klass); methods[i].arity=arity; methods[i].kind=kind; return i;
}
void rb_define_alloc_func(VALUE klass,probe_method0 f) {
    int i=reg(klass,"allocate",0,2); methods[i].fn.zero=f; probe_dispatch(21,(VALUE)i,0,0,0,0);
}
#define DEFINE_REG(N,TYPE,MEMBER) \
void probe_typed_define##N(VALUE k,const char*n,TYPE f,int a) { \
    if(a!=N) rb_raise(rb_eArgError,"native method signature mismatch"); \
    int i=reg(k,n,a,1); methods[i].fn.MEMBER=f; probe_dispatch(21,(VALUE)i,0,0,0,0); } \
void probe_typed_instance##N(VALUE k,const char*n,TYPE f,int a) { \
    if(a!=N) rb_raise(rb_eArgError,"native method signature mismatch"); \
    int i=reg(k,n,a,0); methods[i].fn.MEMBER=f; probe_dispatch(21,(VALUE)i,0,0,0,0); }
DEFINE_REG(0,probe_method0,zero)
DEFINE_REG(1,probe_method1,one)
DEFINE_REG(2,probe_method2,two)
#define DEFINE_MODULE(N,TYPE,MEMBER) \
void probe_typed_module##N(VALUE k,const char*n,TYPE f,int a) { \
    probe_typed_define##N(k,n,f,a); \
    int i=reg(k,n,a,3); methods[i].fn.MEMBER=f; probe_dispatch(21,(VALUE)i,0,0,0,0); }
DEFINE_MODULE(0,probe_method0,zero)
DEFINE_MODULE(1,probe_method1,one)
DEFINE_MODULE(2,probe_method2,two)
int mr_typed_find(const char *name) {
    for(int i=method_count-1;i>=0;i--) {
        char full[400]; snprintf(full,sizeof(full),"%s.%s",names[methods[i].klass],methods[i].name);
        if(!strcmp(full,name)) return i;
    }
    return -1;
}
VALUE probe_typed_entry(int method,VALUE self,VALUE first,VALUE second) {
    if(method>=1000000) {
        int i=method-1000000; assert(i>=0 && i<library_count);
        libraries[i].calls++; libraries[i].init(); return Qnil;
    }
    assert(method>=0 && method<method_count);
    VALUE result;
    if(methods[method].arity==0) result=methods[method].fn.zero(self);
    else if(methods[method].arity==1) result=methods[method].fn.one(self,first);
    else result=methods[method].fn.two(self,first,second);
    // Class constants have stable tagged ids; Ruby receives a scoped token.
    return result & PROBE_CLASS_TAG ? probe_dispatch(17,result,0,0,0,0) : result;
}
int mr_typed_load(const char *path) {
    for(int i=0;i<library_count;i++) if(!strcmp(libraries[i].path,path)) return 1000000+i;
    if(library_count==128 || strlen(path)>=sizeof(libraries[0].path)) { snprintf(error,sizeof(error),"native library capacity exhausted"); return -1; }
    void *handle=dlopen(path,RTLD_NOW|RTLD_LOCAL);
    if(!handle) { snprintf(error,sizeof(error),"%s",dlerror()); open_failures++; return -1; }
    const unsigned *abi=(const unsigned *)dlsym(handle,"mere_extension_abi");
    const char *base=strrchr(path,'/'); base=base?base+1:path;
    char symbol[256]="Init_"; size_t n=strcspn(base,".");
    int valid=n>0 && n+6<sizeof(symbol);
    for(size_t i=0;valid && i<n;i++) if(!(isalnum((unsigned char)base[i]) || base[i]=='_')) valid=0;
    if(valid) { memcpy(symbol+5,base,n); symbol[n+5]=0; }
    void (*init)(void)=valid?(void (*)(void))dlsym(handle,symbol):NULL;
    if(!abi || *abi!=0x4d520002U || !init) {
        snprintf(error,sizeof(error),"native extension ABI or Init symbol mismatch: %s",base);
        dlclose(handle); open_failures++; return -1;
    }
    int i=library_count++; strcpy(libraries[i].path,path);
    libraries[i].handle=handle; libraries[i].init=init; return 1000000+i;
}
int mr_typed_loader_stat(int field) {
    if(field==0) return library_count;
    if(field==1) return open_failures;
    if(field==2) return method_count;
    int n=0; for(int i=0;i<library_count;i++) n+=libraries[i].calls; return n;
}
char *mr_typed_error(void) { return error; }
char *mr_typed_text(void) { return (char *)(text ? text : ""); }
double mr_typed_number(void) { return number; }
int mr_typed_set_number(double value) { number=value; return 0; }
double probe_typed_num2dbl(VALUE value) {
    probe_dispatch(22,value,0,0,0,0); return number;
}
VALUE probe_typed_dbl2num(double value) {
    number=value; return probe_dispatch(23,0,0,0,0,0);
}
VALUE rb_str_new_cstr(const char *s) {
    const char *old=text; text=s;
    VALUE result=probe_dispatch(10,0,0,0,0,0); text=old; return result;
}
int probe_typed_num(VALUE v) { return (int)probe_dispatch(13,v,0,0,0,0); }
VALUE probe_typed_int(int n) { return probe_dispatch(14,(VALUE)n,0,0,0,0); }
void ruby_xfree(void *p) { free(p); }
VALUE probe_typed_wrap(VALUE klass, const rb_data_type_t *type, void *p, size_t owned) {
    int slot;
    if(free_head) { slot=free_head; free_head=entries[slot].next; }
    else {
        assert(high<INT_MAX-1); slot=++high;
        if(slot>=capacity) {
            int n=capacity ? capacity*2 : 256;
            struct payload *q=realloc(entries,(size_t)n*sizeof(*q));
            if(!q) abort();
            memset(q+capacity,0,(size_t)(n-capacity)*sizeof(*q)); entries=q; capacity=n;
        }
    }
    entries[slot]=(struct payload){.type=type,.data=p,.owned=owned};
    live_count++; if(owned) payload_count++; payload_bytes += owned;
    // WRAP publishes the owner before returning its active VALUE token.
    return probe_dispatch(11,(VALUE)slot,(ID)class_id(klass),0,0,0);
}
void *probe_typed_malloc(size_t size) {
    void *p=calloc(1,size); if(!p) abort(); return p;
}
void *probe_typed_data(VALUE object) {
    int slot=(int)probe_dispatch(12,object,0,0,0,0);
    assert(slot>0 && slot<=high && entries[slot].type); return entries[slot].data;
}
void *rb_check_typeddata(VALUE object, const rb_data_type_t *type) {
    int slot=(int)probe_dispatch(12,object,0,0,0,0);
    if(slot>0 && slot<=high && entries[slot].type) {
        for(const rb_data_type_t *t=entries[slot].type;t;t=t->parent)
            if(t==type) return entries[slot].data;
    }
    text=type->wrap_struct_name;
    probe_dispatch(15,object,0,0,0,0); abort();
}
void rb_gc_mark(VALUE token) {
    assert(marking);
    if(token) (void)marker.fn(marker.env,(long long)token);
}
int mr_typed_mark(closure_int_int visit, int slot) {
    assert(slot>0 && slot<=high && entries[slot].type);
    if(getenv("MERE_TYPED_SKIP_MARK")) return 0;
    closure_int_int previous=marker; int was=marking;
    marker=visit; marking=1;
    if(entries[slot].data && entries[slot].type->function.dmark) {
        mark_count++; entries[slot].type->function.dmark(entries[slot].data);
    }
    marker=previous; marking=was; return 0;
}
int mr_typed_free(int slot) {
    assert(slot>0 && slot<=high && entries[slot].type);
    // dfree may free its own descriptor. Read everything before calling it.
    struct payload entry=entries[slot];
    void (*release)(void *)=entry.type->function.dfree;
    int embedded=(entry.type->flags & RUBY_TYPED_EMBEDDABLE)!=0;
    entries[slot]=(struct payload){.next=free_head}; free_head=slot;
    live_count--; if(entry.owned) payload_count--; payload_bytes -= entry.owned;
    if(entry.data && release && !getenv("MERE_TYPED_SKIP_FREE")) {
        free_count++; release(entry.data);
        // The experiment emulates embedded storage with a separate allocation.
        if(embedded && entry.owned) free(entry.data);
    }
    return 0;
}
int mr_typed_stat(int k) {
    switch(k) { case 0:return live_count; case 1:return free_count;
      case 2:return mark_count; case 3:return payload_count; case 4:return high; case 5:return payload_bytes > INT_MAX ? INT_MAX : (int)payload_bytes; default:return -1; }
}
