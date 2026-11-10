/* PKCS12 owns the encrypted container; parsed keys/certificates receive their
 * own handles, independent of the container's Ruby and native lifetimes. */
static void pkcs12_free(void *p) { PKCS12_free(p); }
static void *pkcs12_copy(const void *p) { return ASN1_item_dup(ASN1_ITEM_rptr(PKCS12),p); }
static int pkcs12_own(PKCS12 *p) { return own(p,NK_PKCS12,"OpenSSL::PKCS12",pkcs12_free,pkcs12_copy); }
static const char *format_c_string(const arg *a,buffer *out) {
    if(a->type=='n') return NULL;
    if(a->type!='s') { error(out,"TypeError","expected a String"); return NULL; }
    if(memchr(a->s,0,a->len)) { error(out,"ArgumentError","string contains null byte"); return NULL; }
    return a->s;
}
static void pkcs12_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::PKCS12::PKCS12Error";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); const char *password=format_c_string(at(args,1),out);
        if(out->len) return;
        PKCS12 *container=NULL; EVP_PKEY *key=NULL; X509 *cert=NULL; STACK_OF(X509) *ca=NULL;
        if(data->type=='n') container=PKCS12_new();
        else if(data->type=='s') {
            const unsigned char *cursor=(unsigned char *)data->s;
            container=d2i_PKCS12(NULL,&cursor,(long)data->len);
            if(container&&!PKCS12_parse(container,password,&key,&cert,&ca)) {
                PKCS12_free(container); container=NULL;
            }
        }
        if(!container) {
            EVP_PKEY_free(key); X509_free(cert); sk_X509_pop_free(ca,X509_free);
            ssl_error(out,klass,"PKCS12_parse"); return;
        }
        byte(out,'a'); number(out,4); object_result(out,pkcs12_own(container));
        if(key) object_result(out,own_key(key)); else byte(out,'n');
        if(cert) object_result(out,xcert_own(cert)); else byte(out,'n');
        cert_chain_result(out,ca); sk_X509_pop_free(ca,X509_free); return;
    }
    if(!strcmp(op,"create")) {
        const char *password=format_c_string(at(args,0),out),*name=format_c_string(at(args,1),out);
        if(out->len) return;
        EVP_PKEY *key=key_arg(at(args,2),out); if(!key) return;
        X509 *cert=xcert_arg(at(args,3),out); if(!cert) return;
        const char *key_pbe=format_c_string(at(args,5),out),*cert_pbe=format_c_string(at(args,6),out);
        if(out->len) return;
        int key_nid=key_pbe?OBJ_txt2nid(key_pbe):0,cert_nid=cert_pbe?OBJ_txt2nid(cert_pbe):0;
        if((key_pbe&&!key_nid)||(cert_pbe&&!cert_nid)) { error(out,"ArgumentError","Unknown PBE algorithm"); return; }
        int keytype=(int)num(at(args,9));
        if(keytype&&keytype!=KEY_SIG&&keytype!=KEY_EX) { error(out,"ArgumentError","Unknown key usage type"); return; }
        STACK_OF(X509) *ca=cert_chain_arg(at(args,4),out); if(!ca) return;
        PKCS12 *container=PKCS12_create(password,name,key,cert,ca,key_nid,cert_nid,
            (int)num(at(args,7)),(int)num(at(args,8)),keytype);
        sk_X509_pop_free(ca,X509_free);
        if(container) object_result(out,pkcs12_own(container)); else ssl_error(out,klass,"PKCS12_create"); return;
    }
    native_slot *slot=lookup(num(at(args,0)),NK_PKCS12);
    if(!slot) { error(out,"TypeError","invalid native PKCS12"); return; }
    PKCS12 *container=slot->ptr;
    if(!strcmp(op,"to_der")) {
        unsigned char *der=NULL; int length=i2d_PKCS12(container,&der); der_result(out,der,length,klass);
    } else if(!strcmp(op,"set_mac")) {
        const arg *password=at(args,1),*salt=at(args,2),*digest=at(args,4);
        if(password->type!='s'||(salt->type!='n'&&salt->type!='s')) { error(out,"TypeError","invalid MAC password or salt"); return; }
        EVP_MD *md=NULL;
        if(digest->type!='n') {
            const char *name=format_c_string(digest,out); if(out->len) return;
            md=EVP_MD_fetch(NULL,name,NULL);
            if(!md) { ssl_error(out,klass,"EVP_MD_fetch"); return; }
        }
        int ok=PKCS12_set_mac(container,password->s,(int)password->len,
            salt->type=='s'?(unsigned char *)salt->s:NULL,salt->type=='s'?(int)salt->len:0,(int)num(at(args,3)),md);
        EVP_MD_free(md); if(ok) byte(out,'n'); else ssl_error(out,klass,"PKCS12_set_mac");
    } else error(out,"NotImplementedError","unknown PKCS12 operation");
}
