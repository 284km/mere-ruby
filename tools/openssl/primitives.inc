/* Provider-backed digest/MAC state keeps keys and buffered state out of Ruby. */
static void digest_free(void *p) { EVP_MD_CTX_free(p); }
static void *digest_copy(const void *p) {
    EVP_MD_CTX *copy=EVP_MD_CTX_new();
    if(copy&&!EVP_MD_CTX_copy_ex(copy,(EVP_MD_CTX *)p)) { EVP_MD_CTX_free(copy); copy=NULL; } return copy;
}
static int own_digest(EVP_MD_CTX *ctx) { return own(ctx,NK_DIGEST,"OpenSSL::Backend::DigestContext",digest_free,digest_copy); }
static void digest_name(buffer *out,const EVP_MD *md) {
    int nid=EVP_MD_get_type(md); const char *name=nid==NID_undef?EVP_MD_get0_name(md):OBJ_nid2sn(nid); text(out,name?name:"");
}
typedef struct name_collection { buffer entries; uint32_t count; } name_collection;
static void digest_list_name(const OBJ_NAME *name,void *ptr) {
    name_collection *list=ptr;
    if(!name->alias) { text(&list->entries,name->name); list->count++; }
}
static void digest_list_fetched(EVP_MD *md,void *ptr) {
    name_collection *list=ptr; text(&list->entries,EVP_MD_get0_name(md)); list->count++;
}
static void digest_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::Digest::DigestError";
    if(!strcmp(op,"list")) {
        name_collection names={0}; OBJ_NAME_do_all_sorted(OBJ_NAME_TYPE_MD_METH,digest_list_name,&names);
        EVP_MD_do_all_provided(NULL,digest_list_fetched,&names);
        byte(out,'a'); number(out,names.count); put(out,names.entries.p,names.entries.len); free(names.entries.p); return;
    }
    if(!strcmp(op,"new")) {
        const arg *name=at(args,0);
        if(name->type!='s'||memchr(name->s,0,name->len)) { error(out,"TypeError","invalid digest name"); return; }
        EVP_MD *fetched=EVP_MD_fetch(NULL,name->s,NULL);
        const EVP_MD *md=fetched?fetched:EVP_get_digestbyname(name->s);
        EVP_MD_CTX *ctx=EVP_MD_CTX_new();
        int ok=ctx&&md&&EVP_DigestInit_ex(ctx,md,NULL)>0; EVP_MD_free(fetched);
        if(ok) { ERR_clear_error(); object_result(out,own_digest(ctx)); }
        else { EVP_MD_CTX_free(ctx); ssl_error(out,klass,"EVP_DigestInit_ex"); } return;
    }
    native_slot *slot=lookup(num(at(args,0)),NK_DIGEST);
    if(!slot) { error(out,klass,"digest wasn't initialized"); return; }
    EVP_MD_CTX *ctx=slot->ptr; const EVP_MD *md=EVP_MD_CTX_get0_md(ctx); int ok=1;
    if(!strcmp(op,"info")) { byte(out,'a'); number(out,3); digest_name(out,md); integer(out,EVP_MD_get_size(md)); integer(out,EVP_MD_get_block_size(md)); }
    else if(!strcmp(op,"update")) {
        const arg *data=at(args,1); if(data->type!='s') { error(out,"TypeError","digest data must be a String"); return; }
        ok=EVP_DigestUpdate(ctx,data->s,data->len)>0;
    } else if(!strcmp(op,"reset")) ok=EVP_DigestInit_ex(ctx,NULL,NULL)>0;
    else if(!strcmp(op,"final")) {
        EVP_MD_CTX *copy=digest_copy(ctx); unsigned char digest[EVP_MAX_MD_SIZE]; unsigned int length=0;
        ok=copy&&EVP_DigestFinal_ex(copy,digest,&length)>0;
        if(ok) string(out,digest,length); OPENSSL_cleanse(digest,sizeof(digest)); EVP_MD_CTX_free(copy);
    } else { error(out,"NotImplementedError","unknown digest operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
static void hmac_free(void *p) { EVP_MAC_CTX_free(p); }
static void *hmac_copy(const void *p) { return EVP_MAC_CTX_dup((EVP_MAC_CTX *)p); }
static void hmac_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::HMACError";
    if(!strcmp(op,"new")) {
        const arg *key=at(args,0),*name=at(args,1);
        if(key->type!='s'||name->type!='s'||memchr(name->s,0,name->len)) { error(out,"TypeError","invalid HMAC key or digest"); return; }
        EVP_MAC *mac=EVP_MAC_fetch(NULL,"HMAC",NULL); EVP_MAC_CTX *ctx=mac?EVP_MAC_CTX_new(mac):NULL; EVP_MAC_free(mac);
        OSSL_PARAM params[]={OSSL_PARAM_construct_utf8_string(OSSL_MAC_PARAM_DIGEST,name->s,0),OSSL_PARAM_construct_end()};
        if(ctx&&EVP_MAC_init(ctx,(unsigned char *)key->s,key->len,params)>0)
            object_result(out,own(ctx,NK_HMAC,"OpenSSL::Backend::HMACContext",hmac_free,hmac_copy));
        else { EVP_MAC_CTX_free(ctx); ssl_error(out,klass,"EVP_MAC_init"); } return;
    }
    native_slot *slot=lookup(num(at(args,0)),NK_HMAC);
    if(!slot) { error(out,klass,"HMAC wasn't initialized"); return; }
    EVP_MAC_CTX *ctx=slot->ptr; int ok=1;
    if(!strcmp(op,"update")) { const arg *data=at(args,1); if(data->type!='s') { error(out,"TypeError","HMAC data must be a String"); return; } ok=EVP_MAC_update(ctx,(unsigned char *)data->s,data->len)>0; }
    else if(!strcmp(op,"reset")) ok=EVP_MAC_init(ctx,NULL,0,NULL)>0;
    else if(!strcmp(op,"final")) {
        EVP_MAC_CTX *copy=EVP_MAC_CTX_dup(ctx); unsigned char digest[EVP_MAX_MD_SIZE]; size_t length=0;
        ok=copy&&EVP_MAC_final(copy,digest,&length,sizeof(digest))>0;
        if(ok) string(out,digest,length); OPENSSL_cleanse(digest,sizeof(digest)); EVP_MAC_CTX_free(copy);
    } else { error(out,"NotImplementedError","unknown HMAC operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
static void kdf_call(const char *op,const arg *args,buffer *out) {
    long long length=num(at(args,2));
    if(length<0||length>WIRE_LIMIT-128) { error(out,"ArgumentError","invalid derived key length"); return; }
    const arg *password=at(args,0),*salt=at(args,1);
    if(password->type!='s'||salt->type!='s') { error(out,"TypeError","KDF inputs must be Strings"); return; }
    unsigned char *result=OPENSSL_malloc(length?length:1); int ok=0;
    if(!result) { error(out,"NoMemoryError","KDF output allocation failed"); return; }
    if(!strcmp(op,"pbkdf2")) {
        EVP_MD *md=EVP_MD_fetch(NULL,str(at(args,4)),NULL);
        long long count=num(at(args,3));
        ok=md&&count>0&&count<=INT_MAX&&PKCS5_PBKDF2_HMAC(password->s,(int)password->len,(unsigned char *)salt->s,(int)salt->len,(int)count,md,(int)length,result)>0;
        EVP_MD_free(md);
    } else if(!strcmp(op,"scrypt")) {
        ok=EVP_PBE_scrypt(password->s,password->len,(unsigned char *)salt->s,salt->len,
            (uint64_t)num(at(args,3)),(uint64_t)num(at(args,4)),(uint64_t)num(at(args,5)),128*1024*1024,result,(size_t)length)>0;
    } else if(!strcmp(op,"hkdf")) {
        EVP_PKEY_CTX *ctx=EVP_PKEY_CTX_new_id(EVP_PKEY_HKDF,NULL); EVP_MD *md=EVP_MD_fetch(NULL,str(at(args,4)),NULL);
        const arg *info=at(args,3); size_t n=(size_t)length;
        ok=ctx&&md&&info->type=='s'&&EVP_PKEY_derive_init(ctx)>0&&EVP_PKEY_CTX_set_hkdf_md(ctx,md)>0&&
            EVP_PKEY_CTX_set1_hkdf_salt(ctx,(unsigned char *)salt->s,(int)salt->len)>0&&
            EVP_PKEY_CTX_set1_hkdf_key(ctx,(unsigned char *)password->s,(int)password->len)>0&&
            EVP_PKEY_CTX_add1_hkdf_info(ctx,(unsigned char *)info->s,(int)info->len)>0&&EVP_PKEY_derive(ctx,result,&n)>0;
        EVP_PKEY_CTX_free(ctx); EVP_MD_free(md);
    }
    if(ok) string(out,result,(size_t)length); else ssl_error(out,"OpenSSL::KDF::KDFError",op);
    OPENSSL_clear_free(result,(size_t)length);
}
static void free_provider(void *p) { OSSL_PROVIDER_unload(p); }
static int provider_list(OSSL_PROVIDER *provider,void *ptr) {
    name_collection *names=ptr; text(&names->entries,OSSL_PROVIDER_get0_name(provider)); names->count++; return 1;
}
static void provider_call(const char *op,const arg *args,buffer *out) {
    if(!strcmp(op,"list")) {
        name_collection names={0}; OSSL_PROVIDER_do_all(NULL,provider_list,&names);
        byte(out,'a'); number(out,names.count); put(out,names.entries.p,names.entries.len); free(names.entries.p); return;
    }
    if(!strcmp(op,"load")) {
        const arg *name=at(args,0); OSSL_PROVIDER *provider=NULL;
        if(name->type=='s'&&!memchr(name->s,0,name->len)) provider=OSSL_PROVIDER_load(NULL,name->s);
        if(provider) object_result(out,own(provider,NK_PROVIDER,"OpenSSL::Provider",free_provider,NULL));
        else ssl_error(out,"OpenSSL::Provider::ProviderError","OSSL_PROVIDER_load"); return;
    }
    native_slot *slot=lookup(num(at(args,0)),NK_PROVIDER);
    if(!slot) { error(out,"OpenSSL::Provider::ProviderError","provider was unloaded"); return; }
    if(!strcmp(op,"name")) text(out,OSSL_PROVIDER_get0_name(slot->ptr));
    else error(out,"NotImplementedError","unknown provider operation");
}
