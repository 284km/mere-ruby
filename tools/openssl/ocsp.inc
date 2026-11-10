/* Each exposed OCSP child is an ASN.1 copy, never a borrowed parent field. */
#define OCSP_OBJECT(prefix,ctype,kind,klass) \
static void prefix##_free(void *p) { ctype##_free(p); } \
static void *prefix##_copy(const void *p) { return ASN1_item_dup(ASN1_ITEM_rptr(ctype),p); } \
static int prefix##_own(ctype *p) { return own(p,kind,klass,prefix##_free,prefix##_copy); } \
static ctype *prefix##_arg(const arg *a,buffer *out) { \
    native_slot *s=lookup(num(a),kind); if(!s) error(out,"TypeError","invalid native " klass); return s?s->ptr:NULL; } \
static void prefix##_decode(const arg *a,buffer *out) { \
    const unsigned char *cursor=(const unsigned char *)str(a); \
    ctype *p=a->type=='n'?ctype##_new():a->type=='s'?d2i_##ctype(NULL,&cursor,(long)a->len):NULL; \
    if(p) object_result(out,prefix##_own(p)); else ssl_error(out,"OpenSSL::OCSP::OCSPError","OCSP decode"); } \
static void prefix##_der(buffer *out,ctype *p) { unsigned char *der=NULL; int n=i2d_##ctype(p,&der); der_result(out,der,n,"OpenSSL::OCSP::OCSPError"); }
OCSP_OBJECT(ocid,OCSP_CERTID,NK_OCSP_CERTID,"OpenSSL::OCSP::CertificateId")
OCSP_OBJECT(oreq,OCSP_REQUEST,NK_OCSP_REQUEST,"OpenSSL::OCSP::Request")
OCSP_OBJECT(ores,OCSP_RESPONSE,NK_OCSP_RESPONSE,"OpenSSL::OCSP::Response")
OCSP_OBJECT(obasic,OCSP_BASICRESP,NK_OCSP_BASIC,"OpenSSL::OCSP::BasicResponse")
OCSP_OBJECT(osingle,OCSP_SINGLERESP,NK_OCSP_SINGLE,"OpenSSL::OCSP::SingleResponse")
#undef OCSP_OBJECT
static void format_oid_result(buffer *out,const ASN1_OBJECT *obj,int numeric) {
    int length=obj?OBJ_obj2txt(NULL,0,obj,numeric):0;
    if(length<=0||length>WIRE_LIMIT-128) { error(out,"OpenSSL::ASN1::ASN1Error","invalid object identifier"); return; }
    char *value=OPENSSL_malloc((size_t)length+1);
    if(!value) { error(out,"NoMemoryError","OID allocation failed"); return; }
    OBJ_obj2txt(value,length+1,obj,numeric); string(out,value,(size_t)length); OPENSSL_free(value);
}
static void ocsp_constants(buffer *out) {
    buffer items={0}; unsigned n=0;
#define OC(name,value) text(&items,name); integer(&items,value); n++;
#define O(name) OC(#name,OCSP_##name)
    O(RESPONSE_STATUS_MALFORMEDREQUEST) O(RESPONSE_STATUS_INTERNALERROR) O(RESPONSE_STATUS_TRYLATER)
    O(RESPONSE_STATUS_SIGREQUIRED) O(RESPONSE_STATUS_UNAUTHORIZED) O(RESPONSE_STATUS_SUCCESSFUL)
    O(REVOKED_STATUS_NOSTATUS) O(REVOKED_STATUS_UNSPECIFIED) O(REVOKED_STATUS_KEYCOMPROMISE)
    O(REVOKED_STATUS_CACOMPROMISE) O(REVOKED_STATUS_AFFILIATIONCHANGED) O(REVOKED_STATUS_SUPERSEDED)
    O(REVOKED_STATUS_CESSATIONOFOPERATION) O(REVOKED_STATUS_CERTIFICATEHOLD) O(REVOKED_STATUS_REMOVEFROMCRL)
    O(NOCERTS) O(NOINTERN) O(NOSIGS) O(NOCHAIN) O(NOVERIFY) O(NOEXPLICIT) O(NOCASIGN)
    O(NODELEGATED) O(NOCHECKS) O(TRUSTOTHER) O(RESPID_KEY) O(NOTIME)
    OC("V_CERTSTATUS_GOOD",V_OCSP_CERTSTATUS_GOOD) OC("V_CERTSTATUS_REVOKED",V_OCSP_CERTSTATUS_REVOKED)
    OC("V_CERTSTATUS_UNKNOWN",V_OCSP_CERTSTATUS_UNKNOWN) OC("V_RESPID_NAME",V_OCSP_RESPID_NAME) OC("V_RESPID_KEY",V_OCSP_RESPID_KEY)
#undef O
#undef OC
    byte(out,'m'); number(out,n); put(out,items.p,items.len); free(items.p);
}
static void ocsp_cid_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::OCSP::OCSPError";
    if(!strcmp(op,"new")) {
        if(at(args,0)->type!='n') { ocid_decode(at(args,0),out); return; }
        X509 *subject=xcert_arg(at(args,1),out); if(!subject) return;
        X509 *issuer=xcert_arg(at(args,2),out); if(!issuer) return;
        EVP_MD *md=NULL;
        if(at(args,3)->type!='n') { const char *name=format_c_string(at(args,3),out); if(out->len) return; md=EVP_MD_fetch(NULL,name,NULL); if(!md) { ssl_error(out,klass,"EVP_MD_fetch"); return; } }
        OCSP_CERTID *id=OCSP_cert_to_id(md,subject,issuer); EVP_MD_free(md);
        if(id) object_result(out,ocid_own(id)); else ssl_error(out,klass,"OCSP_cert_to_id"); return;
    }
    OCSP_CERTID *id=ocid_arg(at(args,0),out); if(!id) return;
    if(!strcmp(op,"to_der")) { ocid_der(out,id); return; }
    if(!strcmp(op,"cmp")||!strcmp(op,"cmp_issuer")) {
        OCSP_CERTID *other=ocid_arg(at(args,1),out); if(!other) return;
        boolean(out,(!strcmp(op,"cmp")?OCSP_id_cmp(id,other):OCSP_id_issuer_cmp(id,other))==0); return;
    }
    ASN1_OCTET_STRING *name_hash=NULL,*key_hash=NULL; ASN1_OBJECT *algorithm=NULL; ASN1_INTEGER *serial=NULL;
    if(!OCSP_id_get0_info(&name_hash,&algorithm,&key_hash,&serial,id)) { ssl_error(out,klass,"OCSP_id_get0_info"); return; }
    if(!strcmp(op,"serial")) x509_serial_result(out,serial);
    else if(!strcmp(op,"hash_algorithm")) format_oid_result(out,algorithm,0);
    else if(!strcmp(op,"issuer_name_hash")) string(out,ASN1_STRING_get0_data(name_hash),(size_t)ASN1_STRING_length(name_hash));
    else if(!strcmp(op,"issuer_key_hash")) string(out,ASN1_STRING_get0_data(key_hash),(size_t)ASN1_STRING_length(key_hash));
    else error(out,"NotImplementedError","unknown OCSP CertificateId operation");
}
static void ocsp_sign_verify(const char *op,void *object,int basic,const arg *args,buffer *out) {
    const char *klass="OpenSSL::OCSP::OCSPError";
    if(!strcmp(op,"sign")) {
        X509 *cert=xcert_arg(at(args,1),out); if(!cert) return;
        EVP_PKEY *key=key_arg(at(args,2),out); if(!key) return;
        const arg *digest=at(args,5); EVP_MD *md=NULL;
        if(digest->type!='n') { const char *name=format_c_string(digest,out); if(out->len) return; md=EVP_MD_fetch(NULL,name,NULL); if(!md) { ssl_error(out,klass,"EVP_MD_fetch"); return; } }
        STACK_OF(X509) *certs=cert_chain_arg(at(args,3),out); if(!certs) { EVP_MD_free(md); return; }
        unsigned long flags=(unsigned long)num(at(args,4)); if(at(args,3)->type=='n') flags|=OCSP_NOCERTS;
        int ok=basic?OCSP_basic_sign(object,cert,key,md,certs,flags):OCSP_request_sign(object,cert,key,md,certs,flags);
        sk_X509_pop_free(certs,X509_free); EVP_MD_free(md);
        if(ok) byte(out,'n'); else ssl_error(out,klass,"OCSP sign");
    } else {
        X509_STORE *store=store_arg(at(args,2),out); if(!store) return;
        STACK_OF(X509) *certs=cert_chain_arg(at(args,1),out); if(!certs) return;
        int ok=basic?OCSP_basic_verify(object,certs,store,(unsigned long)num(at(args,3))):OCSP_request_verify(object,certs,store,(unsigned long)num(at(args,3)));
        sk_X509_pop_free(certs,X509_free); if(ok<=0) ERR_clear_error(); boolean(out,ok>0);
    }
}
static void ocsp_req_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::OCSP::OCSPError";
    if(!strcmp(op,"new")) { oreq_decode(at(args,0),out); return; }
    OCSP_REQUEST *req=oreq_arg(at(args,0),out); if(!req) return;
    const arg *value=at(args,1);
    if(!strcmp(op,"to_der")) oreq_der(out,req);
    else if(!strcmp(op,"signed")) boolean(out,OCSP_request_is_signed(req));
    else if(!strcmp(op,"add_nonce")) {
        int ok=OCSP_request_add1_nonce(req,value->type=='n'?NULL:(unsigned char *)str(value),value->type=='n'?-1:(int)value->len);
        if(ok) byte(out,'n'); else ssl_error(out,klass,"OCSP_request_add1_nonce");
    } else if(!strcmp(op,"add_certid")) {
        OCSP_CERTID *id=ocid_arg(value,out); if(!id) return; OCSP_CERTID *copy=OCSP_CERTID_dup(id);
        if(copy&&OCSP_request_add0_id(req,copy)) byte(out,'n'); else { OCSP_CERTID_free(copy); ssl_error(out,klass,"OCSP_request_add0_id"); }
    } else if(!strcmp(op,"certid")) {
        int n=OCSP_request_onereq_count(req); if(!n) { byte(out,'n'); return; }
        byte(out,'a'); number(out,n); for(int i=0;i<n;i++) object_result(out,ocid_own(OCSP_CERTID_dup(OCSP_onereq_get0_id(OCSP_request_onereq_get0(req,i)))));
    } else if(!strcmp(op,"check_nonce")) { OCSP_BASICRESP *basic=obasic_arg(value,out); if(basic) integer(out,OCSP_check_nonce(req,basic)); }
    else if(!strcmp(op,"sign")||!strcmp(op,"verify")) ocsp_sign_verify(op,req,0,args,out);
    else error(out,"NotImplementedError","unknown OCSP request operation");
}
static void ocsp_res_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::OCSP::OCSPError";
    if(!strcmp(op,"new")) { ores_decode(at(args,0),out); return; }
    if(!strcmp(op,"create")) {
        OCSP_BASICRESP *basic=at(args,1)->type=='n'?NULL:obasic_arg(at(args,1),out); if(out->len) return;
        OCSP_RESPONSE *res=OCSP_response_create((int)num(at(args,0)),basic);
        if(res) object_result(out,ores_own(res)); else ssl_error(out,klass,"OCSP_response_create"); return;
    }
    OCSP_RESPONSE *res=ores_arg(at(args,0),out); if(!res) return;
    if(!strcmp(op,"to_der")) ores_der(out,res);
    else if(!strcmp(op,"status")) integer(out,OCSP_response_status(res));
    else if(!strcmp(op,"status_string")) text(out,OCSP_response_status_str(OCSP_response_status(res)));
    else if(!strcmp(op,"basic")) { OCSP_BASICRESP *basic=OCSP_response_get1_basic(res); if(basic) object_result(out,obasic_own(basic)); else byte(out,'n'); }
    else error(out,"NotImplementedError","unknown OCSP response operation");
}
static void ocsp_basic_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::OCSP::OCSPError";
    if(!strcmp(op,"new")) { obasic_decode(at(args,0),out); return; }
    OCSP_BASICRESP *basic=obasic_arg(at(args,0),out); if(!basic) return;
    const arg *value=at(args,1);
    if(!strcmp(op,"to_der")) obasic_der(out,basic);
    else if(!strcmp(op,"sign")||!strcmp(op,"verify")) ocsp_sign_verify(op,basic,1,args,out);
    else if(!strcmp(op,"copy_nonce")) { OCSP_REQUEST *req=oreq_arg(value,out); if(req) integer(out,OCSP_copy_nonce(basic,req)); }
    else if(!strcmp(op,"add_nonce")) {
        int ok=OCSP_basic_add1_nonce(basic,value->type=='n'?NULL:(unsigned char *)str(value),value->type=='n'?-1:(int)value->len);
        if(ok) byte(out,'n'); else ssl_error(out,klass,"OCSP_basic_add1_nonce");
    } else if(!strcmp(op,"add_status")) {
        OCSP_CERTID *id=ocid_arg(value,out); if(!id) return;
        const arg *extensions=at(args,7);
        if(extensions->type!='a'&&extensions->type!='n') { error(out,"TypeError","extensions must be an Array"); return; }
        if(extensions->type=='a') for(size_t i=0;i<extensions->len;i++) if(!xext_arg(&extensions->items[i],out)) return;
        ASN1_TIME *rev=at(args,4)->type=='n'?NULL:ASN1_TIME_set(NULL,(time_t)num(at(args,4))),
            *thisupd=ASN1_TIME_set(NULL,(time_t)num(at(args,5))),*nextupd=at(args,6)->type=='n'?NULL:ASN1_TIME_set(NULL,(time_t)num(at(args,6)));
        OCSP_SINGLERESP *single=thisupd?OCSP_basic_add1_status(basic,id,(int)num(at(args,2)),(int)num(at(args,3)),rev,thisupd,nextupd):NULL;
        ASN1_TIME_free(rev); ASN1_TIME_free(thisupd); ASN1_TIME_free(nextupd);
        if(!single) { ssl_error(out,klass,"OCSP_basic_add1_status"); return; }
        if(extensions->type=='a') for(size_t i=0;i<extensions->len;i++) if(!OCSP_SINGLERESP_add_ext(single,xext_arg(&extensions->items[i],out),-1)) { ssl_error(out,klass,"OCSP_SINGLERESP_add_ext"); return; }
        byte(out,'n');
    } else if(!strcmp(op,"responses")) {
        int n=OCSP_resp_count(basic); byte(out,'a'); number(out,n);
        for(int i=0;i<n;i++) object_result(out,osingle_own(osingle_copy(OCSP_resp_get0(basic,i))));
    } else if(!strcmp(op,"find_response")) {
        OCSP_CERTID *id=ocid_arg(value,out); if(!id) return; int n=OCSP_resp_find(basic,id,-1);
        if(n<0) byte(out,'n'); else object_result(out,osingle_own(osingle_copy(OCSP_resp_get0(basic,n))));
    } else error(out,"NotImplementedError","unknown OCSP basic response operation");
}
static void ocsp_single_call(const char *op,const arg *args,buffer *out) {
    const char *klass="OpenSSL::OCSP::OCSPError";
    if(!strcmp(op,"new")) { if(at(args,0)->type!='s') error(out,"TypeError","expected DER String"); else osingle_decode(at(args,0),out); return; }
    OCSP_SINGLERESP *single=osingle_arg(at(args,0),out); if(!single) return;
    if(!strcmp(op,"to_der")) { osingle_der(out,single); return; }
    int reason=-1; ASN1_GENERALIZEDTIME *rev=NULL,*thisupd=NULL,*nextupd=NULL;
    int status=OCSP_single_get0_status(single,&reason,&rev,&thisupd,&nextupd);
    if(status<0) { ssl_error(out,klass,"OCSP_single_get0_status"); return; }
    if(!strcmp(op,"certid")) object_result(out,ocid_own(OCSP_CERTID_dup(OCSP_SINGLERESP_get0_id(single))));
    else if(!strcmp(op,"cert_status")) integer(out,status);
    else if(!strcmp(op,"revocation_reason")||!strcmp(op,"revocation_time")) {
        if(status!=V_OCSP_CERTSTATUS_REVOKED) { error(out,klass,"certificate is not revoked"); return; }
        if(!strcmp(op,"revocation_reason")) integer(out,reason); else if(rev) x509_time_result(out,rev,klass); else byte(out,'n');
    } else if(!strcmp(op,"this_update")||!strcmp(op,"next_update")) {
        ASN1_TIME *time=!strcmp(op,"this_update")?thisupd:nextupd; if(time) x509_time_result(out,time,klass); else byte(out,'n');
    } else if(!strcmp(op,"check_validity")) {
        int ok=OCSP_check_validity(thisupd,nextupd,(long)num(at(args,1)),(long)num(at(args,2))); if(!ok) ERR_clear_error(); boolean(out,ok);
    } else if(!strcmp(op,"extensions")) {
        int n=OCSP_SINGLERESP_get_ext_count(single); byte(out,'a'); number(out,n);
        for(int i=0;i<n;i++) object_result(out,xext_own(X509_EXTENSION_dup(OCSP_SINGLERESP_get_ext(single,i))));
    } else error(out,"NotImplementedError","unknown OCSP SingleResponse operation");
}
static void ocsp_call(const char *op,const arg *args,buffer *out) {
    if(!strcmp(op,"constants")) ocsp_constants(out);
    else if(!strncmp(op,"cid.",4)) ocsp_cid_call(op+4,args,out);
    else if(!strncmp(op,"req.",4)) ocsp_req_call(op+4,args,out);
    else if(!strncmp(op,"res.",4)) ocsp_res_call(op+4,args,out);
    else if(!strncmp(op,"bres.",5)) ocsp_basic_call(op+5,args,out);
    else if(!strncmp(op,"single.",7)) ocsp_single_call(op+7,args,out);
    else error(out,"NotImplementedError","unknown OCSP operation");
}
