/* Runtime cipher references and child signing keys outlive their callers. */
typedef struct pkcs7_holder { PKCS7 *value; EVP_CIPHER *cipher; } pkcs7_holder;
static void pkcs7_free(void *p) { pkcs7_holder *h=p; PKCS7_free(h->value); EVP_CIPHER_free(h->cipher); free(h); }
static void *pkcs7_copy(const void *p) {
    const pkcs7_holder *old=p; pkcs7_holder *h=calloc(1,sizeof(*h));
    if(!h) return NULL;
    h->value=PKCS7_dup(old->value);
    if(!h->value) { free(h); return NULL; }
    if(old->cipher) {
        if(!EVP_CIPHER_up_ref(old->cipher)) { pkcs7_free(h); return NULL; }
        h->cipher=old->cipher;
        if(PKCS7_type_is_enveloped(h->value)) h->value->d.enveloped->enc_data->cipher=h->cipher;
        if(PKCS7_type_is_signedAndEnveloped(h->value)) h->value->d.signed_and_enveloped->enc_data->cipher=h->cipher;
    }
    return h;
}
static int pkcs7_own(PKCS7 *p) {
    if(!p) return 0;
    pkcs7_holder *h=calloc(1,sizeof(*h)); if(!h) { PKCS7_free(p); return 0; }
    h->value=p; return own(h,NK_PKCS7,"OpenSSL::PKCS7",pkcs7_free,pkcs7_copy);
}
static pkcs7_holder *pkcs7_holder_arg(const arg *a,buffer *out) {
    native_slot *s=lookup(num(a),NK_PKCS7);
    if(!s) error(out,"TypeError","invalid native PKCS7"); return s?s->ptr:NULL;
}
static void p7si_free(void *p) { PKCS7_SIGNER_INFO_free(p); }
static void *p7si_copy(const void *p) {
    const PKCS7_SIGNER_INFO *old=p;
    PKCS7_SIGNER_INFO *copy=ASN1_item_dup(ASN1_ITEM_rptr(PKCS7_SIGNER_INFO),old);
    if(copy&&old->pkey) {
        if(!EVP_PKEY_up_ref(old->pkey)) { PKCS7_SIGNER_INFO_free(copy); return NULL; }
        copy->pkey=old->pkey;
    }
    return copy;
}
static int p7si_own(PKCS7_SIGNER_INFO *p) { return own(p,NK_P7_SIGNER,"OpenSSL::PKCS7::SignerInfo",p7si_free,p7si_copy); }
static PKCS7_SIGNER_INFO *p7si_arg(const arg *a,buffer *out) {
    native_slot *s=lookup(num(a),NK_P7_SIGNER); if(!s) error(out,"TypeError","invalid native PKCS7 signer"); return s?s->ptr:NULL;
}
static void p7ri_free(void *p) { PKCS7_RECIP_INFO_free(p); }
static void *p7ri_copy(const void *p) {
    const PKCS7_RECIP_INFO *old=p;
    PKCS7_RECIP_INFO *copy=ASN1_item_dup(ASN1_ITEM_rptr(PKCS7_RECIP_INFO),old);
    if(copy&&old->cert) {
        if(!X509_up_ref(old->cert)) { PKCS7_RECIP_INFO_free(copy); return NULL; }
        copy->cert=old->cert;
    }
    return copy;
}
static int p7ri_own(PKCS7_RECIP_INFO *p) { return own(p,NK_P7_RECIPIENT,"OpenSSL::PKCS7::RecipientInfo",p7ri_free,p7ri_copy); }
static PKCS7_RECIP_INFO *p7ri_arg(const arg *a,buffer *out) {
    native_slot *s=lookup(num(a),NK_P7_RECIPIENT); if(!s) error(out,"TypeError","invalid native PKCS7 recipient"); return s?s->ptr:NULL;
}
static void p7si_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::PKCS7::PKCS7Error";
    if(!strcmp(op,"new")) {
        X509 *cert=xcert_arg(at(args,0),out); if(!cert) return;
        EVP_PKEY *key=key_arg(at(args,1),out); if(!key) return;
        const char *name=format_c_string(at(args,2),out); if(out->len) return;
        EVP_MD *md=name?EVP_MD_fetch(NULL,name,NULL):NULL; PKCS7_SIGNER_INFO *si=PKCS7_SIGNER_INFO_new();
        int ok=md&&si&&PKCS7_SIGNER_INFO_set(si,cert,key,md); EVP_MD_free(md);
        if(ok) object_result(out,p7si_own(si)); else { PKCS7_SIGNER_INFO_free(si); ssl_error(out,klass,"PKCS7_SIGNER_INFO_set"); } return;
    }
    PKCS7_SIGNER_INFO *si=p7si_arg(at(args,0),out); if(!si) return;
    if(!strcmp(op,"issuer")) object_result(out,xname_own(X509_NAME_dup(si->issuer_and_serial->issuer)));
    else if(!strcmp(op,"serial")) x509_serial_result(out,si->issuer_and_serial->serial);
    else if(!strcmp(op,"signed_time")) {
        ASN1_TYPE *value=PKCS7_get_signed_attribute(si,NID_pkcs9_signingTime);
        if(!value) ssl_error(out,klass,"signingTime attribute missing");
        else if(value->type==V_ASN1_UTCTIME) x509_time_result(out,value->value.utctime,klass);
        else byte(out,'n');
    } else error(out,"NotImplementedError","unknown PKCS7 signer operation");
}
static void p7ri_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::PKCS7::PKCS7Error";
    if(!strcmp(op,"new")) {
        X509 *cert=xcert_arg(at(args,0),out); if(!cert) return;
        PKCS7_RECIP_INFO *ri=PKCS7_RECIP_INFO_new();
        if(ri&&PKCS7_RECIP_INFO_set(ri,cert)) object_result(out,p7ri_own(ri));
        else { PKCS7_RECIP_INFO_free(ri); ssl_error(out,klass,"PKCS7_RECIP_INFO_set"); } return;
    }
    PKCS7_RECIP_INFO *ri=p7ri_arg(at(args,0),out); if(!ri) return;
    if(!strcmp(op,"issuer")) object_result(out,xname_own(X509_NAME_dup(ri->issuer_and_serial->issuer)));
    else if(!strcmp(op,"serial")) x509_serial_result(out,ri->issuer_and_serial->serial);
    else if(!strcmp(op,"enc_key")) string(out,ASN1_STRING_get0_data(ri->enc_key),(size_t)ASN1_STRING_length(ri->enc_key));
    else error(out,"NotImplementedError","unknown PKCS7 recipient operation");
}
static STACK_OF(X509) **pkcs7_certs(PKCS7 *p) {
    if(PKCS7_type_is_signed(p)) return &p->d.sign->cert;
    if(PKCS7_type_is_signedAndEnveloped(p)) return &p->d.signed_and_enveloped->cert;
    return NULL;
}
static STACK_OF(X509_CRL) **pkcs7_crls(PKCS7 *p) {
    if(PKCS7_type_is_signed(p)) return &p->d.sign->crl;
    if(PKCS7_type_is_signedAndEnveloped(p)) return &p->d.signed_and_enveloped->crl;
    return NULL;
}
static void pkcs7_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::PKCS7::PKCS7Error";
    if(!strcmp(op,"new")||!strcmp(op,"read_smime")) {
        const arg *data=at(args,0); PKCS7 *p=NULL; BIO *body=NULL;
        if(data->type=='n'&&!strcmp(op,"new")) p=PKCS7_new();
        else if(data->type=='s') {
            BIO *input=BIO_new_mem_buf(data->s,(int)data->len);
            if(input) {
                if(!strcmp(op,"read_smime")) p=SMIME_read_PKCS7(input,&body);
                else { p=d2i_PKCS7_bio(input,NULL); if(!p) { ERR_clear_error(); BIO_reset(input); p=PEM_read_bio_PKCS7(input,NULL,NULL,NULL); } }
            }
            BIO_free(input);
            if(p&&!p->d.ptr) { PKCS7_free(p); p=NULL; }
        }
        if(!p) { BIO_free(body); ssl_error(out,klass,"PKCS7 decode"); return; }
        ERR_clear_error();
        if(!strcmp(op,"read_smime")) { byte(out,'a'); number(out,2); object_result(out,pkcs7_own(p)); if(body) bio_result(out,body); else byte(out,'n'); BIO_free(body); }
        else object_result(out,pkcs7_own(p));
        return;
    }
    if(!strcmp(op,"sign")||!strcmp(op,"encrypt")) {
        int signing=!strcmp(op,"sign"); PKCS7 *p=NULL; EVP_CIPHER *cipher=NULL;
        const arg *data=at(args,signing?2:1);
        if(data->type!='s') { error(out,"TypeError","PKCS7 input must be a String"); return; }
        X509 *cert=NULL; EVP_PKEY *key=NULL;
        if(signing) { cert=xcert_arg(at(args,0),out); if(!cert) return; key=key_arg(at(args,1),out); if(!key) return; }
        else {
            const char *name=format_c_string(at(args,2),out); if(out->len) return;
            cipher=name?EVP_CIPHER_fetch(NULL,name,NULL):NULL;
            if(!cipher) { ssl_error(out,klass,"EVP_CIPHER_fetch"); return; }
        }
        STACK_OF(X509) *certs=cert_chain_arg(at(args,signing?3:0),out);
        if(!certs) { EVP_CIPHER_free(cipher); return; }
        BIO *input=BIO_new_mem_buf(data->s,(int)data->len);
        if(input) p=signing?PKCS7_sign(cert,key,certs,input,(int)num(at(args,4))):PKCS7_encrypt(certs,input,cipher,(int)num(at(args,3)));
        BIO_free(input); sk_X509_pop_free(certs,X509_free);
        if(p) {
            int id=pkcs7_own(p);
            if(id) ((pkcs7_holder *)lookup(id,NK_PKCS7)->ptr)->cipher=cipher;
            else EVP_CIPHER_free(cipher);
            object_result(out,id);
        } else { EVP_CIPHER_free(cipher); ssl_error(out,klass,signing?"PKCS7_sign":"PKCS7_encrypt"); }
        return;
    }
    pkcs7_holder *h=pkcs7_holder_arg(at(args,0),out); if(!h) return;
    PKCS7 *p=h->value; const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"type")) {
        const char *name=PKCS7_type_is_signed(p)?"signed":PKCS7_type_is_encrypted(p)?"encrypted":PKCS7_type_is_enveloped(p)?"enveloped":PKCS7_type_is_signedAndEnveloped(p)?"signedAndEnveloped":PKCS7_type_is_data(p)?"data":NULL;
        if(name) text(out,name); else byte(out,'n');
    } else if(!strcmp(op,"set_type")) {
        const char *names[]={"signed","data","signedAndEnveloped","enveloped","encrypted","digest"};
        int ids[]={NID_pkcs7_signed,NID_pkcs7_data,NID_pkcs7_signedAndEnveloped,NID_pkcs7_enveloped,NID_pkcs7_encrypted,NID_pkcs7_digest};
        int nid=0; for(int i=0;i<6;i++) if(!strcmp(str(value),names[i])) nid=ids[i];
        if(!nid) { error(out,klass,"unknown PKCS7 type"); return; } ok=PKCS7_set_type(p,nid);
    } else if(!strcmp(op,"detached")) boolean(out,PKCS7_type_is_signed(p)&&PKCS7_get_detached(p));
    else if(!strcmp(op,"detached_p")) boolean(out,PKCS7_is_detached(p));
    else if(!strcmp(op,"set_detached")) ok=PKCS7_set_detached(p,truth(value));
    else if(!strcmp(op,"set_cipher")) {
        const char *name=format_c_string(value,out); if(out->len) return;
        EVP_CIPHER *cipher=name?EVP_CIPHER_fetch(NULL,name,NULL):NULL;
        ok=cipher&&PKCS7_set_cipher(p,cipher);
        if(ok) { EVP_CIPHER_free(h->cipher); h->cipher=cipher; } else EVP_CIPHER_free(cipher);
    } else if(!strcmp(op,"add_signer")) {
        PKCS7_SIGNER_INFO *si=p7si_arg(value,out); if(!si) return;
        PKCS7_SIGNER_INFO *copy=p7si_copy(si); ok=copy&&PKCS7_add_signer(p,copy);
        if(!ok) PKCS7_SIGNER_INFO_free(copy);
    } else if(!strcmp(op,"add_recipient")) {
        PKCS7_RECIP_INFO *ri=p7ri_arg(value,out); if(!ri) return;
        PKCS7_RECIP_INFO *copy=p7ri_copy(ri); ok=copy&&PKCS7_add_recipient_info(p,copy);
        if(!ok) PKCS7_RECIP_INFO_free(copy);
    } else if(!strcmp(op,"signers")) {
        STACK_OF(PKCS7_SIGNER_INFO) *list=PKCS7_get_signer_info(p); int n=sk_PKCS7_SIGNER_INFO_num(list); if(n<0) n=0;
        byte(out,'a'); number(out,n); for(int i=0;i<n;i++) object_result(out,p7si_own(p7si_copy(sk_PKCS7_SIGNER_INFO_value(list,i))));
    } else if(!strcmp(op,"recipients")) {
        STACK_OF(PKCS7_RECIP_INFO) *list=PKCS7_type_is_enveloped(p)?p->d.enveloped->recipientinfo:PKCS7_type_is_signedAndEnveloped(p)?p->d.signed_and_enveloped->recipientinfo:NULL;
        int n=sk_PKCS7_RECIP_INFO_num(list); if(n<0) n=0;
        byte(out,'a'); number(out,n); for(int i=0;i<n;i++) object_result(out,p7ri_own(p7ri_copy(sk_PKCS7_RECIP_INFO_value(list,i))));
    } else if(!strcmp(op,"add_certificate")) { X509 *cert=xcert_arg(value,out); if(!cert) return; ok=PKCS7_add_certificate(p,cert); }
    else if(!strcmp(op,"add_crl")) { X509_CRL *crl=xcrl_arg(value,out); if(!crl) return; ok=PKCS7_add_crl(p,crl); }
    else if(!strcmp(op,"certificates")||!strcmp(op,"clear_certificates")) {
        STACK_OF(X509) **slot=pkcs7_certs(p); STACK_OF(X509) *list=slot?*slot:NULL;
        if(!strcmp(op,"clear_certificates")) { X509 *cert; while(list&&(cert=sk_X509_pop(list))) X509_free(cert); }
        else if(!list) byte(out,'n');
        else { int n=sk_X509_num(list); byte(out,'a'); number(out,n); for(int i=0;i<n;i++) object_result(out,xcert_own(X509_dup(sk_X509_value(list,i)))); }
    } else if(!strcmp(op,"crls")||!strcmp(op,"clear_crls")) {
        STACK_OF(X509_CRL) **slot=pkcs7_crls(p); STACK_OF(X509_CRL) *list=slot?*slot:NULL;
        if(!strcmp(op,"clear_crls")) { X509_CRL *crl; while(list&&(crl=sk_X509_CRL_pop(list))) X509_CRL_free(crl); }
        else if(!list) byte(out,'n');
        else { int n=sk_X509_CRL_num(list); byte(out,'a'); number(out,n); for(int i=0;i<n;i++) object_result(out,xcrl_own(X509_CRL_dup(sk_X509_CRL_value(list,i)))); }
    } else if(!strcmp(op,"add_data")) {
        if(value->type!='s') { error(out,"TypeError","PKCS7 data must be a String"); return; }
        ok=!PKCS7_type_is_signed(p)||PKCS7_content_new(p,NID_pkcs7_data);
        BIO *chain=ok?PKCS7_dataInit(p,NULL):NULL; ok=chain!=NULL;
        for(size_t pos=0;ok&&pos<value->len;) { int n=(int)(value->len-pos>4096?4096:value->len-pos); ok=BIO_write(chain,value->s+pos,n)==n; pos+=(size_t)n; }
        if(ok) ok=BIO_flush(chain)>0&&PKCS7_dataFinal(p,chain); BIO_free_all(chain);
    } else if(!strcmp(op,"verify")) {
        X509_STORE *store=store_arg(at(args,2),out); if(!store) return;
        STACK_OF(X509) *certs=cert_chain_arg(value,out); if(!certs) return;
        const arg *data=at(args,3); BIO *input=data->type=='s'?BIO_new_mem_buf(data->s,(int)data->len):NULL,*output=BIO_new(BIO_s_mem());
        if(!output||(data->type=='s'&&!input)) { BIO_free(input); BIO_free(output); sk_X509_pop_free(certs,X509_free); ssl_error(out,klass,"BIO allocation"); return; }
        int valid=PKCS7_verify(p,certs,store,input,output,(int)num(at(args,4)));
        const char *reason=valid==1?NULL:ERR_reason_error_string(ERR_peek_error());
        byte(out,'a'); number(out,3); boolean(out,valid==1); bio_result(out,output); if(reason) text(out,reason); else byte(out,'n');
        BIO_free(input); BIO_free(output); sk_X509_pop_free(certs,X509_free); ERR_clear_error(); return;
    } else if(!strcmp(op,"decrypt")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return;
        X509 *cert=at(args,2)->type=='n'?NULL:xcert_arg(at(args,2),out); if(out->len) return;
        BIO *output=BIO_new(BIO_s_mem()); ok=output&&PKCS7_decrypt(p,key,cert,output,(int)num(at(args,3)));
        if(ok) bio_result(out,output); BIO_free(output);
    } else if(!strcmp(op,"write_smime")) {
        BIO *input=value->type=='s'?BIO_new_mem_buf(value->s,(int)value->len):NULL,*output=BIO_new(BIO_s_mem());
        int flags=(int)num(at(args,2)); if(input&&PKCS7_is_detached(p)) flags|=PKCS7_DETACHED;
        ok=output&&SMIME_write_PKCS7(output,p,input,flags); if(ok) bio_result(out,output); BIO_free(input); BIO_free(output);
    } else if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_PKCS7(p,&der); der_result(out,der,n,klass); return; }
    else if(!strcmp(op,"to_pem")||!strcmp(op,"to_text")) {
        BIO *output=BIO_new(BIO_s_mem()); ok=output&&(!strcmp(op,"to_pem")?PEM_write_bio_PKCS7(output,p):PKCS7_print_ctx(output,p,0,NULL));
        if(ok) bio_result(out,output); BIO_free(output);
    } else { error(out,"NotImplementedError","unknown PKCS7 operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
