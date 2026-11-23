/* The way between C and the interpreter: calls in progress, the guards an
 * outcome unwinds to, the transit buffers, registered C functions, and
 * loaded extensions. See mr_capi.h for the shape of the whole. */
#include "mr_capi.h"
#include <dlfcn.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>

/* ---- calls in progress --------------------------------------------------- */
struct mr_guard { jmp_buf jump; struct mr_guard *prev; };
struct mr_frame {
    closure_CapiReq_int up;    /* how this call asks the interpreter */
    struct mr_frame *prev;
    struct mr_guard *guard;     /* where an outcome unwinds to */
    VALUE pending;              /* the outcome that is unwinding */
    VALUE block;                /* the block the method was called with */
    ID method;                  /* the name the method was called by */
    int keywords;               /* its last argument is the keywords of the call */
    VALUE outcome;              /* set by the interpreter when a request raised */
    int raised;
};
static struct mr_frame *cur;
static VALUE c_errinfo = Qnil;   /* rb_errinfo's (mr_frame_errinfo, below) */
static int depth;
unsigned long mr_epoch = 1;
static long stats[8];
enum { ST_ENTER, ST_UP, ST_THROW, ST_LIBRARIES, ST_FUNCTIONS };

void mr_fatal(const char *message) {
    fprintf(stderr, "mere-ruby: [BUG] C API: %s\n", message);
    abort();
}

/* ---- transit ------------------------------------------------------------- */
static VALUE *words;
static long words_cap, words_put;
static mere_bytes *bytes_out;       /* C -> interpreter */
static long bytes_out_cap;
static mere_bytes *bytes_in;        /* interpreter -> C */
static long bytes_in_cap;
static char *text_out, *text_in;
static long text_out_cap, text_in_cap;
static double dbl;

static void words_need(long n) {
    if (n <= words_cap) return;
    long cap = words_cap ? words_cap : 64;
    while (cap < n) cap *= 2;
    words = realloc(words, sizeof(VALUE) * (size_t)cap);
    if (!words) mr_fatal("out of memory");
    memset(words + words_cap, 0, sizeof(VALUE) * (size_t)(cap - words_cap));
    words_cap = cap;
}
void mr_put_words(long n, const VALUE *v) {
    words_need(n);
    if (n > 0) memcpy(words, v, sizeof(VALUE) * (size_t)n);
    words_put = n;
}
VALUE mr_word(long i) { return i >= 0 && i < words_cap ? words[i] : Qnil; }
CapiWord mr_capi_get(int i) {
    CapiWord w = { (long long)mr_word(i) };
    return w;
}
int mr_capi_set(int i, CapiWord w) {
    if (i < 0) return 0;
    words_need((long)i + 1);
    words[i] = (VALUE)w.mu_w;
    return 0;
}
static mere_bytes *bytes_need(mere_bytes **buffer, long *cap, long n) {
    if (!*buffer || n > *cap) {
        long want = *cap ? *cap : 256;
        while (want < n) want *= 2;
        *buffer = realloc(*buffer, sizeof(mere_bytes) + (size_t)want + 1);
        if (!*buffer) mr_fatal("out of memory");
        *cap = want;
    }
    (*buffer)->len = n;
    return *buffer;
}
void mr_put_bytes(const void *p, long n) {
    mere_bytes *b = bytes_need(&bytes_out, &bytes_out_cap, n);
    if (n > 0) memcpy(b->data, p, (size_t)n);
}
mere_bytes *mr_capi_bytes(void) { return bytes_out ? bytes_out : bytes_need(&bytes_out, &bytes_out_cap, 0); }
int mr_capi_give(mere_bytes *given) {
    mere_bytes *b = bytes_need(&bytes_in, &bytes_in_cap, given->len);
    if (given->len > 0) memcpy(b->data, given->data, (size_t)given->len);
    b->data[given->len] = 0;
    return 0;
}
const mere_bytes *mr_got_bytes(void) { return bytes_in ? bytes_in : bytes_need(&bytes_in, &bytes_in_cap, 0); }
static void text_set(char **buffer, long *cap, const char *text) {
    long n = (long)strlen(text) + 1;
    if (n > *cap) {
        *buffer = realloc(*buffer, (size_t)n);
        if (!*buffer) mr_fatal("out of memory");
        *cap = n;
    }
    memcpy(*buffer, text, (size_t)n);
}
void mr_put_text(const char *text) { text_set(&text_out, &text_out_cap, text); }
char *mr_capi_text(void) { return text_out ? text_out : ""; }
int mr_capi_say(const char *text) { text_set(&text_in, &text_in_cap, text); return 0; }
const char *mr_got_text(void) { return text_in ? text_in : ""; }
void mr_put_dbl(double d) { dbl = d; }
double mr_got_dbl(void) { return dbl; }
double mr_capi_dbl(void) { return dbl; }
int mr_capi_set_dbl(double d) { dbl = d; return 0; }

/* Writing a struct back asks the interpreter in the middle of some other
 * request's preparation: what that request had put in transit is set aside. */
struct mr_transit { VALUE *words; long nwords; mere_bytes *bytes; char *text; double dbl; };
void mr_transit_save(struct mr_transit *t, long nwords) {
    if (nwords < 0) nwords = words_put;
    t->nwords = nwords < words_cap ? nwords : words_cap;
    t->words = NULL;
    if (t->nwords > 0) {
        t->words = malloc(sizeof(VALUE) * (size_t)t->nwords);
        if (!t->words) mr_fatal("out of memory");
        memcpy(t->words, words, sizeof(VALUE) * (size_t)t->nwords);
    }
    t->bytes = NULL;
    if (bytes_out) {
        t->bytes = malloc(sizeof(mere_bytes) + (size_t)bytes_out->len + 1);
        if (!t->bytes) mr_fatal("out of memory");
        memcpy(t->bytes, bytes_out, sizeof(mere_bytes) + (size_t)bytes_out->len);
    }
    t->text = text_out ? strdup(text_out) : NULL;
    t->dbl = dbl;
}
void mr_transit_restore(struct mr_transit *t) {
    if (t->words) { mr_put_words(t->nwords, t->words); free(t->words); }
    if (t->bytes) { mr_put_bytes(t->bytes->data, (long)t->bytes->len); free(t->bytes); }
    if (t->text) { mr_put_text(t->text); free(t->text); }
    dbl = t->dbl;
}

/* ---- asking the interpreter ---------------------------------------------- */
int mr_capi_raise(CapiWord outcome) {
    if (!cur) mr_fatal("an outcome with no call in progress");
    cur->raised = 1;
    cur->outcome = (VALUE)outcome.mu_w;
    return 0;
}
void mr_throw(VALUE outcome) {
    if (!cur || !cur->guard) mr_fatal("an outcome with no guard to unwind to");
    stats[ST_THROW]++;
    cur->pending = outcome;
    RUBY_LONGJMP(cur->guard->jump, 1);
}
/* A request that only reads leaves every struct as fresh as it was. */
static int reads_only(int op) {
    return op == MR_DESCRIBE || op == MR_STR_GET || op == MR_ARY_GET || op == MR_FLOAT_GET
        || op == MR_INT_GET || op == MR_OUTCOME;
}
VALUE mr_up(int op, VALUE a, VALUE b, VALUE c, VALUE d, VALUE e) {
    struct mr_frame *frame = cur;
    if (!frame) mr_fatal("called with no call from the interpreter in progress (a C thread of its own?)");
    if (!reads_only(op) && op != MR_STR_SET && op != MR_ARY_SET) mr_mirrors_flush();
    CapiReq request = { op, (long long)a, (long long)b, (long long)c, (long long)d, (long long)e };
    stats[ST_UP]++;
    frame->raised = 0;
    long long answer = frame->up.fn(frame->up.env, request);
    if (cur != frame) mr_fatal("the calls in progress are out of step");
    if (!reads_only(op)) mr_epoch++;
    if (frame->raised) {
        frame->raised = 0;
        mr_throw(frame->outcome);
    }
    return (VALUE)answer;
}
VALUE mr_guarded(VALUE (*body)(VALUE), VALUE arg, VALUE *outcome) {
    struct mr_frame *frame = cur;
    if (!frame) mr_fatal("a guard with no call in progress");
    struct mr_guard guard;
    volatile VALUE result = Qnil;
    guard.prev = frame->guard;
    frame->guard = &guard;
    *outcome = Qundef;
    if (RUBY_SETJMP(guard.jump) == 0) {
        result = body(arg);
    }
    else {
        *outcome = frame->pending;
        frame->pending = Qundef;
        result = Qnil;
    }
    frame->guard = guard.prev;
    return result;
}
VALUE mr_frame_block(void) { return cur ? cur->block : Qnil; }
/* (rb_iterate: the block of the call in progress, for as long as one function runs) */
VALUE mr_frame_set_block(VALUE block) {
    if (!cur) mr_fatal("no call in progress to give a block to");
    VALUE old = cur->block;
    cur->block = block;
    return old;
}
ID mr_frame_method(void) { return cur ? cur->method : 0; }
int mr_frame_keywords(void) { return cur ? cur->keywords : 0; }
int mr_kw(int kw) { return kw ? MR_SEND_KW : 0; }

/* (rb_iterate's block, waiting for the first method its function calls) */
VALUE mr_iterate_block;
VALUE mr_callv(VALUE recv, ID mid, int argc, const VALUE *argv, VALUE block, int flags) {
    if (mr_iterate_block && NIL_P(block)) { block = mr_iterate_block; mr_iterate_block = 0; }
    /* (keywords passed are a Hash, or one by #to_hash -- every *_kw function
     *  of the C API refuses anything else: "no implicit conversion of
     *  Integer into Hash") */
    if ((flags & MR_SEND_KW) && argc > 0 && !RB_TYPE_P(argv[argc - 1], T_HASH))
        rb_convert_type(argv[argc - 1], T_HASH, "Hash", "to_hash");
    mr_put_words(argc, argv);
    return mr_up(MR_SEND, recv, (VALUE)mid, (VALUE)argc, block, (VALUE)flags);
}
VALUE mr_call(VALUE recv, const char *name, int argc, ...) {
    VALUE argv[16];
    va_list ap;
    if (argc > 16) mr_fatal("mr_call: too many arguments");
    va_start(ap, argc);
    for (int i = 0; i < argc; i++) argv[i] = va_arg(ap, VALUE);
    va_end(ap);
    return mr_callv(recv, rb_intern(name), argc, argv, Qnil, 0);
}
VALUE mr_callo(int owner, VALUE recv, const char *name, int argc, ...) {
    VALUE argv[16];
    va_list ap;
    if (argc > 16) mr_fatal("mr_callo: too many arguments");
    va_start(ap, argc);
    for (int i = 0; i < argc; i++) argv[i] = va_arg(ap, VALUE);
    va_end(ap);
    return mr_callv(recv, rb_intern(name), argc, argv, Qnil, mr_without("builtin") ? 0 : owner);
}
VALUE mr_const(const char *path) {
    mr_put_text(path);
    return mr_up1(MR_CONST, Qnil);
}
int mr_without(const char *what) {
    static const char *knob;
    static int read;
    if (!read) { knob = getenv("MERE_RUBY_CAPI_WITHOUT"); read = 1; }
    return knob && !strcmp(knob, what);
}
VALUE mr_main(void) { return mr_ruby("self"); }
void mr_unsupported_symbol(const char *name) { mr_unsupported(name); }
VALUE mr_ruby(const char *source) {
    static struct { const char *source; VALUE value; } kept[128];
    static int count;
    for (int i = 0; i < count; i++) if (kept[i].source == source) return kept[i].value;
    if (count == 128) mr_fatal("too many pieces of Ruby kept by the C API");
    /* (UTF-8, as a source file is: the literals in it are then UTF-8 too) */
    VALUE value = mr_call(mr_const("TOPLEVEL_BINDING"), "eval", 1, rb_utf8_str_new_cstr(source));
    rb_gc_register_mark_object(value);
    kept[count].source = source;
    kept[count].value = value;
    count++;
    return value;
}
void mr_unsupported(const char *what) {
    rb_raise(rb_eNotImpError, "%s is not provided by mere-ruby's C API", what);
}

/* ---- C functions run by number -------------------------------------------- */
struct mr_function { void *fn; int arity; };
static struct mr_function *functions;
static long function_count, function_cap;
void *mr_registered_function(long number) {
    return number >= 0 && number < function_count ? functions[number].fn : NULL;
}
long mr_register_function(void *fn, int arity) {
    for (long i = 0; i < function_count; i++)
        if (functions[i].fn == fn && functions[i].arity == arity) return i;
    if (function_count == function_cap) {
        function_cap = function_cap ? function_cap * 2 : 256;
        functions = realloc(functions, sizeof(*functions) * (size_t)function_cap);
        if (!functions) mr_fatal("out of memory");
    }
    functions[function_count].fn = fn;
    functions[function_count].arity = arity;
    stats[ST_FUNCTIONS] = function_count + 1;
    return function_count++;
}

typedef VALUE (*fn_argv)(int, VALUE *, VALUE);
typedef VALUE (*fn_args)(VALUE, VALUE);
typedef VALUE (*fn0)(VALUE);
typedef VALUE (*fn1)(VALUE, VALUE);
typedef VALUE (*fn2)(VALUE, VALUE, VALUE);
typedef VALUE (*fn3)(VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn4)(VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn5)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn6)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn7)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn8)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn9)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn10)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn11)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn12)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn13)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn14)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn15)(VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE, VALUE);
typedef VALUE (*fn_block)(VALUE, VALUE, int, const VALUE *, VALUE);

static VALUE run_method(long number, VALUE self, long argc, VALUE *v) {
    if (number < 0 || number >= function_count) mr_fatal("no such C method");
    void *f = functions[number].fn;
    int arity = functions[number].arity;
    if (arity == -1) return ((fn_argv)f)((int)argc, v, self);
    if (arity == -2) return ((fn_args)f)(self, argc > 0 ? v[0] : Qnil);
    if (arity != argc) mr_fatal("a C method was run with the wrong number of arguments");
    switch (arity) {
      case 0: return ((fn0)f)(self);
      case 1: return ((fn1)f)(self, v[0]);
      case 2: return ((fn2)f)(self, v[0], v[1]);
      case 3: return ((fn3)f)(self, v[0], v[1], v[2]);
      case 4: return ((fn4)f)(self, v[0], v[1], v[2], v[3]);
      case 5: return ((fn5)f)(self, v[0], v[1], v[2], v[3], v[4]);
      case 6: return ((fn6)f)(self, v[0], v[1], v[2], v[3], v[4], v[5]);
      case 7: return ((fn7)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6]);
      case 8: return ((fn8)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7]);
      case 9: return ((fn9)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8]);
      case 10: return ((fn10)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9]);
      case 11: return ((fn11)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10]);
      case 12: return ((fn12)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11]);
      case 13: return ((fn13)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12]);
      case 14: return ((fn14)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13]);
      case 15: return ((fn15)f)(self, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13], v[14]);
    }
    mr_fatal("a C method with an arity outside -2..15");
}

/* ---- loaded extensions ----------------------------------------------------- */
struct mr_library { char *path; void *handle; void (*init)(void); };
static struct mr_library *libraries;
static long library_count, library_cap;

/* The number that says "compiled against these headers". An extension built
 * for CRuby reads objects as addresses and must not be run here. */
#define MR_EXTENSION_ABI 0x4d520101U

/* Was this file compiled against mere-ruby's ruby.h? One built for another
 * ruby is not a candidate for the feature at all: `require` goes on to
 * whatever provided it before (a .rb, the shipped library).
 *
 * The question is asked of the FILE, not of the loaded library: opening a
 * library runs its constructors, and closing it its destructors, so asking
 * by dlopen gave an accepted library a whole extra life before its Init_,
 * and ran a foreign library's constructors in this process. Every extension
 * compiled against these headers defines rb_mere_extension_abi, so its
 * symbol table names it; the number itself is read when the library is
 * really opened (mr_capi_open), which refuses a different one aloud. */
static int file_names(const char *path, const char *needle) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    size_t n = strlen(needle), kept = 0, got;
    char buffer[65536 + 64];
    int found = 0;
    while (!found && (got = fread(buffer + kept, 1, 65536, f)) > 0) {
        size_t have = kept + got;
        for (size_t i = 0; i + n <= have; i++) {
            if (buffer[i] == needle[0] && !memcmp(buffer + i, needle, n)) { found = 1; break; }
        }
        /* (a name that straddles two reads: keep the tail) */
        kept = have < n - 1 ? have : n - 1;
        memmove(buffer, buffer + have - kept, kept);
    }
    fclose(f);
    return found;
}
int mr_capi_probe(const char *path) {
    for (long i = 0; i < library_count; i++)
        if (!strcmp(libraries[i].path, path)) return 1;
    if (mr_without("fileprobe")) {
        void *handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL);
        if (!handle) return 0;
        const unsigned int *abi = (const unsigned int *)dlsym(handle, "rb_mere_extension_abi");
        int ours = abi && *abi == MR_EXTENSION_ABI;
        dlclose(handle);
        return ours;
    }
    return file_names(path, "rb_mere_extension_abi");
}

int mr_capi_open(const char *path) {
    for (long i = 0; i < library_count; i++)
        if (!strcmp(libraries[i].path, path)) return (int)i;
    void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        mr_put_text(dlerror());
        return -1;
    }
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    size_t n = strcspn(base, ".");
    char symbol[512];
    if (n == 0 || n + 6 > sizeof(symbol)) {
        dlclose(handle);
        mr_put_text("an extension's file name must give its Init_ function");
        return -1;
    }
    memcpy(symbol, "Init_", 5);
    memcpy(symbol + 5, base, n);
    symbol[n + 5] = 0;
    const unsigned int *abi = (const unsigned int *)dlsym(handle, "rb_mere_extension_abi");
    void (*init)(void) = (void (*)(void))dlsym(handle, symbol);
    if (!abi || *abi != MR_EXTENSION_ABI) {
        dlclose(handle);
        char message[1024];
        snprintf(message, sizeof(message),
                 "%s was not compiled against mere-ruby's ruby.h (an extension built for another ruby cannot be loaded)", path);
        mr_put_text(message);
        return -1;
    }
    if (!init) {
        dlclose(handle);
        char message[1024];
        snprintf(message, sizeof(message), "%s has no %s", path, symbol);
        mr_put_text(message);
        return -1;
    }
    if (library_count == library_cap) {
        library_cap = library_cap ? library_cap * 2 : 16;
        libraries = realloc(libraries, sizeof(*libraries) * (size_t)library_cap);
        if (!libraries) mr_fatal("out of memory");
    }
    /* Kept open for good: its functions are methods now, whatever Init_ does. */
    libraries[library_count].path = strdup(path);
    libraries[library_count].handle = handle;
    libraries[library_count].init = init;
    stats[ST_LIBRARIES] = library_count + 1;
    return (int)library_count++;
}

/* ---- running C -------------------------------------------------------------- */
extern void mr_capi_boot(void);
static int booted;
/* (has any extension run yet: before that, the C globals are not filled) */
int mr_capi_booted(void) { return booted; }

static VALUE run(const CapiReq *req, long argc, VALUE *argv) {
    switch ((int)req->mu_op) {
      case MR_RUN_METHOD:
        return run_method((long)req->mu_a, (VALUE)req->mu_b, argc, argv);
      case MR_RUN_INIT: {
        long number = (long)req->mu_a;
        if (number < 0 || number >= library_count) mr_fatal("no such extension");
        if (!booted) { booted = 1; mr_capi_boot(); }
        libraries[number].init();
        return Qnil;
      }
      case MR_RUN_DSIZE: {
        /* (a typed data object's dsize, run as C runs: in a call of its own,
         *  so a dsize that asks the C API can -- ObjectSpace.memsize_of) */
        extern long mr_capi_dsize(long number);
        return LONG2NUM(mr_capi_dsize((long)req->mu_a));
      }
      case MR_RUN_BLOCK: {
        long number = (long)req->mu_a;
        if (number < 0 || number >= function_count) mr_fatal("no such C block");
        return ((fn_block)functions[number].fn)(argc > 0 ? argv[0] : Qnil, (VALUE)req->mu_b,
                                                (int)argc, argv, (VALUE)req->mu_d);
      }
    }
    mr_fatal("an unknown request to run C");
}

extern void mr_mirrors_leave(const void *frame, int outermost);

CapiRet mr_capi_enter(closure_CapiReq_int up, CapiReq req) {
    struct mr_frame frame;
    struct mr_guard guard;
    CapiRet ret = { 0, 0 };
    long argc = (long)req.mu_c;
    if (argc < 0 || argc > 1000000) mr_fatal("an impossible argument count");
    /* The arguments leave the transit words before anything else runs, and
     * sit on this stack, where a collection finds them. */
    VALUE *argv = alloca(sizeof(VALUE) * (size_t)(argc + 1));
    for (long i = 0; i < argc; i++) argv[i] = mr_word(i);
    argv[argc] = Qnil;

    memset(&frame, 0, sizeof(frame));
    frame.up = up;
    frame.prev = cur;
    frame.pending = Qundef;
    frame.block = req.mu_op == MR_RUN_METHOD ? (VALUE)req.mu_d : Qnil;
    if (req.mu_op == MR_RUN_METHOD) {
        frame.method = (ID)(req.mu_e & 0xffffffffLL);
        frame.keywords = (int)((req.mu_e >> 32) & 1);
    }
    else if (req.mu_op == MR_RUN_BLOCK) {
        /* A C function run as a block belongs to the C method that made it:
         * that method's name, and (after the arguments) that method's block. */
        frame.method = (ID)(req.mu_e & 0xffffffffLL);
        /* (...and whether what was yielded to it ended in keywords) */
        frame.keywords = (int)((req.mu_e >> 32) & 1);
        frame.block = mr_word(argc);
    }
    guard.prev = NULL;
    frame.guard = &guard;
    cur = &frame;
    depth++;
    mr_epoch++;
    stats[ST_ENTER]++;

    volatile VALUE result = Qnil;
    volatile int raised = 0;
    if (RUBY_SETJMP(guard.jump) == 0) {
        result = run(&req, argc, argv);
    }
    else {
        raised = 1;
        result = frame.pending;
    }
    /* What C wrote into the structs it was given goes back before the
     * interpreter runs again; that can raise too (a String frozen since). */
    struct mr_guard last;
    last.prev = NULL;
    frame.guard = &last;
    if (RUBY_SETJMP(last.jump) == 0) {
        mr_mirrors_flush();
    }
    else if (!raised) {
        raised = 1;
        result = frame.pending;
    }
    /* (an exception leaving C is Ruby's to rescue now, and a Ruby rescue
     *  clears ec->errinfo: one a C handler re-raised is not left behind) */
    if (raised) c_errinfo = Qnil;
    mr_mirrors_leave(&frame, frame.prev == NULL);
    cur = frame.prev;
    depth--;
    mr_epoch++;
    ret.mu_w = (long long)result;
    ret.mu_raised = raised;
    return ret;
}

/* A symbol of an extension that is loaded, by the feature it was required as. */
/* A symbol of the library a feature was loaded from. The feature is named as
 * `require` names it, with or without a suffix (".so" stands for whatever the
 * platform's is). A feature that is loaded but came from no library is part
 * of this executable -- ruby's "statically linked" extensions. */
void *rb_ext_resolve_symbol(const char *feature, const char *symbol) {
    size_t n = strlen(feature);
    const char *suffix = strrchr(feature, '.');
    if (suffix && (!strcmp(suffix, ".so") || !strcmp(suffix, ".bundle") || !strcmp(suffix, ".dll")))
        n = (size_t)(suffix - feature);
    for (long i = 0; i < library_count; i++) {
        const char *path = libraries[i].path;
        const char *dot = strrchr(path, '.');
        size_t stem = dot ? (size_t)(dot - path) : strlen(path);
        if (stem >= n && !strncmp(path + stem - n, feature, n) && (stem == n || path[stem - n - 1] == '/'))
            return dlsym(libraries[i].handle, symbol);
    }
    VALUE name = rb_str_new(feature, (long)n);
    VALUE loaded = mr_call(mr_ruby("->(name) { $LOADED_FEATURES.any? { |f| f == name + '.so' || f == name + '.rb' || f.end_with?('/' + name + '.rb') } }"),
                           "call", 1, name);
    return RTEST(loaded) ? dlsym(RTLD_DEFAULT, symbol) : NULL;
}

/* The file this process is running: where the interpreter was built, which
 * is where its headers are (RbConfig's rubyhdrdir, bindir, topdir). "" when
 * the OS does not say. */
#ifdef __APPLE__
# include <mach-o/dyld.h>
#endif
char *mr_capi_exe(void) {
    static char resolved[PATH_MAX];
    if (resolved[0]) return resolved;
    char raw[PATH_MAX];
#ifdef __APPLE__
    uint32_t size = sizeof(raw);
    if (_NSGetExecutablePath(raw, &size) != 0) return "";
#else
    ssize_t n = readlink("/proc/self/exe", raw, sizeof(raw) - 1);
    if (n <= 0) return "";
    raw[n] = 0;
#endif
    if (!realpath(raw, resolved)) { resolved[0] = 0; return ""; }
    return resolved;
}

/* The C library this interpreter was compiled against, as a configure
 * triplet names it after the OS ("gnu" in x86_64-pc-linux-gnu): "" where the
 * triplet has no such part (macOS) or the library does not say. */
char *mr_capi_libc(void) {
#ifdef __GLIBC__
    return "gnu";
#else
    return "";
#endif
}
int mr_capi_depth(void) { return depth; }
const void *mr_capi_frame(void) { return cur; }
/* CRuby's ec->errinfo, which rb_errinfo answers: the running stack's (the
 * others' are put aside: errinfo_switch, below). Set by C's own rescues --
 * rb_protect, rb_rescue's handler, rb_ensure's cleanup, rb_set_errinfo --
 * and not by a Ruby `rescue`, so a C method a Ruby rescue calls finds none;
 * Ruby a C handler runs, and the C it calls, find the exception. (A root:
 * the collector reads it with the C API's own.) */
VALUE mr_frame_errinfo(void) { return c_errinfo; }
int mr_capi_clear_errinfo(void) { c_errinfo = Qnil; return 0; }
void mr_frame_set_errinfo(VALUE v) {
    static int rooted;
    if (!rooted) { rooted = 1; rb_gc_register_address(&c_errinfo); }
    c_errinfo = v;
}
int mr_capi_stat(int which) { return which >= 0 && which < 8 ? (int)stats[which] : -1; }

/* rb_errinfo is the running stack's: every Fiber (and every Thread's root
 * fiber) has its own, as CRuby's execution context does -- an rb_protect on
 * one Fiber is not what another reads. The one of the stack being left is
 * put aside by its number (a Fiber's number is never handed out again), the
 * target's taken up, and a stack's dropped when its Fiber ends
 * (mr_capi_stack_end). Each put aside is a root (mr_errinfo_parked_at). */
struct mr_errpark { int stack; VALUE err; };
static struct mr_errpark *errparked;
static long errparked_count, errparked_cap;
static void errinfo_drop(int stack) {
    for (long i = 0; i < errparked_count; i++)
        if (errparked[i].stack == stack) { errparked[i] = errparked[--errparked_count]; return; }
}
static void errinfo_switch(int from, int to) {
    if (!NIL_P(c_errinfo)) {
        if (errparked_count == errparked_cap) {
            errparked_cap = errparked_cap ? errparked_cap * 2 : 8;
            errparked = realloc(errparked, sizeof(*errparked) * (size_t)errparked_cap);
            if (!errparked) mr_fatal("out of memory");
        }
        errparked[errparked_count].stack = from;
        errparked[errparked_count].err = c_errinfo;
        errparked_count++;
    }
    c_errinfo = Qnil;
    for (long i = 0; i < errparked_count; i++)
        if (errparked[i].stack == to) { c_errinfo = errparked[i].err; errinfo_drop(to); return; }
}
VALUE mr_errinfo_parked_at(long i) { return i < errparked_count ? errparked[i].err : Qundef; }
int mr_capi_stack_end(int stack) { errinfo_drop(stack); return 0; }

/* A coroutine switch. The calls in progress are a chain through C stack
 * frames, so each stack has its own; the interpreter says when it changes
 * stacks, and the chain of the stack being left is put aside by its number. */
struct mr_parked { int stack; struct mr_frame *frame; int depth; };
static struct mr_parked *parked;
static long parked_count, parked_cap;
int mr_capi_switch(int from, int to) {
    if (mr_without("switch")) return 0;
    errinfo_switch(from, to);
    if (cur) {
        if (parked_count == parked_cap) {
            parked_cap = parked_cap ? parked_cap * 2 : 8;
            parked = realloc(parked, sizeof(*parked) * (size_t)parked_cap);
            if (!parked) mr_fatal("out of memory");
        }
        parked[parked_count].stack = from;
        parked[parked_count].frame = cur;
        parked[parked_count].depth = depth;
        parked_count++;
        cur = NULL;
        depth = 0;
    }
    for (long i = 0; i < parked_count; i++) {
        if (parked[i].stack == to) {
            cur = parked[i].frame;
            depth = parked[i].depth;
            parked[i] = parked[--parked_count];
            break;
        }
    }
    return 0;
}
