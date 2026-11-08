/* Synchronous TypedData experiment. Descriptors and payloads stay in C;
 * Ruby values are borrowed tokens visited only by reachable owners' dmark. */
#define PROBE_TYPED_API
#include "include/ruby.h"
#include "exception_api.h"
#include <assert.h>
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>

extern VALUE probe_dispatch(int, VALUE, ID, int, VALUE, VALUE);
static char names[64][128] = {"", "Object", "StandardError"};
static int class_count = 3;
static struct {
    char name[180]; VALUE klass; int arity;
    union { probe_method0 zero; probe_method1 one; probe_method2 two; } fn;
} methods[64];
static int method_count;
static void *module;
static char error[256];
static _Thread_local const char *text;
static _Thread_local closure_int_int marker;
static _Thread_local int marking;
struct payload { const rb_data_type_t *type; void *data; size_t owned; int next; };
static struct payload *entries;
static int capacity, high, free_head;
static int live_count, free_count, mark_count, payload_count;
static size_t payload_bytes;

VALUE rb_define_module(const char *name) { return rb_define_module_under(0, name); }
VALUE rb_define_module_under(VALUE parent, const char *name) {
    char full[128];
    assert(parent < (VALUE)class_count);
    snprintf(full, sizeof(full), "%s%s%s", names[parent], parent ? "::" : "", name);
    for (int i=1; i<class_count; i++) if (!strcmp(names[i], full)) return (VALUE)i;
    assert(class_count < 64 && strlen(full) < sizeof(names[0]));
    strcpy(names[class_count], full);
    return (VALUE)class_count++;
}
VALUE rb_define_class_under(VALUE parent, const char *name, VALUE super) {
    (void)super; return rb_define_module_under(parent, name);
}
char *mr_typed_class_name(int id) { return id > 0 && id < class_count ? names[id] : "Object"; }
static int reg(VALUE klass, const char *name, int arity) {
    assert(klass < (VALUE)class_count && method_count < 64);
    int i = method_count++;
    snprintf(methods[i].name, sizeof(methods[i].name), "%s.%s", names[klass], name);
    methods[i].klass = klass; methods[i].arity = arity; return i;
}
void rb_define_alloc_func(VALUE klass, probe_method0 fn) {
    int i=reg(klass, "allocate", -1); methods[i].fn.zero=fn;
}
void probe_typed_define0(VALUE k, const char *n, probe_method0 f, int a) {
    assert(a==0); int i=reg(k,n,a); methods[i].fn.zero=f;
}
void probe_typed_define1(VALUE k, const char *n, probe_method1 f, int a) {
    assert(a==1); int i=reg(k,n,a); methods[i].fn.one=f;
}
void probe_typed_define2(VALUE k, const char *n, probe_method2 f, int a) {
    assert(a==2); int i=reg(k,n,a); methods[i].fn.two=f;
}
int mr_typed_find(const char *name) {
    for(int i=0;i<method_count;i++) if(!strcmp(methods[i].name,name)) return i;
    return -1;
}
VALUE probe_typed_entry(int method, VALUE first, VALUE second) {
    assert(method>=0 && method<method_count);
    if(methods[method].arity==-1) return methods[method].fn.zero(methods[method].klass);
    // Static methods in the original typeddata fixture ignore their receiver,
    // except dynamic_type which passes it to Make_Struct. Give those the C class.
    VALUE self = !strcmp(names[methods[method].klass], "Bug::TypedData") ? methods[method].klass : first;
    if(methods[method].arity==0) return methods[method].fn.zero(self);
    if(methods[method].arity==1) return methods[method].fn.one(self,second);
    return methods[method].fn.two(self,first,second);
}
int mr_typed_load(const char *path) {
    if(module) return method_count;
    module=dlopen(path,RTLD_NOW|RTLD_LOCAL);
    if(!module) { snprintf(error,sizeof(error),"%s",dlerror()); return -1; }
    void (*init)(void)=(void (*)(void))dlsym(module,"Init_typed_probe");
    if(!init) { snprintf(error,sizeof(error),"%s",dlerror()); dlclose(module); module=NULL; return -1; }
    init(); return method_count;
}
char *mr_typed_error(void) { return error; }
char *mr_typed_text(void) { return (char *)(text ? text : ""); }
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
    return probe_dispatch(11,(VALUE)slot,klass,0,0,0);
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
