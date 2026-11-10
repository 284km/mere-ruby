/* OpenSSL descriptors contain libc/OpenSSL data only. Ruby callbacks are
 * represented by event masks; no VM pointer crosses into a worker. */
enum tls_callback_kind { TLS_VERIFY=1, TLS_SNI=2, TLS_ALPN=4, TLS_CLIENT_CERT=8,
    TLS_KEYLOG=16, TLS_SESSION_NEW=32, TLS_SESSION_GET=64, TLS_RENEGOTIATE=128,
    TLS_TMP_DH=256, TLS_NPN=512, TLS_SESSION_REMOVE=1024 };
typedef struct removed_session { SSL_SESSION *session; struct removed_session *next; } removed_session;
typedef struct tls_context {
    SSL_CTX *ctx;
    int callbacks,event_failed,event_count;
    unsigned char *npn_data;
    size_t npn_length;
    pthread_mutex_t event_lock;
    removed_session *removed_head,*removed_tail;
} tls_context;
static int tls_context_index=-1;
typedef struct tls_socket {
    SSL *ssl;
    pid_t owner;
    pthread_mutex_t lock;
    pthread_cond_t changed;
    pthread_t thread;
    int started,done,cancelled,waiting,notified,callbacks,event,accepted,operation,rc,ssl_error;
    int verify_handle;
    int event_arg0,event_arg1;
    DH *legacy_dh;
    unsigned char *npn_data;
    size_t npn_length;
    X509_STORE_CTX *verify;
    SSL_SESSION *event_session;
    unsigned char *event_data,*selected;
    size_t event_length,selected_length;
    SSL_CTX *selected_context;
    EVP_PKEY *selected_key;
    X509 *selected_certificate;
    SSL_SESSION *selected_session;
    unsigned char *input,*output;
    size_t input_length,output_length,output_capacity;
    buffer failure;
} tls_socket;
static void tls_context_ex_free(void *parent,void *ptr,CRYPTO_EX_DATA *data,int index,long argl,void *argp) {
    (void)parent; (void)data; (void)index; (void)argl; (void)argp;
    tls_context *context=ptr; if(!context) return;
    removed_session *entry=context->removed_head;
    while(entry) { removed_session *next=entry->next; SSL_SESSION_free(entry->session); free(entry); entry=next; }
    pthread_mutex_destroy(&context->event_lock); OPENSSL_free(context->npn_data); free(context);
}
static void free_tls_context(void *ptr) { tls_context *c=ptr; SSL_CTX_free(c->ctx); }
static tls_context *tls_context_arg(const arg *a,buffer *out) {
    native_slot *slot=lookup(num(a),NK_SSL_CONTEXT);
    if(!slot) error(out,"TypeError","invalid native SSL context"); return slot?slot->ptr:NULL;
}
static void free_tls_session(void *ptr) { SSL_SESSION_free(ptr); }
static void *copy_tls_session(const void *ptr) {
    /* Ruby/OpenSSL duplicates the serialized session. In particular it does
     * not copy libssl's transient not-resumable cache-removal marker. */
    unsigned char *der=NULL; int length=i2d_SSL_SESSION((SSL_SESSION *)ptr,&der);
    const unsigned char *cursor=der;
    SSL_SESSION *copy=length>0?d2i_SSL_SESSION(NULL,&cursor,length):NULL;
    OPENSSL_clear_free(der,length>0?(size_t)length:0); return copy;
}
static int own_tls_session(SSL_SESSION *session) {
    return own(session,NK_SSL_SESSION,"OpenSSL::SSL::Session",free_tls_session,copy_tls_session);
}
static SSL_SESSION *tls_session_arg(const arg *a,buffer *out) {
    native_slot *slot=lookup(num(a),NK_SSL_SESSION);
    if(!slot) error(out,"TypeError","invalid native SSL session"); return slot?slot->ptr:NULL;
}
static tls_socket *tls_socket_arg(const arg *a,buffer *out) {
    native_slot *slot=lookup(num(a),NK_SSL_SOCKET);
    if(!slot) { error(out,"TypeError","invalid native SSL socket"); return NULL; }
    tls_socket *socket=slot->ptr;
    if(socket->owner!=getpid()) { error(out,"OpenSSL::SSL::SSLError","SSL worker belongs to another process"); return NULL; }
    return socket;
}
