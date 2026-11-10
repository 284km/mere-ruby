static void tls_cipher_result(buffer *out,const SSL_CIPHER *cipher) {
    if(!cipher) { byte(out,'n'); return; }
    int algorithm_bits=0,bits=SSL_CIPHER_get_bits(cipher,&algorithm_bits);
    byte(out,'a'); number(out,4); text(out,SSL_CIPHER_get_name(cipher)); text(out,SSL_CIPHER_get_version(cipher)); integer(out,bits); integer(out,algorithm_bits);
}
static void tls_context_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::SSL::SSLError";
    if(!strcmp(op,"new")) {
        tls_context *context=calloc(1,sizeof(*context));
        if(!context) { error(out,"NoMemoryError","SSL context allocation failed"); return; }
        context->ctx=SSL_CTX_new(TLS_method());
        if(!context->ctx) { free(context); ssl_error(out,klass,"SSL_CTX_new"); return; }
        if(pthread_mutex_init(&context->event_lock,NULL)) { SSL_CTX_free(context->ctx); free(context); error(out,klass,"SSL context event mutex initialization"); return; }
        if(tls_context_index<0) tls_context_index=SSL_CTX_get_ex_new_index(0,NULL,NULL,NULL,tls_context_ex_free);
        if(tls_context_index<0||!SSL_CTX_set_ex_data(context->ctx,tls_context_index,context)) {
            SSL_CTX_free(context->ctx); pthread_mutex_destroy(&context->event_lock); free(context); ssl_error(out,klass,"SSL context callback initialization"); return;
        }
        SSL_CTX_set_mode(context->ctx,SSL_MODE_ENABLE_PARTIAL_WRITE|SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER|SSL_MODE_RELEASE_BUFFERS);
        SSL_CTX_set_dh_auto(context->ctx,1);
        SSL_CTX_set_tlsext_servername_callback(context->ctx,tls_servername_callback);
        SSL_CTX_set_alpn_select_cb(context->ctx,tls_alpn_callback,NULL);
        SSL_CTX_set_client_cert_cb(context->ctx,tls_client_certificate_callback);
        SSL_CTX_set_keylog_callback(context->ctx,tls_keylog_callback);
        SSL_CTX_sess_set_new_cb(context->ctx,tls_new_session_callback);
        SSL_CTX_sess_set_get_cb(context->ctx,tls_get_session_callback);
        SSL_CTX_sess_set_remove_cb(context->ctx,tls_remove_session_callback);
#ifndef OPENSSL_NO_NEXTPROTONEG
        SSL_CTX_set_next_protos_advertised_cb(context->ctx,tls_npn_advertise_callback,NULL);
        SSL_CTX_set_next_proto_select_cb(context->ctx,tls_npn_select_callback,NULL);
#endif
        object_result(out,own(context,NK_SSL_CONTEXT,"OpenSSL::SSL::SSLContext",free_tls_context,NULL)); return;
    }
    tls_context *context=tls_context_arg(at(args,0),out); if(!context) return;
    SSL_CTX *ctx=context->ctx; const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"options")) integer(out,(long long)SSL_CTX_get_options(ctx));
    else if(!strcmp(op,"set_options")) { SSL_CTX_clear_options(ctx,SSL_CTX_get_options(ctx)); SSL_CTX_set_options(ctx,(uint64_t)num(value)); }
    else if(!strcmp(op,"set_min_version")) ok=SSL_CTX_set_min_proto_version(ctx,(int)num(value));
    else if(!strcmp(op,"set_max_version")) ok=SSL_CTX_set_max_proto_version(ctx,(int)num(value));
    else if(!strcmp(op,"set_ciphers")) ok=SSL_CTX_set_cipher_list(ctx,str(value));
    else if(!strcmp(op,"set_ciphersuites")) ok=SSL_CTX_set_ciphersuites(ctx,str(value));
    else if(!strcmp(op,"set_sigalgs")) ok=SSL_CTX_set1_sigalgs_list(ctx,str(value));
    else if(!strcmp(op,"set_client_sigalgs")) ok=SSL_CTX_set1_client_sigalgs_list(ctx,str(value));
    else if(!strcmp(op,"set_groups")) ok=SSL_CTX_set1_groups_list(ctx,str(value));
    else if(!strcmp(op,"security_level")) integer(out,SSL_CTX_get_security_level(ctx));
    else if(!strcmp(op,"set_security_level")) SSL_CTX_set_security_level(ctx,(int)num(value));
    else if(!strcmp(op,"timeout")) integer(out,SSL_CTX_get_timeout(ctx));
    else if(!strcmp(op,"set_timeout")) SSL_CTX_set_timeout(ctx,(long)num(value));
    else if(!strcmp(op,"fallback_scsv")) SSL_CTX_set_mode(ctx,SSL_MODE_SEND_FALLBACK_SCSV);
    else if(!strcmp(op,"ciphers")) {
        STACK_OF(SSL_CIPHER) *ciphers=SSL_CTX_get_ciphers(ctx); int n=sk_SSL_CIPHER_num(ciphers); if(n<0) n=0;
        byte(out,'a'); number(out,n); for(int i=0;i<n;i++) tls_cipher_result(out,sk_SSL_CIPHER_value(ciphers,i));
    } else if(!strcmp(op,"callbacks")) {
        context->callbacks=(int)num(value);
        if(context->callbacks&TLS_TMP_DH) { SSL_CTX_set_dh_auto(ctx,0); tls_install_legacy_dh_callback(ctx); }
    }
    else if(!strcmp(op,"set_verify_mode")) SSL_CTX_set_verify(ctx,(int)num(value),tls_verify_callback);
    else if(!strcmp(op,"set_verify_depth")) SSL_CTX_set_verify_depth(ctx,(int)num(value));
    else if(!strcmp(op,"set_cert_store")) { X509_STORE *store=store_arg(value,out); if(!store) return; SSL_CTX_set1_cert_store(ctx,store); }
    else if(!strcmp(op,"set_ca_file")) ok=SSL_CTX_load_verify_locations(ctx,str(value),NULL);
    else if(!strcmp(op,"set_ca_path")) ok=SSL_CTX_load_verify_locations(ctx,NULL,str(value));
    else if(!strcmp(op,"set_cert")) { X509 *cert=xcert_arg(value,out); if(!cert) return; ok=SSL_CTX_use_certificate(ctx,cert); }
    else if(!strcmp(op,"set_key")) { EVP_PKEY *key=key_arg(value,out); if(!key) return; ok=SSL_CTX_use_PrivateKey(ctx,key); }
    else if(!strcmp(op,"check_key")) ok=SSL_CTX_check_private_key(ctx);
    else if(!strcmp(op,"add_certificate")) {
        X509 *cert=xcert_arg(value,out); if(!cert) return; EVP_PKEY *key=key_arg(at(args,2),out); if(!key) return;
        STACK_OF(X509) *chain=cert_chain_arg(at(args,3),out); if(!chain) return;
        ok=SSL_CTX_use_cert_and_key(ctx,cert,key,chain,1); sk_X509_pop_free(chain,X509_free);
    } else if(!strcmp(op,"add_chain_cert")) { X509 *cert=xcert_arg(value,out); if(!cert) return; ok=SSL_CTX_add1_chain_cert(ctx,cert); }
    else if(!strcmp(op,"set_client_ca")) {
        STACK_OF(X509_NAME) *names=sk_X509_NAME_new_null();
        if(!names) { ssl_error(out,klass,"CA names allocation"); return; }
        if(value->type!='a') { sk_X509_NAME_free(names); error(out,"TypeError","client CA names must be an Array"); return; }
        for(size_t i=0;i<value->len;i++) {
            X509_NAME *name=xname_arg(at(value,i),out); if(!name) { sk_X509_NAME_pop_free(names,X509_NAME_free); return; }
            X509_NAME *copy=X509_NAME_dup(name);
            if(!copy||!sk_X509_NAME_push(names,copy)) { X509_NAME_free(copy); sk_X509_NAME_pop_free(names,X509_NAME_free); ssl_error(out,klass,"CA names allocation"); return; }
        }
        SSL_CTX_set_client_CA_list(ctx,names);
    } else if(!strcmp(op,"set_alpn_protocols")) ok=SSL_CTX_set_alpn_protos(ctx,(unsigned char *)str(value),(unsigned int)value->len)==0;
    else if(!strcmp(op,"set_npn_protocols")) {
        unsigned char *data=OPENSSL_memdup(str(value),value->len?value->len:1);
        if(!data) { error(out,"NoMemoryError","NPN protocols allocation failed"); return; }
        OPENSSL_free(context->npn_data); context->npn_data=data; context->npn_length=value->len;
    }
    else if(!strcmp(op,"set_session_id_context")) ok=SSL_CTX_set_session_id_context(ctx,(unsigned char *)str(value),(unsigned int)value->len);
    else if(!strcmp(op,"session_cache_mode")) integer(out,SSL_CTX_get_session_cache_mode(ctx));
    else if(!strcmp(op,"set_session_cache_mode")) SSL_CTX_set_session_cache_mode(ctx,(long)num(value));
    else if(!strcmp(op,"session_cache_size")) integer(out,SSL_CTX_sess_get_cache_size(ctx));
    else if(!strcmp(op,"removed_sessions")) {
        pthread_mutex_lock(&context->event_lock);
        removed_session *entries=context->removed_head; int n=context->event_count,failed=context->event_failed;
        context->removed_head=context->removed_tail=NULL; context->event_count=context->event_failed=0;
        pthread_mutex_unlock(&context->event_lock);
        if(failed) error(out,"OpenSSL::SSL::SSLError","session removal event budget exceeded");
        else { byte(out,'a'); number(out,n); }
        while(entries) {
            removed_session *next=entries->next;
            if(failed) SSL_SESSION_free(entries->session); else object_result(out,own_tls_session(entries->session));
            free(entries); entries=next;
        }
    }
    else if(!strcmp(op,"set_session_cache_size")) SSL_CTX_sess_set_cache_size(ctx,(long)num(value));
    else if(!strcmp(op,"session_add")||!strcmp(op,"session_remove")) {
        SSL_SESSION *session=tls_session_arg(value,out); if(!session) return;
        boolean(out,!strcmp(op,"session_add")?SSL_CTX_add_session(ctx,session):SSL_CTX_remove_session(ctx,session));
    } else if(!strcmp(op,"flush_sessions")) {
#if OPENSSL_VERSION_NUMBER >= 0x30400000L
        SSL_CTX_flush_sessions_ex(ctx,(time_t)num(value));
#else
        SSL_CTX_flush_sessions(ctx,(long)num(value));
#endif
    }
    else if(!strcmp(op,"session_cache_stats")) {
        byte(out,'m'); number(out,12);
#define TLS_STAT(name,fn) text(out,name); integer(out,fn(ctx))
        TLS_STAT("cache_num",SSL_CTX_sess_number); TLS_STAT("connect",SSL_CTX_sess_connect); TLS_STAT("connect_good",SSL_CTX_sess_connect_good);
        TLS_STAT("connect_renegotiate",SSL_CTX_sess_connect_renegotiate); TLS_STAT("accept",SSL_CTX_sess_accept); TLS_STAT("accept_good",SSL_CTX_sess_accept_good);
        TLS_STAT("accept_renegotiate",SSL_CTX_sess_accept_renegotiate); TLS_STAT("cache_hits",SSL_CTX_sess_hits); TLS_STAT("cb_hits",SSL_CTX_sess_cb_hits);
        TLS_STAT("cache_misses",SSL_CTX_sess_misses); TLS_STAT("cache_full",SSL_CTX_sess_cache_full);
        TLS_STAT("timeouts",SSL_CTX_sess_timeouts);
#undef TLS_STAT
    } else if(!strcmp(op,"set_tmp_dh")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return;
        SSL_CTX_set_dh_auto(ctx,0);
        if(!EVP_PKEY_up_ref(key)) ok=0;
        else { ok=SSL_CTX_set0_tmp_dh_pkey(ctx,key); if(!ok) EVP_PKEY_free(key); }
    } else { error(out,"NotImplementedError","unknown SSL context operation"); return; }
    if(!ok) {
        if(!strcmp(op,"set_ciphers")||!strcmp(op,"set_ciphersuites")) {
            const char *reason=ERR_reason_error_string(ERR_peek_last_error()); char message[512];
            snprintf(message,sizeof(message),"%s: %s",!strcmp(op,"set_ciphers")?"SSL_CTX_set_cipher_list":"SSL_CTX_set_ciphersuites",reason?reason:"no cipher match");
            error(out,klass,message);
        } else ssl_error(out,klass,op);
    } else if(!out->len) byte(out,'n');
}
