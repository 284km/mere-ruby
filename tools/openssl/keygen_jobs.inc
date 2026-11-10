/* Generation callbacks rendezvous with Ruby on its own thread. The worker
 * owns only OpenSSL/libc data and never enters the VM or a Mere region. */
typedef struct keygen_job {
    pthread_mutex_t lock;
    pthread_cond_t changed;
    pthread_t thread;
    pid_t owner;
    EVP_PKEY_CTX *ctx;
    EVP_PKEY *key;
    buffer failure;
    int started,done,cancelled,waiting,notified,parameters;
    int count,progress[64];
} keygen_job;

static int keygen_progress(EVP_PKEY_CTX *ctx) {
    keygen_job *job=EVP_PKEY_CTX_get_app_data(ctx);
    pthread_mutex_lock(&job->lock);
    if(job->cancelled) { pthread_mutex_unlock(&job->lock); return 0; }
    int n=EVP_PKEY_CTX_get_keygen_info(ctx,-1);
    job->count=n<0?0:(n>64?64:n);
    for(int i=0;i<job->count;i++) job->progress[i]=EVP_PKEY_CTX_get_keygen_info(ctx,i);
    job->waiting=1; job->notified=0;
    pthread_cond_broadcast(&job->changed);
    while(job->waiting&&!job->cancelled) pthread_cond_wait(&job->changed,&job->lock);
    int ok=!job->cancelled;
    pthread_mutex_unlock(&job->lock);
    return ok;
}
static void *keygen_worker(void *data) {
    keygen_job *job=data;
    EVP_PKEY *key=NULL;
    EVP_PKEY_CTX_set_app_data(job->ctx,job);
    EVP_PKEY_CTX_set_cb(job->ctx,keygen_progress);
    int ok=job->parameters?EVP_PKEY_paramgen(job->ctx,&key):EVP_PKEY_keygen(job->ctx,&key);
    buffer failure={0};
    if(ok<=0) { EVP_PKEY_free(key); key=NULL; ssl_error(&failure,"OpenSSL::PKey::PKeyError","EVP_PKEY generation"); }
    pthread_mutex_lock(&job->lock);
    job->key=key; job->failure=failure; job->done=1;
    pthread_cond_broadcast(&job->changed);
    pthread_mutex_unlock(&job->lock);
    return NULL;
}
static void free_keygen_job(void *ptr) {
    keygen_job *job=ptr;
    if(job->owner!=getpid()) {
        /* The parent's worker is absent after fork. Its copied locks and
         * in-flight OpenSSL context are never used or destroyed in the child. */
        free(job); return;
    }
    pthread_mutex_lock(&job->lock);
    job->cancelled=1; job->waiting=0;
    pthread_cond_broadcast(&job->changed);
    pthread_mutex_unlock(&job->lock);
    if(job->started) pthread_join(job->thread,NULL);
    EVP_PKEY_free(job->key); EVP_PKEY_CTX_free(job->ctx);
    free(job->failure.p);
    pthread_cond_destroy(&job->changed); pthread_mutex_destroy(&job->lock);
    free(job);
}
static void keygen_start(const arg *args,buffer *out) {
    if(!count(args,2,3,out)) return;
    EVP_PKEY_CTX *ctx=generation_context(at(args,0),at(args,1),truth(at(args,2)),out);
    if(!ctx) return;
    keygen_job *job=calloc(1,sizeof(*job));
    if(!job) { EVP_PKEY_CTX_free(ctx); error(out,"NoMemoryError","key generation job allocation failed"); return; }
    job->owner=getpid(); job->ctx=ctx; job->parameters=truth(at(args,2));
    if(pthread_mutex_init(&job->lock,NULL)) {
        EVP_PKEY_CTX_free(ctx); free(job); error(out,"OpenSSL::PKey::PKeyError","cannot initialize generation mutex"); return;
    }
    if(pthread_cond_init(&job->changed,NULL)) {
        pthread_mutex_destroy(&job->lock); EVP_PKEY_CTX_free(ctx); free(job);
        error(out,"OpenSSL::PKey::PKeyError","cannot initialize generation condition"); return;
    }
    int id=own(job,NK_JOB,"OpenSSL::Backend::KeygenJob",free_keygen_job,NULL);
    if(!id) { error(out,"NoMemoryError","native job slots exhausted"); return; }
    if(pthread_create(&job->thread,NULL,keygen_worker,job)) {
        release(id); error(out,"OpenSSL::PKey::PKeyError","cannot start generation worker"); return;
    }
    job->started=1;
    object_result(out,id);
}
static keygen_job *keygen_arg(const arg *arg,buffer *out) {
    native_slot *slot=lookup(num(arg),NK_JOB);
    if(!slot||strcmp(slot->klass,"OpenSSL::Backend::KeygenJob")) { error(out,"TypeError","invalid or released generation job"); return NULL; }
    keygen_job *job=slot->ptr;
    if(job->owner!=getpid()) { error(out,"OpenSSL::PKey::PKeyError","generation job belongs to another process"); return NULL; }
    return job;
}
static void keygen_call(const char *op,const arg *args,buffer *out) {
    if(!strcmp(op,"start")) { keygen_start(args,out); return; }
    if(!count(args,1,1,out)) return;
    keygen_job *job=keygen_arg(at(args,0),out); if(!job) return;
    pthread_mutex_lock(&job->lock);
    if(!strcmp(op,"respond")) {
        if(!job->waiting||!job->notified) error(out,"OpenSSL::PKey::PKeyError","no pending generation callback");
        else { job->waiting=0; pthread_cond_signal(&job->changed); byte(out,'n'); }
    } else if(!strcmp(op,"poll")) {
        if(job->waiting&&!job->notified) {
            job->notified=1;
            byte(out,'a'); number(out,2); text(out,"progress");
            byte(out,'a'); number(out,(uint32_t)job->count);
            for(int i=0;i<job->count;i++) integer(out,job->progress[i]);
        } else if(job->done) {
            if(job->failure.len) put(out,job->failure.p,job->failure.len);
            else if(job->key) {
                EVP_PKEY *key=job->key; job->key=NULL;
                byte(out,'a'); number(out,2); text(out,"done"); object_result(out,own_key(key));
            } else error(out,"OpenSSL::PKey::PKeyError","generation result already consumed");
        } else { byte(out,'a'); number(out,1); text(out,"pending"); }
    } else error(out,"NotImplementedError","unknown key generation operation");
    pthread_mutex_unlock(&job->lock);
}
