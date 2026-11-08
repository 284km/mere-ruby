/* Investigation only: float methods and a legacy single-slot root adapter.
 * The interpreter owns the native root table; C stores only its tokens.
 * This probe does not implement the CRuby binary ABI or C-stack scanning. */
#include "include/ruby.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static struct { char name[64]; probe_method2 fn; } methods[8];
static int count;
static double values[16];
static unsigned used;
static void *module;
static int held;
static char error[512];
double probe_num2dbl(VALUE v) {
    if (!v || v > used) abort();
    return values[v - 1];
}
VALUE probe_dbl2num(double v) {
    if (used == 16) abort();
    values[used++] = v;
    return used;
}
void rb_define_singleton_method(VALUE klass, const char *name, probe_method2 fn, int argc) {
    if (klass != 0 || argc != 2 || count == 8 || strlen(name) >= 64) abort();
    strcpy(methods[count].name, name);
    methods[count++].fn = fn;
}
int mr_probe_load(const char *path) {
    if (module) return count;
    module = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!module) { snprintf(error, sizeof(error), "%s", dlerror()); return -1; }
    void (*init)(VALUE) = (void (*)(VALUE))dlsym(module, "Init_nextafter");
    if (!init) {
        snprintf(error, sizeof(error), "%s", dlerror());
        dlclose(module); module = NULL; return -1;
    }
    init(0);
    return count;
}
const char *mr_probe_error(void) { return error; }
int mr_probe_find(const char *name) {
    for (int i = 0; i < count; i++) if (!strcmp(name, methods[i].name)) return i;
    return -1;
}
double mr_probe_call(int id, double x, double y) {
    if (id < 0 || id >= count) abort();
    used = 0;
    VALUE vx = probe_dbl2num(x), vy = probe_dbl2num(y);
    return probe_num2dbl(methods[id].fn(0, vx, vy));
}
int mr_probe_hold(int token) { held = token; return held; }
int mr_probe_held(void) { return held; }
int mr_probe_mark(void) { return getenv("MERE_NATIVE_PROBE_NO_ROOT") == NULL; }
