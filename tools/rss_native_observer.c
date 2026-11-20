/* Diagnostic fragment, appended only to a separate emitted-C copy.
 * Read native ownership at the subject's existing RSS observations. Never
 * collect, compact, change pins, or free an arena. Ordinary builds omit it.
 * Private layout is checked by compiling with the locked Mere compiler.
 */
static size_t gem_rss_capacity(__lang_region *region) {
    size_t bytes = 0;
    for (__lang_region_block *b = region ? region->blocks : NULL; b; b = b->prev)
        bytes += b->pad;
    return bytes;
}

static long long gem_rss_resident_kb(void) {
#ifdef __linux__
    unsigned long size = 0, resident = 0;
    FILE *status = fopen("/proc/self/statm", "r");
    if (!status) return -1;
    int read = fscanf(status, "%lu %lu", &size, &resident);
    fclose(status);
    long page = sysconf(_SC_PAGESIZE);
    if (read != 2 || page <= 0) return -1;
    return (long long)resident * page / 1024;
#else
    return -1; /* unavailable, never a fabricated RSS measurement */
#endif
}

static void gem_rss_snapshot(const char *phase) {
    const char *enabled = getenv("RSS_NATIVE_ENABLE");
    const char *excluded = getenv("RSS_NATIVE_EXCLUDE_PID");
    if (!enabled || strcmp(enabled, "1")) return;
    if (excluded && strtoll(excluded, NULL, 10) == (long long)getpid()) return;
    static _Thread_local unsigned sample = 0;
    if (!strcmp(phase, "exit") && sample == 0) return;
    unsigned index = sample++;
    unsigned long long current = __lang_coro_cur_handle();
    unsigned long long root = (__lang_coro_root.slot && __lang_coro_gens)
        ? __lang_coro_handle(&__lang_coro_root) : 0;
    fprintf(stderr, "\nRSS_NATIVE_BEGIN sample=%u phase=%s rss_kb=%lld epoch=%lu current=%llu root=%llu\n",
            index, phase, gem_rss_resident_kb(), (unsigned long)__lang_region_epoch, current, root);
    fprintf(stderr, "RSS_NATIVE_DEFAULT sample=%u capacity=%zu allocated=%zu\n", index,
            gem_rss_capacity(&__lang_default_region), __lang_default_region.alloc_total);
#define GEM_RSS_MAP(name) do { \
    if (mu_##name) fprintf(stderr, \
        "RSS_NATIVE_MAP sample=%u name=" #name " rows=%d slots=%d table_capacity=%d capacity=%zu allocated=%zu pin_floor=%zu default=%d\n", \
        index, mu_##name->live, mu_##name->len, mu_##name->cap, gem_rss_capacity(mu_##name->region), \
        mu_##name->region->alloc_total, mu_##name->region->cbase, \
        mu_##name->region == &__lang_default_region); \
} while (0)
    GEM_RSS_MAP(meths_g);
    GEM_RSS_MAP(meth_cref);
    GEM_RSS_MAP(meth_src);
    GEM_RSS_MAP(meth_params);
    GEM_RSS_MAP(method_cores);
    GEM_RSS_MAP(dm_methods);
    GEM_RSS_MAP(dm_closenv);
    GEM_RSS_MAP(dm_captured);
    GEM_RSS_MAP(dm_had_blk);
    GEM_RSS_MAP(alias_origin);
    GEM_RSS_MAP(alias_srcname);
    GEM_RSS_MAP(anonymous_classes);
    GEM_RSS_MAP(modules);
    GEM_RSS_MAP(cls_sup);
    GEM_RSS_MAP(class_meta);
    GEM_RSS_MAP(cls_oids);
    GEM_RSS_MAP(meth_owner_seen);
    GEM_RSS_MAP(mro_local_epoch);
    GEM_RSS_MAP(mro_anc);
    GEM_RSS_MAP(mro_mods);
    GEM_RSS_MAP(hm_memo);
    GEM_RSS_MAP(mro_lookup_root);
    GEM_RSS_MAP(mro_external);
    GEM_RSS_MAP(cls_copy_of);
    GEM_RSS_MAP(bi_class_name);
    GEM_RSS_MAP(bi_reg_r);
    GEM_RSS_MAP(ref_snaps);
#undef GEM_RSS_MAP
    size_t cached = 0, retired = 0, retired_allocated = 0;
    for (int i = 0; i < __lang_region_cache_n; ++i)
        cached += gem_rss_capacity(__lang_region_cache[i]);
    for (int i = 0; i < __lang_retired_n; ++i) {
        __lang_retiree *entry = &__lang_retired[i];
        size_t capacity = gem_rss_capacity(entry->r);
        retired += capacity;
        retired_allocated += entry->r->alloc_total;
        fprintf(stderr, "RSS_NATIVE_RETIRED sample=%u arena=%d capacity=%zu allocated=%zu epoch=%lu pinners=%d\n",
                index, i, capacity, entry->r->alloc_total, entry->ep, entry->nby);
        for (int j = 0; j < entry->nby; ++j) {
            __lang_coro *coro = __lang_coro_of(entry->by[j]);
            fprintf(stderr, "RSS_NATIVE_PIN sample=%u arena=%d handle=%llu present=%d state=%d root=%d current=%d stopped_epoch=%lu cached_words_valid=%d cached_words=%zu\n",
                    index, i, entry->by[j], coro != NULL, coro ? coro->state : -1,
                    coro == &__lang_coro_root, coro && coro == __lang_coro_cur,
                    coro && coro->x ? coro->x->sep : 0,
                    coro && coro->x ? coro->x->pgot : 0,
                    coro && coro->x ? coro->x->pn : 0);
        }
    }
    fprintf(stderr, "RSS_NATIVE_END sample=%u cache_regions=%d cache_capacity=%zu retired_regions=%d retired_capacity=%zu retired_allocated=%zu\n",
            index, __lang_region_cache_n, cached, __lang_retired_n, retired, retired_allocated);
}

__attribute__((destructor)) static void gem_rss_exit_snapshot(void) {
    gem_rss_snapshot("exit");
}
