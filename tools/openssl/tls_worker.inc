static void *tls_worker(void *ptr) {
    tls_socket *socket=ptr;
    ERR_clear_error(); errno=0;
    int rc=0; size_t n=0;
    switch(socket->operation) {
    case 1: rc=SSL_connect(socket->ssl); break;
    case 2: rc=SSL_accept(socket->ssl); break;
    case 3: rc=SSL_read_ex(socket->ssl,socket->output,socket->output_capacity,&n); break;
    case 4: rc=SSL_write_ex(socket->ssl,socket->input,socket->input_length,&n); break;
    case 5: rc=SSL_shutdown(socket->ssl); break;
    }
    int sslerr=rc>0?SSL_ERROR_NONE:SSL_get_error(socket->ssl,rc);
    if(socket->operation==5&&rc==0) sslerr=SSL_ERROR_NONE;
    buffer failure={0};
    if(sslerr!=SSL_ERROR_NONE&&sslerr!=SSL_ERROR_WANT_READ&&sslerr!=SSL_ERROR_WANT_WRITE&&sslerr!=SSL_ERROR_ZERO_RETURN) {
        char message[256];
        long result=SSL_get_verify_result(socket->ssl);
        if(result!=X509_V_OK) snprintf(message,sizeof(message),"SSL operation: certificate verify failed (%s)",X509_verify_cert_error_string(result));
        else snprintf(message,sizeof(message),"SSL operation failed (SSL_error=%d, errno=%d)",sslerr,errno);
        ssl_error(&failure,"OpenSSL::SSL::SSLError",message);
    }
    pthread_mutex_lock(&socket->lock);
    socket->rc=rc; socket->ssl_error=sslerr; socket->output_length=n; socket->failure=failure; socket->done=1;
    pthread_cond_broadcast(&socket->changed); pthread_mutex_unlock(&socket->lock);
    return NULL;
}
static void tls_join(tls_socket *socket,int cancel) {
    if(!socket->started) return;
    if(cancel) {
        pthread_mutex_lock(&socket->lock); socket->cancelled=1; socket->waiting=0;
        pthread_cond_broadcast(&socket->changed); pthread_mutex_unlock(&socket->lock);
    }
    pthread_join(socket->thread,NULL); socket->started=0;
}
static void free_tls_socket(void *ptr) {
    tls_socket *socket=ptr;
    if(socket->owner!=getpid()) { free(socket); return; }
    tls_join(socket,1);
    if(socket->verify_handle) release(socket->verify_handle);
    SSL_free(socket->ssl); SSL_CTX_free(socket->selected_context);
    tls_free_legacy_dh(socket->legacy_dh); OPENSSL_free(socket->npn_data);
    EVP_PKEY_free(socket->selected_key); X509_free(socket->selected_certificate); SSL_SESSION_free(socket->selected_session);
    OPENSSL_clear_free(socket->input,socket->input_length); OPENSSL_clear_free(socket->output,socket->output_capacity);
    OPENSSL_clear_free(socket->event_data,socket->event_length); OPENSSL_free(socket->selected); free(socket->failure.p);
    pthread_cond_destroy(&socket->changed); pthread_mutex_destroy(&socket->lock); free(socket);
}
static void free_borrowed_verify_context(void *ptr) {
    verify_context *context=ptr;
    pthread_cond_destroy(&context->changed); pthread_mutex_destroy(&context->lock); free(context);
}
static void tls_event_result(tls_socket *socket,buffer *out) {
    byte(out,'a'); number(out,3); text(out,"callback"); integer(out,socket->event);
    if(socket->event==TLS_VERIFY) {
        verify_context *context=calloc(1,sizeof(*context));
        if(!context) { error(out,"NoMemoryError","TLS verify callback allocation failed"); return; }
        context->owner=getpid(); context->ctx=socket->verify;
        if(pthread_mutex_init(&context->lock,NULL)) { free(context); error(out,"OpenSSL::SSL::SSLError","TLS callback mutex initialization"); return; }
        if(pthread_cond_init(&context->changed,NULL)) { pthread_mutex_destroy(&context->lock); free(context); error(out,"OpenSSL::SSL::SSLError","TLS callback condition initialization"); return; }
        socket->verify_handle=own(context,NK_STORE_CONTEXT,"OpenSSL::X509::StoreContext",free_borrowed_verify_context,NULL);
        byte(out,'a'); number(out,2); boolean(out,socket->event_length&&socket->event_data[0]); object_result(out,socket->verify_handle);
    } else if(socket->event==TLS_SESSION_NEW) {
        if(socket->event_session&&SSL_SESSION_up_ref(socket->event_session)) object_result(out,own_tls_session(socket->event_session));
        else ssl_error(out,"OpenSSL::SSL::SSLError","SSL_SESSION_up_ref");
    } else if(socket->event==TLS_TMP_DH) {
        byte(out,'a'); number(out,2); boolean(out,socket->event_arg0); integer(out,socket->event_arg1);
    } else string(out,socket->event_data,socket->event_length);
}
static void tls_job_call(const char *op,const arg *args,buffer *out) {
    tls_socket *socket=tls_socket_arg(at(args,0),out); if(!socket) return;
    const char *klass="OpenSSL::SSL::SSLError";
    if(!strcmp(op,"start")) {
        if(socket->started) { error(out,klass,"SSL operation already running"); return; }
        socket->operation=(int)num(at(args,1));
        if(socket->operation<1||socket->operation>5) { error(out,"ArgumentError","invalid SSL operation"); return; }
        OPENSSL_clear_free(socket->input,socket->input_length); socket->input=NULL; socket->input_length=0;
        OPENSSL_clear_free(socket->output,socket->output_capacity); socket->output=NULL; socket->output_capacity=0;
        free(socket->failure.p); memset(&socket->failure,0,sizeof(socket->failure));
        if(socket->operation==3) {
            long long n=num(at(args,2));
            if(n<0||n>WIRE_LIMIT-128) { error(out,"ArgumentError","invalid SSL read size"); return; }
            socket->output_capacity=(size_t)n; socket->output=OPENSSL_malloc(n?n:1);
            if(!socket->output) { error(out,"NoMemoryError","SSL read allocation failed"); return; }
        } else if(socket->operation==4) {
            const arg *data=at(args,2);
            if(data->type!='s') { error(out,"TypeError","SSL write data must be a String"); return; }
            socket->input=OPENSSL_memdup(data->s,data->len?data->len:1); socket->input_length=data->len;
            if(!socket->input) { error(out,"NoMemoryError","SSL write allocation failed"); return; }
        }
        socket->done=socket->cancelled=socket->waiting=socket->notified=socket->event=0;
        if(pthread_create(&socket->thread,NULL,tls_worker,socket)) { error(out,klass,"cannot start SSL worker"); return; }
        socket->started=1; byte(out,'n'); return;
    }
    if(!strcmp(op,"stop")) {
        tls_join(socket,1);
        if(socket->verify_handle) { release(socket->verify_handle); socket->verify_handle=0; }
        byte(out,'n'); return;
    }
    pthread_mutex_lock(&socket->lock);
    if(!strcmp(op,"poll")) {
        if(socket->waiting&&!socket->notified) { socket->notified=1; tls_event_result(socket,out); }
        else if(socket->done) {
            if(socket->failure.len) put(out,socket->failure.p,socket->failure.len);
            else {
                byte(out,'a'); number(out,3); text(out,"done");
                if(socket->ssl_error==SSL_ERROR_WANT_READ) { text(out,"wait_readable"); byte(out,'n'); }
                else if(socket->ssl_error==SSL_ERROR_WANT_WRITE) { text(out,"wait_writable"); byte(out,'n'); }
                else if(socket->ssl_error==SSL_ERROR_ZERO_RETURN) { text(out,"eof"); byte(out,'n'); }
                else { text(out,"ok"); if(socket->operation==3) string(out,socket->output,socket->output_length); else integer(out,(long long)socket->output_length); }
            }
        } else { byte(out,'a'); number(out,1); text(out,"pending"); }
    } else if(!strcmp(op,"respond")) {
        if(!socket->waiting||!socket->notified) { error(out,klass,"no pending SSL callback"); goto unlock; }
        const arg *value=at(args,1); int accepted=truth(value);
        if(socket->event==TLS_VERIFY) {
            if(socket->verify_handle) { release(socket->verify_handle); socket->verify_handle=0; }
        } else if(socket->event==TLS_SNI&&value->type!='n'&&value->type!='f') {
            tls_context *context=tls_context_arg(value,out); if(!context) goto unlock;
            if(!SSL_CTX_up_ref(context->ctx)) { ssl_error(out,klass,"SSL_CTX_up_ref"); goto unlock; }
            SSL_CTX_free(socket->selected_context); socket->selected_context=context->ctx; socket->callbacks=context->callbacks;
        } else if(socket->event==TLS_SNI&&value->type=='n') accepted=1;
        else if(socket->event==TLS_ALPN||socket->event==TLS_NPN) {
            if(value->type=='s'&&value->len>0&&value->len<=255) {
                OPENSSL_free(socket->selected); socket->selected=OPENSSL_memdup(value->s,value->len); socket->selected_length=value->len;
                if(!socket->selected) { error(out,"NoMemoryError","ALPN allocation failed"); goto unlock; }
            } else if(value->type=='n') { OPENSSL_free(socket->selected); socket->selected=NULL; socket->selected_length=0; accepted=1; }
            else accepted=0;
        } else if(socket->event==TLS_TMP_DH) {
            EVP_PKEY *key=key_arg(value,out); if(!key) goto unlock;
            DH *dh=tls_extract_legacy_dh(key);
            if(!dh) { ssl_error(out,klass,"temporary DH parameters"); goto unlock; }
            tls_free_legacy_dh(socket->legacy_dh); socket->legacy_dh=dh;
        } else if(socket->event==TLS_CLIENT_CERT&&value->type=='a'&&value->len==2) {
            X509 *cert=xcert_arg(at(value,0),out); if(!cert) goto unlock;
            EVP_PKEY *key=key_arg(at(value,1),out); if(!key) goto unlock;
            if(!X509_up_ref(cert)) { ssl_error(out,klass,"X509_up_ref"); goto unlock; }
            if(!EVP_PKEY_up_ref(key)) { X509_free(cert); ssl_error(out,klass,"EVP_PKEY_up_ref"); goto unlock; }
            X509_free(socket->selected_certificate); EVP_PKEY_free(socket->selected_key);
            socket->selected_certificate=cert; socket->selected_key=key;
        } else if(socket->event==TLS_SESSION_GET&&value->type=='i') {
            SSL_SESSION *session=tls_session_arg(value,out); if(!session) goto unlock;
            if(!SSL_SESSION_up_ref(session)) { ssl_error(out,klass,"SSL_SESSION_up_ref"); goto unlock; }
            SSL_SESSION_free(socket->selected_session); socket->selected_session=session;
        }
        socket->accepted=accepted; socket->waiting=0; pthread_cond_signal(&socket->changed); byte(out,'n');
    } else error(out,"NotImplementedError","unknown SSL operation job");
unlock:
    pthread_mutex_unlock(&socket->lock);
}
