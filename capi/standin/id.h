/* Stands in for CRuby's generated id.h where a file of capi/vendor includes
 * it. bignum.c names seven method IDs; here they are interned by name. */
#ifndef RUBY_ID_H
#define RUBY_ID_H
#include "ruby/ruby.h"
#define idCmp rb_intern("<=>")
#define idDiv rb_intern("div")
#define idDivmod rb_intern("divmod")
#define idFdiv rb_intern("fdiv")
#define idGE rb_intern(">=")
#define idLE rb_intern("<=")
#define idPow rb_intern("**")
#endif
