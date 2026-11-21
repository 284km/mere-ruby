/* Read page-table flags only. Never fault in payload bytes, change mappings,
 * clear references, or request collection. PFNs are neither needed nor logged. */
#if defined(__linux__)
#include <stdint.h>
#include <fcntl.h>
#include <limits.h>
static void gem_page_region(unsigned sample, const char *kind, int arena,
                            uintptr_t lo, size_t capacity) {
    int saved_errno = errno, error = 0;
    const char *reason = "range";
    long size = sysconf(_SC_PAGESIZE);
    int fd = -1;
    size_t pages = 0, present = 0, exclusive = 0, swapped = 0;
    if (size <= 0 || capacity > UINTPTR_MAX - lo) goto failed;
    uintptr_t hi = lo + capacity, page = (uintptr_t)size;
    uintptr_t first = lo / page + (lo % page != 0), stop = hi / page;
    if (stop < first) stop = first;
    if (stop > (uint64_t)LLONG_MAX / sizeof(uint64_t)) goto failed;
    pages = (size_t)(stop - first);
    if (pages) {
        fd = open("/proc/self/pagemap", O_RDONLY | O_CLOEXEC);
        if (fd < 0) { reason = "open"; error = errno; goto failed; }
        uint64_t entries[512];
        for (uintptr_t at = first; at < stop; ) {
            size_t count = (size_t)(stop - at);
            if (count > 512) count = 512;
            size_t bytes = count * sizeof(uint64_t), done = 0;
            while (done < bytes) {
                ssize_t n = pread(fd, (char *)entries + done, bytes - done,
                                  (off_t)(at * sizeof(uint64_t) + done));
                if (n < 0 && errno == EINTR) continue;
                if (n <= 0 || n % sizeof(uint64_t)) {
                    reason = "read"; error = n < 0 ? errno : EIO; goto failed;
                }
                done += (size_t)n;
            }
            for (size_t i = 0; i < count; ++i) {
                unsigned p = (unsigned)(entries[i] >> 63);
                unsigned s = (unsigned)((entries[i] >> 62) & 1);
                if (p && s) { reason = "flags"; error = EIO; goto failed; }
                present += p;
                swapped += s;
                exclusive += p && ((entries[i] >> 56) & 1);
            }
            at += count;
        }
        close(fd);
    }
    fprintf(stderr, "RSS_PAGE sample=%u kind=%s arena=%d lo=%lu hi=%lu page_bytes=%ld pages=%zu present=%zu exclusive=%zu swapped=%zu\n",
            sample, kind, arena, (unsigned long)lo, (unsigned long)hi,
            size, pages, present, exclusive, swapped);
    errno = saved_errno;
    return;
failed:
    if (fd >= 0) close(fd);
    fprintf(stderr, "RSS_PAGE_ERROR sample=%u kind=%s arena=%d reason=%s errno=%d\n",
            sample, kind, arena, reason, error);
    errno = saved_errno;
}
#else
static void gem_page_region(unsigned sample, const char *kind, int arena,
                            uintptr_t lo, size_t capacity) {
    (void)kind; (void)arena; (void)lo; (void)capacity;
    fprintf(stderr, "RSS_PAGE_ERROR sample=%u reason=unsupported\n", sample);
}
#endif
