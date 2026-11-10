/* O(1) lookup with a slot generation. A freed identifier never names a reused
 * object. Exhausted generations retire their slot instead of wrapping. */
enum object_kind { NK_KEY=1, NK_GROUP, NK_POINT, NK_NAME, NK_CERT, NK_REQUEST, NK_CRL, NK_REVOKED, NK_EXTENSION,
                   NK_ATTRIBUTE, NK_STORE, NK_STORE_CONTEXT, NK_SSL_CONTEXT, NK_SSL_SOCKET,
                   NK_SSL_SESSION, NK_JOB, NK_CONFIG, NK_PROVIDER, NK_DIGEST, NK_HMAC, NK_CIPHER };
typedef void (*destroy_fn)(void *);
typedef void *(*copy_fn)(const void *);
typedef struct native_slot {
    void *ptr;
    destroy_fn destroy;
    copy_fn copy;
    const char *klass;
    int kind,next;
    uint16_t generation;
} native_slot;
static native_slot *objects;
static int object_capacity,free_head=-1,live_objects;
static unsigned long long objects_created;

static native_slot *lookup(long long id,int kind) {
    if(id<=0||id>INT_MAX) return NULL;
    unsigned slot=(unsigned)id&32767, generation=(unsigned)id>>15;
    if(slot>=(unsigned)object_capacity) return NULL;
    native_slot *s=&objects[slot];
    return s->ptr&&s->generation==generation&&(!kind||s->kind==kind)?s:NULL;
}
static int own(void *ptr,int kind,const char *klass,destroy_fn destroy,copy_fn copy) {
    if(!ptr) return 0;
    if(free_head<0) {
        int old=object_capacity,cap=old?old*2:64;
        if(old==32768) { destroy(ptr); return 0; }
        native_slot *p=realloc(objects,(size_t)cap*sizeof(*objects));
        if(!p) { destroy(ptr); return 0; }
        objects=p; memset(objects+old,0,(size_t)(cap-old)*sizeof(*objects));
        for(int i=cap-1;i>=old;i--) {
            objects[i].generation=1; objects[i].next=free_head; free_head=i;
        }
        object_capacity=cap;
    }
    int index=free_head; native_slot *s=&objects[index]; free_head=s->next;
    s->ptr=ptr; s->kind=kind; s->klass=klass; s->destroy=destroy; s->copy=copy;
    live_objects++; objects_created++;
    return ((int)s->generation<<15)|index;
}
static int release(long long id) {
    native_slot *s=lookup(id,0); if(!s) return 0;
    void *ptr=s->ptr; destroy_fn destroy=s->destroy;
    int index=(int)(s-objects);
    s->ptr=NULL; s->destroy=NULL; s->copy=NULL; s->klass=NULL; s->kind=0;
    live_objects--;
    if(s->generation<65535) { s->generation++; s->next=free_head; free_head=index; }
    else s->generation=0;
    destroy(ptr); return 1;
}
static void object_result(buffer *out,int id) {
    native_slot *s=lookup(id,0);
    if(!s) { error(out,"OpenSSL::OpenSSLError","native object allocation failed"); return; }
    byte(out,'h'); number(out,(uint32_t)id); text(out,s->klass);
}
static void object_call(const char *op,const arg *args,buffer *out) {
    if(!strcmp(op,"stats")) {
        byte(out,'a'); number(out,3); integer(out,live_objects); integer(out,object_capacity); integer(out,(long long)objects_created); return;
    }
    if(!count(args,1,1,out)) return;
    long long id=num(at(args,0));
    if(!strcmp(op,"release")) { boolean(out,release(id)); return; }
    native_slot *s=lookup(id,0);
    if(!s) { error(out,"TypeError","invalid or released native OpenSSL object"); return; }
    if(!strcmp(op,"copy")) {
        if(!s->copy) { error(out,"TypeError","native OpenSSL object cannot be copied"); return; }
        /* own() may move the slot table, so save metadata before calling it. */
        void *ptr=s->copy(s->ptr); int kind=s->kind; const char *klass=s->klass;
        destroy_fn destroy=s->destroy; copy_fn copy=s->copy;
        if(!ptr) { ssl_error(out,"OpenSSL::OpenSSLError","native object copy"); return; }
        object_result(out,own(ptr,kind,klass,destroy,copy)); return;
    }
    error(out,"NotImplementedError","unknown native object operation");
}
