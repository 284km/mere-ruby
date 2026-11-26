/* Extensions of ruby's own build linked into this executable, as ruby links
 * an extension statically (--with-static-linked-ext): `require` of the
 * feature runs its Init_ (mr_capi_static_open, then MR_RUN_INIT as for a
 * library), and its methods are C functions, so Method#source_location is
 * nil as on ruby. The sources are CRuby 4.0.9's, unchanged, in capi/vendor/;
 * each Init_ is renamed here so that two extensions' Init_escape do not meet.
 *
 * erb/escape: ext/erb/escape/escape.c (ERB::Escape.html_escape). Its
 * extconf.rb asks have_func("rb_ext_ractor_safe"), which this C API has.
 * cgi/escape: ext/cgi/escape/escape.c, compiled in static_cgi_escape.c. */
#include "mr_capi.h"
#define HAVE_RB_EXT_RACTOR_SAFE 1
#define Init_escape mr_static_Init_erb_escape
#include "erb_escape.c"
#undef Init_escape

extern void mr_static_Init_cgi_escape(void);

const struct mr_static_ext mr_static_exts[] = {
    { "erb/escape", mr_static_Init_erb_escape },
    { "cgi/escape", mr_static_Init_cgi_escape },
    { NULL, NULL },
};
