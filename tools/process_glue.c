/* Read process identities without spawning commands or consulting PATH. */
#include <inttypes.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>

/* Match GC::Profiler's process CPU clock. Wall time would incorrectly charge
 * sleeps and I/O waits to GC_TIME and the invocation timeline. */
double mr_gc_process_cpu_time(void) {
#if defined(CLOCK_PROCESS_CPUTIME_ID)
    struct timespec value;
    if (clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value) == 0)
        return (double)value.tv_sec + (double)value.tv_nsec * 1e-9;
#endif
    clock_t ticks = clock();
    return ticks == (clock_t)-1 ? -1.0 : (double)ticks / CLOCKS_PER_SEC;
}

char *mr_process_id(int kind) {
    /* Mere's plain int extern uses C int. Decimal text preserves the full
     * unsigned uid_t/gid_t range; the extern adapter copies this C string. */
    static _Thread_local char result[sizeof(uintmax_t) * 3 + 1];
    uintmax_t id;
    switch (kind) {
    case 0: id = (uintmax_t)getuid(); break;
    case 1: id = (uintmax_t)getgid(); break;
    case 2: id = (uintmax_t)geteuid(); break;
    case 3: id = (uintmax_t)getegid(); break;
    default: return "";
    }
    snprintf(result, sizeof(result), "%" PRIuMAX, id);
    return result;
}
