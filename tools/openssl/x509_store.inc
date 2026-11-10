/* Verification callbacks rendezvous with the VM just like key generation.
 * libcrypto remains responsible for chain construction and every verify rule. */
typedef struct verify_context {
    X509_STORE_CTX *ctx;
    X509_STORE *store;
    X509 *cert;
    STACK_OF(X509) *untrusted;
    pthread_mutex_t lock;
    pthread_cond_t changed;
    pthread_t thread;
    pid_t owner;
    int started,done,cancelled,callbacks,waiting,notified,preverify,response,result;
    buffer failure;
} verify_context;
static int verify_ex_index=-1;
static void free_store(void *p) { X509_STORE_free(p); }
static int own_store(X509_STORE *store) { return own(store,NK_STORE,"OpenSSL::X509::Store",free_store,NULL); }
static X509_STORE *store_arg(const arg *a,buffer *out) {
    native_slot *slot=lookup(num(a),NK_STORE);
    if(!slot) error(out,"TypeError","invalid native X509 store"); return slot?slot->ptr:NULL;
}
static int verify_callback(int preverify,X509_STORE_CTX *ctx) {
    verify_context *job=X509_STORE_CTX_get_ex_data(ctx,verify_ex_index);
    pthread_mutex_lock(&job->lock);
    if(job->cancelled) { pthread_mutex_unlock(&job->lock); return 0; }
    job->preverify=preverify; job->waiting=1; job->notified=0;
    pthread_cond_broadcast(&job->changed);
    while(job->waiting&&!job->cancelled) pthread_cond_wait(&job->changed,&job->lock);
    int result=!job->cancelled&&job->response;
    if(!result&&X509_STORE_CTX_get_error(ctx)==X509_V_OK) X509_STORE_CTX_set_error(ctx,X509_V_ERR_CERT_REJECTED);
    pthread_mutex_unlock(&job->lock); return result;
}
static void *verify_worker(void *ptr) {
    verify_context *job=ptr;
    int result=X509_verify_cert(job->ctx); buffer failure={0};
    if(result<0) ssl_error(&failure,"OpenSSL::X509::StoreError","X509_verify_cert"); else ERR_clear_error();
    pthread_mutex_lock(&job->lock);
    job->result=result; job->failure=failure; job->done=1;
    pthread_cond_broadcast(&job->changed);
    pthread_mutex_unlock(&job->lock); return NULL;
}
static void verify_stop(verify_context *job) {
    if(!job->started) return;
    pthread_mutex_lock(&job->lock); job->cancelled=1; job->waiting=0;
    pthread_cond_broadcast(&job->changed); pthread_mutex_unlock(&job->lock);
    pthread_join(job->thread,NULL); job->started=0;
}
static void free_verify_context(void *ptr) {
    verify_context *job=ptr;
    if(job->owner!=getpid()) { free(job); return; }
    verify_stop(job);
    X509_STORE_CTX_free(job->ctx); X509_STORE_free(job->store); X509_free(job->cert);
    sk_X509_pop_free(job->untrusted,X509_free); free(job->failure.p);
    pthread_cond_destroy(&job->changed); pthread_mutex_destroy(&job->lock); free(job);
}
static verify_context *verify_context_arg(const arg *a,buffer *out) {
    native_slot *slot=lookup(num(a),NK_STORE_CONTEXT);
    if(!slot) { error(out,"TypeError","invalid or released X509 store context"); return NULL; }
    verify_context *job=slot->ptr;
    if(job->owner!=getpid()) { error(out,"OpenSSL::X509::StoreError","verification belongs to another process"); return NULL; }
    return job;
}
static STACK_OF(X509) *cert_chain_arg(const arg *a,buffer *out) {
    STACK_OF(X509) *chain=sk_X509_new_null();
    if(!chain) { ssl_error(out,"OpenSSL::X509::StoreError","chain allocation"); return NULL; }
    if(a->type=='n') return chain;
    if(a->type!='a') { error(out,"TypeError","chain must be an Array"); sk_X509_free(chain); return NULL; }
    for(size_t i=0;i<a->len;i++) {
        X509 *cert=xcert_arg(&a->items[i],out);
        if(!cert||!X509_up_ref(cert)) { sk_X509_pop_free(chain,X509_free); return NULL; }
        if(!sk_X509_push(chain,cert)) { X509_free(cert); sk_X509_pop_free(chain,X509_free); ssl_error(out,"OpenSSL::X509::StoreError","chain allocation"); return NULL; }
    }
    return chain;
}
static void cert_chain_result(buffer *out,STACK_OF(X509) *chain) {
    if(!chain) { byte(out,'n'); return; }
    int n=sk_X509_num(chain); byte(out,'a'); number(out,n);
    for(int i=0;i<n;i++) {
        X509 *cert=sk_X509_value(chain,i);
        if(!X509_up_ref(cert)) { ssl_error(out,"OpenSSL::X509::StoreError","X509_up_ref"); return; }
        object_result(out,xcert_own(cert));
    }
}
static void x509_store_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::StoreError";
    if(!strcmp(op,"new")) { object_result(out,own_store(X509_STORE_new())); return; }
    X509_STORE *store=store_arg(at(args,0),out); if(!store) return;
    const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"add_cert")) { X509 *cert=xcert_arg(value,out); if(!cert) return; ok=X509_STORE_add_cert(store,cert); }
    else if(!strcmp(op,"add_crl")) { X509_CRL *crl=xcrl_arg(value,out); if(!crl) return; ok=X509_STORE_add_crl(store,crl); }
    else if(!strcmp(op,"add_file")) ok=X509_STORE_load_file(store,str(value));
    else if(!strcmp(op,"add_path")) ok=X509_STORE_load_path(store,str(value));
    else if(!strcmp(op,"default_paths")) ok=X509_STORE_set_default_paths(store);
    else if(!strcmp(op,"set_flags")) ok=X509_STORE_set_flags(store,(unsigned long)num(value));
    else if(!strcmp(op,"set_purpose")) ok=X509_STORE_set_purpose(store,(int)num(value));
    else if(!strcmp(op,"set_trust")) ok=X509_STORE_set_trust(store,(int)num(value));
    else if(!strcmp(op,"set_time")) X509_VERIFY_PARAM_set_time(X509_STORE_get0_param(store),(time_t)num(value));
    else { error(out,"NotImplementedError","unknown X509 store operation"); return; }
    if(ok) { ERR_clear_error(); byte(out,'n'); } else ssl_error(out,klass,op);
}
static void x509_context_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::StoreError";
    if(!strcmp(op,"new")) {
        X509_STORE *store=store_arg(at(args,0),out); if(!store) return;
        X509 *cert=NULL;
        if(at(args,1)->type!='n'&&!(cert=xcert_arg(at(args,1),out))) return;
        STACK_OF(X509) *chain=cert_chain_arg(at(args,2),out); if(!chain) return;
        verify_context *job=calloc(1,sizeof(*job));
        if(!job) { sk_X509_pop_free(chain,X509_free); error(out,"NoMemoryError","verification context allocation"); return; }
        if(pthread_mutex_init(&job->lock,NULL)) { free(job); sk_X509_pop_free(chain,X509_free); error(out,klass,"verification mutex initialization"); return; }
        if(pthread_cond_init(&job->changed,NULL)) { pthread_mutex_destroy(&job->lock); free(job); sk_X509_pop_free(chain,X509_free); error(out,klass,"verification condition initialization"); return; }
        job->owner=getpid(); job->untrusted=chain; job->ctx=X509_STORE_CTX_new();
        int ok=job->ctx&&X509_STORE_up_ref(store);
        if(ok) job->store=store;
        if(ok&&cert) { ok=X509_up_ref(cert); if(ok) job->cert=cert; }
        if(ok) ok=X509_STORE_CTX_init(job->ctx,store,cert,chain)>0;
        if(!ok) { free_verify_context(job); ssl_error(out,klass,"X509_STORE_CTX_init"); return; }
        if(verify_ex_index<0) verify_ex_index=X509_STORE_CTX_get_ex_new_index(0,NULL,NULL,NULL,NULL);
        if(verify_ex_index<0||!X509_STORE_CTX_set_ex_data(job->ctx,verify_ex_index,job)) { free_verify_context(job); ssl_error(out,klass,"verification callback initialization"); return; }
        object_result(out,own(job,NK_STORE_CONTEXT,"OpenSSL::X509::StoreContext",free_verify_context,NULL)); return;
    }
    verify_context *job=verify_context_arg(at(args,0),out); if(!job) return;
    const arg *value=at(args,1);
    if(!strcmp(op,"start")) {
        if(job->started||job->done) { error(out,klass,"verification already started"); return; }
        job->callbacks=truth(value);
        if(job->callbacks) X509_STORE_CTX_set_verify_cb(job->ctx,verify_callback);
        if(pthread_create(&job->thread,NULL,verify_worker,job)) { error(out,klass,"cannot start verification worker"); return; }
        job->started=1; byte(out,'n'); return;
    }
    if(!strcmp(op,"stop")) { verify_stop(job); byte(out,'n'); return; }
    pthread_mutex_lock(&job->lock);
    if(!strcmp(op,"poll")) {
        byte(out,'a');
        if(job->waiting&&!job->notified) {
            job->notified=1; number(out,2); text(out,"callback"); boolean(out,job->preverify);
        } else if(job->done) {
            if(job->failure.len) { out->len=0; put(out,job->failure.p,job->failure.len); }
            else { number(out,2); text(out,"done"); boolean(out,job->result==1); }
        } else { number(out,1); text(out,"pending"); }
    } else if(!strcmp(op,"respond")) {
        if(!job->waiting||!job->notified) error(out,klass,"no pending verify callback");
        else { job->response=truth(value); job->waiting=0; pthread_cond_signal(&job->changed); byte(out,'n'); }
    } else if(job->started&&!job->waiting&&!job->done) error(out,klass,"verification context is running");
    else if(!strcmp(op,"error")) integer(out,X509_STORE_CTX_get_error(job->ctx));
    else if(!strcmp(op,"error_string")) text(out,X509_verify_cert_error_string(X509_STORE_CTX_get_error(job->ctx)));
    else if(!strcmp(op,"error_depth")) integer(out,X509_STORE_CTX_get_error_depth(job->ctx));
    else if(!strcmp(op,"set_error")) { X509_STORE_CTX_set_error(job->ctx,(int)num(value)); byte(out,'n'); }
    else if(!strcmp(op,"current_cert")) {
        X509 *cert=X509_STORE_CTX_get_current_cert(job->ctx);
        if(cert&&X509_up_ref(cert)) object_result(out,xcert_own(cert)); else byte(out,'n');
    } else if(!strcmp(op,"current_crl")) {
        X509_CRL *crl=X509_STORE_CTX_get0_current_crl(job->ctx);
        if(crl&&X509_CRL_up_ref(crl)) object_result(out,xcrl_own(crl)); else byte(out,'n');
    } else if(!strcmp(op,"chain")) cert_chain_result(out,X509_STORE_CTX_get0_chain(job->ctx));
    else if(!strcmp(op,"set_time")) { X509_VERIFY_PARAM_set_time(X509_STORE_CTX_get0_param(job->ctx),(time_t)num(value)); byte(out,'n'); }
    else if(!strcmp(op,"set_flags")) { X509_VERIFY_PARAM_set_flags(X509_STORE_CTX_get0_param(job->ctx),(unsigned long)num(value)); byte(out,'n'); }
    else if(!strcmp(op,"set_purpose")) {
        if(X509_STORE_CTX_set_purpose(job->ctx,(int)num(value))) byte(out,'n'); else ssl_error(out,klass,"X509_STORE_CTX_set_purpose");
    } else if(!strcmp(op,"set_trust")) {
        if(X509_STORE_CTX_set_trust(job->ctx,(int)num(value))) byte(out,'n'); else ssl_error(out,klass,"X509_STORE_CTX_set_trust");
    } else error(out,"NotImplementedError","unknown X509 store context operation");
    pthread_mutex_unlock(&job->lock);
}
