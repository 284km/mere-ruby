/* CRuby's own st.c (capi/vendor), compiled as it is. */
#define RUBY_EXPORT 1
#include "vendor/st.c"

/* The two things it asks of a Hash, which only CRuby's Hash (an st_table
 * itself) could answer. */
#include "mr_capi.h"
VALUE rb_hash_key_str(VALUE key) {
    if (RB_OBJ_FROZEN(key)) return key;
    return rb_str_new_frozen(key);
}
st_table *rb_hash_tbl_raw(VALUE hash, const char *file, int line) {
    (void)hash; (void)file; (void)line;
    mr_unsupported("a Hash's st_table");
}
void ruby_malloc_size_overflow(size_t count, size_t size) {
    rb_raise(rb_eArgError, "malloc: possible integer overflow (%zu*%zu)", count, size);
}
