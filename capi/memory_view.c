/* Memory views (ruby/memory_view.h): CRuby's own memory_view.c, compiled as
 * it is (capi/vendor/memory_view.c -- nothing in it is edited, and
 * capi/tools/headers_check.py holds it to the ruby source tree).
 *
 * It is written against four names of CRuby's inside. Two come with headers
 * this C API has no equivalent of, and capi/standin has those headers with
 * just what is used: an instance variable read with a default
 * (internal/variable.h) and the VM lock around the registry (vm_sync.h). The
 * other two are given here in terms of the public API: an identity table and
 * a value kept for the life of the process. */
#define RUBY_EXPORT 1
#include "ruby/ruby.h"
#include "ruby/st.h"
static void rb_vm_register_global_object(VALUE obj) { rb_gc_register_mark_object(obj); }
st_table *rb_init_identtable(void) { return st_init_numtable(); }
#include "vendor/memory_view.c"
