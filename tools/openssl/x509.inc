/* Mutable X.509 objects stay inside libcrypto; all getters return copies. */
#define X509_OBJECT(prefix,ctype,kind,klass,freefn,dupfn) \
static void prefix##_free(void *p) { freefn(p); } \
static void *prefix##_copy(const void *p) { return dupfn((ctype *)p); } \
static int prefix##_own(ctype *p) { return own(p,kind,klass,prefix##_free,prefix##_copy); } \
static ctype *prefix##_arg(const arg *a,buffer *out) { \
    native_slot *s=lookup(num(a),kind); \
    if(!s) error(out,"TypeError","invalid native " klass); return s?s->ptr:NULL; }
X509_OBJECT(xname,X509_NAME,NK_NAME,"OpenSSL::X509::Name",X509_NAME_free,X509_NAME_dup)
X509_OBJECT(xcert,X509,NK_CERT,"OpenSSL::X509::Certificate",X509_free,X509_dup)
X509_OBJECT(xreq,X509_REQ,NK_REQUEST,"OpenSSL::X509::Request",X509_REQ_free,X509_REQ_dup)
X509_OBJECT(xcrl,X509_CRL,NK_CRL,"OpenSSL::X509::CRL",X509_CRL_free,X509_CRL_dup)
X509_OBJECT(xrev,X509_REVOKED,NK_REVOKED,"OpenSSL::X509::Revoked",X509_REVOKED_free,X509_REVOKED_dup)
X509_OBJECT(xext,X509_EXTENSION,NK_EXTENSION,"OpenSSL::X509::Extension",X509_EXTENSION_free,X509_EXTENSION_dup)
#undef X509_OBJECT
static void oid_result(buffer *out,const ASN1_OBJECT *obj) {
    int nid=OBJ_obj2nid(obj);
    const char *short_name=nid==NID_undef?NULL:OBJ_nid2sn(nid);
    if(short_name) { text(out,short_name); return; }
    int len=OBJ_obj2txt(NULL,0,obj,0);
    if(len<=0||len>WIRE_LIMIT) { ssl_error(out,"OpenSSL::OpenSSLError","OBJ_obj2txt"); return; }
    char *s=OPENSSL_malloc((size_t)len+1);
    if(!s) { error(out,"NoMemoryError","OID allocation failed"); return; }
    OBJ_obj2txt(s,len+1,obj,0); text(out,s); OPENSSL_free(s);
}
static void der_result(buffer *out,unsigned char *der,int length,const char *klass) {
    if(length>0) string(out,der,(size_t)length); else ssl_error(out,klass,"DER encoding");
    OPENSSL_free(der);
}
static void x509_name_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::NameError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); const unsigned char *p=(const unsigned char *)str(data);
        X509_NAME *n=data->type=='n'?X509_NAME_new():d2i_X509_NAME(NULL,&p,(long)data->len);
        if(!n) ssl_error(out,klass,"X509_NAME decode"); else object_result(out,xname_own(n)); return;
    }
    X509_NAME *name=xname_arg(at(args,0),out); if(!name) return;
    if(!strcmp(op,"add")) {
        const arg *oid=at(args,1),*value=at(args,2);
        int ok=oid->type=='s'&&value->type=='s'&&!memchr(oid->s,0,oid->len)&&
            X509_NAME_add_entry_by_txt(name,str(oid),(int)num(at(args,3)),(unsigned char *)value->s,(int)value->len,(int)num(at(args,4)),(int)num(at(args,5)));
        if(ok) byte(out,'n'); else ssl_error(out,klass,"X509_NAME_add_entry_by_txt");
    } else if(!strcmp(op,"to_der")) {
        unsigned char *der=NULL; int n=i2d_X509_NAME(name,&der); der_result(out,der,n,klass);
    } else if(!strcmp(op,"to_a")) {
        int n=X509_NAME_entry_count(name); byte(out,'a'); number(out,n);
        for(int i=0;i<n;i++) {
            X509_NAME_ENTRY *entry=X509_NAME_get_entry(name,i);
            const ASN1_STRING *value=X509_NAME_ENTRY_get_data(entry);
            byte(out,'a'); number(out,3); oid_result(out,X509_NAME_ENTRY_get_object(entry));
            unsigned char *utf8=NULL; int len=ASN1_STRING_to_UTF8(&utf8,value);
            if(len<0) { ssl_error(out,klass,"ASN1_STRING_to_UTF8"); return; }
            string(out,utf8,(size_t)len); OPENSSL_free(utf8); integer(out,ASN1_STRING_type(value));
        }
    } else if(!strcmp(op,"to_s")) {
        if(at(args,1)->type=='n') {
            char *s=X509_NAME_oneline(name,NULL,0);
            if(s) { text(out,s); OPENSSL_free(s); } else ssl_error(out,klass,"X509_NAME_oneline");
        } else {
            BIO *bio=BIO_new(BIO_s_mem());
            if(bio&&X509_NAME_print_ex(bio,name,0,(unsigned long)num(at(args,1)))>=0) bio_result(out,bio);
            else ssl_error(out,klass,"X509_NAME_print_ex"); BIO_free(bio);
        }
    } else if(!strcmp(op,"cmp")) {
        X509_NAME *other=xname_arg(at(args,1),out); if(other) { int n=X509_NAME_cmp(name,other); integer(out,(n>0)-(n<0)); }
    } else if(!strcmp(op,"hash")) integer(out,(long long)X509_NAME_hash(name));
    else if(!strcmp(op,"hash_old")) integer(out,(long long)X509_NAME_hash_old(name));
    else error(out,"NotImplementedError","unknown X509 name operation");
}
static void x509_extension_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::ExtensionError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); const unsigned char *p=(const unsigned char *)str(data);
        X509_EXTENSION *ext=d2i_X509_EXTENSION(NULL,&p,(long)data->len);
        if(ext) object_result(out,xext_own(ext)); else ssl_error(out,klass,"d2i_X509_EXTENSION"); return;
    }
    if(!strcmp(op,"create")) {
        const arg *oid=at(args,0),*value=at(args,1),*config=at(args,7);
        ASN1_OBJECT *obj=OBJ_txt2obj(str(oid),0); X509_EXTENSION *ext=NULL;
        if(obj&&value->type=='s') {
            if(truth(at(args,2))) {
                ASN1_OCTET_STRING *oct=ASN1_OCTET_STRING_new();
                if(oct&&ASN1_OCTET_STRING_set(oct,(unsigned char *)value->s,(int)value->len))
                    ext=X509_EXTENSION_create_by_OBJ(NULL,obj,truth(at(args,3)),oct);
                ASN1_OCTET_STRING_free(oct);
            } else {
                X509 *issuer=NULL,*subject=NULL; X509_REQ *req=NULL; X509_CRL *crl=NULL;
                if(at(args,3)->type!='n'&&!(issuer=xcert_arg(at(args,3),out))) goto factory_done;
                if(at(args,4)->type!='n'&&!(subject=xcert_arg(at(args,4),out))) goto factory_done;
                if(at(args,5)->type!='n'&&!(req=xreq_arg(at(args,5),out))) goto factory_done;
                if(at(args,6)->type!='n'&&!(crl=xcrl_arg(at(args,6),out))) goto factory_done;
                CONF *conf=NULL; BIO *bio=NULL;
                if(config->type=='s') {
                    conf=NCONF_new(NULL); bio=BIO_new_mem_buf(config->s,(int)config->len);
                    if(!conf||!bio||NCONF_load_bio(conf,bio,NULL)<=0) {
                        BIO_free(bio); NCONF_free(conf); ssl_error(out,klass,"NCONF_load_bio"); goto factory_done;
                    }
                }
                X509V3_CTX ctx; X509V3_set_ctx(&ctx,issuer,subject,req,crl,0); X509V3_set_nconf(&ctx,conf);
                int nid=OBJ_obj2nid(obj);
                if(!memchr(value->s,0,value->len)) ext=X509V3_EXT_nconf_nid(conf,&ctx,nid,str(value));
                BIO_free(bio); NCONF_free(conf);
            }
        }
factory_done:
        ASN1_OBJECT_free(obj);
        if(ext) object_result(out,xext_own(ext)); else if(!out->len) ssl_error(out,klass,"X509V3 extension creation"); return;
    }
    X509_EXTENSION *ext=xext_arg(at(args,0),out); if(!ext) return;
    if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_X509_EXTENSION(ext,&der); der_result(out,der,n,klass); }
    else if(!strcmp(op,"oid")) oid_result(out,X509_EXTENSION_get_object(ext));
    else if(!strcmp(op,"critical")) boolean(out,X509_EXTENSION_get_critical(ext));
    else if(!strcmp(op,"set_critical")) { X509_EXTENSION_set_critical(ext,truth(at(args,1))); byte(out,'n'); }
    else if(!strcmp(op,"value_der")) {
        ASN1_OCTET_STRING *data=X509_EXTENSION_get_data(ext); string(out,ASN1_STRING_get0_data(data),(size_t)ASN1_STRING_length(data));
    } else if(!strcmp(op,"value")) {
        BIO *bio=BIO_new(BIO_s_mem());
        if(!bio) { ssl_error(out,klass,"BIO_new"); return; }
        if(!X509V3_EXT_print(bio,ext,0,0)) ASN1_STRING_print(bio,X509_EXTENSION_get_data(ext));
        bio_result(out,bio); BIO_free(bio);
    } else if(!strcmp(op,"set_oid")) {
        ASN1_OBJECT *obj=OBJ_txt2obj(str(at(args,1)),0);
        if(obj&&X509_EXTENSION_set_object(ext,obj)) byte(out,'n'); else ssl_error(out,klass,"X509_EXTENSION_set_object"); ASN1_OBJECT_free(obj);
    } else if(!strcmp(op,"set_value")) {
        const arg *value=at(args,1); ASN1_OCTET_STRING *oct=ASN1_OCTET_STRING_new();
        if(oct&&ASN1_OCTET_STRING_set(oct,(unsigned char *)str(value),(int)value->len)&&X509_EXTENSION_set_data(ext,oct)) byte(out,'n');
        else ssl_error(out,klass,"X509_EXTENSION_set_data"); ASN1_OCTET_STRING_free(oct);
    } else error(out,"NotImplementedError","unknown X509 extension operation");
}
static void x509_time_result(buffer *out,const ASN1_TIME *time,const char *klass) {
    struct tm parts={0};
    if(!time||!ASN1_TIME_to_tm(time,&parts)) { ssl_error(out,klass,"ASN1_TIME_to_tm"); return; }
    integer(out,(long long)timegm(&parts));
}
static void x509_serial_result(buffer *out,const ASN1_INTEGER *serial) {
    BIGNUM *n=ASN1_INTEGER_to_BN(serial,NULL);
    if(n) bn_result(out,n); else ssl_error(out,"OpenSSL::OpenSSLError","ASN1_INTEGER_to_BN"); BN_clear_free(n);
}
static int x509_signature_digest(EVP_PKEY *key,const arg *digest,EVP_MD_CTX **result,buffer *out,const char *klass) {
    *result=EVP_MD_CTX_new();
    if(!*result||EVP_DigestSignInit_ex(*result,NULL,digest->type=='n'?NULL:str(digest),NULL,NULL,key,NULL)<=0) {
        EVP_MD_CTX_free(*result); *result=NULL; ssl_error(out,klass,"EVP_DigestSignInit_ex"); return 0;
    }
    return 1;
}
static void x509_certificate_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::CertificateError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); X509 *cert=NULL;
        if(data->type=='n') cert=X509_new();
        else {
            BIO *bio=BIO_new_mem_buf(str(data),(int)data->len);
            if(bio) cert=d2i_X509_bio(bio,NULL);
            if(!cert&&bio) { ERR_clear_error(); BIO_reset(bio); cert=PEM_read_bio_X509(bio,NULL,NULL,NULL); }
            BIO_free(bio);
        }
        if(cert) { ERR_clear_error(); object_result(out,xcert_own(cert)); } else ssl_error(out,klass,"X509 decode"); return;
    }
    X509 *cert=xcert_arg(at(args,0),out); if(!cert) return;
    int ok=1; const arg *value=at(args,1);
    if(!strcmp(op,"version")) integer(out,X509_get_version(cert));
    else if(!strcmp(op,"set_version")) ok=X509_set_version(cert,(long)num(value));
    else if(!strcmp(op,"serial")) x509_serial_result(out,X509_get0_serialNumber(cert));
    else if(!strcmp(op,"set_serial")) {
        BIGNUM *bn=bn_arg(value); ASN1_INTEGER *serial=bn?BN_to_ASN1_INTEGER(bn,NULL):NULL;
        ok=serial&&X509_set_serialNumber(cert,serial); BN_clear_free(bn); ASN1_INTEGER_free(serial);
    } else if(!strcmp(op,"subject")) object_result(out,xname_own(X509_NAME_dup(X509_get_subject_name(cert))));
    else if(!strcmp(op,"issuer")) object_result(out,xname_own(X509_NAME_dup(X509_get_issuer_name(cert))));
    else if(!strcmp(op,"set_subject")||!strcmp(op,"set_issuer")) {
        X509_NAME *name=xname_arg(value,out); if(!name) return;
        ok=!strcmp(op,"set_subject")?X509_set_subject_name(cert,name):X509_set_issuer_name(cert,name);
    } else if(!strcmp(op,"public_key")) {
        EVP_PKEY *key=X509_get_pubkey(cert); if(key) object_result(out,own_key(key)); else ok=0;
    } else if(!strcmp(op,"set_public_key")) { EVP_PKEY *key=key_arg(value,out); if(!key) return; ok=X509_set_pubkey(cert,key); }
    else if(!strcmp(op,"not_before")) x509_time_result(out,X509_get0_notBefore(cert),klass);
    else if(!strcmp(op,"not_after")) x509_time_result(out,X509_get0_notAfter(cert),klass);
    else if(!strcmp(op,"set_not_before")||!strcmp(op,"set_not_after")) {
        ASN1_TIME *time=ASN1_TIME_set(NULL,(time_t)num(value));
        ok=time&&(!strcmp(op,"set_not_before")?X509_set1_notBefore(cert,time):X509_set1_notAfter(cert,time)); ASN1_TIME_free(time);
    } else if(!strcmp(op,"extensions")) {
        int n=X509_get_ext_count(cert); byte(out,'a'); number(out,n);
        for(int i=0;i<n;i++) object_result(out,xext_own(X509_EXTENSION_dup(X509_get_ext(cert,i))));
    } else if(!strcmp(op,"clear_extensions")) {
        X509_EXTENSION *ext; while((ext=X509_delete_ext(cert,0))) X509_EXTENSION_free(ext);
    } else if(!strcmp(op,"add_extension")) { X509_EXTENSION *ext=xext_arg(value,out); if(!ext) return; ok=X509_add_ext(cert,ext,-1); }
    else if(!strcmp(op,"sign")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return; EVP_MD_CTX *ctx=NULL;
        if(!x509_signature_digest(key,at(args,2),&ctx,out,klass)) return;
        ok=X509_sign_ctx(cert,ctx)>0; EVP_MD_CTX_free(ctx);
    } else if(!strcmp(op,"verify")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return; int rc=X509_verify(cert,key);
        if(rc<0) ok=0; else { boolean(out,rc==1); ERR_clear_error(); }
    } else if(!strcmp(op,"check_private_key")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return; boolean(out,X509_check_private_key(cert,key)==1); ERR_clear_error();
    } else if(!strcmp(op,"signature_algorithm")) {
        const X509_ALGOR *alg=NULL; const ASN1_OBJECT *obj=NULL; X509_get0_signature(NULL,&alg,cert); X509_ALGOR_get0(&obj,NULL,NULL,alg); text(out,OBJ_nid2ln(OBJ_obj2nid(obj)));
    } else if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_X509(cert,&der); der_result(out,der,n,klass); }
    else if(!strcmp(op,"to_pem")||!strcmp(op,"to_text")) {
        BIO *bio=BIO_new(BIO_s_mem());
        ok=bio&&(!strcmp(op,"to_pem")?PEM_write_bio_X509(bio,cert):X509_print(bio,cert));
        if(ok) bio_result(out,bio); BIO_free(bio);
    } else if(!strcmp(op,"equal")) { X509 *other=xcert_arg(value,out); if(!other) return; boolean(out,X509_cmp(cert,other)==0); }
    else if(!strcmp(op,"tbs_bytes")) {
        unsigned char *der=NULL; int n=i2d_re_X509_tbs(cert,&der); der_result(out,der,n,klass);
    } else if(!strcmp(op,"tbs_precert_bytes")) {
        X509 *copy=X509_dup(cert); int n;
        if(copy) while((n=X509_get_ext_by_NID(copy,NID_ct_precert_scts,-1))>=0) X509_EXTENSION_free(X509_delete_ext(copy,n));
        unsigned char *der=NULL; n=copy?i2d_re_X509_tbs(copy,&der):-1;
        der_result(out,der,n,klass); X509_free(copy);
    } else { error(out,"NotImplementedError","unknown X509 certificate operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
static void x509_request_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::RequestError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); X509_REQ *req=NULL;
        if(data->type=='n') req=X509_REQ_new();
        else {
            BIO *bio=BIO_new_mem_buf(str(data),(int)data->len);
            if(bio) req=d2i_X509_REQ_bio(bio,NULL);
            if(!req&&bio) { ERR_clear_error(); BIO_reset(bio); req=PEM_read_bio_X509_REQ(bio,NULL,NULL,NULL); }
            BIO_free(bio);
        }
        if(req) { ERR_clear_error(); object_result(out,xreq_own(req)); } else ssl_error(out,klass,"X509_REQ decode"); return;
    }
    X509_REQ *req=xreq_arg(at(args,0),out); if(!req) return;
    const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"version")) integer(out,X509_REQ_get_version(req));
    else if(!strcmp(op,"set_version")) ok=X509_REQ_set_version(req,(long)num(value));
    else if(!strcmp(op,"subject")) object_result(out,xname_own(X509_NAME_dup(X509_REQ_get_subject_name(req))));
    else if(!strcmp(op,"set_subject")) { X509_NAME *name=xname_arg(value,out); if(!name) return; ok=X509_REQ_set_subject_name(req,name); }
    else if(!strcmp(op,"public_key")) { EVP_PKEY *key=X509_REQ_get_pubkey(req); if(key) object_result(out,own_key(key)); else ok=0; }
    else if(!strcmp(op,"set_public_key")) { EVP_PKEY *key=key_arg(value,out); if(!key) return; ok=X509_REQ_set_pubkey(req,key); }
    else if(!strcmp(op,"attributes")) {
        int n=X509_REQ_get_attr_count(req); byte(out,'a'); number(out,n);
        for(int i=0;i<n;i++) {
            unsigned char *der=NULL; int len=i2d_X509_ATTRIBUTE(X509_REQ_get_attr(req,i),&der); der_result(out,der,len,klass);
        }
    } else if(!strcmp(op,"clear_attributes")) { X509_ATTRIBUTE *attr; while((attr=X509_REQ_delete_attr(req,0))) X509_ATTRIBUTE_free(attr); ERR_clear_error(); }
    else if(!strcmp(op,"add_attribute")) {
        const unsigned char *p=(const unsigned char *)str(value); X509_ATTRIBUTE *attr=d2i_X509_ATTRIBUTE(NULL,&p,(long)value->len);
        ok=attr&&X509_REQ_add1_attr(req,attr); X509_ATTRIBUTE_free(attr);
    } else if(!strcmp(op,"sign")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return; EVP_MD_CTX *ctx=NULL;
        if(!x509_signature_digest(key,at(args,2),&ctx,out,klass)) return;
        ok=X509_REQ_sign_ctx(req,ctx)>0; EVP_MD_CTX_free(ctx);
    } else if(!strcmp(op,"verify")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return; int rc=X509_REQ_verify(req,key);
        if(rc<0) ok=0; else { boolean(out,rc==1); ERR_clear_error(); }
    } else if(!strcmp(op,"signature_algorithm")) {
        const X509_ALGOR *alg=NULL; const ASN1_OBJECT *obj=NULL; X509_REQ_get0_signature(req,NULL,&alg); X509_ALGOR_get0(&obj,NULL,NULL,alg); text(out,OBJ_nid2ln(OBJ_obj2nid(obj)));
    } else if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_X509_REQ(req,&der); der_result(out,der,n,klass); }
    else if(!strcmp(op,"to_pem")||!strcmp(op,"to_text")) {
        BIO *bio=BIO_new(BIO_s_mem()); ok=bio&&(!strcmp(op,"to_pem")?PEM_write_bio_X509_REQ(bio,req):X509_REQ_print(bio,req));
        if(ok) bio_result(out,bio); BIO_free(bio);
    } else { error(out,"NotImplementedError","unknown X509 request operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
static void x509_crl_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::CRLError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); X509_CRL *crl=NULL;
        if(data->type=='n') crl=X509_CRL_new();
        else {
            BIO *bio=BIO_new_mem_buf(str(data),(int)data->len);
            if(bio) crl=d2i_X509_CRL_bio(bio,NULL);
            if(!crl&&bio) { ERR_clear_error(); BIO_reset(bio); crl=PEM_read_bio_X509_CRL(bio,NULL,NULL,NULL); }
            BIO_free(bio);
        }
        if(crl) { ERR_clear_error(); object_result(out,xcrl_own(crl)); } else ssl_error(out,klass,"X509_CRL decode"); return;
    }
    X509_CRL *crl=xcrl_arg(at(args,0),out); if(!crl) return;
    const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"version")) integer(out,X509_CRL_get_version(crl));
    else if(!strcmp(op,"set_version")) ok=X509_CRL_set_version(crl,(long)num(value));
    else if(!strcmp(op,"issuer")) object_result(out,xname_own(X509_NAME_dup(X509_CRL_get_issuer(crl))));
    else if(!strcmp(op,"set_issuer")) { X509_NAME *name=xname_arg(value,out); if(!name) return; ok=X509_CRL_set_issuer_name(crl,name); }
    else if(!strcmp(op,"last_update")) x509_time_result(out,X509_CRL_get0_lastUpdate(crl),klass);
    else if(!strcmp(op,"next_update")) x509_time_result(out,X509_CRL_get0_nextUpdate(crl),klass);
    else if(!strcmp(op,"set_last_update")||!strcmp(op,"set_next_update")) {
        ASN1_TIME *time=ASN1_TIME_set(NULL,(time_t)num(value));
        ok=time&&(!strcmp(op,"set_last_update")?X509_CRL_set1_lastUpdate(crl,time):X509_CRL_set1_nextUpdate(crl,time)); ASN1_TIME_free(time);
    } else if(!strcmp(op,"extensions")) {
        int n=X509_CRL_get_ext_count(crl); byte(out,'a'); number(out,n);
        for(int i=0;i<n;i++) object_result(out,xext_own(X509_EXTENSION_dup(X509_CRL_get_ext(crl,i))));
    } else if(!strcmp(op,"clear_extensions")) { X509_EXTENSION *ext; while((ext=X509_CRL_delete_ext(crl,0))) X509_EXTENSION_free(ext); }
    else if(!strcmp(op,"add_extension")) { X509_EXTENSION *ext=xext_arg(value,out); if(!ext) return; ok=X509_CRL_add_ext(crl,ext,-1); }
    else if(!strcmp(op,"revoked")) {
        STACK_OF(X509_REVOKED) *entries=X509_CRL_get_REVOKED(crl); int n=sk_X509_REVOKED_num(entries); if(n<0) n=0;
        byte(out,'a'); number(out,n); for(int i=0;i<n;i++) object_result(out,xrev_own(X509_REVOKED_dup(sk_X509_REVOKED_value(entries,i))));
    } else if(!strcmp(op,"clear_revoked")) {
        STACK_OF(X509_REVOKED) *entries=X509_CRL_get_REVOKED(crl);
        while(sk_X509_REVOKED_num(entries)>0) X509_REVOKED_free(sk_X509_REVOKED_pop(entries));
    } else if(!strcmp(op,"add_revoked")) {
        X509_REVOKED *rev=xrev_arg(value,out); if(!rev) return; X509_REVOKED *copy=X509_REVOKED_dup(rev);
        ok=copy&&X509_CRL_add0_revoked(crl,copy); if(!ok) X509_REVOKED_free(copy);
    } else if(!strcmp(op,"sign")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return; EVP_MD_CTX *ctx=NULL;
        if(!x509_signature_digest(key,at(args,2),&ctx,out,klass)) return;
        X509_CRL_sort(crl); ok=X509_CRL_sign_ctx(crl,ctx)>0; EVP_MD_CTX_free(ctx);
    } else if(!strcmp(op,"verify")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return; int rc=X509_CRL_verify(crl,key);
        if(rc<0) ok=0; else { boolean(out,rc==1); ERR_clear_error(); }
    } else if(!strcmp(op,"signature_algorithm")) {
        const X509_ALGOR *alg=NULL; const ASN1_OBJECT *obj=NULL; X509_CRL_get0_signature(crl,NULL,&alg); X509_ALGOR_get0(&obj,NULL,NULL,alg); text(out,OBJ_nid2ln(OBJ_obj2nid(obj)));
    } else if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_X509_CRL(crl,&der); der_result(out,der,n,klass); }
    else if(!strcmp(op,"to_pem")||!strcmp(op,"to_text")) {
        BIO *bio=BIO_new(BIO_s_mem()); ok=bio&&(!strcmp(op,"to_pem")?PEM_write_bio_X509_CRL(bio,crl):X509_CRL_print(bio,crl));
        if(ok) bio_result(out,bio); BIO_free(bio);
    } else { error(out,"NotImplementedError","unknown X509 CRL operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
static void x509_revoked_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::X509::RevokedError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); const unsigned char *p=(const unsigned char *)str(data);
        X509_REVOKED *rev=data->type=='n'?X509_REVOKED_new():d2i_X509_REVOKED(NULL,&p,(long)data->len);
        if(rev) object_result(out,xrev_own(rev)); else ssl_error(out,klass,"X509_REVOKED decode"); return;
    }
    X509_REVOKED *rev=xrev_arg(at(args,0),out); if(!rev) return;
    const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"serial")) x509_serial_result(out,X509_REVOKED_get0_serialNumber(rev));
    else if(!strcmp(op,"set_serial")) {
        BIGNUM *bn=bn_arg(value); ASN1_INTEGER *serial=bn?BN_to_ASN1_INTEGER(bn,NULL):NULL;
        ok=serial&&X509_REVOKED_set_serialNumber(rev,serial); BN_clear_free(bn); ASN1_INTEGER_free(serial);
    } else if(!strcmp(op,"time")) x509_time_result(out,X509_REVOKED_get0_revocationDate(rev),klass);
    else if(!strcmp(op,"set_time")) {
        ASN1_TIME *time=ASN1_TIME_set(NULL,(time_t)num(value)); ok=time&&X509_REVOKED_set_revocationDate(rev,time); ASN1_TIME_free(time);
    } else if(!strcmp(op,"extensions")) {
        int n=X509_REVOKED_get_ext_count(rev); byte(out,'a'); number(out,n);
        for(int i=0;i<n;i++) object_result(out,xext_own(X509_EXTENSION_dup(X509_REVOKED_get_ext(rev,i))));
    } else if(!strcmp(op,"clear_extensions")) { X509_EXTENSION *ext; while((ext=X509_REVOKED_delete_ext(rev,0))) X509_EXTENSION_free(ext); }
    else if(!strcmp(op,"add_extension")) { X509_EXTENSION *ext=xext_arg(value,out); if(!ext) return; ok=X509_REVOKED_add_ext(rev,ext,-1); }
    else if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_X509_REVOKED(rev,&der); der_result(out,der,n,klass); }
    else { error(out,"NotImplementedError","unknown X509 revoked operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
