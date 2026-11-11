/* The C side of mere-ruby's `extern fn prism_*` (m_state.mere): the few
 * entry points of libprism that the Ruby half (lib/prism_ext.rb, answered for
 * `require "prism/prism"`) needs. Prism's own Ruby library deserializes what
 * these return (lib/prism/serialize.rb), so no node is built here -- the same
 * shape as Prism's FFI backend (lib/prism/ffi.rb), with Mere's `bytes` in
 * place of FFI::MemoryPointer.
 *
 * libprism is vendor/prism (Prism 1.8.2, the copy Ruby 4.0.9 ships;
 * vendor/prism/README.md says how it is regenerated). tools/build.sh compiles
 * it and this file beside mr.c.
 *
 * ⚠ A `bytes` that comes BACK across the boundary is a `mere_bytes*` the
 * emitted code uses as it is -- it does not copy it (a `str` return is copied
 * by __lang_str_of_cstr; a `bytes` return is not). So the result lives in ONE
 * static buffer owned by this file, reused by the next call, and the Mere
 * side copies it into a Ruby string (str_of_bytes) before anything else runs.
 * Nothing in Mere's regions points here, so a collection never sees it.
 *
 * ⚠ A boundary `int` is C's 32-bit int (Mere docs, language-reference "FFI
 * types"); lengths travel inside the bytes, never as an int.
 */
#include <stdlib.h>
#include <string.h>
#include "prism.h"

#if __has_include("mere_extern.h")
#include "mere_extern.h"
#else
/* The layout `mere --ffi-header` prints; only for a --cc-only build made
 * where the header was not generated. */
struct mere_bytes { long long len; unsigned char data[]; };
typedef struct mere_bytes mere_bytes;
#endif

static mere_bytes *out = NULL;
static size_t out_cap = 0;

/* Move a pm_buffer's contents into the static result and free the buffer. */
static mere_bytes *
prism_take(pm_buffer_t *buffer) {
    size_t n = pm_buffer_length(buffer);
    if (out == NULL || out_cap < n) {
        size_t cap = n < 4096 ? 4096 : n;
        mere_bytes *grown = (mere_bytes *) realloc(out, sizeof(mere_bytes) + cap);
        if (grown == NULL) { pm_buffer_free(buffer); abort(); }
        out = grown;
        out_cap = cap;
    }
    out->len = (long long) n;
    if (n > 0) memcpy(out->data, pm_buffer_value(buffer), n);
    pm_buffer_free(buffer);
    return out;
}

/* kind: 0 parse, 1 lex, 2 parse_comments, 3 parse_lex. `opts` is the options
 * string lib/prism_ext.rb packs (the same format pm_options_read reads). */
mere_bytes *
prism_ser(int kind, mere_bytes *src, mere_bytes *opts) {
    pm_buffer_t buffer;
    pm_buffer_init(&buffer);
    const uint8_t *source = (const uint8_t *) src->data;
    size_t size = (size_t) src->len;
    const char *data = (const char *) opts->data;
    switch (kind) {
      case 0: pm_serialize_parse(&buffer, source, size, data); break;
      case 1: pm_serialize_lex(&buffer, source, size, data); break;
      case 2: pm_serialize_parse_comments(&buffer, source, size, data); break;
      default: pm_serialize_parse_lex(&buffer, source, size, data); break;
    }
    return prism_take(&buffer);
}

/* Prism.parse_success? */
int
prism_ok(mere_bytes *src, mere_bytes *opts) {
    return pm_parse_success_p((const uint8_t *) src->data, (size_t) src->len, (const char *) opts->data) ? 1 : 0;
}

/* Prism.parse_stream reads the stream in pieces, and after each piece asks
 * whether the parser wants more: it does when there are errors and either a
 * lex mode is still open (an unterminated string or regexp whose body holds
 * the `__END__` line the reader stopped at) or a heredoc is unterminated --
 * pm_parse_stream's own loop condition, written out here because the
 * reading side is Ruby. */
int
prism_more(mere_bytes *src, mere_bytes *opts) {
    pm_options_t options = { 0 };
    pm_options_read(&options, (const char *) opts->data);
    pm_parser_t parser;
    pm_parser_init(&parser, (const uint8_t *) src->data, (size_t) src->len, &options);
    pm_node_t *node = pm_parse(&parser);
    int more = 0;
    if (parser.error_list.size > 0) {
        if (parser.lex_modes.index > 0) {
            more = 1;
        } else {
            pm_diagnostic_t *diagnostic = (pm_diagnostic_t *) parser.error_list.head;
            for (; diagnostic != NULL; diagnostic = (pm_diagnostic_t *) diagnostic->node.next) {
                if (diagnostic->diag_id == PM_ERR_HEREDOC_TERM) { more = 1; break; }
            }
        }
    }
    pm_node_destroy(&parser, node);
    pm_parser_free(&parser);
    pm_options_free(&options);
    return more;
}

/* Prism::StringQuery: kind 0 local?, 1 constant?, 2 method_name?.
 * -1 is PM_STRING_QUERY_ERROR (the encoding is not ASCII-compatible). */
int
prism_query(int kind, mere_bytes *s, const char *encoding_name) {
    size_t length = (size_t) s->len;
    if (s->len < 0 || (unsigned long long) s->len >= SIZE_MAX) abort();
    /* StringQuery's identifier scanner inspects the byte after the logical
     * slice. Mere bytes have no trailing sentinel; provide the same NUL
     * boundary as Prism's Ruby/FFI string inputs, independent of reused
     * region storage. The parser's source-buffer API needs no such copy. */
    uint8_t *source = (uint8_t *) malloc(length + 1);
    if (source == NULL) abort();
    memcpy(source, s->data, length);
    source[length] = 0;
    pm_string_query_t result;
    switch (kind) {
      case 0: result = pm_string_query_local(source, length, encoding_name); break;
      case 1: result = pm_string_query_constant(source, length, encoding_name); break;
      default: result = pm_string_query_method_name(source, length, encoding_name); break;
    }
    free(source);
    return (int) result;
}

const char *
prism_version(void) {
    return pm_version();
}
