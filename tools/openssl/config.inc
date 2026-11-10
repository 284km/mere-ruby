static void config_call(const char *op,const arg *args,buffer *out) {
    if(!strcmp(op,"default_file")) {
        char *path=CONF_get1_default_config_file();
        if(path) { text(out,path); OPENSSL_free(path); } else ssl_error(out,"OpenSSL::ConfigError","default config file"); return;
    }
    if(strcmp(op,"parse")) { error(out,"NotImplementedError","unknown OpenSSL configuration operation"); return; }
    const arg *source=at(args,0);
    CONF *conf=NCONF_new(NULL); BIO *bio=BIO_new_mem_buf(str(source),(int)source->len); long line=0;
    if(!conf||!bio||!NCONF_load_bio(conf,bio,&line)) {
        unsigned long code=ERR_peek_last_error(); const char *reason=ERR_reason_error_string(code);
        char message[512]; snprintf(message,sizeof(message),"error in line %ld: %s",line,reason?reason:"configuration parse failed");
        error(out,"OpenSSL::ConfigError",message); goto done;
    }
    STACK_OF(OPENSSL_CSTRING) *sections=NCONF_get_section_names(conf);
    if(!sections) { ssl_error(out,"OpenSSL::ConfigError","NCONF_get_section_names"); goto done; }
    int n=sk_OPENSSL_CSTRING_num(sections); byte(out,'m'); number(out,n);
    for(int i=0;i<n;i++) {
        const char *section=sk_OPENSSL_CSTRING_value(sections,i); text(out,section);
        STACK_OF(CONF_VALUE) *values=NCONF_get_section(conf,section); int m=sk_CONF_VALUE_num(values); if(m<0) m=0;
        byte(out,'m'); number(out,m);
        for(int j=0;j<m;j++) { CONF_VALUE *value=sk_CONF_VALUE_value(values,j); text(out,value->name); text(out,value->value); }
    }
    sk_OPENSSL_CSTRING_free(sections);
    ERR_clear_error();
done:
    NCONF_free(conf); BIO_free(bio);
}
