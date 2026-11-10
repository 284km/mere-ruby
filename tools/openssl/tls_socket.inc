static void tls_socket_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::SSL::SSLError";
    if(!strcmp(op,"new")) {
        tls_context *context=tls_context_arg(at(args,0),out); if(!context) return;
        int fd=(int)num(at(args,1)),flags=fcntl(fd,F_GETFL,0);
        if(flags<0||fcntl(fd,F_SETFL,flags|O_NONBLOCK)<0) { error(out,"IOError","closed stream"); return; }
        tls_socket *socket=calloc(1,sizeof(*socket));
        if(!socket) { error(out,"NoMemoryError","SSL socket allocation failed"); return; }
        if(pthread_mutex_init(&socket->lock,NULL)) { free(socket); error(out,klass,"SSL socket mutex initialization"); return; }
        if(pthread_cond_init(&socket->changed,NULL)) { pthread_mutex_destroy(&socket->lock); free(socket); error(out,klass,"SSL socket condition initialization"); return; }
        socket->owner=getpid(); socket->callbacks=context->callbacks; socket->ssl=SSL_new(context->ctx);
        if(context->npn_length) {
            socket->npn_data=OPENSSL_memdup(context->npn_data,context->npn_length); socket->npn_length=context->npn_length;
            if(!socket->npn_data) { free_tls_socket(socket); error(out,"NoMemoryError","NPN protocols allocation failed"); return; }
        }
        if(!socket->ssl||!SSL_set_fd(socket->ssl,fd)) { free_tls_socket(socket); ssl_error(out,klass,"SSL_new/SSL_set_fd"); return; }
        SSL_set_app_data(socket->ssl,socket); SSL_set_info_callback(socket->ssl,tls_info_callback);
        object_result(out,own(socket,NK_SSL_SOCKET,"OpenSSL::SSL::SSLSocket",free_tls_socket,NULL)); return;
    }
    tls_socket *socket=tls_socket_arg(at(args,0),out); if(!socket) return;
    pthread_mutex_lock(&socket->lock);
    if(socket->started&&!socket->done&&!socket->waiting) { error(out,klass,"SSL operation is running"); goto done; }
    SSL *ssl=socket->ssl; const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"cert")||!strcmp(op,"peer_cert")) {
        X509 *cert=!strcmp(op,"cert")?SSL_get_certificate(ssl):SSL_get0_peer_certificate(ssl);
        if(cert&&X509_up_ref(cert)) object_result(out,xcert_own(cert)); else byte(out,'n');
    } else if(!strcmp(op,"peer_cert_chain")) cert_chain_result(out,SSL_get_peer_cert_chain(ssl));
    else if(!strcmp(op,"cipher")) tls_cipher_result(out,SSL_get_current_cipher(ssl));
    else if(!strcmp(op,"ssl_version")) { if(SSL_is_init_finished(ssl)) text(out,SSL_get_version(ssl)); else byte(out,'n'); }
    else if(!strcmp(op,"state")) text(out,SSL_state_string(ssl));
    else if(!strcmp(op,"pending")) integer(out,SSL_pending(ssl));
    else if(!strcmp(op,"session_reused")) boolean(out,SSL_session_reused(ssl));
    else if(!strcmp(op,"verify_result")) integer(out,SSL_get_verify_result(ssl));
    else if(!strcmp(op,"session")) {
        SSL_SESSION *session=SSL_get1_session(ssl);
        if(session) object_result(out,own_tls_session(session)); else error(out,"OpenSSL::SSL::Session::SessionError","no session available");
    } else if(!strcmp(op,"set_session")) { SSL_SESSION *session=tls_session_arg(value,out); if(!session) goto done; ok=SSL_set_session(ssl,session); }
    else if(!strcmp(op,"client_ca")) {
        STACK_OF(X509_NAME) *names=SSL_get_client_CA_list(ssl); int n=sk_X509_NAME_num(names); if(n<0) n=0;
        byte(out,'a'); number(out,n); for(int i=0;i<n;i++) object_result(out,xname_own(X509_NAME_dup(sk_X509_NAME_value(names,i))));
    } else if(!strcmp(op,"set_hostname")) {
        if(value->type!='s'||memchr(value->s,0,value->len)) { error(out,"ArgumentError","invalid hostname"); goto done; }
        ok=SSL_set_tlsext_host_name(ssl,str(value));
        if(ok&&truth(at(args,2))) ok=SSL_set1_host(ssl,str(value));
    } else if(!strcmp(op,"finished_message")||!strcmp(op,"peer_finished_message")) {
        size_t length=!strcmp(op,"finished_message")?SSL_get_finished(ssl,NULL,0):SSL_get_peer_finished(ssl,NULL,0);
        if(!length) byte(out,'n'); else {
            unsigned char *data=OPENSSL_malloc(length);
            if(!data) { error(out,"NoMemoryError","finished message allocation failed"); goto done; }
            if(!strcmp(op,"finished_message")) SSL_get_finished(ssl,data,length); else SSL_get_peer_finished(ssl,data,length);
            string(out,data,length); OPENSSL_clear_free(data,length);
        }
    } else if(!strcmp(op,"tmp_key")) {
        EVP_PKEY *key=NULL;
        if(!SSL_get_peer_tmp_key(ssl,&key)) SSL_get_tmp_key(ssl,&key);
        if(key) object_result(out,own_key(key)); else byte(out,'n');
    } else if(!strcmp(op,"alpn_protocol")) {
        const unsigned char *data=NULL; unsigned int length=0; SSL_get0_alpn_selected(ssl,&data,&length);
        if(length) string(out,data,length); else byte(out,'n');
    }
#ifndef OPENSSL_NO_NEXTPROTONEG
    else if(!strcmp(op,"npn_protocol")) {
        const unsigned char *data=NULL; unsigned int length=0; SSL_get0_next_proto_negotiated(ssl,&data,&length);
        if(length) string(out,data,length); else byte(out,'n');
    }
#endif
    else if(!strcmp(op,"export_keying_material")) {
        long long n=num(at(args,2)); const arg *context=at(args,3);
        if(n<0||n>WIRE_LIMIT-128) { error(out,"ArgumentError","invalid keying material length"); goto done; }
        unsigned char *data=OPENSSL_malloc(n?n:1);
        if(!data) { error(out,"NoMemoryError","keying material allocation failed"); goto done; }
        ok=SSL_export_keying_material(ssl,data,(size_t)n,str(value),value->len,(unsigned char *)str(context),context->len,context->type!='n');
        if(ok) string(out,data,(size_t)n); OPENSSL_clear_free(data,(size_t)n);
#ifdef SSL_get0_signature_name
    } else if(!strcmp(op,"sigalg")||!strcmp(op,"peer_sigalg")) {
        const char *name=NULL; int found=!strcmp(op,"sigalg")?SSL_get0_signature_name(ssl,&name):SSL_get0_peer_signature_name(ssl,&name);
        if(found&&name) text(out,name); else byte(out,'n');
#endif
#if OPENSSL_VERSION_NUMBER >= 0x30200000L
    } else if(!strcmp(op,"group")) { const char *name=SSL_get0_group_name(ssl); if(name) text(out,name); else byte(out,'n');
#endif
    } else { error(out,"NotImplementedError","unknown SSL socket operation"); goto done; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
done:
    pthread_mutex_unlock(&socket->lock);
}
static void tls_session_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::SSL::Session::SessionError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); BIO *bio=BIO_new_mem_buf(str(data),(int)data->len); SSL_SESSION *session=NULL;
        if(bio) session=d2i_SSL_SESSION_bio(bio,NULL);
        if(!session&&bio) { ERR_clear_error(); BIO_reset(bio); session=PEM_read_bio_SSL_SESSION(bio,NULL,NULL,NULL); }
        BIO_free(bio);
        if(session) { ERR_clear_error(); object_result(out,own_tls_session(session)); } else ssl_error(out,"ArgumentError","unknown type"); return;
    }
    SSL_SESSION *session=tls_session_arg(at(args,0),out); if(!session) return;
    const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"time")) {
#if OPENSSL_VERSION_NUMBER >= 0x30400000L
        integer(out,SSL_SESSION_get_time_ex(session));
#else
        integer(out,SSL_SESSION_get_time(session));
#endif
    }
    else if(!strcmp(op,"timeout")) integer(out,SSL_SESSION_get_timeout(session));
    else if(!strcmp(op,"set_time")) {
#if OPENSSL_VERSION_NUMBER >= 0x30400000L
        SSL_SESSION_set_time_ex(session,(time_t)num(value));
#else
        SSL_SESSION_set_time(session,(long)num(value));
#endif
    }
    else if(!strcmp(op,"set_timeout")) SSL_SESSION_set_timeout(session,(long)num(value));
    else if(!strcmp(op,"id")) { unsigned int n=0; const unsigned char *id=SSL_SESSION_get_id(session,&n); string(out,id,n); }
    else if(!strcmp(op,"equal")) {
        SSL_SESSION *other=tls_session_arg(value,out); if(!other) return;
        unsigned int n=0,m=0; const unsigned char *a=SSL_SESSION_get_id(session,&n),*b=SSL_SESSION_get_id(other,&m);
        boolean(out,SSL_SESSION_get_protocol_version(session)==SSL_SESSION_get_protocol_version(other)&&n==m&&!CRYPTO_memcmp(a,b,n));
    } else if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_SSL_SESSION(session,&der); der_result(out,der,n,klass); }
    else if(!strcmp(op,"to_pem")||!strcmp(op,"to_text")) {
        BIO *bio=BIO_new(BIO_s_mem()); ok=bio&&(!strcmp(op,"to_pem")?PEM_write_bio_SSL_SESSION(bio,session):SSL_SESSION_print(bio,session));
        if(ok) bio_result(out,bio);
        if(bio) { char *p; long n=BIO_get_mem_data(bio,&p); if(n>0) OPENSSL_cleanse(p,(size_t)n); } BIO_free(bio);
    } else { error(out,"NotImplementedError","unknown SSL session operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
