/* Read-only Linux/glibc diagnostics, included after the private runtime.
 * Allocation totals and virtual mappings are not resident memory. */
#if defined(__linux__) && defined(__GLIBC__)
#include <malloc.h>
static void gem_heap_region(unsigned sample, const char *kind, int arena, __lang_region *r) {
    for (__lang_region_block *b = r ? r->blocks : NULL; b; b = b->prev)
        fprintf(stderr, "RSS_REGION sample=%u kind=%s arena=%d lo=%lu hi=%lu capacity=%zu\n",
                sample, kind, arena, (unsigned long)(b + 1),
                (unsigned long)(b + 1) + b->pad, b->pad);
}

static void gem_heap_snapshot(unsigned sample) {
    struct mallinfo2 info = mallinfo2();
    fprintf(stderr, "\nRSS_HEAP sample=%u arena=%zu mmap=%zu used=%zu free=%zu top=%zu\n",
            sample, info.arena, info.hblkhd, info.uordblks, info.fordblks, info.keepcost);
    gem_heap_region(sample, "default", 0, &__lang_default_region);
    gem_heap_region(sample, "kept", 0, &__lang_kept_region);
    gem_heap_region(sample, "methods", 0, mu_meths_g ? mu_meths_g->region : NULL);
    for (int i = 0; i < __lang_region_cache_n; ++i)
        gem_heap_region(sample, "cache", i, __lang_region_cache[i]);
    for (int i = 0; i < __lang_retired_n; ++i)
        gem_heap_region(sample, "retired", i, __lang_retired[i].r);
    for (__lang_coro *c = __lang_coro_live; c; c = c->x->lnext) {
        if (!c->x) continue;
        fprintf(stderr,
            "RSS_STACK sample=%u handle=%llu state=%d lo=%lu hi=%lu map=%lu bytes=%zu\n",
            sample, __lang_coro_handle(c), c->state, (unsigned long)c->x->s_lo,
            (unsigned long)c->x->s_hi, (unsigned long)c->x->map, c->x->map_size);
        __lang_region **active = c == __lang_coro_cur ? __lang_region_active : c->x->s_active;
        int count = c == __lang_coro_cur ? __lang_region_active_n : c->x->s_active_n;
        fprintf(stderr, "RSS_ACTIVE_SET sample=%u handle=%llu count=%d\n", sample, __lang_coro_handle(c), count);
        for (int i = 0; i < count; ++i) {
            __lang_region *r = active[i];
            size_t capacity = 0;
            for (__lang_region_block *b = r ? r->blocks : NULL; b; b = b->prev) capacity += b->pad;
            fprintf(stderr, "RSS_ACTIVE sample=%u handle=%llu index=%d site=%s capacity=%zu allocated=%zu\n",
                    sample, __lang_coro_handle(c), i, r && r->site ? r->site : "none",
                    capacity, r ? r->alloc_total : 0);
            gem_heap_region(sample, "active", i, r);
        }
    }
    FILE *maps = fopen("/proc/self/smaps", "r");
    if (!maps) return;
    char line[512], kind[16] = "unknown";
    unsigned long lo = 0, hi = 0, rss = 0;
    while (fgets(line, sizeof line, maps)) {
        unsigned long a, b, n;
        char permissions[8];
        if (sscanf(line, "%lx-%lx %7s", &a, &b, permissions) == 3) {
            if (rss >= 1024) fprintf(stderr,
                "RSS_MAPPING sample=%u lo=%lu hi=%lu rss_kb=%lu kind=%s\n", sample, lo, hi, rss, kind);
            lo = a; hi = b; rss = 0;
            strcpy(kind, strstr(line, "[heap]") ? "heap" : strstr(line, "[stack]") ? "stack" :
                   strchr(line, '/') ? "file" : "anonymous");
        } else if (sscanf(line, "Rss: %lu kB", &n) == 1) rss = n;
    }
    if (rss >= 1024) fprintf(stderr,
        "RSS_MAPPING sample=%u lo=%lu hi=%lu rss_kb=%lu kind=%s\n", sample, lo, hi, rss, kind);
    fclose(maps);
}
#else
static void gem_heap_snapshot(unsigned sample) { (void)sample; }
#endif
