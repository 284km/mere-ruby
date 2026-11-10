static int tls_rendezvous(tls_socket *socket,int event,const unsigned char *data,size_t length) {
    pthread_mutex_lock(&socket->lock);
    if(socket->cancelled) { pthread_mutex_unlock(&socket->lock); return 0; }
    OPENSSL_clear_free(socket->event_data,socket->event_length); socket->event_data=NULL; socket->event_length=length;
    if(length) {
        socket->event_data=OPENSSL_memdup(data,length);
        if(!socket->event_data) { pthread_mutex_unlock(&socket->lock); return 0; }
    }
    socket->event=event; socket->waiting=1; socket->notified=0; socket->accepted=0;
    pthread_cond_broadcast(&socket->changed);
    while(socket->waiting&&!socket->cancelled) pthread_cond_wait(&socket->changed,&socket->lock);
    int accepted=!socket->cancelled&&socket->accepted;
    pthread_mutex_unlock(&socket->lock); return accepted;
}
static int tls_verify_callback(int ok,X509_STORE_CTX *ctx) {
    SSL *ssl=X509_STORE_CTX_get_ex_data(ctx,SSL_get_ex_data_X509_STORE_CTX_idx());
    tls_socket *socket=ssl?SSL_get_app_data(ssl):NULL;
    if(!socket||!(socket->callbacks&TLS_VERIFY)) return ok;
    socket->verify=ctx;
    unsigned char value=ok?1:0;
    int result=tls_rendezvous(socket,TLS_VERIFY,&value,1);
    socket->verify=NULL;
    if(!result&&X509_STORE_CTX_get_error(ctx)==X509_V_OK) X509_STORE_CTX_set_error(ctx,X509_V_ERR_CERT_REJECTED);
    return result;
}
static int tls_servername_callback(SSL *ssl,int *alert,void *unused) {
    (void)unused;
    tls_socket *socket=SSL_get_app_data(ssl);
    if(!socket||!(socket->callbacks&TLS_SNI)) return SSL_TLSEXT_ERR_OK;
    const char *name=SSL_get_servername(ssl,TLSEXT_NAMETYPE_host_name);
    if(!name) return SSL_TLSEXT_ERR_OK;
    if(!tls_rendezvous(socket,TLS_SNI,(unsigned char *)name,strlen(name))) { *alert=SSL_AD_UNRECOGNIZED_NAME; return SSL_TLSEXT_ERR_ALERT_FATAL; }
    if(socket->selected_context) {
        SSL_CTX *ctx=socket->selected_context; socket->selected_context=NULL;
        int ok=SSL_set_SSL_CTX(ssl,ctx)!=NULL; SSL_CTX_free(ctx);
        if(!ok) { *alert=SSL_AD_INTERNAL_ERROR; return SSL_TLSEXT_ERR_ALERT_FATAL; }
    }
    return SSL_TLSEXT_ERR_OK;
}
static int tls_alpn_callback(SSL *ssl,const unsigned char **out,unsigned char *outlen,const unsigned char *in,unsigned int inlen,void *unused) {
    (void)unused;
    tls_socket *socket=SSL_get_app_data(ssl);
    if(!socket||!(socket->callbacks&TLS_ALPN)) return SSL_TLSEXT_ERR_NOACK;
    if(!tls_rendezvous(socket,TLS_ALPN,in,inlen)) return SSL_TLSEXT_ERR_ALERT_FATAL;
    if(!socket->selected) return SSL_TLSEXT_ERR_NOACK;
    *out=socket->selected; *outlen=(unsigned char)socket->selected_length;
    return SSL_TLSEXT_ERR_OK;
}
static int tls_client_certificate_callback(SSL *ssl,X509 **cert,EVP_PKEY **key) {
    tls_socket *socket=SSL_get_app_data(ssl);
    if(!socket||!(socket->callbacks&TLS_CLIENT_CERT)) return 0;
    if(!tls_rendezvous(socket,TLS_CLIENT_CERT,NULL,0)) return 0;
    *cert=socket->selected_certificate; socket->selected_certificate=NULL;
    *key=socket->selected_key; socket->selected_key=NULL;
    return *cert&&*key;
}
static void tls_keylog_callback(const SSL *ssl,const char *line) {
    tls_socket *socket=SSL_get_app_data(ssl);
    if(socket&&(socket->callbacks&TLS_KEYLOG)) tls_rendezvous(socket,TLS_KEYLOG,(unsigned char *)line,strlen(line));
}
static int tls_new_session_callback(SSL *ssl,SSL_SESSION *session) {
    tls_socket *socket=SSL_get_app_data(ssl);
    if(socket&&(socket->callbacks&TLS_SESSION_NEW)) {
        socket->event_session=session;
        tls_rendezvous(socket,TLS_SESSION_NEW,NULL,0);
        socket->event_session=NULL;
    }
    return 0;
}
static void tls_remove_session_callback(SSL_CTX *ctx,SSL_SESSION *session) {
    tls_context *context=SSL_CTX_get_ex_data(ctx,tls_context_index);
    if(!context||!(context->callbacks&TLS_SESSION_REMOVE)) return;
    pthread_mutex_lock(&context->event_lock);
    removed_session *entry=context->event_count<4096?malloc(sizeof(*entry)):NULL;
    if(!entry||!SSL_SESSION_up_ref(session)) { free(entry); context->event_failed=1; }
    else {
        entry->session=session; entry->next=NULL;
        if(context->removed_tail) context->removed_tail->next=entry; else context->removed_head=entry;
        context->removed_tail=entry; context->event_count++;
    }
    pthread_mutex_unlock(&context->event_lock);
}
static SSL_SESSION *tls_get_session_callback(SSL *ssl,const unsigned char *id,int length,int *copy) {
    tls_socket *socket=SSL_get_app_data(ssl);
    if(!socket||!(socket->callbacks&TLS_SESSION_GET)) return NULL;
    if(!tls_rendezvous(socket,TLS_SESSION_GET,id,(size_t)length)) return NULL;
    SSL_SESSION *session=socket->selected_session; socket->selected_session=NULL; *copy=0;
    return session;
}
static void tls_info_callback(const SSL *ssl,int where,int value) {
    (void)value;
    tls_socket *socket=SSL_get_app_data(ssl);
    if(socket&&(socket->callbacks&TLS_RENEGOTIATE)&&(where&SSL_CB_HANDSHAKE_START)) tls_rendezvous(socket,TLS_RENEGOTIATE,NULL,0);
}
#ifndef OPENSSL_NO_NEXTPROTONEG
static int tls_npn_advertise_callback(SSL *ssl,const unsigned char **out,unsigned int *length,void *unused) {
    (void)unused; tls_socket *socket=SSL_get_app_data(ssl);
    if(!socket||!socket->npn_length) return SSL_TLSEXT_ERR_NOACK;
    *out=socket->npn_data; *length=(unsigned int)socket->npn_length; return SSL_TLSEXT_ERR_OK;
}
static int tls_npn_select_callback(SSL *ssl,unsigned char **out,unsigned char *length,const unsigned char *in,unsigned int inlen,void *unused) {
    (void)unused; tls_socket *socket=SSL_get_app_data(ssl);
    if(!socket||!(socket->callbacks&TLS_NPN)) return SSL_TLSEXT_ERR_NOACK;
    if(!tls_rendezvous(socket,TLS_NPN,in,inlen)||!socket->selected) return SSL_TLSEXT_ERR_ALERT_FATAL;
    *out=socket->selected; *length=(unsigned char)socket->selected_length; return SSL_TLSEXT_ERR_OK;
}
#endif
/* Ruby's legacy tmp_dh_callback returns DH parameters. Keep the deprecated
 * compatibility boundary local; key generation and exchange still use EVP. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static DH *tls_extract_legacy_dh(EVP_PKEY *key) { return EVP_PKEY_get1_DH(key); }
static void tls_free_legacy_dh(DH *dh) { DH_free(dh); }
static DH *tls_tmp_dh_callback(SSL *ssl,int is_export,int length) {
    tls_socket *socket=SSL_get_app_data(ssl);
    if(!socket||!(socket->callbacks&TLS_TMP_DH)) return NULL;
    socket->event_arg0=is_export; socket->event_arg1=length;
    return tls_rendezvous(socket,TLS_TMP_DH,NULL,0)?socket->legacy_dh:NULL;
}
static void tls_install_legacy_dh_callback(SSL_CTX *ctx) { SSL_CTX_set_tmp_dh_callback(ctx,tls_tmp_dh_callback); }
#pragma clang diagnostic pop
