/* Read process identities without spawning commands or consulting PATH; and
 * the times of a file to the nanosecond, which Mere's stat gives in seconds. */
#include <inttypes.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>

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

/* File.stat's atime, mtime and ctime as "sec nsec sec nsec sec nsec", from
 * one stat(2) (how 1), lstat(2) (how 0) or fstat(2) of `fd` (how 2); "" when
 * the call fails. The interpreter takes the seconds from here as well, so
 * the two halves of a time come from the same call. */
char *mr_stat_times(const char *path, int how, int fd) {
    static _Thread_local char result[6 * 24];
    struct stat st;
    int rc = how == 2 ? fstat(fd, &st) : how == 1 ? stat(path, &st) : lstat(path, &st);
    if (rc != 0) return "";
#ifdef __APPLE__
    struct timespec a = st.st_atimespec, m = st.st_mtimespec, c = st.st_ctimespec;
#else
    struct timespec a = st.st_atim, m = st.st_mtim, c = st.st_ctim;
#endif
    snprintf(result, sizeof(result), "%lld %ld %lld %ld %lld %ld",
             (long long)a.tv_sec, (long)a.tv_nsec, (long long)m.tv_sec, (long)m.tv_nsec,
             (long long)c.tv_sec, (long)c.tv_nsec);
    return result;
}

/* File.utime / File.lutime: utimensat(2) to the nanosecond, of the path
 * (follow 1) or of a link itself (follow 0). `spec` is "asec ansec msec mnsec"
 * (text: a Mere int extern argument is a C int, and seconds pass 2038).
 * 0, or the errno. */
int mr_utimens(const char *path, int follow, const char *spec) {
    struct timespec ts[2];
    char *end = (char *)spec;
    for (int i = 0; i < 2; i++) {
        ts[i].tv_sec = (time_t)strtoll(end, &end, 10);
        ts[i].tv_nsec = strtol(end, &end, 10);
    }
    return utimensat(AT_FDCWD, path, ts, follow ? 0 : AT_SYMLINK_NOFOLLOW) == 0 ? 0 : errno;
}
