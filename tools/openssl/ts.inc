/* RFC 3161 request, response, token and verification use native TS objects. */
#define TS_OBJECT(prefix,ctype,kind,klass) \
static void prefix##_free(void *p) { ctype##_free(p); } \
static void *prefix##_copy(const void *p) { return ctype##_dup(p); } \
static int prefix##_own(ctype *p) { return own(p,kind,klass,prefix##_free,prefix##_copy); } \
static ctype *prefix##_arg(const arg *a,buffer *out) { native_slot *s=lookup(num(a),kind); if(!s) error(out,"TypeError","invalid native " klass); return s?s->ptr:NULL; } \
static void prefix##_decode(const arg *a,buffer *out) { const unsigned char *cursor=(const unsigned char *)str(a); \
    ctype *p=a->type=='s'?d2i_##ctype(NULL,&cursor,(long)a->len):NULL; \
    if(p) object_result(out,prefix##_own(p)); else ssl_error(out,"OpenSSL::Timestamp::TimestampError","timestamp decode"); } \
static void prefix##_der(buffer *out,ctype *p) { unsigned char *der=NULL; int n=i2d_##ctype(p,&der); der_result(out,der,n,"OpenSSL::Timestamp::TimestampError"); }
TS_OBJECT(treq,TS_REQ,NK_TS_REQUEST,"OpenSSL::Timestamp::Request")
TS_OBJECT(tres,TS_RESP,NK_TS_RESPONSE,"OpenSSL::Timestamp::Response")
TS_OBJECT(tinfo,TS_TST_INFO,NK_TS_INFO,"OpenSSL::Timestamp::TokenInfo")
#undef TS_OBJECT
static int ts_request_complete(TS_REQ *req,buffer *out) {
    TS_MSG_IMPRINT *imprint=TS_REQ_get_msg_imprint(req); const ASN1_OBJECT *obj=NULL;
    X509_ALGOR *algorithm=imprint?TS_MSG_IMPRINT_get_algo(imprint):NULL;
    if(algorithm) X509_ALGOR_get0(&obj,NULL,NULL,algorithm);
    if(!obj||OBJ_obj2nid(obj)==NID_undef) { error(out,"OpenSSL::Timestamp::TimestampError","Message imprint missing algorithm"); return 0; }
    if(!ASN1_STRING_length(TS_MSG_IMPRINT_get_msg(imprint))) { error(out,"OpenSSL::Timestamp::TimestampError","Message imprint missing hashed message"); return 0; }
    return 1;
}
static void ts_imprint_result(buffer *out,TS_MSG_IMPRINT *imprint,int algorithm) {
    if(!imprint) { byte(out,'n'); return; }
    if(algorithm) {
        const ASN1_OBJECT *obj=NULL; X509_ALGOR_get0(&obj,NULL,NULL,TS_MSG_IMPRINT_get_algo(imprint));
        if(obj) oid_result(out,obj); else byte(out,'n');
    } else {
        ASN1_OCTET_STRING *message=TS_MSG_IMPRINT_get_msg(imprint);
        if(message) string(out,ASN1_STRING_get0_data(message),(size_t)ASN1_STRING_length(message)); else byte(out,'n');
    }
}
static void ts_req_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::Timestamp::TimestampError";
    if(!strcmp(op,"new")) {
        if(at(args,0)->type=='n') {
            TS_REQ *req=TS_REQ_new(); if(req&&TS_REQ_set_version(req,1)&&TS_REQ_set_cert_req(req,1)) object_result(out,treq_own(req));
            else { TS_REQ_free(req); ssl_error(out,klass,"TS_REQ_new"); }
        } else treq_decode(at(args,0),out);
        return;
    }
    TS_REQ *req=treq_arg(at(args,0),out); if(!req) return;
    const arg *value=at(args,1); TS_MSG_IMPRINT *imprint=TS_REQ_get_msg_imprint(req); int ok=1;
    if(!strcmp(op,"version")) integer(out,TS_REQ_get_version(req));
    else if(!strcmp(op,"set_version")) {
        long version=(long)num(value); if(version<0) { error(out,klass,"version must be >= 0!"); return; } ok=TS_REQ_set_version(req,version);
    } else if(!strcmp(op,"algorithm")||!strcmp(op,"message_imprint")) ts_imprint_result(out,imprint,!strcmp(op,"algorithm"));
    else if(!strcmp(op,"set_algorithm")||!strcmp(op,"set_policy_id")) {
        const char *name=format_c_string(value,out); if(out->len) return;
        ASN1_OBJECT *obj=name?OBJ_txt2obj(name,0):NULL;
        if(!obj) { ssl_error(out,"OpenSSL::ASN1::ASN1Error","invalid object identifier"); return; }
        if(!strcmp(op,"set_algorithm")) {
            ok=X509_ALGOR_set0(TS_MSG_IMPRINT_get_algo(imprint),obj,V_ASN1_NULL,NULL); if(ok) obj=NULL;
        } else ok=TS_REQ_set_policy_id(req,obj);
        ASN1_OBJECT_free(obj);
    } else if(!strcmp(op,"set_message_imprint")) {
        if(value->type!='s') { error(out,"TypeError","message imprint must be a String"); return; }
        ok=TS_MSG_IMPRINT_set_msg(imprint,(unsigned char *)value->s,(int)value->len);
    } else if(!strcmp(op,"policy_id")) {
        ASN1_OBJECT *obj=TS_REQ_get_policy_id(req); if(obj) oid_result(out,obj); else byte(out,'n');
    } else if(!strcmp(op,"nonce")) { const ASN1_INTEGER *nonce=TS_REQ_get_nonce(req); if(nonce) x509_serial_result(out,nonce); else byte(out,'n'); }
    else if(!strcmp(op,"set_nonce")) {
        BIGNUM *bn=bn_arg(value); ASN1_INTEGER *nonce=bn?BN_to_ASN1_INTEGER(bn,NULL):NULL; BN_clear_free(bn);
        ok=nonce&&TS_REQ_set_nonce(req,nonce); ASN1_INTEGER_free(nonce);
    } else if(!strcmp(op,"cert_requested")) boolean(out,TS_REQ_get_cert_req(req));
    else if(!strcmp(op,"set_cert_requested")) ok=TS_REQ_set_cert_req(req,truth(value));
    else if(!strcmp(op,"to_der")) { if(ts_request_complete(req,out)) treq_der(out,req); return; }
    else if(!strcmp(op,"to_text")) { BIO *bio=BIO_new(BIO_s_mem()); ok=bio&&TS_REQ_print_bio(bio,req); if(ok) bio_result(out,bio); BIO_free(bio); }
    else { error(out,"NotImplementedError","unknown timestamp request operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
static void ts_info_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::Timestamp::TimestampError";
    if(!strcmp(op,"new")) { tinfo_decode(at(args,0),out); return; }
    TS_TST_INFO *info=tinfo_arg(at(args,0),out); if(!info) return;
    if(!strcmp(op,"to_der")) tinfo_der(out,info);
    else if(!strcmp(op,"version")) integer(out,TS_TST_INFO_get_version(info));
    else if(!strcmp(op,"policy_id")) oid_result(out,TS_TST_INFO_get_policy_id(info));
    else if(!strcmp(op,"algorithm")||!strcmp(op,"message_imprint")) ts_imprint_result(out,TS_TST_INFO_get_msg_imprint(info),!strcmp(op,"algorithm"));
    else if(!strcmp(op,"serial_number")) x509_serial_result(out,TS_TST_INFO_get_serial(info));
    else if(!strcmp(op,"nonce")) { const ASN1_INTEGER *nonce=TS_TST_INFO_get_nonce(info); if(nonce) x509_serial_result(out,nonce); else byte(out,'n'); }
    else if(!strcmp(op,"gen_time")) x509_time_result(out,TS_TST_INFO_get_time(info),klass);
    else if(!strcmp(op,"ordering")) boolean(out,TS_TST_INFO_get_ordering(info));
    else if(!strcmp(op,"to_text")) { BIO *bio=BIO_new(BIO_s_mem()); int ok=bio&&TS_TST_INFO_print_bio(bio,info); if(ok) bio_result(out,bio); else ssl_error(out,klass,"TS_TST_INFO_print_bio"); BIO_free(bio); }
    else error(out,"NotImplementedError","unknown timestamp token-info operation");
}
static void ts_res_verify(TS_RESP *response,const arg *args,buffer *out) {
    const char *klass="OpenSSL::Timestamp::TimestampError";
    TS_REQ *req=treq_arg(at(args,1),out); if(!req) return;
    X509_STORE *store=store_arg(at(args,2),out); if(!store) return;
    TS_VERIFY_CTX *ctx=TS_REQ_to_TS_VERIFY_CTX(req,NULL);
    if(!ctx) { ssl_error(out,klass,"TS_REQ_to_TS_VERIFY_CTX"); return; }
    STACK_OF(X509) *chain=cert_chain_arg(at(args,3),out);
    if(!chain) { TS_VERIFY_CTX_free(ctx); return; }
    PKCS7 *token=TS_RESP_get_token(response);
    if(!token||!PKCS7_type_is_signed(token)) { TS_VERIFY_CTX_free(ctx); sk_X509_pop_free(chain,X509_free); error(out,klass,"TS_RESP_get_token"); return; }
    STACK_OF(X509) *certs=token->d.sign->cert;
    for(int i=0;i<sk_X509_num(certs);i++) {
        X509 *cert=sk_X509_value(certs,i);
        if(!X509_up_ref(cert)) { TS_VERIFY_CTX_free(ctx); sk_X509_pop_free(chain,X509_free); ssl_error(out,klass,"X509_up_ref"); return; }
        if(!sk_X509_push(chain,cert)) { X509_free(cert); TS_VERIFY_CTX_free(ctx); sk_X509_pop_free(chain,X509_free); ssl_error(out,klass,"chain allocation"); return; }
    }
    if(!X509_STORE_up_ref(store)) { TS_VERIFY_CTX_free(ctx); sk_X509_pop_free(chain,X509_free); ssl_error(out,klass,"X509_STORE_up_ref"); return; }
#if OPENSSL_VERSION_NUMBER >= 0x30400000L
    TS_VERIFY_CTX_set0_certs(ctx,chain); TS_VERIFY_CTX_set0_store(ctx,store);
#else
    TS_VERIFY_CTX_set_certs(ctx,chain); TS_VERIFY_CTX_set_store(ctx,store);
#endif
    TS_VERIFY_CTX_add_flags(ctx,TS_VFY_SIGNATURE);
    int ok=TS_RESP_verify_response(ctx,response); TS_VERIFY_CTX_free(ctx);
    if(ok) byte(out,'n'); else ssl_error(out,klass,"TS_RESP_verify_response");
}
static void ts_res_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::Timestamp::TimestampError";
    if(!strcmp(op,"new")) { tres_decode(at(args,0),out); return; }
    TS_RESP *res=tres_arg(at(args,0),out); if(!res) return;
    TS_STATUS_INFO *status=TS_RESP_get_status_info(res);
    if(!strcmp(op,"to_der")) tres_der(out,res);
    else if(!strcmp(op,"status")) integer(out,ASN1_INTEGER_get(TS_STATUS_INFO_get0_status(status)));
    else if(!strcmp(op,"status_text")) {
        const STACK_OF(ASN1_UTF8STRING) *list=TS_STATUS_INFO_get0_text(status); int n=sk_ASN1_UTF8STRING_num(list); if(n<0) n=0;
        byte(out,'a'); number(out,n); for(int i=0;i<n;i++) { const ASN1_STRING *value=sk_ASN1_UTF8STRING_value(list,i); string(out,ASN1_STRING_get0_data(value),(size_t)ASN1_STRING_length(value)); }
    } else if(!strcmp(op,"failure_info")) {
        const ASN1_BIT_STRING *bits=TS_STATUS_INFO_get0_failure_info(status);
        if(!bits) { byte(out,'n'); return; }
        int positions[]={TS_INFO_BAD_ALG,TS_INFO_BAD_REQUEST,TS_INFO_BAD_DATA_FORMAT,TS_INFO_TIME_NOT_AVAILABLE,TS_INFO_UNACCEPTED_POLICY,TS_INFO_UNACCEPTED_EXTENSION,TS_INFO_ADD_INFO_NOT_AVAILABLE,TS_INFO_SYSTEM_FAILURE};
        const char *names[]={"BAD_ALG","BAD_REQUEST","BAD_DATA_FORMAT","TIME_NOT_AVAILABLE","UNACCEPTED_POLICY","UNACCEPTED_EXTENSION","ADD_INFO_NOT_AVAILABLE","SYSTEM_FAILURE"};
        for(int i=0;i<8;i++) if(ASN1_BIT_STRING_get_bit(bits,positions[i])) { text(out,names[i]); return; }
        error(out,klass,"Unrecognized failure info.");
    } else if(!strcmp(op,"token")) { PKCS7 *token=TS_RESP_get_token(res); if(token) object_result(out,pkcs7_own(PKCS7_dup(token))); else byte(out,'n'); }
    else if(!strcmp(op,"token_info")) { TS_TST_INFO *info=TS_RESP_get_tst_info(res); if(info) object_result(out,tinfo_own(TS_TST_INFO_dup(info))); else byte(out,'n'); }
    else if(!strcmp(op,"tsa_certificate")) {
        PKCS7 *token=TS_RESP_get_token(res); X509 *cert=NULL;
        if(token&&PKCS7_type_is_signed(token)&&sk_PKCS7_SIGNER_INFO_num(token->d.sign->signer_info)>0)
            cert=PKCS7_cert_from_signer_info(token,sk_PKCS7_SIGNER_INFO_value(token->d.sign->signer_info,0));
        if(cert) object_result(out,xcert_own(X509_dup(cert))); else byte(out,'n');
    } else if(!strcmp(op,"verify")) ts_res_verify(res,args,out);
    else if(!strcmp(op,"to_text")) { BIO *bio=BIO_new(BIO_s_mem()); int ok=bio&&TS_RESP_print_bio(bio,res); if(ok) bio_result(out,bio); else ssl_error(out,klass,"TS_RESP_print_bio"); BIO_free(bio); }
    else error(out,"NotImplementedError","unknown timestamp response operation");
}
static ASN1_INTEGER *ts_serial_callback(TS_RESP_CTX *ctx,void *ptr) {
    (void)ctx; ASN1_INTEGER **serial=ptr; ASN1_INTEGER *value=*serial; *serial=NULL; return value;
}
static int ts_time_callback(TS_RESP_CTX *ctx,void *ptr,long *sec,long *usec) { (void)ctx; *sec=*(long *)ptr; *usec=0; return 1; }
static void ts_create(const arg *args,buffer *out) {
    const char *klass="OpenSSL::Timestamp::TimestampError";
    EVP_PKEY *key=key_arg(at(args,0),out); if(!key) return;
    X509 *cert=xcert_arg(at(args,1),out); if(!cert) return;
    TS_REQ *request=treq_arg(at(args,2),out); if(!request||!ts_request_complete(request,out)) return;
    BIGNUM *bn=bn_arg(at(args,3)); ASN1_INTEGER *serial=bn?BN_to_ASN1_INTEGER(bn,NULL):NULL; BN_clear_free(bn);
    TS_RESP_CTX *ctx=TS_RESP_CTX_new(); ASN1_OBJECT *policy=NULL; STACK_OF(X509) *certs=NULL;
    EVP_MD **digests=NULL; size_t digest_count=0; BIO *input=NULL; TS_RESP *response=NULL;
    if(!serial||!ctx) goto done;
    long seconds=(long)num(at(args,4));
    TS_RESP_CTX_set_serial_cb(ctx,ts_serial_callback,&serial); TS_RESP_CTX_set_time_cb(ctx,ts_time_callback,&seconds);
    if(!TS_RESP_CTX_set_signer_cert(ctx,cert)||!TS_RESP_CTX_set_signer_key(ctx,key)) goto done;
    const ASN1_OBJECT *request_policy=TS_REQ_get_policy_id(request);
    if(!request_policy) {
        const char *name=format_c_string(at(args,5),out); if(out->len) goto done;
        policy=name?OBJ_txt2obj(name,0):NULL;
        if(!policy) { error(out,"OpenSSL::ASN1::ASN1Error","invalid default policy"); goto done; }
        request_policy=policy;
    }
    if(!TS_RESP_CTX_set_def_policy(ctx,request_policy)) goto done;
    certs=cert_chain_arg(at(args,7),out); if(!certs||!TS_RESP_CTX_set_certs(ctx,certs)) goto done;
    const arg *allowed=at(args,6);
    if(allowed->type=='a'&&allowed->len) {
        digests=calloc(allowed->len,sizeof(*digests)); if(!digests) goto done;
        for(size_t i=0;i<allowed->len;i++) {
            const char *name=format_c_string(&allowed->items[i],out); if(out->len||!name) goto done;
            EVP_MD *md=EVP_MD_fetch(NULL,name,NULL); if(!md) goto done;
            digests[digest_count++]=md; if(!TS_RESP_CTX_add_md(ctx,md)) goto done;
        }
    }
    input=BIO_new(BIO_s_mem()); if(!input||!i2d_TS_REQ_bio(input,request)) goto done;
    response=TS_RESP_create_response(ctx,input);
done:
    TS_RESP_CTX_free(ctx); BIO_free(input); ASN1_INTEGER_free(serial); ASN1_OBJECT_free(policy); sk_X509_pop_free(certs,X509_free);
    for(size_t i=0;i<digest_count;i++) EVP_MD_free(digests[i]); free(digests);
    if(response) { ERR_clear_error(); object_result(out,tres_own(response)); }
    else if(!out->len) ssl_error(out,klass,"timestamp response creation");
}
static void ts_call(const char *op,const arg *args,buffer *out) {
    if(!strncmp(op,"req.",4)) ts_req_call(op+4,args,out);
    else if(!strncmp(op,"res.",4)) ts_res_call(op+4,args,out);
    else if(!strncmp(op,"info.",5)) ts_info_call(op+5,args,out);
    else if(!strcmp(op,"create")) ts_create(args,out);
    else error(out,"NotImplementedError","unknown timestamp operation");
}
