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

/* ---------------------------------------------------------------------------
 * RubyVM::AbstractSyntaxTree.parse(src, keep_tokens: true)'s #all_tokens.
 *
 * The reference answers parse.y's tokens: every byte of the program up to
 * `__END__` in some token (the spaces are tSP, the spaces of a %w list
 * word_sep), each [id, type, text, [line, column, last line, last column]],
 * in the order the lexer made them. Prism's lexer makes nearly the same
 * tokens, so this lexes with libprism and writes them as parse.y would:
 *
 *   - the names are parse.y's (Prism's names come from it: KEYWORD_DO_LOOP
 *     is keyword_do_cond, PARENTHESIS_LEFT is "(" or tLPAREN by the lexer
 *     state before it, as parse.y decides);
 *   - a `do` whose block belongs to a call with arguments and no parentheses
 *     is keyword_do_block (parse.y's CMDARG_P(); Prism decides it in the
 *     parser, so the tree is walked for those calls);
 *   - the gaps between tokens are tSP / word_sep, cut after each newline and
 *     each `\` newline;
 *   - a newline that ends a statement is made after the comment lines that
 *     follow it (parse.y looks past them for a leading `.`);
 *   - a <<~ heredoc's body is one token per line until a line with no
 *     indentation, and an expanding <<- / <<~ body is cut after a line that
 *     ends with `\` (parse.y's here_document).
 *
 * Measured against the reference over test/**\/*.rb (850 files): the text and
 * the places agree in every file; the names in 839.
 *
 * The result is the same static buffer as above: 7 little-endian int32 per
 * token (name index, start, end, line, column, last line, last column). The
 * names are prism_token_names()'s lines.
 * ------------------------------------------------------------------------- */
#include <stdint.h>
#include <stdbool.h>

typedef struct { int type; uint32_t start, end, state; } ast_lexed_t;
typedef struct { int name, ptype, look; uint32_t start, end; } ast_tok_t;
typedef struct { ast_tok_t *v; size_t n, cap; } ast_vec_t;

static ast_lexed_t *ast_lexed = NULL;
static size_t ast_lexed_n = 0, ast_lexed_cap = 0;

static void *
ast_grow(void *p, size_t *cap, size_t need, size_t elem) {
    if (need <= *cap) return p;
    size_t c = *cap < 256 ? 256 : *cap;
    while (c < need) c *= 2;
    void *q = realloc(p, c * elem);
    if (q == NULL) abort();
    *cap = c;
    return q;
}

static void
ast_push(ast_vec_t *v, ast_tok_t t) {
    v->v = (ast_tok_t *) ast_grow(v->v, &v->cap, v->n + 1, sizeof(ast_tok_t));
    v->v[v->n++] = t;
}

static void
ast_on_token(void *data, pm_parser_t *parser, pm_token_t *token) {
    (void) data;
    ast_lexed = (ast_lexed_t *) ast_grow(ast_lexed, &ast_lexed_cap, ast_lexed_n + 1, sizeof(ast_lexed_t));
    ast_lexed[ast_lexed_n++] = (ast_lexed_t) {
        token->type, (uint32_t) (token->start - parser->start), (uint32_t) (token->end - parser->start), (uint32_t) parser->lex_state
    };
}

/* --- the names --- */
static const char *ast_names[256];
static int ast_nnames = 0;
static int ast_type_name[PM_TOKEN_MAXIMUM + 1];
static int ast_names_ready = 0;
static char ast_kw[PM_TOKEN_MAXIMUM + 1][40];

static int
ast_intern(const char *s) {
    for (int i = 0; i < ast_nnames; i++) if (strcmp(ast_names[i], s) == 0) return i;
    if (ast_nnames >= 256) abort();
    ast_names[ast_nnames] = s;
    return ast_nnames++;
}

static const char *const ast_table[][2] = {
    {"AMPERSAND", "&"}, {"AMPERSAND_AMPERSAND", "tANDOP"}, {"AMPERSAND_AMPERSAND_EQUAL", "tOP_ASGN"},
    {"AMPERSAND_DOT", "tANDDOT"}, {"AMPERSAND_EQUAL", "tOP_ASGN"}, {"BACKTICK", "tXSTRING_BEG"},
    {"BACK_REFERENCE", "tBACK_REF"}, {"BANG", "!"}, {"BANG_EQUAL", "tNEQ"}, {"BANG_TILDE", "tNMATCH"},
    {"BRACE_LEFT", "\"{\""}, {"BRACE_RIGHT", "\"}\""}, {"BRACKET_LEFT", "\"[\""}, {"BRACKET_LEFT_ARRAY", "tLBRACK"},
    {"BRACKET_LEFT_RIGHT", "tAREF"}, {"BRACKET_LEFT_RIGHT_EQUAL", "tASET"}, {"BRACKET_RIGHT", "\"]\""},
    {"CARET", "^"}, {"CARET_EQUAL", "tOP_ASGN"}, {"CHARACTER_LITERAL", "tCHAR"}, {"CLASS_VARIABLE", "tCVAR"},
    {"COLON", ":"}, {"COLON_COLON", "tCOLON2"}, {"COMMA", ","}, {"COMMENT", "tCOMMENT"}, {"CONSTANT", "tCONSTANT"},
    {"DOT", "."}, {"DOT_DOT", "tDOT2"}, {"DOT_DOT_DOT", "tDOT3"}, {"EMBDOC_BEGIN", "tEMBDOC_BEG"},
    {"EMBDOC_END", "tEMBDOC_END"}, {"EMBDOC_LINE", "tEMBDOC"}, {"EMBEXPR_BEGIN", "tSTRING_DBEG"},
    {"EMBEXPR_END", "tSTRING_DEND"}, {"EMBVAR", "tSTRING_DVAR"}, {"EQUAL", "="}, {"EQUAL_EQUAL", "tEQ"},
    {"EQUAL_EQUAL_EQUAL", "tEQQ"}, {"EQUAL_GREATER", "tASSOC"}, {"EQUAL_TILDE", "tMATCH"}, {"FLOAT", "tFLOAT"},
    {"FLOAT_IMAGINARY", "tIMAGINARY"}, {"FLOAT_RATIONAL", "tRATIONAL"}, {"FLOAT_RATIONAL_IMAGINARY", "tIMAGINARY"},
    {"GLOBAL_VARIABLE", "tGVAR"}, {"GREATER", ">"}, {"GREATER_EQUAL", "tGEQ"}, {"GREATER_GREATER", "tRSHFT"},
    {"GREATER_GREATER_EQUAL", "tOP_ASGN"}, {"HEREDOC_END", "tHEREDOC_END"}, {"HEREDOC_START", "tHEREDOC_BEG"},
    {"IDENTIFIER", "tIDENTIFIER"}, {"IGNORED_NEWLINE", "tIGNORED_NL"}, {"INSTANCE_VARIABLE", "tIVAR"},
    {"INTEGER", "tINTEGER"}, {"INTEGER_IMAGINARY", "tIMAGINARY"}, {"INTEGER_RATIONAL", "tRATIONAL"},
    {"INTEGER_RATIONAL_IMAGINARY", "tIMAGINARY"}, {"KEYWORD_BEGIN_UPCASE", "keyword_BEGIN"},
    {"KEYWORD_END_UPCASE", "keyword_END"}, {"KEYWORD_DO_LOOP", "keyword_do_cond"},
    {"KEYWORD_IF_MODIFIER", "modifier_if"}, {"KEYWORD_RESCUE_MODIFIER", "modifier_rescue"},
    {"KEYWORD_UNLESS_MODIFIER", "modifier_unless"}, {"KEYWORD_UNTIL_MODIFIER", "modifier_until"},
    {"KEYWORD_WHILE_MODIFIER", "modifier_while"}, {"KEYWORD___ENCODING__", "keyword__ENCODING__"},
    {"KEYWORD___FILE__", "keyword__FILE__"}, {"KEYWORD___LINE__", "keyword__LINE__"}, {"LABEL", "tLABEL"},
    {"LABEL_END", "tLABEL_END"}, {"LAMBDA_BEGIN", "tLAMBEG"}, {"LESS", "<"}, {"LESS_EQUAL", "tLEQ"},
    {"LESS_EQUAL_GREATER", "tCMP"}, {"LESS_LESS", "tLSHFT"}, {"LESS_LESS_EQUAL", "tOP_ASGN"},
    {"METHOD_NAME", "tFID"}, {"MINUS", "-"}, {"MINUS_EQUAL", "tOP_ASGN"}, {"MINUS_GREATER", "tLAMBDA"},
    {"NEWLINE", "nl"}, {"NUMBERED_REFERENCE", "tNTH_REF"}, {"PARENTHESIS_LEFT", "\"(\""},
    {"PARENTHESIS_LEFT_PARENTHESES", "tLPAREN_ARG"}, {"PARENTHESIS_RIGHT", "\")\""}, {"PERCENT", "%"},
    {"PERCENT_LOWER_I", "tQSYMBOLS_BEG"}, {"PERCENT_LOWER_W", "tQWORDS_BEG"}, {"PERCENT_LOWER_X", "tXSTRING_BEG"},
    {"PERCENT_UPPER_I", "tSYMBOLS_BEG"}, {"PERCENT_UPPER_W", "tWORDS_BEG"}, {"PIPE", "|"}, {"PIPE_EQUAL", "tOP_ASGN"},
    {"PIPE_PIPE", "tOROP"}, {"PIPE_PIPE_EQUAL", "tOP_ASGN"}, {"PLUS", "+"}, {"PLUS_EQUAL", "tOP_ASGN"},
    {"QUESTION_MARK", "?"}, {"REGEXP_BEGIN", "tREGEXP_BEG"}, {"REGEXP_END", "tREGEXP_END"}, {"SEMICOLON", ";"},
    {"SLASH", "/"}, {"SLASH_EQUAL", "tOP_ASGN"}, {"STAR", "*"}, {"STAR_EQUAL", "tOP_ASGN"}, {"STAR_STAR", "tPOW"},
    {"STAR_STAR_EQUAL", "tOP_ASGN"}, {"STRING_BEGIN", "tSTRING_BEG"}, {"STRING_CONTENT", "tSTRING_CONTENT"},
    {"STRING_END", "tSTRING_END"}, {"SYMBOL_BEGIN", "tSYMBEG"}, {"TILDE", "~"}, {"UAMPERSAND", "tAMPER"},
    {"UCOLON_COLON", "tCOLON3"}, {"UDOT_DOT", "tBDOT2"}, {"UDOT_DOT_DOT", "tBDOT3"}, {"UMINUS", "tUMINUS"},
    {"UMINUS_NUM", "tUMINUS_NUM"}, {"UPLUS", "tUPLUS"}, {"USTAR", "tSTAR"}, {"USTAR_STAR", "tDSTAR"},
    {"WORDS_SEP", "word_sep"},
};

enum { AST_SP, AST_WORD_SEP, AST_DO_BLOCK, AST_DO_LAMBDA, AST_LPAREN, AST_LBRACE, AST_LBRACE_ARG, AST_BACKTICK };

static void
ast_names_init(void) {
    if (ast_names_ready) return;
    /* (the names this file chooses by context, at fixed indexes) */
    ast_intern("tSP"); ast_intern("word_sep"); ast_intern("keyword_do_block"); ast_intern("keyword_do_LAMBDA");
    ast_intern("tLPAREN"); ast_intern("tLBRACE"); ast_intern("tLBRACE_ARG"); ast_intern("`");
    for (int t = 0; t <= PM_TOKEN_MAXIMUM; t++) ast_type_name[t] = AST_SP;
    for (int t = PM_TOKEN_EOF; t < PM_TOKEN_MISSING; t++) {
        const char *pn = pm_token_type_name((pm_token_type_t) t);
        const char *name = NULL;
        for (size_t i = 0; i < sizeof(ast_table) / sizeof(ast_table[0]); i++) {
            if (strcmp(ast_table[i][0], pn) == 0) { name = ast_table[i][1]; break; }
        }
        if (name == NULL) {
            if (strncmp(pn, "KEYWORD_", 8) == 0) {
                /* keyword_alias, keyword_do, ...: parse.y's spelling */
                snprintf(ast_kw[t], sizeof(ast_kw[t]), "keyword_%s", pn + 8);
                for (char *p = ast_kw[t] + 8; *p; p++) if (*p >= 'A' && *p <= 'Z') *p = (char) (*p - 'A' + 'a');
                name = ast_kw[t];
            } else {
                name = pn;
            }
        }
        ast_type_name[t] = ast_intern(name);
    }
    ast_names_ready = 1;
}

/* The names, one per line, in index order. */
const char *
prism_token_names(void) {
    static char *joined = NULL;
    ast_names_init();
    if (joined != NULL) return joined;
    size_t n = 1;
    for (int i = 0; i < ast_nnames; i++) n += strlen(ast_names[i]) + 1;
    joined = (char *) malloc(n);
    if (joined == NULL) abort();
    char *p = joined;
    for (int i = 0; i < ast_nnames; i++) {
        size_t l = strlen(ast_names[i]);
        memcpy(p, ast_names[i], l); p += l; *p++ = '\n';
    }
    *p = 0;
    return joined;
}

/* --- the `do`s that parse.y calls keyword_do_block --- */
typedef struct { const uint8_t *base; uint8_t *flag; } ast_do_t;

static bool
ast_do_visit(const pm_node_t *node, void *data) {
    ast_do_t *d = (ast_do_t *) data;
    const pm_node_t *block = NULL;
    const void *args = NULL;
    bool paren = false;
    if (PM_NODE_TYPE_P(node, PM_CALL_NODE)) {
        const pm_call_node_t *c = (const pm_call_node_t *) node;
        block = c->block; args = c->arguments; paren = c->opening_loc.start != NULL;
    } else if (PM_NODE_TYPE_P(node, PM_SUPER_NODE)) {
        const pm_super_node_t *c = (const pm_super_node_t *) node;
        block = c->block; args = c->arguments; paren = c->lparen_loc.start != NULL;
    }
    if (block != NULL && args != NULL && !paren && PM_NODE_TYPE_P(block, PM_BLOCK_NODE)) {
        const pm_location_t *o = &((const pm_block_node_t *) block)->opening_loc;
        if (o->start != NULL && o->end - o->start == 2 && o->start[0] == 'd' && o->start[1] == 'o') {
            d->flag[o->start - d->base] = 1;
        }
    }
    return true;
}

static bool
ast_is_words(int t) {
    return t == PM_TOKEN_PERCENT_LOWER_W || t == PM_TOKEN_PERCENT_UPPER_W
        || t == PM_TOKEN_PERCENT_LOWER_I || t == PM_TOKEN_PERCENT_UPPER_I;
}

/* bytes [from, to) end with a newline that an odd run of `\` escapes */
static bool
ast_bs_newline(const uint8_t *s, size_t from, size_t to) {
    if (to < from + 2 || s[to - 1] != '\n') return false;
    size_t k = 0, i = to - 1;
    while (i > from && s[i - 1] == '\\') { k++; i--; }
    return (k & 1) == 1;
}

static int32_t *ast_rec = NULL;
static size_t ast_rec_n = 0, ast_rec_cap = 0;
static size_t *ast_lines = NULL;
static size_t ast_nlines = 0, ast_lines_cap = 0;

static size_t
ast_line_of(size_t off) {
    size_t lo = 0, hi = ast_nlines;   /* the last start <= off */
    while (hi - lo > 1) {
        size_t mid = (lo + hi) / 2;
        if (ast_lines[mid] <= off) lo = mid; else hi = mid;
    }
    return lo;
}

static void
ast_emit(int name, size_t s, size_t e) {
    ast_rec = (int32_t *) ast_grow(ast_rec, &ast_rec_cap, ast_rec_n + 7, sizeof(int32_t));
    size_t l1 = ast_line_of(s), l2 = ast_line_of(e - 1);
    int32_t *r = ast_rec + ast_rec_n;
    r[0] = name; r[1] = (int32_t) s; r[2] = (int32_t) e;
    r[3] = (int32_t) (l1 + 1); r[4] = (int32_t) (s - ast_lines[l1]);
    r[5] = (int32_t) (l2 + 1); r[6] = (int32_t) (e - ast_lines[l2]);
    ast_rec_n += 7;
}

/* the gap [from, to): `\` newline, a newline, a run of anything else, a lone `\` */
static void
ast_emit_gap(const uint8_t *s, size_t from, size_t to, int name) {
    size_t i = from;
    while (i < to) {
        size_t j = i;
        if (s[i] == '\\') {
            if (i + 1 < to && s[i + 1] == '\n') j = i + 2;
            else if (i + 2 < to && s[i + 1] == '\r' && s[i + 2] == '\n') j = i + 3;
            else j = i + 1;
        } else if (s[i] == '\n') {
            j = i + 1;
        } else {
            while (j < to && s[j] != '\\' && s[j] != '\n') j++;
        }
        ast_emit(name, i, j);
        i = j;
    }
}

typedef struct { bool sq, dash, expand, zero, cont; int depth; long last; } ast_heredoc_t;

static int
ast_cmp_start(const void *a, const void *b) {
    const size_t *x = (const size_t *) a, *y = (const size_t *) b;
    return x[0] < y[0] ? -1 : x[0] > y[0] ? 1 : (x[1] < y[1] ? -1 : x[1] > y[1]);
}

mere_bytes *
prism_tokens(mere_bytes *src) {
    ast_names_init();
    const uint8_t *s = (const uint8_t *) src->data;
    size_t size = (size_t) src->len;

    /* lex (and parse: the `do`s need the tree) */
    pm_options_t options = { 0 };
    pm_parser_t parser;
    pm_parser_init(&parser, s, size, &options);
    pm_lex_callback_t cb = { .data = NULL, .callback = ast_on_token };
    parser.lex_callback = &cb;
    ast_lexed_n = 0;
    pm_node_t *node = pm_parse(&parser);
    uint8_t *doflag = (uint8_t *) calloc(size + 1, 1);
    if (doflag == NULL) abort();
    ast_do_t dd = { s, doflag };
    pm_visit_node(node, ast_do_visit, &dd);
    pm_node_destroy(&parser, node);
    pm_parser_free(&parser);

    /* names, in the lexer's order (a %w separator cut after its newlines) */
    ast_vec_t lx = { 0 };
    uint32_t prev = PM_LEX_STATE_BEG;
    int depth = 0, lambda_depth = -1;
    for (size_t k = 0; k < ast_lexed_n; k++) {
        ast_lexed_t L = ast_lexed[k];
        int ty = L.type;
        if (ty == PM_TOKEN_EOF) continue;
        int name = ast_type_name[ty];
        switch (ty) {
          case PM_TOKEN_PARENTHESIS_LEFT:
            if ((prev & (PM_LEX_STATE_BEG | PM_LEX_STATE_MID | PM_LEX_STATE_CLASS)) != 0
                || (prev & (PM_LEX_STATE_ARG | PM_LEX_STATE_LABELED)) == (PM_LEX_STATE_ARG | PM_LEX_STATE_LABELED))
                name = AST_LPAREN;
            break;
          case PM_TOKEN_BRACE_LEFT:
            if (prev & PM_LEX_STATE_LABELED) name = AST_LBRACE;
            else if (prev & (PM_LEX_STATE_ARG | PM_LEX_STATE_CMDARG | PM_LEX_STATE_END | PM_LEX_STATE_ENDFN)) ;
            else if (prev & PM_LEX_STATE_ENDARG) name = AST_LBRACE_ARG;
            else name = AST_LBRACE;
            break;
          case PM_TOKEN_BACKTICK:
            if (prev & (PM_LEX_STATE_FNAME | PM_LEX_STATE_DOT)) name = AST_BACKTICK;
            break;
          default: break;
        }
        switch (ty) {
          case PM_TOKEN_PARENTHESIS_LEFT: case PM_TOKEN_PARENTHESIS_LEFT_PARENTHESES: case PM_TOKEN_BRACKET_LEFT:
          case PM_TOKEN_BRACKET_LEFT_ARRAY: case PM_TOKEN_BRACE_LEFT: case PM_TOKEN_LAMBDA_BEGIN: case PM_TOKEN_EMBEXPR_BEGIN:
            depth++; break;
          case PM_TOKEN_PARENTHESIS_RIGHT: case PM_TOKEN_BRACKET_RIGHT: case PM_TOKEN_BRACE_RIGHT: case PM_TOKEN_EMBEXPR_END:
            depth--; break;
          default: break;
        }
        if (ty == PM_TOKEN_MINUS_GREATER) lambda_depth = depth;
        else if (ty == PM_TOKEN_KEYWORD_DO) {
            if (lambda_depth == depth) { name = AST_DO_LAMBDA; lambda_depth = -1; }
            else if (doflag[L.start]) name = AST_DO_BLOCK;
        } else if (ty == PM_TOKEN_LAMBDA_BEGIN) lambda_depth = -1;
        int look = ty == PM_TOKEN_NEWLINE ? 1 : ty == PM_TOKEN_IGNORED_NEWLINE ? 2 : 0;
        if (ty == PM_TOKEN_WORDS_SEP) {
            uint32_t a = L.start;
            for (uint32_t i = L.start; i < L.end; i++) {
                if (s[i] == '\n') { ast_push(&lx, (ast_tok_t) { name, ty, 0, a, i + 1 }); a = i + 1; }
            }
            if (a < L.end) ast_push(&lx, (ast_tok_t) { name, ty, 0, a, L.end });
        } else {
            ast_push(&lx, (ast_tok_t) { name, ty, look, L.start, L.end });
        }
        prev = L.state;
    }
    free(doflag);

    /* a statement's newline after the comment lines that follow it (an
     * ignored one only when a leading `.` / `&.` comes after them) */
    for (size_t i = 0; i < lx.n; ) {
        if (lx.v[i].look) {
            size_t j = i + 1;
            while (j < lx.n && lx.v[j].ptype == PM_TOKEN_COMMENT) j++;
            if (j > i + 1 && (lx.v[i].look == 1
                              || (j < lx.n && (lx.v[j].ptype == PM_TOKEN_DOT || lx.v[j].ptype == PM_TOKEN_AMPERSAND_DOT)))) {
                ast_tok_t nl = lx.v[i];
                memmove(&lx.v[i], &lx.v[i + 1], (j - i - 1) * sizeof(ast_tok_t));
                lx.v[j - 1] = nl;
                i = j;
                continue;
            }
        }
        i++;
    }

    /* heredoc bodies cut as parse.y cuts them */
    ast_vec_t res = { 0 };
    ast_heredoc_t hs[64];
    int nh = 0;
    for (size_t k = 0; k < lx.n; k++) {
        ast_tok_t tok = lx.v[k];
        if (tok.ptype == PM_TOKEN_HEREDOC_START) {
            const uint8_t *t = s + tok.start;
            size_t tl = tok.end - tok.start;
            ast_heredoc_t h = { 0 };
            h.sq = tl > 2 && t[2] == '~';
            h.dash = tl > 2 && t[2] == '-';
            size_t q = (h.sq || h.dash) ? 3 : 2;
            h.expand = !(q < tl && t[q] == '\'');
            h.last = -1;
            if (nh < 64) hs[nh++] = h;
            ast_push(&res, tok);
            continue;
        }
        if (nh > 0) {
            ast_heredoc_t *h = &hs[nh - 1];
            if (tok.ptype == PM_TOKEN_HEREDOC_END && h->depth == 0) { nh--; ast_push(&res, tok); continue; }
            if (tok.ptype == PM_TOKEN_EMBEXPR_BEGIN) h->depth++;
            if (tok.ptype == PM_TOKEN_EMBEXPR_END) h->depth--;
            if (tok.ptype == PM_TOKEN_STRING_CONTENT && h->depth == 0) {
                bool merged = false;
                if (h->sq) {
                    bool line_start = tok.start == 0 || s[tok.start - 1] == '\n';
                    uint8_t c = tok.start < size ? s[tok.start] : 0;
                    if (!h->zero && line_start && c != ' ' && c != '\t' && c != '\n' && c != '\r') h->zero = true;
                    if (h->zero && res.n > 0 && h->last == (long) res.n - 1 && !h->cont
                        && res.v[res.n - 1].ptype == PM_TOKEN_STRING_CONTENT && res.v[res.n - 1].end == tok.start) {
                        res.v[res.n - 1].end = tok.end;
                        merged = true;
                    }
                }
                if (!merged) { ast_push(&res, tok); h->last = (long) res.n - 1; }
                h->cont = false;
                if (h->expand && (h->sq || h->dash)) {
                    ast_tok_t t0 = res.v[res.n - 1];
                    size_t from = t0.start, cut0 = res.n - 1;
                    for (size_t i = t0.start; i < t0.end; i++) {
                        if (s[i] == '\n' && i + 1 < t0.end && ast_bs_newline(s, t0.start, i + 1)) {
                            if (from == t0.start) res.n = cut0;
                            ast_tok_t piece = t0; piece.start = (uint32_t) from; piece.end = (uint32_t) (i + 1);
                            ast_push(&res, piece);
                            from = i + 1;
                        }
                    }
                    if (from != t0.start) {
                        ast_tok_t piece = t0; piece.start = (uint32_t) from;
                        ast_push(&res, piece);
                        h->last = (long) res.n - 1;
                    }
                    if (ast_bs_newline(s, t0.start, t0.end)) h->cont = true;
                }
                continue;
            }
            if (tok.ptype != PM_TOKEN_STRING_CONTENT) h->last = -1;
        }
        ast_push(&res, tok);
    }
    free(lx.v);

    /* up to `__END__`; the gaps, found in the order of place */
    size_t cut = size;
    for (size_t k = 0; k < res.n; k++) if (res.v[k].ptype == PM_TOKEN___END__) { cut = res.v[k].start; break; }
    size_t m = 0;
    for (size_t k = 0; k < res.n; k++) {
        ast_tok_t t = res.v[k];
        if (t.ptype == PM_TOKEN___END__ || t.start >= cut || t.end <= t.start) continue;
        res.v[m++] = t;
    }
    res.n = m;
    size_t *order = (size_t *) malloc((m + 1) * 2 * sizeof(size_t));
    uint8_t *keep = (uint8_t *) calloc(m + 1, 1);
    size_t *gap = (size_t *) malloc((m + 1) * 3 * sizeof(size_t));   /* from, to, words */
    if (order == NULL || keep == NULL || gap == NULL) abort();
    for (size_t k = 0; k < m; k++) { order[2 * k] = res.v[k].start; order[2 * k + 1] = k; }
    qsort(order, m, 2 * sizeof(size_t), ast_cmp_start);
    size_t pos = 0;
    int words = 0;
    for (size_t k = 0; k < m; k++) {
        size_t i = order[2 * k + 1];
        ast_tok_t t = res.v[i];
        gap[3 * i] = gap[3 * i + 1] = 0;
        if (t.start < pos) continue;
        keep[i] = 1;
        gap[3 * i] = pos; gap[3 * i + 1] = t.start; gap[3 * i + 2] = words > 0;
        if (ast_is_words(t.ptype)) words++;
        if (t.ptype == PM_TOKEN_STRING_END && words > 0) words--;
        pos = t.end;
    }

    /* the lines, then the records in the lexer's order */
    ast_nlines = 0;
    ast_lines = (size_t *) ast_grow(ast_lines, &ast_lines_cap, 1, sizeof(size_t));
    ast_lines[ast_nlines++] = 0;
    for (size_t i = 0; i < size; i++) {
        if (s[i] == '\n') {
            ast_lines = (size_t *) ast_grow(ast_lines, &ast_lines_cap, ast_nlines + 1, sizeof(size_t));
            ast_lines[ast_nlines++] = i + 1;
        }
    }
    ast_rec_n = 0;
    for (size_t i = 0; i < m; i++) {
        if (!keep[i]) continue;
        if (gap[3 * i + 1] > gap[3 * i]) ast_emit_gap(s, gap[3 * i], gap[3 * i + 1], gap[3 * i + 2] ? AST_WORD_SEP : AST_SP);
        ast_emit(res.v[i].name, res.v[i].start, res.v[i].end);
    }
    if (pos < cut) ast_emit_gap(s, pos, cut, AST_SP);
    free(order); free(keep); free(gap); free(res.v);

    size_t n = ast_rec_n * sizeof(int32_t);
    if (out == NULL || out_cap < n) {
        size_t cap = n < 4096 ? 4096 : n;
        mere_bytes *grown = (mere_bytes *) realloc(out, sizeof(mere_bytes) + cap);
        if (grown == NULL) abort();
        out = grown;
        out_cap = cap;
    }
    out->len = (long long) n;
    if (n > 0) memcpy(out->data, ast_rec, n);
    return out;
}
