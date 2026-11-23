/* The inside of mere-ruby's C API: what the files of capi/ share and no
 * extension sees.
 *
 * A VALUE is CRuby's bit pattern for nil, true, false, a Fixnum, a flonum and
 * a Symbol; anything else is a HANDLE -- MR_BASE plus eight times a number
 * the interpreter gave out for the value. It is never an address. The structs
 * an extension reads through RSTRING(), RARRAY(), RBASIC() and the rest are
 * MIRRORS this side keeps for a handle (mirror.c): made when first asked for,
 * brought up to date when the interpreter has run since, written back when C
 * changed them. The interpreter's copy is the value.
 *
 * C asks the interpreter for everything through mr_up(): one operation, up
 * to five words, more words / bytes / a name / a double in the transit
 * buffers beside it. An exception the interpreter raises under mr_up() does
 * not unwind C: mr_up() gets it back as an OUTCOME (a handle) and longjmps to
 * the nearest C guard -- rb_protect, rb_rescue, rb_ensure, or the entry of
 * the call that brought control into C, which hands it back to the
 * interpreter to raise there.
 */
#ifndef MR_CAPI_H
#define MR_CAPI_H 1
#include "ruby.h"
#include "ruby/encoding.h"
#include "mere_capi.h"
#include <setjmp.h>

/* Above every handle the interpreter uses for itself (2^48 and up), so a
 * collection reading a C stack can tell these apart. */
#define MR_BASE ((VALUE)1 << 56)
#define MR_LIMIT (MR_BASE + ((VALUE)1 << 40))
#define MR_HANDLE_P(v) ((v) >= MR_BASE && (v) < MR_LIMIT && ((v) & 7) == 0)
#define MR_NUMBER(v) ((long)(((v) - MR_BASE) >> 3))
#define MR_HANDLE(n) (MR_BASE + ((VALUE)(n) << 3))

/* What C asks of the interpreter (capi_up in main.mere answers each). */
enum mr_op {
    MR_DESCRIBE = 1,    /* a: handle -> type | frozen<<5 | enc<<8; word 0: its class */
    MR_STR_GET,         /* a: String -> its bytes (given) */
    MR_STR_SET,         /* a: String, bytes: its new contents */
    MR_ARY_GET,         /* a: Array, b: version held + 1 -> length (words: elements, then version), or -1: unchanged */
    MR_ARY_SET,         /* a: Array, b: length; words: elements */
    MR_SEND,            /* a: receiver, b: ID, c: argc, d: block or nil, e: flags; words: arguments */
    MR_STR_NEW,         /* bytes; text: the encoding's name -> String */
    MR_FLOAT_NEW,       /* dbl -> Float (one that is not a flonum) */
    MR_FLOAT_GET,       /* a: Float -> dbl */
    MR_INT_NEW,         /* text: digits, a: base -> Integer */
    MR_INT_GET,         /* a: Integer, b: base -> text */
    MR_CONST,           /* text: "A::B" from Object -> its value */
    MR_DEFINE_CLASS,    /* a: outer or nil, b: superclass, c: 1 for a module; text: name -> the class */
    MR_DEFINE_METHOD,   /* a: class, b: method number, c: arity, d: kind; text: name */
    MR_DEFINE_ALLOC,    /* a: class, b: method number, or -1 to remove */
    MR_OBJECT_NEW,      /* a: class -> a bare instance (what a C struct is wrapped in) */
    MR_RAISE,           /* a: exception */
    MR_OUTCOME,         /* a: outcome, b: what is asked of it (enum mr_outcome_ask) */
    MR_ERRINFO,         /* a: 0 read $!, 1 write b to it */
    MR_EVAL,            /* bytes: source; text: file; a: line; b: self or undef; -> value */
    MR_PROC_NEW,        /* a: function number, c: 0 a block (b: its data), 1 the same as a lambda, 2 a method body (b: arity, d: its name) -> Proc */
    MR_SYMBOL,          /* bytes: a name with bytes text cannot carry -> Symbol (its ID) */
    MR_GC,              /* a: 0 collect, 1 stress on, 2 stress off, 3 enable, 4 disable, 5 count */
    MR_ARY_NEW,         /* a: length; words: elements -> Array */
    MR_BREAK,           /* a: value -- `break value` from the block this C was called in */
    MR_BACKREF,         /* a: 0 read, 1 write (b: the MatchData or nil) -- `$~` of the Ruby frame that called C */
    MR_DEFINE_GVAR,     /* a: the function that reads and writes it; text: the name without `$` */
    MR_RX_DEPTH = 28,   /* a: 0 read, 1 write (b: the limit) -- how deep a pattern may nest */
    MR_SYM_STATE = 31   /* a: String or Symbol -> 0 not a Symbol, 1 a dynamic one, 2 pinned down */
};
enum mr_send_flag { MR_SEND_PUBLIC = 1, MR_SEND_KW = 2, MR_SEND_PASS_BLOCK = 4, MR_SEND_SUPER = 8,
    /* (16: the receiver is the current one)
     * THE BUILTIN, NOT WHAT THE RECEIVER'S CLASS MADE OF THE NAME. rb_ary_push
     * is CRuby's own push, whatever `class A < Array; def push` says; a
     * primitive of the C API names the class whose method it is, and where
     * the receiver's class (or its singleton) overrides the name, that
     * class's own method is called instead of the override. */
    MR_SEND_ARRAY = 32, MR_SEND_STRING = 64, MR_SEND_HASH = 128, MR_SEND_KERNEL = 256 };
enum mr_method_kind { MR_M_INSTANCE = 0, MR_M_SINGLETON, MR_M_MODULE_FUNCTION, MR_M_PRIVATE, MR_M_PROTECTED, MR_M_GLOBAL };
enum mr_outcome_ask { MR_O_TAG = 0, MR_O_EXCEPTION, MR_O_ENTER, MR_O_VALUE };
/* What the interpreter asks C to run (mr_capi_enter's req.op). */
enum mr_run { MR_RUN_METHOD = 1, MR_RUN_INIT, MR_RUN_BLOCK };
/* CRuby's jump tags (rb_protect's *state, rb_jump_tag's argument). */
enum mr_tag { MR_TAG_NONE = 0, MR_TAG_RETURN = 1, MR_TAG_BREAK = 2, MR_TAG_NEXT = 3, MR_TAG_RETRY = 4,
              MR_TAG_REDO = 5, MR_TAG_RAISE = 6, MR_TAG_THROW = 7, MR_TAG_FATAL = 8 };

/* ---- core.c: the way across ------------------------------------------- */
VALUE mr_up(int op, VALUE a, VALUE b, VALUE c, VALUE d, VALUE e);
#define mr_up1(op, a) mr_up((op), (a), 0, 0, 0, 0)
#define mr_up2(op, a, b) mr_up((op), (a), (b), 0, 0, 0)
/* The transit buffers. Whatever is put there is read by the other side
 * before it does anything else; nothing is kept in them across a call. */
void mr_put_words(long n, const VALUE *words);
VALUE mr_word(long i);
void mr_put_bytes(const void *p, long n);
const mere_bytes *mr_got_bytes(void);
void mr_put_text(const char *text);
const char *mr_got_text(void);
void mr_put_dbl(double d);
double mr_got_dbl(void);
/* Call a method by name: mr_call(recv, "name", n, a1 .. an). */
/* The send flag for a `kw` argument of the *_kw functions: nonzero says the
 * last argument is the keywords (RB_PASS_CALLED_KEYWORDS is that question
 * asked of the call in progress, where it is written). */
int mr_kw(int kw);
VALUE mr_call(VALUE recv, const char *name, int argc, ...);
/* (...the same, as the builtin of the class `owner` names: MR_SEND_ARRAY, ...) */
VALUE mr_callo(int owner, VALUE recv, const char *name, int argc, ...);
#define mr_calla(recv, ...) mr_callo(MR_SEND_ARRAY, recv, __VA_ARGS__)
#define mr_calls(recv, ...) mr_callo(MR_SEND_STRING, recv, __VA_ARGS__)
#define mr_callh(recv, ...) mr_callo(MR_SEND_HASH, recv, __VA_ARGS__)
#define mr_callk(recv, ...) mr_callo(MR_SEND_KERNEL, recv, __VA_ARGS__)
VALUE mr_callv(VALUE recv, ID mid, int argc, const VALUE *argv, VALUE block, int flags);
/* The top-level object: Kernel's functions (Integer(), throw, sleep ...) are
 * private methods, and it is as good a receiver as any. */
VALUE mr_main(void);
/* A piece of Ruby this side is written in (a lambda, mostly): evaluated once
 * at the top level and kept. `source` is a string literal -- its address is
 * the key. */
VALUE mr_ruby(const char *source);
/* The constant at a path from Object, kept by path ("Comparable", "File::Stat"). */
VALUE mr_const(const char *path);
/* Unwind C to the nearest guard with an outcome on its way out. */
RBIMPL_ATTR_NORETURN() void mr_throw(VALUE outcome);
/* Run body(arg) under a guard: Qundef in *outcome when it returned, the
 * outcome when something left it. */
VALUE mr_guarded(VALUE (*body)(VALUE), VALUE arg, VALUE *outcome);
/* The block the C method in progress was called with (nil when none). */
VALUE mr_frame_block(void);
/* A C function registered to be run by number. */
long mr_register_function(void *fn, int arity);
RBIMPL_ATTR_NORETURN() void mr_fatal(const char *message);
/* MERE_RUBY_CAPI_WITHOUT=dmark|dfree|ensure|switch|fileprobe|builtin: one guarantee switched off, for
 * the negative controls of tools/capi_check.py. UNSOUND; a diagnostic. */
int mr_without(const char *what);
/* An API this C side does not provide: NotImplementedError, never a guess. */
RBIMPL_ATTR_NORETURN() void mr_unsupported(const char *what);

/* ---- mirror.c: the structs behind a handle ------------------------------ */
struct mr_mirror;
struct mr_mirror *mr_mirror_of(VALUE obj);
/* Make a data object's struct (T_DATA) for a new bare instance. */
void mr_mirror_data(VALUE obj, int typed, const rb_data_type_t *type, void *data,
                    RUBY_DATA_FUNC dmark, RUBY_DATA_FUNC dfree, size_t embedded);
/* Before control goes to the interpreter: write back what C changed. */
void mr_mirrors_flush(void);
/* After it comes back: every struct is stale until asked for again. */
extern unsigned long mr_epoch;
/* The String's bytes changed on the interpreter's side by this C's own
 * request: nothing to write back, and the struct is stale. */
void mr_mirror_forget(VALUE obj);

long mr_string_capacity(VALUE str);
int mr_string_terminator(VALUE str);
void mr_string_reserve(VALUE str, long capa);

/* ---- symbol.c ----------------------------------------------------------- */
const char *mr_id_name(ID id, long *len);

/* ---- encoding.c --------------------------------------------------------- */
int mr_enc_index_of_name(const char *name);
const char *mr_enc_name_of_index(int index);

#endif
