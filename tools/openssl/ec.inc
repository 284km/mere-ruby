/* Ruby/OpenSSL exposes the legacy EC parameter serializers as public Group
 * methods. Keep their exact formatting while using EVP for key operations. */
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif
typedef struct native_group { EC_GROUP *value; unsigned refs; } native_group;
typedef struct native_point { native_group *group; EC_POINT *value; } native_point;
static native_group *make_group(EC_GROUP *value) {
    if(!value) return NULL;
    native_group *g=malloc(sizeof(*g));
    if(!g) { EC_GROUP_free(value); return NULL; }
    g->value=value; g->refs=1; return g;
}
static native_group *retain_group(native_group *g) { if(g) g->refs++; return g; }
static void free_group(void *ptr) {
    native_group *g=ptr; if(!--g->refs) { EC_GROUP_free(g->value); free(g); }
}
static void *copy_group(const void *ptr) { return make_group(EC_GROUP_dup(((const native_group *)ptr)->value)); }
static int own_group(native_group *g) { return own(g,NK_GROUP,"OpenSSL::PKey::EC::Group",free_group,copy_group); }
static native_group *group_arg(const arg *a,buffer *out) {
    native_slot *s=lookup(num(a),NK_GROUP);
    if(!s) error(out,"TypeError","EC group wasn't initialized");
    return s?s->ptr:NULL;
}
static native_point *make_point(native_group *group,EC_POINT *value) {
    if(!value) return NULL;
    native_point *p=malloc(sizeof(*p));
    if(!p) { EC_POINT_free(value); return NULL; }
    p->group=retain_group(group); p->value=value; return p;
}
static void free_point(void *ptr) {
    native_point *p=ptr; EC_POINT_clear_free(p->value); free_group(p->group); free(p);
}
static void *copy_point(const void *ptr) {
    const native_point *p=ptr;
    return make_point(p->group,EC_POINT_dup(p->value,p->group->value));
}
static int own_point(native_point *p) { return own(p,NK_POINT,"OpenSSL::PKey::EC::Point",free_point,copy_point); }
static native_point *point_arg(const arg *a,buffer *out) {
    native_slot *s=lookup(num(a),NK_POINT);
    if(!s) error(out,"TypeError","EC point wasn't initialized");
    return s?s->ptr:NULL;
}
static native_group *key_group(EVP_PKEY *key,buffer *out) {
    unsigned char *data=NULL;
    int n=i2d_KeyParams(key,&data);
    const unsigned char *p=data;
    EC_GROUP *group=n>0?d2i_ECPKParameters(NULL,&p,n):NULL;
    OPENSSL_free(data);
    if(!group) { ssl_error(out,"OpenSSL::PKey::PKeyError","EC group"); return NULL; }
    char form[32]; size_t size=0;
    if(EVP_PKEY_get_utf8_string_param(key,OSSL_PKEY_PARAM_EC_POINT_CONVERSION_FORMAT,form,sizeof(form),&size)>0) {
        EC_GROUP_set_point_conversion_form(group,!strcmp(form,"compressed")?POINT_CONVERSION_COMPRESSED:!strcmp(form,"hybrid")?POINT_CONVERSION_HYBRID:POINT_CONVERSION_UNCOMPRESSED);
    } else ERR_clear_error();
    return make_group(group);
}
static void ec_key_group(EVP_PKEY *key,buffer *out) {
    native_group *group=key_group(key,out);
    if(group) object_result(out,own_group(group));
}
static void ec_key_point(EVP_PKEY *key,buffer *out) {
    native_group *group=key_group(key,out); if(!group) return;
    size_t size=0; unsigned char *data=NULL; EC_POINT *point=NULL;
    int ok=EVP_PKEY_get_octet_string_param(key,OSSL_PKEY_PARAM_PUB_KEY,NULL,0,&size)>0;
    if(ok&&size<=WIRE_LIMIT) {
        data=OPENSSL_malloc(size); point=EC_POINT_new(group->value);
        ok=data&&point&&EVP_PKEY_get_octet_string_param(key,OSSL_PKEY_PARAM_PUB_KEY,data,size,&size)>0&&EC_POINT_oct2point(group->value,point,data,size,NULL)>0;
    } else ok=0;
    if(ok) object_result(out,own_point(make_point(group,point)));
    else { EC_POINT_free(point); ssl_error(out,"OpenSSL::PKey::PKeyError","EC public key"); }
    OPENSSL_free(data); free_group(group);
}
static void ec_group_call(const char *op,const arg *args,buffer *out) {
    if(!strcmp(op,"curves")) {
        size_t count=EC_get_builtin_curves(NULL,0);
        EC_builtin_curve *curves=calloc(count,sizeof(*curves));
        if(!curves) { error(out,"NoMemoryError","EC curves allocation failed"); return; }
        EC_get_builtin_curves(curves,count);
        byte(out,'a'); number(out,(uint32_t)count);
        for(size_t i=0;i<count;i++) { byte(out,'a'); number(out,2); text(out,OBJ_nid2sn(curves[i].nid)); text(out,curves[i].comment?curves[i].comment:""); }
        free(curves); return;
    }
    if(!count(args,1,4,out)) return;
    if(!strcmp(op,"new")) {
        EC_GROUP *group=NULL;
        if(args->len==4) {
            BIGNUM *p=bn_arg(at(args,1)),*a=bn_arg(at(args,2)),*b=bn_arg(at(args,3));
            if(p&&a&&b) {
                if(!strcmp(str(at(args,0)),"GFp")) group=EC_GROUP_new_curve_GFp(p,a,b,NULL);
#ifndef OPENSSL_NO_EC2M
                else if(!strcmp(str(at(args,0)),"GF2m")) group=EC_GROUP_new_curve_GF2m(p,a,b,NULL);
#endif
            }
            BN_free(p); BN_free(a); BN_free(b);
        } else if(args->len==1&&at(args,0)->type=='s') {
            const arg *a=at(args,0); const unsigned char *p=(unsigned char *)a->s;
            group=d2i_ECPKParameters(NULL,&p,(long)a->len);
            if(!group) {
                ERR_clear_error(); BIO *bio=BIO_new_mem_buf(a->s,(int)a->len);
                if(bio) group=PEM_read_bio_ECPKParameters(bio,NULL,NULL,NULL);
                BIO_free(bio);
            }
            if(!group) {
                ERR_clear_error();
                if(memchr(a->s,0,a->len)) { error(out,"ArgumentError","string contains null byte"); return; }
                int nid=OBJ_txt2nid(a->s);
                if(nid) group=EC_GROUP_new_by_curve_name(nid);
            }
        }
        if(group) { ERR_clear_error(); object_result(out,own_group(make_group(group))); }
        else ssl_error(out,"OpenSSL::PKey::EC::Group::Error","EC_GROUP_new");
        return;
    }
    native_group *g=group_arg(at(args,0),out); if(!g) return;
    EC_GROUP *group=g->value;
    if(!strcmp(op,"curve_name")) { const char *name=OBJ_nid2sn(EC_GROUP_get_curve_name(group)); if(name&&EC_GROUP_get_curve_name(group)) text(out,name); else byte(out,'n'); }
    else if(!strcmp(op,"degree")) integer(out,EC_GROUP_get_degree(group));
    else if(!strcmp(op,"asn1_flag")) integer(out,EC_GROUP_get_asn1_flag(group));
    else if(!strcmp(op,"set_asn1_flag")) { EC_GROUP_set_asn1_flag(group,(int)num(at(args,1))); byte(out,'n'); }
    else if(!strcmp(op,"form")) integer(out,EC_GROUP_get_point_conversion_form(group));
    else if(!strcmp(op,"set_form")) { int form=(int)num(at(args,1)); if(form!=2&&form!=4&&form!=6) error(out,"ArgumentError","invalid point conversion form"); else { EC_GROUP_set_point_conversion_form(group,(point_conversion_form_t)form); byte(out,'n'); } }
    else if(!strcmp(op,"seed")) string(out,EC_GROUP_get0_seed(group),EC_GROUP_get_seed_len(group));
    else if(!strcmp(op,"set_seed")) {
        const arg *data=at(args,1);
        if(data->type=='s'&&EC_GROUP_set_seed(group,(unsigned char *)data->s,data->len)==data->len) byte(out,'n');
        else ssl_error(out,"OpenSSL::PKey::EC::Group::Error",op);
    }
    else if(!strcmp(op,"order")||!strcmp(op,"cofactor")) {
        BIGNUM *n=BN_new();
        int ok=n&&(!strcmp(op,"order")?EC_GROUP_get_order(group,n,NULL):EC_GROUP_get_cofactor(group,n,NULL));
        if(ok) bn_result(out,n); else ssl_error(out,"OpenSSL::PKey::EC::Group::Error",op);
        BN_free(n);
    } else if(!strcmp(op,"generator")) {
        const EC_POINT *gen=EC_GROUP_get0_generator(group);
        if(gen) object_result(out,own_point(make_point(g,EC_POINT_dup(gen,group))));
        else ssl_error(out,"OpenSSL::PKey::EC::Group::Error","no generator");
    } else if(!strcmp(op,"set_generator")) {
        native_point *point=point_arg(at(args,1),out); if(!point) return;
        BIGNUM *order=bn_arg(at(args,2)),*cofactor=bn_arg(at(args,3));
        if(order&&cofactor&&EC_GROUP_set_generator(group,point->value,order,cofactor)) byte(out,'n');
        else ssl_error(out,"OpenSSL::PKey::EC::Group::Error",op);
        BN_free(order); BN_free(cofactor);
    } else if(!strcmp(op,"equal")) {
        native_group *other=group_arg(at(args,1),out); if(other) boolean(out,EC_GROUP_cmp(group,other->value,NULL)==0);
    } else if(!strcmp(op,"to_der")) {
        unsigned char *data=NULL; int size=i2d_ECPKParameters(group,&data);
        if(size>0) string(out,data,(size_t)size); else ssl_error(out,"OpenSSL::PKey::EC::Group::Error",op);
        OPENSSL_free(data);
    } else if(!strcmp(op,"to_pem")||!strcmp(op,"to_text")) {
        BIO *bio=BIO_new(BIO_s_mem());
        int ok=bio&&(!strcmp(op,"to_pem")?PEM_write_bio_ECPKParameters(bio,group):ECPKParameters_print(bio,group,0));
        if(ok) bio_result(out,bio); else ssl_error(out,"OpenSSL::PKey::EC::Group::Error",op);
        BIO_free(bio);
    } else error(out,"NotImplementedError","unknown native EC group operation");
}
static void ec_point_call(const char *op,const arg *args,buffer *out) {
    if(!count(args,1,3,out)) return;
    if(!strcmp(op,"new")) {
        native_group *g=group_arg(at(args,0),out); if(!g) return;
        EC_POINT *point=EC_POINT_new(g->value); const arg *data=at(args,1);
        if(point&&(data->type=='n'||(data->type=='s'&&EC_POINT_oct2point(g->value,point,(unsigned char *)data->s,data->len,NULL)>0))) object_result(out,own_point(make_point(g,point)));
        else { EC_POINT_free(point); ssl_error(out,"OpenSSL::PKey::EC::Point::Error","EC_POINT_oct2point"); }
        return;
    }
    native_point *point=point_arg(at(args,0),out); if(!point) return;
    EC_GROUP *group=point->group->value;
    if(!strcmp(op,"group")) object_result(out,own_group(retain_group(point->group)));
    else if(!strcmp(op,"infinity")) boolean(out,EC_POINT_is_at_infinity(group,point->value));
    else if(!strcmp(op,"on_curve")) { int answer=EC_POINT_is_on_curve(group,point->value,NULL); if(answer>=0) boolean(out,answer); else ssl_error(out,"OpenSSL::PKey::EC::Point::Error",op); }
    else if(!strcmp(op,"invert")) { if(EC_POINT_invert(group,point->value,NULL)) byte(out,'n'); else ssl_error(out,"OpenSSL::PKey::EC::Point::Error",op); }
    else if(!strcmp(op,"infinity_set")) { if(EC_POINT_set_to_infinity(group,point->value)) byte(out,'n'); else ssl_error(out,"OpenSSL::PKey::EC::Point::Error",op); }
    else if(!strcmp(op,"equal")) {
        native_point *other=point_arg(at(args,1),out); if(!other) return;
        int answer=EC_POINT_cmp(group,point->value,other->value,NULL);
        if(answer>=0) boolean(out,answer==0); else ssl_error(out,"OpenSSL::PKey::EC::Point::Error",op);
    } else if(!strcmp(op,"octets")) {
        int form=(int)num(at(args,1)); if(!form) form=EC_GROUP_get_point_conversion_form(group);
        if(form!=2&&form!=4&&form!=6) { error(out,"ArgumentError","invalid point conversion form"); return; }
        size_t size=EC_POINT_point2oct(group,point->value,(point_conversion_form_t)form,NULL,0,NULL);
        unsigned char *data=size?OPENSSL_malloc(size):NULL;
        if(data&&EC_POINT_point2oct(group,point->value,(point_conversion_form_t)form,data,size,NULL)>0) string(out,data,size);
        else ssl_error(out,"OpenSSL::PKey::EC::Point::Error",op);
        OPENSSL_free(data);
    } else if(!strcmp(op,"add")||!strcmp(op,"mul")) {
        EC_POINT *result=EC_POINT_new(group); int ok=0;
        if(!strcmp(op,"add")) { native_point *other=point_arg(at(args,1),out); if(other&&result) ok=EC_POINT_add(group,result,point->value,other->value,NULL); }
        else {
            BIGNUM *scalar=bn_arg(at(args,1)),*generator=at(args,2)->type=='n'?NULL:bn_arg(at(args,2));
            if(result&&scalar&&(at(args,2)->type=='n'||generator)) ok=EC_POINT_mul(group,result,generator,point->value,scalar,NULL);
            BN_clear_free(scalar); BN_clear_free(generator);
        }
        if(ok) object_result(out,own_point(make_point(point->group,result)));
        else { EC_POINT_free(result); if(!out->len) ssl_error(out,"OpenSSL::PKey::EC::Point::Error",op); }
    } else error(out,"NotImplementedError","unknown native EC point operation");
}
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
