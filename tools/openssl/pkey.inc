static void free_key(void *p) { EVP_PKEY_free(p); }
static void *copy_key(const void *p) { return EVP_PKEY_dup((EVP_PKEY *)p); }
static const char *key_class(EVP_PKEY *p) {
    switch(EVP_PKEY_id(p)) {
        case EVP_PKEY_RSA: return "OpenSSL::PKey::RSA";
        case EVP_PKEY_DSA: return "OpenSSL::PKey::DSA";
        case EVP_PKEY_DH: case EVP_PKEY_DHX: return "OpenSSL::PKey::DH";
        case EVP_PKEY_EC: return "OpenSSL::PKey::EC";
        default: return "OpenSSL::PKey::PKey";
    }
}
static int own_key(EVP_PKEY *p) { return p?own(p,NK_KEY,key_class(p),free_key,copy_key):0; }
static EVP_PKEY *key_arg(const arg *a,buffer *out) {
    native_slot *s=lookup(num(a),NK_KEY);
    if(!s) error(out,"TypeError","pkey wasn't initialized");
    return s?s->ptr:NULL;
}
static void bio_result(buffer *out,BIO *bio) {
    char *p=NULL; long n=BIO_get_mem_data(bio,&p);
    if(n<0) ssl_error(out,"OpenSSL::PKey::PKeyError","BIO_get_mem_data");
    else string(out,p,(size_t)n);
}
static int key_options(EVP_PKEY_CTX *ctx,const arg *options,buffer *out) {
    if(options->type=='n') return 1;
    if(options->type!='m') { error(out,"TypeError","options must be a Hash"); return 0; }
    for(size_t i=0;i<options->len;i+=2) {
        const arg *k=&options->items[i],*v=&options->items[i+1];
        if(k->type!='s'||(v->type!='s'&&v->type!='i') || memchr(k->s,0,k->len)||memchr(v->s,0,v->len)) {
            error(out,"ArgumentError","invalid key option string"); return 0;
        }
        if(EVP_PKEY_CTX_ctrl_str(ctx,k->s,v->s)<=0) {
            ssl_error(out,"OpenSSL::PKey::PKeyError",k->s); return 0;
        }
    }
    return 1;
}
static int missing_password(char *pass,size_t size,size_t *len,const OSSL_PARAM params[],void *arg) {
    (void)pass; (void)size; (void)len; (void)params;
    *(int *)arg=1; return 0;
}
static EVP_PKEY *read_key(const arg *data,const arg *password,const char *type,int *requested) {
    if(data->type!='s') return NULL;
    EVP_PKEY *key=NULL;
    const char *formats[]={"DER","PEM"};
    int selections[]={EVP_PKEY_KEYPAIR,EVP_PKEY_KEY_PARAMETERS,EVP_PKEY_PUBLIC_KEY};
    for(size_t f=0;f<2&&!key;f++) for(size_t n=0;n<3&&!key;n++) {
        BIO *bio=BIO_new_mem_buf(data->s,(int)data->len);
        OSSL_DECODER_CTX *ctx=OSSL_DECODER_CTX_new_for_pkey(&key,formats[f],NULL,type,selections[n],NULL,NULL);
        if(bio&&ctx) {
            if(password->type=='s') OSSL_DECODER_CTX_set_passphrase(ctx,(unsigned char *)password->s,password->len);
            else OSSL_DECODER_CTX_set_passphrase_cb(ctx,missing_password,requested);
            for(int pos=-1;!BIO_eof(bio);) {
                ERR_clear_error();
                if(OSSL_DECODER_from_bio(ctx,bio)==1) break;
                int next=(int)BIO_tell(bio); if(next<=pos) break; pos=next;
            }
        }
        OSSL_DECODER_CTX_free(ctx); BIO_free(bio);
    }
    if(key) ERR_clear_error();
    return key;
}
static EVP_PKEY_CTX *generation_context(const arg *input,const arg *options,int parameters,buffer *out) {
    EVP_PKEY_CTX *ctx=NULL;
    if(input->type=='i') {
        EVP_PKEY *key=key_arg(input,out); if(!key) return NULL;
        ctx=EVP_PKEY_CTX_new_from_pkey(NULL,key,NULL);
    } else if(input->type=='s'&&!memchr(input->s,0,input->len)) ctx=EVP_PKEY_CTX_new_from_name(NULL,input->s,NULL);
    if(!ctx || (parameters?EVP_PKEY_paramgen_init(ctx):EVP_PKEY_keygen_init(ctx))<=0 || !key_options(ctx,options,out)) {
        EVP_PKEY_CTX_free(ctx);
        if(!out->len) ssl_error(out,"OpenSSL::PKey::PKeyError","EVP_PKEY generation init");
        return NULL;
    }
    return ctx;
}
static int key_is_private(EVP_PKEY *key) {
    EVP_PKEY_CTX *ctx=EVP_PKEY_CTX_new_from_pkey(NULL,key,NULL);
    int ok=ctx&&EVP_PKEY_private_check(ctx)>0;
    EVP_PKEY_CTX_free(ctx); ERR_clear_error(); return ok;
}
static int key_is_public(EVP_PKEY *key) {
    EVP_PKEY_CTX *ctx=EVP_PKEY_CTX_new_from_pkey(NULL,key,NULL);
    int ok=ctx&&EVP_PKEY_public_check(ctx)>0;
    EVP_PKEY_CTX_free(ctx); ERR_clear_error(); return ok;
}
static void pkey_export(const char *format,EVP_PKEY *key,const arg *cipher,const arg *pass,buffer *out) {
    BIO *bio=BIO_new(BIO_s_mem());
    EVP_CIPHER *algorithm=NULL;
    int ok=0, pem=strstr(format,"pem")!=NULL;
    if(cipher->type=='s') algorithm=EVP_CIPHER_fetch(NULL,str(cipher),NULL);
    if(!bio || (cipher->type=='s'&&!algorithm)) goto done;
    if(!strncmp(format,"private_",8)) {
        if(pem) ok=PEM_write_bio_PKCS8PrivateKey(bio,key,algorithm,str(pass),(int)pass->len,NULL,NULL);
        else ok=i2d_PKCS8PrivateKey_bio(bio,key,algorithm,str(pass),(int)pass->len,NULL,NULL);
    } else if(!strncmp(format,"public_",7)) ok=pem?PEM_write_bio_PUBKEY(bio,key):i2d_PUBKEY_bio(bio,key);
    else if(EVP_PKEY_is_a(key,"DH")||EVP_PKEY_is_a(key,"DHX")) {
        if(pem) ok=PEM_write_bio_Parameters(bio,key);
        else {
            unsigned char *der=NULL; int n=i2d_KeyParams(key,&der);
            if(n>0) ok=BIO_write(bio,der,n)==n;
            OPENSSL_free(der);
        }
    } else if(!key_is_private(key)) ok=pem?PEM_write_bio_PUBKEY(bio,key):i2d_PUBKEY_bio(bio,key);
    else {
        if(pem) ok=PEM_write_bio_PrivateKey_traditional(bio,key,algorithm,(unsigned char *)str(pass),(int)pass->len,NULL,NULL);
        else ok=i2d_PrivateKey_bio(bio,key);
    }
done:
    if(ok) bio_result(out,bio); else ssl_error(out,"OpenSSL::PKey::PKeyError",format);
    if(bio) { char *p; long n=BIO_get_mem_data(bio,&p); if(n>0) OPENSSL_cleanse(p,(size_t)n); }
    BIO_free(bio); EVP_CIPHER_free(algorithm);
}
static void pkey_crypt(const char *op,EVP_PKEY *key,const arg *args,buffer *out) {
    int sign=!strcmp(op,"sign"), verify=!strcmp(op,"verify");
    const arg *digest=at(args,1),*data=at(args,verify?3:2),*signature=at(args,2),*options=at(args,verify?4:3);
    if(data->type!='s'||(verify&&signature->type!='s')) { error(out,"TypeError","data must be a String"); return; }
    EVP_MD_CTX *mdctx=EVP_MD_CTX_new(); EVP_PKEY_CTX *ctx=NULL;
    unsigned char *buf=NULL; size_t size=0,allocated=0; int ok=0,verified=-1;
    const char *mdname=digest->type=='n'?NULL:str(digest);
    if(!mdctx) goto done;
    if(sign) ok=EVP_DigestSignInit_ex(mdctx,&ctx,mdname,NULL,NULL,key,NULL)>0;
    else if(verify) ok=EVP_DigestVerifyInit_ex(mdctx,&ctx,mdname,NULL,NULL,key,NULL)>0;
    if(!ok||!key_options(ctx,options,out)) goto done;
    if(verify) {
        verified=EVP_DigestVerify(mdctx,(unsigned char *)signature->s,signature->len,(unsigned char *)data->s,data->len);
        if(verified>=0) { boolean(out,verified==1); ERR_clear_error(); }
        ok=verified>=0; goto done;
    }
    ok=EVP_DigestSign(mdctx,NULL,&size,(unsigned char *)data->s,data->len)>0;
    if(!ok||size>WIRE_LIMIT) { ok=0; goto done; }
    allocated=size; buf=OPENSSL_malloc(allocated); if(!buf) { ok=0; goto done; }
    ok=EVP_DigestSign(mdctx,buf,&size,(unsigned char *)data->s,data->len)>0;
    if(ok) string(out,buf,size);
done:
    if(!ok&&!out->len) ssl_error(out,"OpenSSL::PKey::PKeyError",op);
    OPENSSL_clear_free(buf,allocated); EVP_MD_CTX_free(mdctx);
}
static void pkey_raw(const char *op,EVP_PKEY *key,const arg *args,buffer *out) {
    int verify=!strcmp(op,"verify_raw"), recover=!strcmp(op,"verify_recover"), encrypt=!strcmp(op,"encrypt"), decrypt=!strcmp(op,"decrypt");
    int cipher=encrypt||decrypt;
    const arg *digest=cipher?&missing:at(args,1), *data=at(args,cipher?1:(verify?3:2)), *sig=at(args,2);
    const arg *options=at(args,cipher?2:(verify?4:3));
    EVP_PKEY_CTX *ctx=EVP_PKEY_CTX_new_from_pkey(NULL,key,NULL);
    EVP_MD *md=NULL; unsigned char *buf=NULL; size_t size=0,allocated=0; int ok=0;
    if(data->type!='s'||(verify&&sig->type!='s')) { error(out,"TypeError","data must be a String"); goto done; }
    if(!ctx) goto done;
    ok=(encrypt?EVP_PKEY_encrypt_init(ctx):decrypt?EVP_PKEY_decrypt_init(ctx):verify?EVP_PKEY_verify_init(ctx):recover?EVP_PKEY_verify_recover_init(ctx):EVP_PKEY_sign_init(ctx))>0;
    if(!ok) goto done;
    if(digest->type!='n') {
        md=EVP_MD_fetch(NULL,str(digest),NULL);
        ok=md&&EVP_PKEY_CTX_set_signature_md(ctx,md)>0;
        if(!ok) goto done;
    }
    if(!key_options(ctx,options,out)) { ok=0; goto done; }
    if(verify) {
        int answer=EVP_PKEY_verify(ctx,(unsigned char *)sig->s,sig->len,(unsigned char *)data->s,data->len);
        ok=answer>=0; if(ok) { boolean(out,answer==1); ERR_clear_error(); }
        goto done;
    }
    if(encrypt) ok=EVP_PKEY_encrypt(ctx,NULL,&size,(unsigned char *)data->s,data->len)>0;
    else if(decrypt) ok=EVP_PKEY_decrypt(ctx,NULL,&size,(unsigned char *)data->s,data->len)>0;
    else if(recover) ok=EVP_PKEY_verify_recover(ctx,NULL,&size,(unsigned char *)data->s,data->len)>0;
    else ok=EVP_PKEY_sign(ctx,NULL,&size,(unsigned char *)data->s,data->len)>0;
    if(!ok||size>WIRE_LIMIT) { ok=0; goto done; }
    allocated=size; buf=OPENSSL_malloc(allocated); if(!buf) { ok=0; goto done; }
    if(encrypt) ok=EVP_PKEY_encrypt(ctx,buf,&size,(unsigned char *)data->s,data->len)>0;
    else if(decrypt) ok=EVP_PKEY_decrypt(ctx,buf,&size,(unsigned char *)data->s,data->len)>0;
    else if(recover) ok=EVP_PKEY_verify_recover(ctx,buf,&size,(unsigned char *)data->s,data->len)>0;
    else ok=EVP_PKEY_sign(ctx,buf,&size,(unsigned char *)data->s,data->len)>0;
    if(ok) string(out,buf,size);
done:
    if(!ok&&!out->len) ssl_error(out,"OpenSSL::PKey::PKeyError",op);
    OPENSSL_clear_free(buf,allocated); EVP_MD_free(md); EVP_PKEY_CTX_free(ctx);
}
#include "ec.inc"
#include "keygen_jobs.inc"

static void pkey_call(const char *op,const arg *args,buffer *out) {
    if(!count(args,1,5,out)) return;
    if(!strcmp(op,"read")) {
        int requested=0;
        const arg *kind=at(args,2);
        EVP_PKEY *key=read_key(at(args,0),at(args,1),kind->type=='s'?kind->s:NULL,&requested);
        if(!key) ssl_error(out,requested?"OpenSSL::PKey::PasswordRequired":"OpenSSL::PKey::PKeyError","Could not parse PKey");
        else object_result(out,own_key(key));
        return;
    }
    if(!strcmp(op,"generate_key")||!strcmp(op,"generate_parameters")) {
        int params=!strcmp(op,"generate_parameters");
        EVP_PKEY_CTX *ctx=generation_context(at(args,0),at(args,1),params,out);
        EVP_PKEY *key=NULL;
        if(ctx) {
            int ok=params?EVP_PKEY_paramgen(ctx,&key):EVP_PKEY_keygen(ctx,&key);
            if(ok>0&&key) object_result(out,own_key(key));
            else { EVP_PKEY_free(key); ssl_error(out,"OpenSSL::PKey::PKeyError",op); }
        }
        EVP_PKEY_CTX_free(ctx); return;
    }
    if(!strcmp(op,"new_raw_private_key")||!strcmp(op,"new_raw_public_key")) {
        const arg *data=at(args,1); EVP_PKEY *key=NULL;
        if(data->type=='s') key=!strcmp(op,"new_raw_private_key")?
          EVP_PKEY_new_raw_private_key_ex(NULL,str(at(args,0)),NULL,(unsigned char *)data->s,data->len):
          EVP_PKEY_new_raw_public_key_ex(NULL,str(at(args,0)),NULL,(unsigned char *)data->s,data->len);
        if(key) object_result(out,own_key(key)); else ssl_error(out,"OpenSSL::PKey::PKeyError",op);
        return;
    }
    EVP_PKEY *key=key_arg(at(args,0),out); if(!key) return;
    if(!strcmp(op,"oid")) {
        const char *name=OBJ_nid2sn(EVP_PKEY_id(key));
        if(!name) name=EVP_PKEY_get0_type_name(key);
        if(name) text(out,name); else byte(out,'n');
    } else if(!strcmp(op,"type_name")) text(out,EVP_PKEY_get0_type_name(key));
    else if(!strcmp(op,"private")) boolean(out,key_is_private(key));
    else if(!strcmp(op,"public")) boolean(out,key_is_public(key));
    else if(!strcmp(op,"ec_group")) ec_key_group(key,out);
    else if(!strcmp(op,"ec_point")) ec_key_point(key,out);
    else if(!strcmp(op,"params_ok")) {
        EVP_PKEY_CTX *ctx=EVP_PKEY_CTX_new_from_pkey(NULL,key,NULL);
        if(ctx) { boolean(out,EVP_PKEY_param_check(ctx)>0); ERR_clear_error(); }
        else ssl_error(out,"OpenSSL::PKey::PKeyError",op);
        EVP_PKEY_CTX_free(ctx);
    }
    else if(!strcmp(op,"get_bn")) {
        BIGNUM *n=NULL;
        if(EVP_PKEY_get_bn_param(key,str(at(args,1)),&n)>0) bn_result(out,n);
        else { byte(out,'n'); ERR_clear_error(); }
        BN_clear_free(n);
    } else if(!strcmp(op,"export")) pkey_export(str(at(args,1)),key,at(args,2),at(args,3),out);
    else if(!strcmp(op,"to_text")) {
        BIO *bio=BIO_new(BIO_s_mem());
        int ok=bio&&EVP_PKEY_print_private(bio,key,0,NULL)>0;
        if(bio&&!ok) { BIO_reset(bio); ERR_clear_error(); ok=EVP_PKEY_print_public(bio,key,0,NULL)>0; }
        if(bio&&!ok) { BIO_reset(bio); ERR_clear_error(); ok=EVP_PKEY_print_params(bio,key,0,NULL)>0; }
        if(ok) bio_result(out,bio); else ssl_error(out,"OpenSSL::PKey::PKeyError",op);
        BIO_free(bio);
    } else if(!strcmp(op,"sign")||!strcmp(op,"verify")) pkey_crypt(op,key,args,out);
    else if(!strcmp(op,"sign_raw")||!strcmp(op,"verify_raw")||!strcmp(op,"verify_recover")||!strcmp(op,"encrypt")||!strcmp(op,"decrypt")) pkey_raw(op,key,args,out);
    else if(!strcmp(op,"raw_private_key")||!strcmp(op,"raw_public_key")) {
        int priv=!strcmp(op,"raw_private_key"); size_t size=0; unsigned char *data=NULL;
        int ok=priv?EVP_PKEY_get_raw_private_key(key,NULL,&size):EVP_PKEY_get_raw_public_key(key,NULL,&size);
        if(ok>0&&size<=WIRE_LIMIT) {
            data=OPENSSL_malloc(size);
            ok=data&&(priv?EVP_PKEY_get_raw_private_key(key,data,&size):EVP_PKEY_get_raw_public_key(key,data,&size));
            if(ok>0) string(out,data,size);
        } else ok=0;
        if(ok<=0) ssl_error(out,"OpenSSL::PKey::PKeyError",op);
        OPENSSL_clear_free(data,size);
    } else if(!strcmp(op,"derive")) {
        EVP_PKEY *peer=key_arg(at(args,1),out); if(!peer) return;
        EVP_PKEY_CTX *ctx=EVP_PKEY_CTX_new_from_pkey(NULL,key,NULL);
        size_t size=0; unsigned char *data=NULL;
        int ok=ctx&&EVP_PKEY_derive_init(ctx)>0&&EVP_PKEY_derive_set_peer(ctx,peer)>0&&key_options(ctx,at(args,2),out)&&EVP_PKEY_derive(ctx,NULL,&size)>0;
        if(ok&&size<=WIRE_LIMIT) { data=OPENSSL_malloc(size); ok=data&&EVP_PKEY_derive(ctx,data,&size)>0; if(ok) string(out,data,size); }
        else ok=0;
        if(!ok&&!out->len) ssl_error(out,"OpenSSL::PKey::PKeyError",op);
        OPENSSL_clear_free(data,size); EVP_PKEY_CTX_free(ctx);
    } else if(!strcmp(op,"compare")) {
        EVP_PKEY *other=key_arg(at(args,1),out);
        if(other) {
            int answer=EVP_PKEY_eq(key,other);
            if(answer==-1) error(out,"TypeError","cannot compare different PKey types");
            else if(answer<0) ssl_error(out,"OpenSSL::PKey::PKeyError","cannot compare PKeys");
            else { boolean(out,answer==1); ERR_clear_error(); }
        }
    } else if(!strcmp(op,"check")) {
        EVP_PKEY_CTX *ctx=EVP_PKEY_CTX_new_from_pkey(NULL,key,NULL);
        int ok=ctx&&(key_is_private(key)?EVP_PKEY_check(ctx):EVP_PKEY_public_check(ctx))>0;
        EVP_PKEY_CTX_free(ctx);
        if(ok) boolean(out,1); else ssl_error(out,"OpenSSL::PKey::PKeyError",op);
    } else error(out,"NotImplementedError","unknown native PKey operation");
}
