/* libcrypto/libssl boundary. Only copied bytes and checked object IDs cross
 * this ABI; no Ruby/Mere pointer is kept by OpenSSL. The returned bytes are
 * borrowed until the next call and must be copied immediately by the VM. */
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/bn.h>
#include <openssl/evp.h>
#include <openssl/decoder.h>
#include <openssl/encoder.h>
#include <openssl/core_names.h>
#include <openssl/pem.h>
#include <openssl/ec.h>
#include <openssl/provider.h>
#include <openssl/x509v3.h>
#include <openssl/conf.h>
#include <openssl/kdf.h>
#include <openssl/pkcs12.h>
#include <openssl/ocsp.h>
#include <openssl/ts.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>
#include <stdint.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>

struct mere_bytes { long long len; unsigned char data[]; };
typedef struct mere_bytes mere_bytes;
enum { WIRE_LIMIT = 64 * 1024 * 1024, NODE_LIMIT = 1048576 };
typedef struct arg { char type; size_t len; char *s; struct arg *items; } arg;
typedef struct buffer { unsigned char *p; size_t len, cap; int failed,raised; } buffer;
static mere_bytes *result;
static size_t result_cap;

static int reserve(buffer *b, size_t n) {
    if (b->failed) return 0;
    if (n > WIRE_LIMIT || b->len > WIRE_LIMIT - n) { b->failed=1; return 0; }
    if (b->len + n > b->cap) {
        size_t cap = b->cap ? b->cap : 256;
        while (cap < b->len + n) cap *= 2;
        void *p = realloc(b->p, cap);
        if (!p) { b->failed=2; return 0; }
        b->p = p; b->cap = cap;
    }
    return 1;
}
static void put(buffer *b, const void *p, size_t n) {
    if(b->raised) return;
    if (!reserve(b,n)) return;
    if(n) memcpy(b->p+b->len,p,n); b->len+=n;
}
static void byte(buffer *b, char c) { put(b,&c,1); }
static void number(buffer *b, uint32_t n) {
    unsigned char p[4] = {n>>24,n>>16,n>>8,n}; put(b,p,4);
}
static void string(buffer *b, const void *p, size_t n) {
    byte(b,'s'); number(b,(uint32_t)n); put(b,p,n);
}
static void text(buffer *b, const char *p) { string(b,p,strlen(p)); }
static void integer(buffer *b, long long n) {
    char buf[64]; int size=snprintf(buf,sizeof(buf),"%lld",n);
    byte(b,'i'); number(b,(uint32_t)size); put(b,buf,(size_t)size);
}
static void boolean(buffer *b, int truth) { byte(b,truth?'t':'f'); }
static void error(buffer *b, const char *klass, const char *message) {
    if(b->raised) { ERR_clear_error(); return; }
    b->len=0; b->failed=0; byte(b,'e'); text(b,klass); text(b,message);
    b->raised=1;
    ERR_clear_error();
}
static void ssl_error(buffer *b, const char *klass, const char *operation) {
    if(b->raised) { ERR_clear_error(); return; }
    unsigned long code;
    char detail[768]="", message[1024]; buffer errors={0}; uint32_t count=0;
    const char *data=NULL; int flags=0;
    while ((code=ERR_get_error_all(NULL,NULL,NULL,&data,&flags))) {
        char base[256]; ERR_error_string_n(code,base,sizeof(base));
        snprintf(detail,sizeof(detail),"%s%s%s%s",base,(flags&ERR_TXT_STRING)&&data?" (":"",(flags&ERR_TXT_STRING)&&data?data:"",(flags&ERR_TXT_STRING)&&data?")":"");
        text(&errors,detail); count++;
    }
    snprintf(message,sizeof(message),"%s%s%s",operation,detail[0]?": ":"",detail);
    b->len=0; b->failed=0; byte(b,'E'); text(b,klass); text(b,message);
    byte(b,'a'); number(b,count); put(b,errors.p,errors.len); free(errors.p);
    b->raised=1;
    ERR_clear_error();
}

static int read32(const unsigned char **p, const unsigned char *end, uint32_t *n) {
    if ((size_t)(end-*p)<4) return 0;
    *n=((uint32_t)(*p)[0]<<24)|((uint32_t)(*p)[1]<<16)|((uint32_t)(*p)[2]<<8)|(*p)[3];
    *p+=4; return 1;
}
static void free_arg(arg *a) {
    if (a->items) {
        for(size_t i=0;i<a->len;i++) free_arg(&a->items[i]);
        free(a->items);
    }
    if (a->s) { OPENSSL_cleanse(a->s,a->len); free(a->s); }
    memset(a,0,sizeof(*a));
}
static int parse_arg(const unsigned char **p,const unsigned char *end,arg *a,int depth,size_t *nodes) {
    if (*p==end || depth>64) return 0;
    a->type=(char)*(*p)++;
    if (a->type=='n'||a->type=='t'||a->type=='f') return 1;
    uint32_t n;
    if (!read32(p,end,&n)) return 0;
    a->len=n;
    if (a->type=='s'||a->type=='i') {
        if ((size_t)(end-*p)<n) return 0;
        a->s=malloc((size_t)n+1); if(!a->s) return 0;
        memcpy(a->s,*p,n); a->s[n]=0; *p+=n; return 1;
    }
    if(a->type!='a'&&a->type!='m') return 0;
    if (a->type=='m') a->len*=2;
    /* Reserve every declared child before allocating: counting only parsed
     * nodes lets nested malformed arrays allocate the budget at each depth. */
    if(a->len>NODE_LIMIT-*nodes || a->len>(size_t)(end-*p)) return 0;
    *nodes+=a->len;
    a->items=calloc(a->len?a->len:1,sizeof(arg));
    if(!a->items) return 0;
    for(size_t i=0;i<a->len;i++) if(!parse_arg(p,end,&a->items[i],depth+1,nodes)) return 0;
    return 1;
}
static const arg missing={.type='n'};
static const arg *at(const arg *a,size_t i) { return a->type=='a'&&i<a->len?&a->items[i]:&missing; }
static int truth(const arg *a) { return a->type!='n'&&a->type!='f'; }
static const char *str(const arg *a) { return (a->type=='s'||a->type=='i')?a->s:""; }
static long long num(const arg *a) { return strtoll(str(a),NULL,10); }
static int count(const arg *a,size_t low,size_t high,buffer *b) {
    if(a->type=='a'&&a->len>=low&&a->len<=high) return 1;
    error(b,"ArgumentError","invalid provider argument count"); return 0;
}
static BIGNUM *bn_arg(const arg *a) {
    const char *s=str(a), *digits=s;
    if(a->s && memchr(a->s,0,a->len)) return NULL;
    if(*digits=='-') digits++;
    if(!*digits) return NULL;
    for(const char *p=digits;*p;p++) if(*p<'0'||*p>'9') return NULL;
    BIGNUM *n=NULL;
    if(!BN_dec2bn(&n,s)) return NULL;
    return n;
}
static void bn_result(buffer *out,const BIGNUM *n) {
    char *s=BN_bn2dec(n);
    if(!s) { ssl_error(out,"OpenSSL::BNError","BN_bn2dec"); return; }
    text(out,s); OPENSSL_clear_free(s,strlen(s));
}

static void bn_call(const char *op,const arg *args,buffer *out) {
    if(!count(args,1,5,out)) return;
    BIGNUM *a=bn_arg(at(args,0)),*b=NULL,*c=NULL,*r=BN_new(),*rem=BN_new();
    BN_CTX *ctx=BN_CTX_new();
    int ok=0, answer=-1;
    if(!a||!r||!rem||!ctx) goto done;
    const arg *flags=at(args,args->len-1);
    size_t argc=args->len-(flags->type=='a'?1:0);
    if(argc>1 && at(args,1)->type!='n') b=bn_arg(at(args,1));
    if(argc>2 && at(args,2)->type!='n') c=bn_arg(at(args,2));
    if(flags->type=='a') {
        BN_set_flags(a,(int)num(at(flags,0)));
        if(b) BN_set_flags(b,(int)num(at(flags,1)));
        if(c) BN_set_flags(c,(int)num(at(flags,2)));
    }
    if(!strcmp(op,"sqr")) ok=BN_sqr(r,a,ctx);
    else if(!strcmp(op,"add")&&b) ok=BN_add(r,a,b);
    else if(!strcmp(op,"sub")&&b) ok=BN_sub(r,a,b);
    else if(!strcmp(op,"mul")&&b) ok=BN_mul(r,a,b,ctx);
    else if(!strcmp(op,"div")&&b) {
        ok=BN_div(r,rem,a,b,ctx);
        if(ok) { byte(out,'a'); number(out,2); bn_result(out,r); bn_result(out,rem); }
        goto done;
    }
    else if(!strcmp(op,"mod")&&b) ok=BN_mod(r,a,b,ctx);
    else if(!strcmp(op,"exp")&&b) ok=BN_exp(r,a,b,ctx);
    else if(!strcmp(op,"gcd")&&b) ok=BN_gcd(r,a,b,ctx);
    else if(!strcmp(op,"mod_sqr")&&b) ok=BN_mod_sqr(r,a,b,ctx);
    else if(!strcmp(op,"mod_sqrt")&&b) ok=BN_mod_sqrt(r,a,b,ctx)!=NULL;
    else if(!strcmp(op,"mod_inverse")&&b) ok=BN_mod_inverse(r,a,b,ctx)!=NULL;
    else if(!strcmp(op,"mod_add")&&b&&c) ok=BN_mod_add(r,a,b,c,ctx);
    else if(!strcmp(op,"mod_sub")&&b&&c) ok=BN_mod_sub(r,a,b,c,ctx);
    else if(!strcmp(op,"mod_mul")&&b&&c) ok=BN_mod_mul(r,a,b,c,ctx);
    else if(!strcmp(op,"mod_exp")&&b&&c) {
        if(num(at(args,3))) BN_set_flags(a,BN_FLG_CONSTTIME);
        if(num(at(args,4))) BN_set_flags(b,BN_FLG_CONSTTIME);
        ok=BN_mod_exp(r,a,b,c,ctx);
    }
    else if(!strcmp(op,"prime")) { answer=BN_check_prime(a,ctx,NULL); ok=answer>=0; boolean(out,answer==1); goto done; }
    else if(!strcmp(op,"generate_prime")) {
        int bits=BN_get_word(a);
        ok=bits>1 && bits<=16384 && BN_generate_prime_ex(r,bits,truth(at(args,1)),c,
            args->len>3 ? (BN_free(rem),rem=bn_arg(at(args,3))) : NULL,NULL);
    }
    else if(!strcmp(op,"rand")) {
        long long bits=num(at(args,0)),top=num(at(args,1));
        ok=bits>=0&&bits<=WIRE_LIMIT*8LL&&top>=-1&&top<=1&&BN_rand(r,(int)bits,(int)top,truth(at(args,2)));
    }
    else if(!strcmp(op,"rand_range")) ok=BN_rand_range(r,a);
    if(ok) bn_result(out,r);
done:
    if(!ok) ssl_error(out,"OpenSSL::BNError",op);
    BN_clear_free(a); BN_clear_free(b); BN_clear_free(c); BN_clear_free(r); BN_clear_free(rem); BN_CTX_free(ctx);
}

#include "openssl/registry.inc"
#include "openssl/pkey.inc"
#include "openssl/x509.inc"
#include "openssl/x509_constants.inc"
#include "openssl/x509_store.inc"
#include "openssl/config.inc"
#include "openssl/pkcs12.inc"
#include "openssl/pkcs7.inc"
#include "openssl/ocsp.inc"
#include "openssl/ts.inc"
#include "openssl/ns_spki.inc"
#include "openssl/tls_types.inc"
#include "openssl/tls_callbacks.inc"
#include "openssl/tls_worker.inc"
#include "openssl/tls_context.inc"
#include "openssl/tls_socket.inc"
#include "openssl/tls_constants.inc"
#include "openssl/primitives.inc"
#include "openssl/cipher.inc"

static void dispatch(const char *op,const arg *args,buffer *out) {
    if(!strncmp(op,"spki.",5)) { spki_call(op+5,args,out); return; }
    if(!strncmp(op,"ts.",3)) { ts_call(op+3,args,out); return; }
    if(!strncmp(op,"ocsp.",5)) { ocsp_call(op+5,args,out); return; }
    if(!strncmp(op,"pkcs7.",6)) { pkcs7_call(op+6,args,out); return; }
    if(!strncmp(op,"p7si.",5)) { p7si_call(op+5,args,out); return; }
    if(!strncmp(op,"p7ri.",5)) { p7ri_call(op+5,args,out); return; }
    if(!strncmp(op,"pkcs12.",7)) { pkcs12_call(op+7,args,out); return; }
    if(!strcmp(op,"version")) { text(out,OpenSSL_version(OPENSSL_VERSION)); return; }
    if(!strcmp(op,"version_number")) { integer(out,(long long)OpenSSL_version_num()); return; }
    if(!strcmp(op,"errors")) {
        buffer entries={0}; uint32_t n=0; unsigned long code; char message[256];
        while((code=ERR_get_error())) { ERR_error_string_n(code,message,sizeof(message)); text(&entries,message); n++; }
        byte(out,'a'); number(out,n); put(out,entries.p,entries.len); free(entries.p); return;
    }
    if(!strncmp(op,"bn.",3)) { bn_call(op+3,args,out); return; }
    if(!strncmp(op,"object.",7)) { object_call(op+7,args,out); return; }
    if(!strncmp(op,"pkey.",5)) { pkey_call(op+5,args,out); return; }
    if(!strncmp(op,"keygen.",7)) { keygen_call(op+7,args,out); return; }
    if(!strncmp(op,"ec_group.",9)) { ec_group_call(op+9,args,out); return; }
    if(!strncmp(op,"ec_point.",9)) { ec_point_call(op+9,args,out); return; }
    if(!strncmp(op,"xname.",6)) { x509_name_call(op+6,args,out); return; }
    if(!strncmp(op,"xext.",5)) { x509_extension_call(op+5,args,out); return; }
    if(!strncmp(op,"xcert.",6)) { x509_certificate_call(op+6,args,out); return; }
    if(!strncmp(op,"xreq.",5)) { x509_request_call(op+5,args,out); return; }
    if(!strncmp(op,"xcrl.",5)) { x509_crl_call(op+5,args,out); return; }
    if(!strncmp(op,"xrev.",5)) { x509_revoked_call(op+5,args,out); return; }
    if(!strncmp(op,"xstore.",7)) { x509_store_call(op+7,args,out); return; }
    if(!strncmp(op,"xctx.",5)) { x509_context_call(op+5,args,out); return; }
    if(!strcmp(op,"x509.constants")) { x509_constants(out); return; }
    if(!strncmp(op,"config.",7)) { config_call(op+7,args,out); return; }
    if(!strcmp(op,"tls.constants")) { tls_constants(out); return; }
    if(!strcmp(op,"tls.npn_available")) {
#ifdef OPENSSL_NO_NEXTPROTONEG
        boolean(out,0);
#else
        boolean(out,1);
#endif
        return;
    }
    if(!strncmp(op,"tls_context.",12)) { tls_context_call(op+12,args,out); return; }
    if(!strncmp(op,"tls_socket.",11)) { tls_socket_call(op+11,args,out); return; }
    if(!strncmp(op,"tls_job.",8)) { tls_job_call(op+8,args,out); return; }
    if(!strncmp(op,"tls_session.",12)) { tls_session_call(op+12,args,out); return; }
    if(!strncmp(op,"digest.",7)) { digest_call(op+7,args,out); return; }
    if(!strncmp(op,"hmac.",5)) { hmac_call(op+5,args,out); return; }
    if(!strncmp(op,"kdf.",4)) { kdf_call(op+4,args,out); return; }
    if(!strncmp(op,"provider.",9)) { provider_call(op+9,args,out); return; }
    if(!strncmp(op,"cipher.",7)) { cipher_call(op+7,args,out); return; }
    if(!strcmp(op,"oid.register")) {
        if(!count(args,3,3,out)) return;
        const arg *oid=at(args,0),*sn=at(args,1),*ln=at(args,2);
        if(oid->type!='s'||sn->type!='s'||ln->type!='s'||memchr(oid->s,0,oid->len)||memchr(sn->s,0,sn->len)||memchr(ln->s,0,ln->len))
            error(out,"OpenSSL::ASN1::ASN1Error","invalid OID name");
        else if(OBJ_create(oid->s,sn->s,ln->s)==NID_undef) ssl_error(out,"OpenSSL::ASN1::ASN1Error","OBJ_create");
        else boolean(out,1);
        return;
    }
    if(!strcmp(op,"fips_mode")) { boolean(out,EVP_default_properties_is_fips_enabled(NULL)); return; }
    if(!strcmp(op,"set_fips_mode")) {
        if(EVP_default_properties_enable_fips(NULL,truth(at(args,0)))) byte(out,'n');
        else ssl_error(out,"OpenSSL::OpenSSLError","setting FIPS mode failed");
        return;
    }
    error(out,"NotImplementedError","unknown native OpenSSL operation");
}

int mr_ossl_available(void) { return 1; }
int mr_ossl_valid(int id) { return lookup(id,0)!=NULL; }
int mr_ossl_release(int id) { return release(id); }
int mr_ossl_clear_result(void) {
    if(result&&result->len>0) { OPENSSL_cleanse(result->data,(size_t)result->len); result->len=0; }
    return 0;
}
mere_bytes *mr_ossl_call(const char *operation,mere_bytes *input) {
    mr_ossl_clear_result();
    request_created_count=0; request_active=1;
    buffer out={0}; arg args={0}; size_t nodes=1;
    if(!input||input->len<0||input->len>WIRE_LIMIT) {
        error(&out,"ArgumentError","provider request too large");
    } else {
        const unsigned char *p=input->data,*end=p+(size_t)input->len;
        if(!parse_arg(&p,end,&args,0,&nodes)||p!=end||args.type!='a') error(&out,"ArgumentError","invalid provider wire request");
        else dispatch(operation,&args,&out);
    }
    free_arg(&args);
    if(out.failed) {
        int memory=out.failed==2;
        error(&out,memory?"NoMemoryError":"RangeError",memory?"native provider allocation failed":"native provider response exceeds wire budget");
    }
    request_active=0;
    if(out.len&&(out.p[0]=='e'||out.p[0]=='E')) {
        for(int i=request_created_count-1;i>=0;i--) release(request_created[i]);
        ERR_clear_error();
    }
    if(result_cap<out.len || (result_cap>8*1024*1024 && out.len<4096)) {
        size_t cap=out.len<4096?4096:out.len;
        void *p=realloc(result,sizeof(mere_bytes)+cap); if(!p) abort();
        result=p; result_cap=cap;
    }
    result->len=(long long)out.len;
    if(out.len) memcpy(result->data,out.p,out.len);
    if(out.p) { OPENSSL_cleanse(out.p,out.len); free(out.p); }
    return result;
}
