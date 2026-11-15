/* Raising, and the C functions that stand where `rescue` and `ensure` do.
 *
 * Something leaving a call into the interpreter -- an exception, a throw, a
 * break -- arrives here as an OUTCOME: a handle the interpreter can be asked
 * about (its kind, its exception) and that mr_throw sends on. C unwinds only
 * C: from the request that got the outcome to the nearest guard. */
#include "mr_capi.h"
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* The outcome rb_protect stopped, for rb_jump_tag to send on. */
static VALUE protected_outcome = Qundef;
static int roots_registered;
static void register_roots(void) {
    if (roots_registered) return;
    roots_registered = 1;
    rb_gc_register_address(&protected_outcome);
}
static int outcome_tag(VALUE outcome) { return (int)mr_up2(MR_OUTCOME, outcome, MR_O_TAG); }

/* ---- raising ------------------------------------------------------------- */
void rb_exc_raise(VALUE exc) {
    mr_up1(MR_RAISE, exc);
    mr_fatal("a raise returned");
}
void rb_exc_fatal(VALUE exc) { rb_exc_raise(exc); }
VALUE rb_exc_new_str(VALUE klass, VALUE message) { return mr_call(klass, "new", 1, message); }
VALUE rb_exc_new(VALUE klass, const char *ptr, long len) { return rb_exc_new_str(klass, rb_str_new(ptr, len)); }
#undef rb_exc_new_cstr
VALUE rb_exc_new_cstr(VALUE klass, const char *ptr) { return rb_exc_new_str(klass, rb_str_new_cstr(ptr)); }
static void raise_formatted(VALUE klass, rb_encoding *enc, const char *fmt, va_list ap) {
    VALUE message = rb_enc_vsprintf(enc, fmt, ap);
    rb_exc_raise(rb_exc_new_str(klass, message));
}
void rb_raise(VALUE klass, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    raise_formatted(klass, NULL, fmt, ap);
    va_end(ap);
    mr_fatal("a raise returned");
}
void rb_enc_raise(rb_encoding *enc, VALUE klass, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    raise_formatted(klass, enc, fmt, ap);
    va_end(ap);
    mr_fatal("a raise returned");
}
void rb_fatal(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    raise_formatted(rb_eFatal, NULL, fmt, ap);
    va_end(ap);
    mr_fatal("a raise returned");
}
void rb_loaderror(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    raise_formatted(rb_eLoadError, NULL, fmt, ap);
    va_end(ap);
    mr_fatal("a raise returned");
}
void rb_name_error(ID id, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    VALUE message = rb_vsprintf(fmt, ap);
    va_end(ap);
    rb_exc_raise(mr_call(rb_eNameError, "new", 2, message, ID2SYM(id)));
}
void rb_name_error_str(VALUE name, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    VALUE message = rb_vsprintf(fmt, ap);
    va_end(ap);
    rb_exc_raise(mr_call(rb_eNameError, "new", 2, message, name));
}
void rb_frozen_error_raise(VALUE obj, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    VALUE message = rb_vsprintf(fmt, ap);
    va_end(ap);
    VALUE options = rb_hash_new();
    rb_hash_aset(options, ID2SYM(rb_intern("receiver")), obj);
    VALUE argv[2] = { message, options };
    rb_exc_raise(mr_callv(rb_eFrozenError, rb_intern("new"), 2, argv, Qnil, MR_SEND_KW));
}
void rb_error_frozen_object(VALUE obj) {
    rb_frozen_error_raise(obj, "can't modify frozen %" PRIsVALUE ": %" PRIsVALUE, rb_obj_class(obj), rb_inspect(obj));
}
void rb_error_frozen(const char *what) { rb_raise(rb_eFrozenError, "can't modify frozen %s", what); }
#undef rb_check_frozen
void rb_check_frozen(VALUE obj) {
    if (RB_SPECIAL_CONST_P(obj) || RTEST(rb_obj_frozen_p(obj))) rb_error_frozen_object(obj);
}
void rb_notimplement(void) { rb_raise(rb_eNotImpError, "function is unimplemented on this machine"); }
VALUE rb_f_notimplement(int argc, const VALUE *argv, VALUE obj, VALUE marker) {
    (void)argc; (void)argv; (void)obj; (void)marker;
    rb_notimplement();
}
void rb_invalid_str(const char *str, const char *type) {
    VALUE s = rb_str_new_cstr(str);
    rb_raise(rb_eArgError, "invalid value for %s: %" PRIsVALUE, type, rb_inspect(s));
}
void rb_error_arity(int argc, int min, int max) {
    if (min == max) rb_raise(rb_eArgError, "wrong number of arguments (given %d, expected %d)", argc, min);
    if (max == UNLIMITED_ARGUMENTS) rb_raise(rb_eArgError, "wrong number of arguments (given %d, expected %d+)", argc, min);
    rb_raise(rb_eArgError, "wrong number of arguments (given %d, expected %d..%d)", argc, min, max);
}
void rb_bug(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fputs("[BUG] ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
    abort();
}
void rb_bug_errno(const char *what, int number) { rb_bug("%s: errno == %d (%s)", what, number, strerror(number)); }
void rb_memerror(void) { rb_raise(rb_eNoMemError, "failed to allocate memory"); }
void rb_exit(int status) { rb_exc_raise(mr_call(rb_eSystemExit, "new", 1, INT2FIX(status))); }
void rb_sys_fail(const char *message) {
    int e = errno;
    VALUE argv[2] = { message ? rb_str_new_cstr(message) : Qnil, INT2FIX(e) };
    rb_exc_raise(mr_callv(rb_eSystemCallError, rb_intern("new"), 2, argv, Qnil, 0));
}
void rb_sys_fail_str(VALUE message) {
    int e = errno;
    VALUE argv[2] = { message, INT2FIX(e) };
    rb_exc_raise(mr_callv(rb_eSystemCallError, rb_intern("new"), 2, argv, Qnil, 0));
}
VALUE rb_syserr_new(int e, const char *message) {
    VALUE argv[2] = { message ? rb_str_new_cstr(message) : Qnil, INT2FIX(e) };
    return mr_callv(rb_eSystemCallError, rb_intern("new"), 2, argv, Qnil, 0);
}
VALUE rb_syserr_new_str(int e, VALUE message) {
    VALUE argv[2] = { message, INT2FIX(e) };
    return mr_callv(rb_eSystemCallError, rb_intern("new"), 2, argv, Qnil, 0);
}
void rb_syserr_fail(int e, const char *message) { rb_exc_raise(rb_syserr_new(e, message)); }
void rb_syserr_fail_str(int e, VALUE message) { rb_exc_raise(rb_syserr_new_str(e, message)); }
void rb_mod_sys_fail(VALUE module, const char *message) {
    VALUE exc = rb_syserr_new(errno, message);
    rb_extend_object(exc, module);
    rb_exc_raise(exc);
}
void rb_mod_syserr_fail(VALUE module, int e, const char *message) {
    VALUE exc = rb_syserr_new(e, message);
    rb_extend_object(exc, module);
    rb_exc_raise(exc);
}
static void warn_formatted(const char *fmt, va_list ap, int verbose_only) {
    if (verbose_only && !RTEST(rb_gv_get("$VERBOSE"))) return;
    if (NIL_P(rb_gv_get("$VERBOSE"))) return;
    VALUE message = rb_vsprintf(fmt, ap);
    mr_call(rb_mKernel, "warn", 1, rb_sprintf("warning: %" PRIsVALUE, message));
}
void rb_warn(const char *fmt, ...) { va_list ap; va_start(ap, fmt); warn_formatted(fmt, ap, 0); va_end(ap); }
void rb_warning(const char *fmt, ...) { va_list ap; va_start(ap, fmt); warn_formatted(fmt, ap, 1); va_end(ap); }
void rb_compile_warn(const char *file, int line, const char *fmt, ...) { (void)file; (void)line; va_list ap; va_start(ap, fmt); warn_formatted(fmt, ap, 0); va_end(ap); }
void rb_category_warn(rb_warning_category_t category, const char *fmt, ...) { (void)category; va_list ap; va_start(ap, fmt); warn_formatted(fmt, ap, 0); va_end(ap); }
void rb_category_warning(rb_warning_category_t category, const char *fmt, ...) { (void)category; va_list ap; va_start(ap, fmt); warn_formatted(fmt, ap, 1); va_end(ap); }
void rb_sys_warning(const char *fmt, ...) { va_list ap; va_start(ap, fmt); warn_formatted(fmt, ap, 1); va_end(ap); }

/* ---- $! --------------------------------------------------------------------- */
VALUE rb_errinfo(void) { return mr_up2(MR_ERRINFO, 0, Qnil); }
void rb_set_errinfo(VALUE exc) {
    if (!NIL_P(exc) && !RTEST(rb_obj_is_kind_of(exc, rb_eException))) rb_raise(rb_eTypeError, "assigning non-exception to $!");
    mr_up2(MR_ERRINFO, 1, exc);
}

/* ---- the guards ----------------------------------------------------------- */
VALUE rb_protect(VALUE (*func)(VALUE), VALUE arg, int *state) {
    register_roots();
    VALUE outcome;
    VALUE result = mr_guarded(func, arg, &outcome);
    if (outcome == Qundef) {
        if (state) *state = 0;
        return result;
    }
    int tag = outcome_tag(outcome);
    protected_outcome = outcome;
    /* ($! is the exception from here on, until the caller clears it) */
    mr_up2(MR_OUTCOME, outcome, MR_O_ENTER);
    if (state) *state = tag;
    return Qnil;
}
void rb_jump_tag(int state) {
    if (state == 0) rb_raise(rb_eArgError, "rb_jump_tag: no jump is pending for state 0");
    VALUE outcome = protected_outcome;
    if (outcome != Qundef && outcome_tag(outcome) == state) {
        protected_outcome = Qundef;
        mr_throw(outcome);
    }
    if (state == MR_TAG_RAISE) rb_exc_raise(rb_errinfo());
    rb_raise(rb_eRuntimeError, "rb_jump_tag: no jump of state %d is pending", state);
}
VALUE rb_ensure(VALUE (*body)(VALUE), VALUE data1, VALUE (*cleanup)(VALUE), VALUE data2) {
    VALUE before = rb_errinfo();
    VALUE leaving, cleanup_leaving;
    volatile VALUE result = mr_guarded(body, data1, &leaving);
    if (leaving != Qundef) mr_up2(MR_OUTCOME, leaving, MR_O_ENTER);
    volatile VALUE kept = leaving;      /* (on this stack: a collection in the cleanup finds it) */
    mr_guarded(cleanup, data2, &cleanup_leaving);
    mr_up2(MR_ERRINFO, 1, before);
    if (cleanup_leaving != Qundef) mr_throw(cleanup_leaving);
    if (kept != Qundef) mr_throw(kept);
    return result;
}
static VALUE rescue_classes(VALUE (*body)(VALUE), VALUE data1, VALUE (*handler)(VALUE, VALUE), VALUE data2,
                            int count, const VALUE *classes) {
    VALUE leaving;
    VALUE before = rb_errinfo();
    VALUE result = mr_guarded(body, data1, &leaving);
    if (leaving == Qundef) return result;
    volatile VALUE kept = leaving;
    if (outcome_tag(leaving) != MR_TAG_RAISE) mr_throw(kept);
    volatile VALUE exc = mr_up2(MR_OUTCOME, leaving, MR_O_EXCEPTION);
    int handled = 0;
    for (int i = 0; i < count && !handled; i++) handled = RTEST(rb_obj_is_kind_of(exc, classes[i]));
    if (!handled) mr_throw(kept);
    mr_up2(MR_OUTCOME, kept, MR_O_ENTER);
    result = handler ? handler(data2, exc) : Qnil;
    mr_up2(MR_ERRINFO, 1, before);
    return result;
}
VALUE rb_vrescue2(VALUE (*body)(VALUE), VALUE data1, VALUE (*handler)(VALUE, VALUE), VALUE data2, va_list ap) {
    VALUE classes[32];
    int count = 0;
    VALUE klass;
    while ((klass = va_arg(ap, VALUE)) != 0) {
        if (count == 32) rb_raise(rb_eArgError, "rb_rescue2: too many exception classes");
        classes[count++] = klass;
    }
    return rescue_classes(body, data1, handler, data2, count, classes);
}
VALUE rb_rescue2(VALUE (*body)(VALUE), VALUE data1, VALUE (*handler)(VALUE, VALUE), VALUE data2, ...) {
    va_list ap;
    va_start(ap, data2);
    VALUE result = rb_vrescue2(body, data1, handler, data2, ap);
    va_end(ap);
    return result;
}
VALUE rb_rescue(VALUE (*body)(VALUE), VALUE data1, VALUE (*handler)(VALUE, VALUE), VALUE data2) {
    return rescue_classes(body, data1, handler, data2, 1, &rb_eStandardError);
}

/* ---- throw and catch --------------------------------------------------------- */
void rb_throw_obj(VALUE tag, VALUE value) {
    mr_call(rb_mKernel, "throw", 2, tag, value);
    mr_fatal("a throw returned");
}
void rb_throw(const char *tag, VALUE value) { rb_throw_obj(ID2SYM(rb_intern(tag)), value); }
VALUE rb_catch_obj(VALUE tag, rb_block_call_func_t func, VALUE data) {
    return rb_block_call(rb_mKernel, rb_intern("catch"), 1, &tag, func, data);
}
VALUE rb_catch(const char *tag, rb_block_call_func_t func, VALUE data) { return rb_catch_obj(ID2SYM(rb_intern(tag)), func, data); }
