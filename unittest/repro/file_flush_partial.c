#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#ifndef __APPLE__
#include <dlfcn.h>
#endif

/* Fault only the named fixture's writes. A short successful write is followed
 * by ENOSPC until the Ruby program disarms the fault and retries flush. */
static ssize_t fixture_write(int fd, const void *bytes, size_t length) {
    static int partial;
    const char *control = getenv("MR_FLUSH_PARTIAL_CONTROL");
    const char *target = getenv("MR_FLUSH_PARTIAL_TARGET");
    char path[PATH_MAX];
    int matches = 0;
#ifdef __APPLE__
    if (target && fcntl(fd, F_GETPATH, path) == 0)
        matches = strcmp(path, target) == 0;
#else
    char link[64];
    snprintf(link, sizeof(link), "/proc/self/fd/%d", fd);
    ssize_t n = readlink(link, path, sizeof(path) - 1);
    if (target && n >= 0) {
        path[n] = '\0';
        matches = strcmp(path, target) == 0;
    }
#endif
    char armed = '0';
    if (matches && control) {
        int control_fd = open(control, O_RDONLY);
        if (control_fd >= 0) { (void)read(control_fd, &armed, 1); close(control_fd); }
    }
    if (matches && armed != '1') partial = 0;
    else if (matches) {
        if (partial) { errno = ENOSPC; return -1; }
        partial = 1;
        if (length > 5) length = 5;
    }
#ifdef __APPLE__
    return write(fd, bytes, length);
#else
    ssize_t (*real_write)(int, const void *, size_t) = dlsym(RTLD_NEXT, "write");
    return real_write(fd, bytes, length);
#endif
}

#ifdef __APPLE__
__attribute__((used)) static struct {
    const void *replacement;
    const void *original;
} interpose_write __attribute__((section("__DATA,__interpose"))) = {
    (const void *)fixture_write, (const void *)write
};
#else
ssize_t write(int fd, const void *bytes, size_t length) {
    return fixture_write(fd, bytes, length);
}
#endif
