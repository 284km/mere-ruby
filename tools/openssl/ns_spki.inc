/* SPKAC encodes an actual public key/challenge and native signature. */
static void spki_free(void *p) { NETSCAPE_SPKI_free(p); }
static void *spki_copy(const void *p) { return ASN1_item_dup(ASN1_ITEM_rptr(NETSCAPE_SPKI),p); }
static int spki_own(NETSCAPE_SPKI *p) { return own(p,NK_SPKI,"OpenSSL::Netscape::SPKI",spki_free,spki_copy); }
static void spki_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::Netscape::SPKIError";
    if(!strcmp(op,"new")) {
        const arg *data=at(args,0); NETSCAPE_SPKI *p=NULL;
        if(data->type=='n') p=NETSCAPE_SPKI_new();
        else if(data->type=='s') {
            p=NETSCAPE_SPKI_b64_decode(data->s,(int)data->len);
            if(!p) { ERR_clear_error(); const unsigned char *cursor=(unsigned char *)data->s; p=d2i_NETSCAPE_SPKI(NULL,&cursor,(long)data->len); }
        }
        if(p) object_result(out,spki_own(p)); else ssl_error(out,klass,"NETSCAPE_SPKI decode"); return;
    }
    native_slot *slot=lookup(num(at(args,0)),NK_SPKI);
    if(!slot) { error(out,"TypeError","invalid native Netscape SPKI"); return; }
    NETSCAPE_SPKI *p=slot->ptr; const arg *value=at(args,1); int ok=1;
    if(!strcmp(op,"to_der")) { unsigned char *der=NULL; int n=i2d_NETSCAPE_SPKI(p,&der); der_result(out,der,n,klass); return; }
    if(!strcmp(op,"to_pem")) {
        char *encoded=NETSCAPE_SPKI_b64_encode(p); if(encoded) { text(out,encoded); OPENSSL_free(encoded); } else ssl_error(out,klass,"NETSCAPE_SPKI_b64_encode"); return;
    }
    if(!strcmp(op,"to_text")) {
        BIO *bio=BIO_new(BIO_s_mem()); ok=bio&&NETSCAPE_SPKI_print(bio,p); if(ok) bio_result(out,bio); BIO_free(bio);
    } else if(!strcmp(op,"public_key")) {
        EVP_PKEY *key=NETSCAPE_SPKI_get_pubkey(p); if(key) object_result(out,own_key(key)); else ssl_error(out,klass,"NETSCAPE_SPKI_get_pubkey"); return;
    } else if(!strcmp(op,"set_public_key")) { EVP_PKEY *key=key_arg(value,out); if(!key) return; ok=NETSCAPE_SPKI_set_pubkey(p,key); }
    else if(!strcmp(op,"challenge")) { ASN1_STRING *text=p->spkac->challenge; string(out,ASN1_STRING_get0_data(text),(size_t)ASN1_STRING_length(text)); }
    else if(!strcmp(op,"set_challenge")) {
        if(value->type!='s') { error(out,"TypeError","challenge must be a String"); return; }
        ok=ASN1_STRING_set(p->spkac->challenge,value->s,(int)value->len);
    } else if(!strcmp(op,"sign")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return;
        const char *name=format_c_string(at(args,2),out); if(out->len) return;
        EVP_MD *md=name?EVP_MD_fetch(NULL,name,NULL):NULL;
        ok=md&&NETSCAPE_SPKI_sign(p,key,md)>0; EVP_MD_free(md);
    } else if(!strcmp(op,"verify")) {
        EVP_PKEY *key=key_arg(value,out); if(!key) return;
        int result=NETSCAPE_SPKI_verify(p,key);
        if(result==1) boolean(out,1); else if(result==0) { ERR_clear_error(); boolean(out,0); } else ssl_error(out,klass,"NETSCAPE_SPKI_verify"); return;
    } else { error(out,"NotImplementedError","unknown Netscape SPKI operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
