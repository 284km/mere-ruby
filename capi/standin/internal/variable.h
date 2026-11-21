/* Stands in for CRuby's internal/variable.h where a file of capi/vendor
 * includes it. Of that header, the vendored sources use one function. */
#ifndef INTERNAL_VARIABLE_H
#define INTERNAL_VARIABLE_H
#include "ruby/ruby.h"
/* an instance variable's value, or `undef` when the object has none by that name */
static inline VALUE rb_ivar_lookup(VALUE obj, ID id, VALUE undef) {
    return RTEST(rb_ivar_defined(obj, id)) ? rb_ivar_get(obj, id) : undef;
}
#endif
