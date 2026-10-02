#!/usr/bin/env python3
# Patch an emitted mere-ruby mr.c for an ASan build that sees region REUSE:
#   - a block region returned to the cache is poisoned whole
#   - a map's private region wound back by *_recycle has its seed block poisoned
#   - every bump allocation (and an in-place grow) unpoisons what it hands out
#   - on an ASan report, the interpreter's own call-name table is printed
#     (read without allocating: the report's memory may be the allocator's)
# usage: asan_patch.py <in mr.c> <out mr.c>
# build: clang -O1 -fsanitize=address -fno-omit-frame-pointer \
#          -Wl,-stack_size,0x20000000 -fbracket-depth=1024 -w out.c -o mrasan
# A site that is not found stops the script: the emitted runtime moved.
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding='latin-1').read()
def rep(old, new, count=1):
    global s
    n = s.count(old)
    if (count == 'any' and n == 0) or (count != 'any' and n != count):
        sys.exit("site not found (%d): %r" % (n, old[:60]))
    s = s.replace(old, new)
s = '#include <sanitizer/asan_interface.h>\n' + s
rep('''  r->top = r->base;
  if (__lang_region_cache_n < __LANG_REGION_CACHE_CAP)
    __lang_region_cache[__lang_region_cache_n++] = r;
  else { __lang_region_free(r); free(r); }
}''', '''  ASAN_POISON_MEMORY_REGION(r->base, r->cap);
  r->top = r->base;
  if (__lang_region_cache_n < __LANG_REGION_CACHE_CAP)
    __lang_region_cache[__lang_region_cache_n++] = r;
  else { ASAN_UNPOISON_MEMORY_REGION(r->base, r->cap); __lang_region_free(r); free(r); }
}''')
rep('''  void* p = r->top;
  r->top += aligned;
  if (shared) pthread_mutex_unlock(&__lang_default_region_lock);
  return p;
}''', '''  void* p = r->top;
  r->top += aligned;
  ASAN_UNPOISON_MEMORY_REGION(p, aligned);
  if (shared) pthread_mutex_unlock(&__lang_default_region_lock);
  return p;
}''')
rep('''      r->top = (char*)old + new_al;
      r->alloc_total += new_al - old_al;''', '''      r->top = (char*)old + new_al;
      ASAN_UNPOISON_MEMORY_REGION(old, new_al);
      r->alloc_total += new_al - old_al;''')
rep('''    r->blocks = b;
    r->base = (char*)(b + 1);
    r->top = r->base;
    r->cap = 4096;''', '''    r->blocks = b;
    r->base = (char*)(b + 1);
    ASAN_POISON_MEMORY_REGION(r->base, 4096);
    r->top = r->base;
    r->cap = 4096;''', 'any')
rep('static mere_map_str_int* mu_struct_ctr;\n', '''static mere_map_str_int* mu_struct_ctr;
static mere_map_int_str* mu_call_names_s;
static const struct { size_t l; char s[3]; } __dbg_cd = { 2, "cd" };
static void __dbg_death(void) {
  long long cd = mu_struct_ctr && mere_map_str_int_has(mu_struct_ctr, __dbg_cd.s) ? mere_map_str_int_get(mu_struct_ctr, __dbg_cd.s) : 0;
  fprintf(stderr, "[dbg] ruby call depth %lld; innermost frames:\\n", cd);
  for (long long k = cd - 1; k >= 0 && k >= cd - 30; k--) {
    const char* nm = mu_call_names_s && mere_map_int_str_has(mu_call_names_s, k) ? mere_map_int_str_get(mu_call_names_s, k) : "?";
    fprintf(stderr, "  %lld %s\\n", k, nm);
  }
}
__attribute__((constructor)) static void __dbg_reg(void) { __sanitizer_set_death_callback(__dbg_death); }
''')
open(dst, 'w', encoding='latin-1').write(s)
