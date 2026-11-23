/* Stands in for CRuby's internal/gc.h where a file of capi/vendor includes
 * it (the real one includes vm_core.h). bignum.c makes its objects with
 * NEWOBJ_OF and asks how big a slot may be; a Bignum it makes is a C struct
 * of its own (capi/bignum_cruby.c), which becomes an Integer when it reaches
 * the interpreter. */
#ifndef INTERNAL_GC_H
#define INTERNAL_GC_H
#include "ruby/ruby.h"
#include "ruby/internal/stdbool.h"
VALUE mr_vbig_newobj(VALUE klass, VALUE flags, size_t size);
#define NEWOBJ_OF(var, T, c, f, s, ec) T *(var) = (T *)mr_vbig_newobj((c), (f), (s))
bool rb_gc_size_allocatable_p(size_t size);
size_t rb_gc_obj_slot_size(VALUE obj);
#endif
