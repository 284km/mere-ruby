/* cgi/escape: ruby's ext/cgi/escape/escape.c (CGI::EscapeExt: escapeHTML,
 * unescapeHTML, escape, unescape, escapeURIComponent, unescapeURIComponent),
 * CRuby 4.0.10's, unchanged, in capi/vendor/cgi_escape.c, linked into this
 * executable as erb/escape is (static_ext.c holds the table). A file of its
 * own: erb's escape.c has static functions of the same names
 * (escaped_length, optimized_escape_html, preserve_original_state). Its
 * Init_ and InitVM_ are renamed so that neither meets an extension's.
 * HAVE_RB_EXT_RACTOR_SAFE comes from ruby/internal/intern/load.h, as in a
 * CRuby build. */
#include "mr_capi.h"
#define Init_escape mr_static_Init_cgi_escape
#define InitVM_escape mr_static_InitVM_cgi_escape
#include "cgi_escape.c"
