/* libcrypto/libssl boundary. Only copied bytes and checked object IDs cross
 * this ABI; no Ruby/Mere pointer is kept by OpenSSL. The returned bytes are
 * borrowed until the next call and must be copied immediately by the VM. */
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/bn.h>
#include <openssl/evp.h>
#include <stdint.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct mere_bytes { long long len; unsigned char data[]; };
typedef struct mere_bytes mere_bytes;
enum { WIRE_LIMIT = 64 * 1024 * 1024, NODE_LIMIT = 1048576 };
typedef struct arg { char type; size_t len; char *s; struct arg *items; } arg;
typedef struct buffer { unsigned char *p; size_t len, cap; } buffer;
static mere_bytes *result;
static size_t result_cap;

static int reserve(buffer *b, size_t n) {
    if (n > WIRE_LIMIT || b->len > WIRE_LIMIT - n) return 0;
    if (b->len + n > b->cap) {
        size_t cap = b->cap ? b->cap : 256;
        while (cap < b->len + n) cap *= 2;
        void *p = realloc(b->p, cap);
        if (!p) return 0;
        b->p = p; b->cap = cap;
    }
    return 1;
}
static void put(buffer *b, const void *p, size_t n) {
    if (!reserve(b,n)) abort();
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
    b->len=0; byte(b,'e'); text(b,klass); text(b,message);
    ERR_clear_error();
}
static void ssl_error(buffer *b, const char *klass, const char *operation) {
    unsigned long code;
    char detail[256]="", message[512];
    while ((code=ERR_get_error())) ERR_error_string_n(code,detail,sizeof(detail));
    snprintf(message,sizeof(message),"%s%s%s",operation,detail[0]?": ":"",detail);
    error(b,klass,message);
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
    if (*p==end || depth>64 || ++*nodes>NODE_LIMIT) return 0;
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
    if(a->len>NODE_LIMIT || a->len>(size_t)(end-*p)) return 0;
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
    if(args->len>1 && at(args,1)->type!='n') b=bn_arg(at(args,1));
    if(args->len>2 && at(args,2)->type!='n') c=bn_arg(at(args,2));
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

static void dispatch(const char *op,const arg *args,buffer *out) {
    if(!strcmp(op,"version")) { text(out,OpenSSL_version(OPENSSL_VERSION)); return; }
    if(!strcmp(op,"version_number")) { integer(out,(long long)OpenSSL_version_num()); return; }
    if(!strcmp(op,"errors")) {
        buffer entries={0}; uint32_t n=0; unsigned long code; char message[256];
        while((code=ERR_get_error())) { ERR_error_string_n(code,message,sizeof(message)); text(&entries,message); n++; }
        byte(out,'a'); number(out,n); put(out,entries.p,entries.len); free(entries.p); return;
    }
    if(!strncmp(op,"bn.",3)) { bn_call(op+3,args,out); return; }
    error(out,"NotImplementedError","unknown native OpenSSL operation");
}

int mr_ossl_available(void) { return 1; }
mere_bytes *mr_ossl_call(const char *operation,mere_bytes *input) {
    buffer out={0}; arg args={0}; size_t nodes=0;
    if(!input||input->len<0||input->len>WIRE_LIMIT) {
        error(&out,"ArgumentError","provider request too large");
    } else {
        const unsigned char *p=input->data,*end=p+(size_t)input->len;
        if(!parse_arg(&p,end,&args,0,&nodes)||p!=end||args.type!='a') error(&out,"ArgumentError","invalid provider wire request");
        else dispatch(operation,&args,&out);
    }
    free_arg(&args);
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
