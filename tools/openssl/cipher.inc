typedef struct cipher_context { EVP_CIPHER_CTX *ctx; int keyed,tag_length; } cipher_context;
static void cipher_free(void *ptr) { cipher_context *cipher=ptr; EVP_CIPHER_CTX_free(cipher->ctx); free(cipher); }
static void *cipher_copy(const void *ptr) {
    const cipher_context *source=ptr; cipher_context *copy=calloc(1,sizeof(*copy)); if(!copy) return NULL;
    copy->ctx=EVP_CIPHER_CTX_new(); copy->keyed=source->keyed; copy->tag_length=source->tag_length;
    if(!copy->ctx||!EVP_CIPHER_CTX_copy(copy->ctx,source->ctx)) { cipher_free(copy); return NULL; } return copy;
}
static void cipher_list_name(const OBJ_NAME *name,void *ptr) {
    name_collection *names=ptr; text(&names->entries,name->name); names->count++;
}
static void cipher_list_fetched(EVP_CIPHER *cipher,void *ptr) {
    name_collection *names=ptr; text(&names->entries,EVP_CIPHER_get0_name(cipher)); names->count++;
}
static void cipher_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::Cipher::CipherError";
    if(!strcmp(op,"list")) {
        name_collection names={0}; OBJ_NAME_do_all_sorted(OBJ_NAME_TYPE_CIPHER_METH,cipher_list_name,&names);
        EVP_CIPHER_do_all_provided(NULL,cipher_list_fetched,&names);
        byte(out,'a'); number(out,names.count); put(out,names.entries.p,names.entries.len); free(names.entries.p); return;
    }
    if(!strcmp(op,"new")) {
        const arg *name=at(args,0);
        if(name->type!='s'||memchr(name->s,0,name->len)) { error(out,"TypeError","invalid cipher name"); return; }
        EVP_CIPHER *algorithm=EVP_CIPHER_fetch(NULL,name->s,NULL);
        cipher_context *cipher=calloc(1,sizeof(*cipher));
        if(cipher) { cipher->ctx=EVP_CIPHER_CTX_new(); cipher->tag_length=16; }
        int ok=algorithm&&cipher&&cipher->ctx;
        if(ok) { EVP_CIPHER_CTX_set_flags(cipher->ctx,EVP_CIPHER_CTX_FLAG_WRAP_ALLOW); ok=EVP_CipherInit_ex(cipher->ctx,algorithm,NULL,NULL,NULL,-1)>0; }
        EVP_CIPHER_free(algorithm);
        if(ok) object_result(out,own(cipher,NK_CIPHER,"OpenSSL::Backend::CipherContext",cipher_free,cipher_copy));
        else { if(cipher) cipher_free(cipher); ssl_error(out,klass,"unsupported cipher algorithm"); } return;
    }
    native_slot *slot=lookup(num(at(args,0)),NK_CIPHER);
    if(!slot) { error(out,"RuntimeError","Cipher not initialized!"); return; }
    cipher_context *cipher=slot->ptr; EVP_CIPHER_CTX *ctx=cipher->ctx;
    const arg *value=at(args,1); int ok=1;
    int aead=(EVP_CIPHER_get_flags(EVP_CIPHER_CTX_get0_cipher(ctx))&EVP_CIPH_FLAG_AEAD_CIPHER)!=0;
    if(!strcmp(op,"info")) {
        const EVP_CIPHER *algorithm=EVP_CIPHER_CTX_get0_cipher(ctx); int nid=EVP_CIPHER_get_nid(algorithm);
        const char *name=nid==NID_undef?EVP_CIPHER_get0_name(algorithm):OBJ_nid2sn(nid);
        byte(out,'a'); number(out,5); text(out,name); integer(out,EVP_CIPHER_CTX_get_key_length(ctx)); integer(out,EVP_CIPHER_CTX_get_iv_length(ctx)); integer(out,EVP_CIPHER_CTX_get_block_size(ctx)); boolean(out,aead);
    } else if(!strcmp(op,"encrypt")||!strcmp(op,"decrypt")) {
        ok=EVP_CipherInit_ex(ctx,NULL,NULL,NULL,NULL,!strcmp(op,"encrypt")); cipher->keyed=0;
    } else if(!strcmp(op,"reset")) ok=EVP_CipherInit_ex(ctx,NULL,NULL,NULL,NULL,-1);
    else if(!strcmp(op,"set_padding")) ok=EVP_CIPHER_CTX_set_padding(ctx,truth(value));
    else if(!strcmp(op,"set_key_length")) ok=EVP_CIPHER_CTX_set_key_length(ctx,(int)num(value));
    else if(!strcmp(op,"set_iv_length")) ok=aead&&EVP_CIPHER_CTX_ctrl(ctx,EVP_CTRL_AEAD_SET_IVLEN,(int)num(value),NULL)>0;
    else if(!strcmp(op,"set_key")||!strcmp(op,"set_iv")) {
        int key=!strcmp(op,"set_key"),n=key?EVP_CIPHER_CTX_get_key_length(ctx):EVP_CIPHER_CTX_get_iv_length(ctx);
        if(value->type!='s') { error(out,"TypeError","key and IV must be Strings"); return; }
        if(value->len!=(size_t)n) { error(out,"ArgumentError",key?"key must have the expected length":"iv must have the expected length"); return; }
        ok=EVP_CipherInit_ex(ctx,NULL,NULL,key?(unsigned char *)value->s:NULL,key?NULL:(unsigned char *)value->s,-1);
        if(ok&&key) cipher->keyed=1;
    } else if(!strcmp(op,"auth_tag_length")) {
        long long n=num(value); ok=aead&&n>0&&n<=16&&EVP_CIPHER_CTX_ctrl(ctx,EVP_CTRL_AEAD_SET_TAG,(int)n,NULL)>0;
        if(ok) cipher->tag_length=(int)n;
    } else if(!strcmp(op,"set_auth_tag")) {
        ok=aead&&value->type=='s'&&value->len>0&&value->len<=16&&EVP_CIPHER_CTX_ctrl(ctx,EVP_CTRL_AEAD_SET_TAG,(int)value->len,value->s)>0;
        if(ok) cipher->tag_length=(int)value->len;
    } else if(!strcmp(op,"auth_tag")) {
        int length=value->type=='n'?cipher->tag_length:(int)num(value); unsigned char tag[16];
        ok=aead&&length>0&&length<=16&&EVP_CIPHER_CTX_ctrl(ctx,EVP_CTRL_AEAD_GET_TAG,length,tag)>0;
        if(ok) string(out,tag,(size_t)length); OPENSSL_cleanse(tag,sizeof(tag));
    } else if(!strcmp(op,"auth_data")) {
        int n=0; ok=aead&&value->type=='s'&&EVP_CipherUpdate(ctx,NULL,&n,(unsigned char *)value->s,(int)value->len)>0;
    } else if(!strcmp(op,"ccm_data_length")) {
        int n=0; long long length=num(value); ok=aead&&length>=0&&length<=INT_MAX&&EVP_CipherUpdate(ctx,NULL,&n,NULL,(int)length)>0;
    } else if(!strcmp(op,"update")||!strcmp(op,"final")) {
        if(!cipher->keyed) { error(out,klass,"key not set"); return; }
        int final=!strcmp(op,"final");
        if(!final&&value->type!='s') { error(out,"TypeError","cipher data must be a String"); return; }
        if(!final&&!value->len) { error(out,"ArgumentError","data must not be empty"); return; }
        size_t capacity=(final?0:value->len)+(size_t)EVP_CIPHER_CTX_get_block_size(ctx)+32;
        if(capacity>WIRE_LIMIT-128) { error(out,"RangeError","cipher input exceeds wire budget"); return; }
        unsigned char *data=OPENSSL_malloc(capacity); int length=0;
        if(!data) { error(out,"NoMemoryError","cipher output allocation failed"); return; }
        ok=final?EVP_CipherFinal_ex(ctx,data,&length):EVP_CipherUpdate(ctx,data,&length,(unsigned char *)value->s,(int)value->len);
        if(ok) string(out,data,(size_t)length);
        else if(final&&aead&&!EVP_CIPHER_CTX_is_encrypting(ctx)) klass="OpenSSL::Cipher::AuthTagError";
        OPENSSL_clear_free(data,capacity);
    } else if(!strcmp(op,"pkcs5_keyivgen")) {
        const arg *salt=at(args,2),*count=at(args,3),*hash=at(args,4);
        long long iterations=num(count);
        if(value->type!='s'||(salt->type!='n'&&(salt->type!='s'||salt->len!=8))||iterations<=0||iterations>INT_MAX) { error(out,"ArgumentError","invalid password, salt or iteration count"); return; }
        unsigned char key[EVP_MAX_KEY_LENGTH]={0},iv[EVP_MAX_IV_LENGTH]={0};
        if(EVP_CIPHER_CTX_get_key_length(ctx)>EVP_MAX_KEY_LENGTH||EVP_CIPHER_CTX_get_iv_length(ctx)>EVP_MAX_IV_LENGTH) {
            error(out,klass,"password derivation is unavailable with this key or IV length"); return;
        }
        EVP_MD *md=EVP_MD_fetch(NULL,str(hash),NULL);
        ok=md&&EVP_BytesToKey(EVP_CIPHER_CTX_get0_cipher(ctx),md,salt->type=='n'?NULL:(unsigned char *)salt->s,(unsigned char *)value->s,(int)value->len,(int)iterations,key,iv)>0&&
            EVP_CipherInit_ex(ctx,NULL,NULL,key,iv,-1)>0;
        if(ok) cipher->keyed=1;
        EVP_MD_free(md); OPENSSL_cleanse(key,sizeof(key)); OPENSSL_cleanse(iv,sizeof(iv));
    } else { error(out,"NotImplementedError","unknown cipher operation"); return; }
    if(!ok) ssl_error(out,klass,op); else if(!out->len) byte(out,'n');
}
