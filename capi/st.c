/* CRuby's own st.c (capi/vendor), compiled as it is. */
#define RUBY_EXPORT 1
#include "vendor/st.c"

/* What it asks of a Hash: a String key frozen as a Hash keeps it (a Hash's
 * own st_table is capi/hashtbl.c). */
#include "mr_capi.h"
VALUE rb_hash_key_str(VALUE key) {
    if (RB_OBJ_FROZEN(key)) return key;
    return rb_str_new_frozen(key);
}
void ruby_malloc_size_overflow(size_t count, size_t size) {
    rb_raise(rb_eArgError, "malloc: possible integer overflow (%zu*%zu)", count, size);
}
