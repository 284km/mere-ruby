/* Investigation adapter for unchanged ensured.c. Exceptions never longjmp
 * across a Mere callback: it first returns a negative rooted outcome token.
 * Every setjmp/longjmp below is confined to active C frames on this thread. */
#include "include/ruby.h"
#include "exception_api.h"
#include <assert.h>
#include <dlfcn.h>
#include <limits.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { CALL = 1, YIELD, RAISE, GET_BANG, ENTER_ENSURE, SET_BANG, API_ERROR };
struct guard { jmp_buf jump; struct guard *previous; };
struct context {
    closure_native_request_int callback;
    struct context *previous;
    struct guard *guard;
    int pending, method;
    VALUE first, second, third;
};
static _Thread_local struct context *active;
static int live_resources, call_depth, ensures;
static void *module;
static char error[256];
static char names[64][96];
static int name_count;
static struct {
    char name[96]; int arity;
    union { probe_method1 one; probe_method2 two; } fn;
} methods[16];
static int method_count;

static _Noreturn void jump_pending(int token) {
    assert(active && active->guard && token > 0);
    active->pending = token;
    longjmp(active->guard->jump, 1);
}
VALUE probe_dispatch(int op, VALUE recv, ID mid, int argc, VALUE a0, VALUE a1) {
    assert(active);
    native_request request = {.mu_op=op, .mu_recv=recv, .mu_mid=mid,
        .mu_argc=argc, .mu_a0=a0, .mu_a1=a1};
    long long result = active->callback.fn(active->callback.env, request);
    assert(result >= -INT_MAX && result <= INT_MAX);
    if (result < 0) jump_pending((int)-result);
    return (VALUE)result;
}
static VALUE protect(probe_body body, VALUE argument) {
    struct guard guard = {.previous=active->guard};
    volatile VALUE result = Qnil;
    active->guard = &guard;
    if (setjmp(guard.jump) == 0) result = body(argument);
    active->guard = guard.previous;
    return result;
}
ID rb_intern(const char *name) {
    for (int i=0; i<name_count; i++) if (!strcmp(names[i], name)) return (ID)i+1;
    if (name_count == 64 || strlen(name) >= sizeof(names[0])) {
        probe_dispatch(API_ERROR, 0, 1, 0, 0, 0); abort();
    }
    strcpy(names[name_count], name);
    return (ID)++name_count;
}
char *mr_native_method_name(int id) {
    return id > 0 && id <= name_count ? names[id-1] : "";
}
VALUE rb_funcall(VALUE object, ID id, int argc, ...) {
    if (argc < 0 || argc > 2 || id == 0 || id > (ID)name_count) {
        probe_dispatch(API_ERROR, 0, 1, 0, 0, 0); abort();
    }
    va_list args; va_start(args, argc);
    VALUE a0 = argc > 0 ? va_arg(args, VALUE) : Qnil;
    VALUE a1 = argc > 1 ? va_arg(args, VALUE) : Qnil;
    va_end(args);
    return probe_dispatch(CALL, object, id, argc, a0, a1);
}
VALUE rb_yield(VALUE object) { return probe_dispatch(YIELD, object, 0, 0, 0, 0); }
_Noreturn void rb_exc_raise(VALUE exception) {
    probe_dispatch(RAISE, exception, 0, 0, 0, 0); abort();
}
VALUE rb_ensure(probe_body body, VALUE object, probe_body cleanup, VALUE data) {
    VALUE previous_bang = probe_dispatch(GET_BANG, 0, 0, 0, 0, 0);
    VALUE result = protect(body, object);
    int body_pending = active->pending;
    active->pending = 0;
    probe_dispatch(ENTER_ENSURE, (VALUE)body_pending, 0, 0, 0, 0);
    if (!getenv("MERE_NATIVE_SKIP_ENSURE")) {
        ensures++;
        (void)protect(cleanup, data);
    }
    int cleanup_pending = active->pending;
    active->pending = 0;
    probe_dispatch(SET_BANG, previous_bang, 0, 0, 0, 0);
    if (cleanup_pending) jump_pending(cleanup_pending);
    if (body_pending) jump_pending(body_pending);
    return result;
}
static int register_method(const char *name, int arity) {
    if (method_count == 16 || strlen(name) >= sizeof(methods[0].name)) {
        snprintf(error, sizeof(error), "native registration capacity exceeded"); return -1;
    }
    int i = method_count++;
    strcpy(methods[i].name, name); methods[i].arity = arity;
    return i;
}
void probe_define_module1(VALUE klass, const char *name, probe_method1 fn, int arity) {
    (void)klass;
    if (arity != 1) { snprintf(error, sizeof(error), "invalid native arity"); return; }
    int i = register_method(name, arity); if (i >= 0) methods[i].fn.one = fn;
}
void probe_define_module2(VALUE klass, const char *name, probe_method2 fn, int arity) {
    (void)klass;
    if (arity != 2) { snprintf(error, sizeof(error), "invalid native arity"); return; }
    int i = register_method(name, arity); if (i >= 0) methods[i].fn.two = fn;
}
int mr_native_load(const char *path) {
    if (module) return method_count;
    error[0] = 0; method_count = 0;
    module = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!module) { snprintf(error, sizeof(error), "%s", dlerror()); return -1; }
    void (*init)(VALUE) = (void (*)(VALUE))dlsym(module, "Init_ensured");
    if (!init) snprintf(error, sizeof(error), "%s", dlerror());
    else init(Qnil);
    if (error[0]) { dlclose(module); module = NULL; method_count = 0; return -1; }
    return method_count;
}
char *mr_native_error(void) { return error; }
int mr_native_find(const char *name) {
    for (int i=0; i<method_count; i++) if (!strcmp(methods[i].name, name)) return i;
    return -1;
}
int mr_native_arity(int method) {
    return method >= 0 && method < method_count ? methods[method].arity : -1;
}
extern VALUE probe_typed_entry(int, VALUE, VALUE, VALUE);
static VALUE entry(VALUE unused) {
    (void)unused;
    int method = active->method;
    if (method < 0) return probe_typed_entry(-method-1, active->first, active->second, active->third);
    if (method >= method_count) {
        probe_dispatch(API_ERROR, 0, 1, 0, 0, 0); abort();
    }
    if (methods[method].arity == 1) return methods[method].fn.one(Qnil, active->first);
    return methods[method].fn.two(Qnil, active->first, active->second);
}
int mr_native_invoke(closure_native_request_int callback, int method, int first, int second, int third) {
    struct context context = {.callback=callback, .previous=active,
        .method=method, .first=(VALUE)first, .second=(VALUE)second, .third=(VALUE)third};
    void *resource = malloc(64);
    if (!resource) abort();
    live_resources++; call_depth++;
    active = &context;
    VALUE result = protect(entry, Qnil);
    int pending = context.pending;
    active = context.previous;
    free(resource); live_resources--; call_depth--;
    return pending ? -pending : (int)result;
}
int mr_native_resources(void) { return live_resources; }
int mr_native_depth(void) { return call_depth; }
int mr_native_ensures(void) { return ensures; }
