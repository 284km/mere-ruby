/* Diagnostic only. Compile this in place of mr.c using the same build flags.
 * Read retired native arenas at exit; do not collect, compact or free them.
 * This depends on the pinned Mere runtime's private C layout and is never
 * linked into the ordinary interpreter or used as the lifetime gate binary.
 */
#include "../mr.c"

__attribute__((destructor)) static void gem_retired_observation(void) {
  size_t capacity = 0;
  size_t allocated = 0;
  for (int index = 0; index < __lang_retired_n; ++index) {
    __lang_retiree *entry = &__lang_retired[index];
    size_t bytes = 0;
    for (__lang_region_block *block = entry->r->blocks; block; block = block->prev)
      bytes += block->pad;
    capacity += bytes;
    allocated += entry->r->alloc_total;
    fprintf(stderr, "retired-observer arena=%d capacity=%zu allocated=%zu pinners=%d\n",
            index, bytes, entry->r->alloc_total, entry->nby);
  }
  fprintf(stderr, "retired-observer total arenas=%d capacity=%zu allocated=%zu\n",
          __lang_retired_n, capacity, allocated);
}
