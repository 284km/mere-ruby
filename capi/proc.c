/* Blocks, procs, evaluation, loading, and reading a method's arguments. */
#include "mr_capi.h"
#include <stdarg.h>
#include <string.h>

extern ID mr_frame_method(void);
extern int mr_frame_keywords(void);

/* ---- the block of the method in progress ------------------------------------ */
int rb_block_given_p(void) { return !NIL_P(mr_frame_block()); }
int rb_keyword_given_p(void) { return mr_frame_keywords(); }
void rb_need_block(void) {
    if (!rb_block_given_p()) rb_raise(rb_eLocalJumpError, "no block given (yield)");
}
VALUE rb_block_proc(void) {
    VALUE block = mr_frame_block();
    if (NIL_P(block)) rb_raise(rb_eArgError, "tried to create Proc object without a block");
    return block;
}
VALUE rb_block_lambda(void) { return rb_block_proc(); }
static VALUE yield_values(int argc, const VALUE *argv, int flags) {
    rb_need_block();
    return mr_callv(mr_frame_block(), rb_intern("yield"), argc, argv, Qnil, flags);
}
VALUE rb_yield(VALUE value) {
    if (value == Qundef) return yield_values(0, NULL, 0);
    return yield_values(1, &value, 0);
}
VALUE rb_yield_values(int argc, ...) {
    VALUE *argv = argc > 0 ? alloca(sizeof(VALUE) * (size_t)argc) : NULL;
    va_list ap;
    va_start(ap, argc);
    for (int i = 0; i < argc; i++) argv[i] = va_arg(ap, VALUE);
    va_end(ap);
    return yield_values(argc, argv, 0);
}
VALUE rb_yield_values2(int argc, const VALUE *argv) { return yield_values(argc, argv, 0); }
VALUE rb_yield_values_kw(int argc, const VALUE *argv, int kw) { return yield_values(argc, argv, mr_kw(kw)); }
VALUE rb_yield_splat(VALUE ary) {
    VALUE args = rb_check_array_type(ary);
    if (NIL_P(args)) rb_raise(rb_eArgError, "not an array");
    return yield_values(RARRAY_LENINT(args), RARRAY_CONST_PTR(args), 0);
}
VALUE rb_yield_splat_kw(VALUE ary, int kw) {
    VALUE args = rb_check_array_type(ary);
    if (NIL_P(args)) rb_raise(rb_eArgError, "not an array");
    return yield_values(RARRAY_LENINT(args), RARRAY_CONST_PTR(args), mr_kw(kw));
}
/* A block function that yields what it was given to the C method's block,
 * and the block it was given as that block's own (`{ |x, &b| }`). */
VALUE rb_yield_block(VALUE yielded, VALUE data, int argc, const VALUE *argv, VALUE block) {
    (void)yielded; (void)data;
    rb_need_block();
    /* (keywords the block function was yielded stay keywords for the block) */
    return mr_callv(mr_frame_block(), rb_intern("call"), argc, argv, block, mr_frame_keywords() ? MR_SEND_KW : 0);
}

/* ---- procs ------------------------------------------------------------------ */
static VALUE block_proc(rb_block_call_func_t func, VALUE data, int lambda);
/* (a Proc, not a lambda: `rb_proc_new(f, v).lambda?` is false in ruby) */
VALUE rb_proc_new(rb_block_call_func_t func, VALUE data) { return block_proc(func, data, 0); }
VALUE rb_obj_is_proc(VALUE obj) { return rb_obj_is_kind_of(obj, rb_cProc); }
VALUE rb_obj_is_method(VALUE obj) { return rb_obj_is_kind_of(obj, rb_cMethod); }
VALUE rb_proc_call(VALUE proc, VALUE args) { return mr_callv(proc, rb_intern("call"), RARRAY_LENINT(args), RARRAY_CONST_PTR(args), Qnil, 0); }
VALUE rb_proc_call_kw(VALUE proc, VALUE args, int kw) { return mr_callv(proc, rb_intern("call"), RARRAY_LENINT(args), RARRAY_CONST_PTR(args), Qnil, mr_kw(kw)); }
VALUE rb_proc_call_with_block(VALUE proc, int argc, const VALUE *argv, VALUE block) { return mr_callv(proc, rb_intern("call"), argc, argv, block, 0); }
VALUE rb_proc_call_with_block_kw(VALUE proc, int argc, const VALUE *argv, VALUE block, int kw) { return mr_callv(proc, rb_intern("call"), argc, argv, block, mr_kw(kw)); }
int rb_proc_arity(VALUE proc) { return NUM2INT(mr_call(proc, "arity", 0)); }
VALUE rb_proc_lambda_p(VALUE proc) { return mr_call(proc, "lambda?", 0); }
VALUE rb_method_call(int argc, const VALUE *argv, VALUE method) { return mr_callv(method, rb_intern("call"), argc, argv, Qnil, 0); }
VALUE rb_method_call_kw(int argc, const VALUE *argv, VALUE method, int kw) { return mr_callv(method, rb_intern("call"), argc, argv, Qnil, mr_kw(kw)); }
VALUE rb_method_call_with_block(int argc, const VALUE *argv, VALUE method, VALUE block) { return mr_callv(method, rb_intern("call"), argc, argv, block, 0); }
VALUE rb_binding_new(void) { mr_unsupported("rb_binding_new"); }

/* A call with a C function as its block. The block is the C method's own:
 * it carries that method's name and block (rb_frame_this_func, rb_yield). */
static VALUE block_proc(rb_block_call_func_t func, VALUE data, int lambda) {
    return mr_up(MR_PROC_NEW, (VALUE)mr_register_function((void *)func, -3), data, (VALUE)lambda,
                 (VALUE)mr_frame_method(), mr_frame_block());
}
VALUE mr_block_function(rb_block_call_func_t func, VALUE data) { return block_proc(func, data, 0); }
VALUE rb_block_call(VALUE obj, ID mid, int argc, const VALUE *argv, rb_block_call_func_t func, VALUE data) {
    VALUE block = func ? block_proc(func, data, 0) : Qnil;
    return mr_callv(obj, mid, argc, argv, block, 0);
}
VALUE rb_block_call_kw(VALUE obj, ID mid, int argc, const VALUE *argv, rb_block_call_func_t func, VALUE data, int kw) {
    VALUE block = func ? block_proc(func, data, 0) : Qnil;
    return mr_callv(obj, mid, argc, argv, block, mr_kw(kw));
}
VALUE rb_each(VALUE obj) { return mr_callv(obj, rb_intern("each"), 0, NULL, mr_frame_block(), 0); }
void rb_iter_break_value(VALUE value) {
    mr_up1(MR_BREAK, value);
    mr_fatal("a break returned");
}
void rb_iter_break(void) { rb_iter_break_value(Qnil); }

/* ---- evaluation and loading ---------------------------------------------------- */
/* In the frame that called the C method in progress: its self, its locals. */
VALUE rb_eval_string(const char *source) {
    mr_put_bytes(source, (long)strlen(source));
    return mr_up(MR_EVAL, 0, 0, 0, 0, 0);
}
static VALUE eval_body(VALUE source) { return rb_eval_string((const char *)source); }
VALUE rb_eval_string_protect(const char *source, int *state) { return rb_protect(eval_body, (VALUE)source, state); }
VALUE rb_eval_string_wrap(const char *source, int *state) { return rb_eval_string_protect(source, state); }
VALUE rb_obj_instance_eval(int argc, const VALUE *argv, VALUE self) { return mr_callv(self, rb_intern("instance_eval"), argc, argv, mr_frame_block(), 0); }
VALUE rb_obj_instance_exec(int argc, const VALUE *argv, VALUE self) { return mr_callv(self, rb_intern("instance_exec"), argc, argv, mr_frame_block(), 0); }
VALUE rb_mod_module_eval(int argc, const VALUE *argv, VALUE module) { return mr_callv(module, rb_intern("module_eval"), argc, argv, mr_frame_block(), 0); }
VALUE rb_mod_module_exec(int argc, const VALUE *argv, VALUE module) { return mr_callv(module, rb_intern("module_exec"), argc, argv, mr_frame_block(), 0); }
VALUE rb_require_string(VALUE feature) { return mr_call(mr_main(), "require", 1, feature); }
VALUE rb_require(const char *feature) { return rb_require_string(rb_str_new_cstr(feature)); }
VALUE rb_f_require(VALUE obj, VALUE feature) { (void)obj; return rb_require_string(feature); }
void rb_provide(const char *feature) { mr_call(rb_gv_get("$LOADED_FEATURES"), "push", 1, rb_str_new_cstr(feature)); }
int rb_provided(const char *feature) {
    return RTEST(mr_call(mr_ruby("->(f) { $LOADED_FEATURES.any? { |x| x == f || x.end_with?('/' + f) || File.basename(x, '.*') == f } }"),
                         "call", 1, rb_str_new_cstr(feature)));
}
int rb_feature_provided(const char *feature, const char **loading) { if (loading) *loading = NULL; return rb_provided(feature); }
void rb_load(VALUE path, int wrap) { mr_call(mr_main(), "load", 2, path, wrap ? Qtrue : Qfalse); }
static VALUE load_body(VALUE args) { rb_load(((VALUE *)args)[0], (int)((VALUE *)args)[1]); return Qnil; }
void rb_load_protect(VALUE path, int wrap, int *state) {
    VALUE args[2] = { path, (VALUE)wrap };
    rb_protect(load_body, (VALUE)args, state);
}
ID rb_frame_this_func(void) { return mr_frame_method(); }
ID rb_frame_callee(void) { return mr_frame_method(); }

/* ---- reading arguments ---------------------------------------------------------- */
void rb_scan_args_bad_format(const char *fmt) { rb_fatal("bad scan arg format: %s", fmt); }
void rb_scan_args_length_mismatch(const char *fmt, int varc) { rb_fatal("variable argument length doesn't match: %s (%d)", fmt, varc); }

static int scan(int kw_flag, int argc, const VALUE *argv, const char *fmt, va_list ap) {
    const char *p = fmt;
    int lead = 0, opt = 0, rest = 0, trail = 0, hash = 0, block = 0;
    if (*p >= '0' && *p <= '9') {
        lead = *p++ - '0';
        if (*p >= '0' && *p <= '9') {
            opt = *p++ - '0';
        }
    }
    if (*p == '*') { rest = 1; p++; }
    if (*p >= '0' && *p <= '9') trail = *p++ - '0';
    if (*p == ':') { hash = 1; p++; }
    if (*p == '&') { block = 1; p++; }
    if (*p) rb_scan_args_bad_format(fmt);

    int keywords = kw_flag == RB_SCAN_ARGS_PASS_CALLED_KEYWORDS ? rb_keyword_given_p()
                 : kw_flag == RB_SCAN_ARGS_KEYWORDS ? 1
                 : kw_flag == RB_SCAN_ARGS_LAST_HASH_KEYWORDS ? (argc > 0 && RB_TYPE_P(argv[argc - 1], T_HASH)) : 0;
    VALUE options = Qnil;
    int given = argc;
    if (hash && keywords && argc > 0) {
        VALUE last = argv[argc - 1];
        if (RB_TYPE_P(last, T_HASH)) { options = rb_hash_dup(last); argc--; }
    }
    if (argc < lead + trail || (!rest && argc > lead + opt + trail)) {
        rb_error_arity(given - (given - argc > 0 && argc < lead + trail ? 0 : 0), lead + trail, rest ? UNLIMITED_ARGUMENTS : lead + opt + trail);
    }
    int i = 0;
    for (int k = 0; k < lead; k++, i++) { VALUE *var = va_arg(ap, VALUE *); if (var) *var = argv[i]; }
    int optional = argc - lead - trail;
    for (int k = 0; k < opt; k++) {
        VALUE *var = va_arg(ap, VALUE *);
        if (k < optional) { if (var) *var = argv[i]; i++; }
        else if (var) *var = Qnil;
    }
    if (rest) {
        int n = argc - i - trail;
        VALUE *var = va_arg(ap, VALUE *);
        if (n < 0) n = 0;
        if (var) *var = rb_ary_new_from_values(n, argv + i);
        i += n;
    }
    for (int k = 0; k < trail; k++, i++) { VALUE *var = va_arg(ap, VALUE *); if (var) *var = argv[i]; }
    if (hash) { VALUE *var = va_arg(ap, VALUE *); if (var) *var = options; }
    if (block) { VALUE *var = va_arg(ap, VALUE *); if (var) *var = rb_block_given_p() ? rb_block_proc() : Qnil; }
    return given;
}
#undef rb_scan_args
#undef rb_scan_args_kw
int rb_scan_args(int argc, const VALUE *argv, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = scan(RB_SCAN_ARGS_PASS_CALLED_KEYWORDS, argc, argv, fmt, ap);
    va_end(ap);
    return n;
}
int rb_scan_args_kw(int kw_flag, int argc, const VALUE *argv, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = scan(kw_flag, argc, argv, fmt, ap);
    va_end(ap);
    return n;
}
VALUE rb_extract_keywords(VALUE *options) {
    VALUE hash = *options;
    if (NIL_P(hash)) return Qnil;
    VALUE keywords = mr_ruby("->(h) { h.select { |k, _| k.is_a?(Symbol) } }");
    VALUE rest = mr_ruby("->(h) { h.reject { |k, _| k.is_a?(Symbol) } }");
    VALUE symbols = mr_call(keywords, "call", 1, hash);
    VALUE others = mr_call(rest, "call", 1, hash);
    *options = RTEST(mr_call(others, "empty?", 0)) ? 0 : others;
    return RTEST(mr_call(symbols, "empty?", 0)) ? 0 : symbols;
}
/* class.c's rb_get_kwargs, as it is in 4.0. With `values` a keyword that is
 * found is TAKEN OUT of the Hash (also when a negative `optional` lets others
 * stay), and one that is not found is Qundef; without `values` the Hash is
 * only looked at. What is left in a Hash that may not have a rest is the
 * unknown keywords. */
static VALUE keyword_error(const char *what, VALUE keys) {
    return rb_exc_new_str(rb_eArgError, rb_sprintf("%s keyword%s: %" PRIsVALUE, what, RARRAY_LEN(keys) > 1 ? "s" : "",
                          mr_call(mr_ruby("->(a) { a.map(&:inspect).join(', ') }"), "call", 1, keys)));
}
static int extract_keyword(VALUE keywords, VALUE key, VALUE *values, int at) {
    if (!RTEST(mr_callh(keywords, "key?", 1, key))) {
        if (values) values[at] = Qundef;
        return 0;
    }
    if (values) values[at] = mr_callh(keywords, "delete", 1, key);
    return 1;
}
int rb_get_kwargs(VALUE keywords, const ID *table, int required, int optional, VALUE *values) {
    int i = 0, j, rest = 0;
    VALUE missing = Qnil;
    if (NIL_P(keywords)) keywords = 0;
    if (optional < 0) { rest = 1; optional = -1 - optional; }
    if (required) {
        for (; i < required; i++) {
            VALUE key = ID2SYM(table[i]);
            if (keywords && extract_keyword(keywords, key, values, i)) continue;
            if (NIL_P(missing)) missing = rb_ary_new();
            rb_ary_push(missing, key);
        }
        if (!NIL_P(missing)) rb_exc_raise(keyword_error("missing", missing));
    }
    j = i;
    if (optional && keywords) {
        for (i = 0; i < optional; i++)
            if (extract_keyword(keywords, ID2SYM(table[required + i]), values, required + i)) j++;
    }
    if (!rest && keywords) {
        if (RHASH_SIZE(keywords) > (size_t)(values ? 0 : j)) {
            for (i = 0; i < required + optional; i++) mr_callh(keywords, "delete", 1, ID2SYM(table[i]));
            rb_exc_raise(keyword_error("unknown", mr_callh(keywords, "keys", 0)));
        }
    }
    if (values && !keywords) {
        for (i = 0; i < required + optional; i++) values[i] = Qundef;
    }
    return j;
}

/* ---- recursion guards --------------------------------------------------------------- */
/* What rb_exec_recursive remembers: (function, object, paired object) for
 * each call in progress. An object met again is recursion. */
struct recursive { void *func; VALUE obj, paired; int outer; };
static struct recursive *recursing;
static long recursing_count, recursing_cap;
struct recursive_call { VALUE (*func)(VALUE, VALUE, int); VALUE obj, arg; };
static VALUE recursive_body(VALUE p) {
    struct recursive_call *c = (struct recursive_call *)p;
    return c->func(c->obj, c->arg, 0);
}
static VALUE exec_recursive(VALUE (*func)(VALUE, VALUE, int), VALUE obj, VALUE paired, VALUE arg, int outer) {
    for (long i = recursing_count - 1; i >= 0; i--) {
        if (recursing[i].func == (void *)func && recursing[i].obj == obj && recursing[i].paired == paired) {
            if (outer) {
                /* unwind to the outermost call of this function, which answers */
                rb_throw_obj(rb_ary_entry(mr_ruby("[Object.new]"), 0), ULONG2NUM((uintptr_t)func));
            }
            return func(obj, arg, 1);
        }
    }
    if (recursing_count == recursing_cap) {
        recursing_cap = recursing_cap ? recursing_cap * 2 : 32;
        recursing = realloc(recursing, sizeof(*recursing) * (size_t)recursing_cap);
        if (!recursing) mr_fatal("out of memory");
    }
    long mine = recursing_count++;
    recursing[mine].func = (void *)func;
    recursing[mine].obj = obj;
    recursing[mine].paired = paired;
    recursing[mine].outer = outer;
    struct recursive_call call = { func, obj, arg };
    VALUE leaving;
    VALUE result = mr_guarded(recursive_body, (VALUE)&call, &leaving);
    recursing_count = mine;
    if (leaving != Qundef) mr_throw(leaving);
    return result;
}
VALUE rb_exec_recursive(VALUE (*func)(VALUE, VALUE, int), VALUE obj, VALUE arg) { return exec_recursive(func, obj, Qundef, arg, 0); }
VALUE rb_exec_recursive_paired(VALUE (*func)(VALUE, VALUE, int), VALUE obj, VALUE paired, VALUE arg) { return exec_recursive(func, obj, paired, arg, 0); }
struct outer_call { VALUE (*func)(VALUE, VALUE, int); VALUE obj, paired, arg; };
static VALUE outer_body(VALUE yielded, VALUE data, int argc, const VALUE *argv, VALUE block) {
    (void)yielded; (void)argc; (void)argv; (void)block;
    struct outer_call *c = (struct outer_call *)(uintptr_t)NUM2ULONG(data);
    return exec_recursive(c->func, c->obj, c->paired, c->arg, 1);
}
static VALUE exec_recursive_outer(VALUE (*func)(VALUE, VALUE, int), VALUE obj, VALUE paired, VALUE arg) {
    /* Is a call of this function already in progress? Then this one is inner. */
    for (long i = recursing_count - 1; i >= 0; i--)
        if (recursing[i].func == (void *)func && recursing[i].outer) return exec_recursive(func, obj, paired, arg, 1);
    struct outer_call call = { func, obj, paired, arg };
    VALUE tag = rb_ary_entry(mr_ruby("[Object.new]"), 0);
    VALUE result = rb_catch_obj(tag, outer_body, ULONG2NUM((uintptr_t)&call));
    /* (the throw's value is the function's address: recursion was met below) */
    if (RB_INTEGER_TYPE_P(result) && rb_num2ulong(result) == (uintptr_t)func && recursing_count >= 0) {
        long saved = recursing_count;
        VALUE answer = func(obj, arg, 1);
        recursing_count = saved;
        return answer;
    }
    return result;
}
VALUE rb_exec_recursive_outer(VALUE (*func)(VALUE, VALUE, int), VALUE obj, VALUE arg) { return exec_recursive_outer(func, obj, Qundef, arg); }
VALUE rb_exec_recursive_paired_outer(VALUE (*func)(VALUE, VALUE, int), VALUE obj, VALUE paired, VALUE arg) { return exec_recursive_outer(func, obj, paired, arg); }
