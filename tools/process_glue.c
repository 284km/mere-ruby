/* Read process identities without spawning commands or consulting PATH. */
#include <inttypes.h>
#include <stdio.h>
#include <unistd.h>

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
