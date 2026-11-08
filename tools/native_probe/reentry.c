/* Separately compiled against the header generated from reentry.mere.
 * Synchronous invocation only: the callback is never stored past this call. */
#include "reentry.h"
#include <stdlib.h>
static int native_probe_phase;
static int native_probe_resources;
int mr_probe_reenter(closure_int_int cb, int value) {
    void *resource = malloc(64);
    if (!resource) abort();
    native_probe_resources++;
    native_probe_phase = 1;
    int result = (int)cb.fn(cb.env, value);
    free(resource);
    native_probe_resources--;
    native_probe_phase = 2;
    return result;
}
int mr_probe_phase(void) { return native_probe_phase; }
int mr_probe_live_resources(void) { return native_probe_resources; }
