/* The structs behind a handle.
 *
 * ruby.h's casting macros (RBASIC, RSTRING, RARRAY, RDATA, RTYPEDDATA, ...)
 * call rb_mere_basic() and its siblings here. Each answers a pointer to a
 * struct laid out as ruby.h declares it, kept for the handle for as long as
 * the handle lasts:
 *
 *   - its header (flags: the type, frozen, the encoding; klass) is asked of
 *     the interpreter when the interpreter has run since it was last asked;
 *   - a String's bytes and an Array's elements are fetched the same way, and
 *     only when RSTRING() / RARRAY() is used on it -- a value that only
 *     passes through C costs nothing here;
 *   - what C writes into them (through RSTRING_PTR, rb_str_set_len,
 *     RARRAY_PTR) is found by comparing a hash taken at the last fetch, and
 *     written back before the interpreter runs again;
 *   - a data object's struct (RData / RTypedData) lives only here: it is the
 *     C pointer the object wraps. The collector says when the object is
 *     gone (mr_capi_release), and its dfree runs then.
 */
#include "mr_capi.h"
#include "ruby/io.h"
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct mr_mirror {
    unsigned long head_epoch;   /* when flags and klass were last asked */
    unsigned long body_epoch;   /* when the bytes / elements were last fetched */
    uint64_t hash;              /* of the body as fetched or last written back */
    long version;               /* an Array's version at the last fetch */
    long capa;                  /* elements an Array's buffer holds */
    char *own;                  /* a String's buffer when its bytes are not in the struct */
    long own_size;              /* ...and how many bytes it is */
    int own_mapped;             /* ...and it is mapped (mr_big_alloc): unmapped, not freed. A buffer C made and the mirror took over is malloc's */
    long reserve;               /* room the interpreter asked for (mr_capi_reserve), not yet made */
    long slot;                  /* a String's: the bytes its struct is allocated in (0 until chosen) */
    int heap_only;              /* ...and the room asked for is to be a buffer, whatever it fits (rb_str_init) */
    int frozen_by_c;            /* a String OBJ_FREEZE / rb_obj_freeze froze: its room stays (only String#freeze, rb_str_freeze, resizes) */
    int body;                   /* 0 none yet, T_STRING, T_ARRAY */
    int data;                   /* 0, 1 RData, 2 RTypedData */
    int listed;                 /* how many C calls in progress watch it (entries of `touched`) */
    int hidden;                 /* rb_obj_hide: its class reads as 0 to C until rb_obj_reveal */
    size_t embedded;            /* a typed struct's own bytes, after it */
    struct rb_io *io;           /* an IO's, made when RFILE first asks for it */
    union {
        struct RBasic basic;
        struct RFile file;
        struct RString string;
        struct RArray array;
        struct RData data;
        struct RTypedData typed;
    } as;
};

static struct mr_mirror **table;
static long table_cap;
/* (structs C may have written since they were fetched, with the C call that
 *  touched them: checked at every crossing until THAT call ends. The call is
 *  named by its frame and not by how deep it is: a Fiber that is stopped
 *  inside a C call has frames of its own, and another stack's call at the
 *  same depth must not end their watch -- what the stopped C writes through
 *  the pointer it holds, after it is resumed, still has to go back.) */
struct touched { struct mr_mirror *mirror; VALUE handle; const void *owner; };
static struct touched *touched;
static long touched_count, touched_cap;
extern const void *mr_capi_frame(void);
struct mr_transit { VALUE *words; long nwords; mere_bytes *bytes; char *text; double dbl; };
extern void mr_transit_save(struct mr_transit *, long);
extern void mr_transit_restore(struct mr_transit *);

static struct mr_mirror *mirror_at(long number, int create) {
    if (number < 0) mr_fatal("a VALUE that is not a handle was read as an object");
    if (number >= table_cap) {
        if (!create) return NULL;
        long cap = table_cap ? table_cap : 1024;
        while (cap <= number) cap *= 2;
        table = realloc(table, sizeof(*table) * (size_t)cap);
        if (!table) mr_fatal("out of memory");
        memset(table + table_cap, 0, sizeof(*table) * (size_t)(cap - table_cap));
        table_cap = cap;
    }
    if (!table[number] && create) {
        table[number] = calloc(1, sizeof(struct mr_mirror));
        if (!table[number]) mr_fatal("out of memory");
    }
    return table[number];
}

/* What a struct's body hashed to tells whether C wrote into it (write_back).
 * Four lanes over each 32 bytes, so the multiplications do not wait on each
 * other: one lane was a chain of dependent multiplies, about 1.5 ms for 8 MiB,
 * and a String C reads is hashed twice per call (when fetched and when the
 * call ends). copy_hash is the same hash taken while the bytes are copied. */
struct hash_lanes { uint64_t lane[4]; };
static inline uint64_t mix(uint64_t h, uint64_t k) {
    h = (h ^ k) * 0xFF51AFD7ED558CCDULL;
    return h ^ (h >> 32);
}
static void hash_start(struct hash_lanes *s, size_t n, uint64_t seed) {
    uint64_t h = seed ^ (n * 0x9E3779B97F4A7C15ULL);
    s->lane[0] = h;
    s->lane[1] = h ^ 0x6A09E667F3BCC908ULL;
    s->lane[2] = h ^ 0xBB67AE8584CAA73BULL;
    s->lane[3] = h ^ 0x3C6EF372FE94F82BULL;
}
static inline void hash_block(struct hash_lanes *s, const unsigned char *p) {
    uint64_t k[4];
    memcpy(k, p, 32);
    s->lane[0] = mix(s->lane[0], k[0]);
    s->lane[1] = mix(s->lane[1], k[1]);
    s->lane[2] = mix(s->lane[2], k[2]);
    s->lane[3] = mix(s->lane[3], k[3]);
}
/* (the last n < 32 bytes) */
static uint64_t hash_end(struct hash_lanes *s, const unsigned char *p, size_t n) {
    uint64_t h = mix(mix(mix(s->lane[0], s->lane[1]), s->lane[2]), s->lane[3]);
    while (n >= 8) {
        uint64_t k;
        memcpy(&k, p, 8);
        h = mix(h, k);
        p += 8; n -= 8;
    }
    while (n--) h = (h ^ *p++) * 0x100000001B3ULL;
    return h ^ (h >> 29);
}
/* (under 32 bytes, one lane: the four cost more than they save there, and a
 *  C call that reads many short Strings hashes each at every crossing) */
static inline __attribute__((always_inline)) uint64_t hash_short(const unsigned char *s, size_t n, uint64_t seed) {
    uint64_t h = seed ^ (n * 0x9E3779B97F4A7C15ULL);
    while (n >= 8) {
        uint64_t k;
        memcpy(&k, s, 8);
        h = mix(h, k);
        s += 8; n -= 8;
    }
    while (n--) h = (h ^ *s++) * 0x100000001B3ULL;
    return h ^ (h >> 29);
}
static uint64_t hash_long(const unsigned char *s, size_t n, uint64_t seed) {
    struct hash_lanes h;
    hash_start(&h, n, seed);
    size_t i = 0;
    for (; i + 32 <= n; i += 32) hash_block(&h, s + i);
    return hash_end(&h, s + i, n - i);
}
static inline __attribute__((always_inline)) uint64_t hash_bytes(const void *p, size_t n, uint64_t seed) {
    return n < 32 ? hash_short(p, n, seed) : hash_long(p, n, seed);
}
/* Copy n bytes to dst unless dst already holds them, and answer
 * hash_bytes(src, n, seed). *changed: whether dst was written -- on entry,
 * whether it must be (dst holds something else). One pass over src. */
static uint64_t copy_hash(unsigned char *dst, const unsigned char *src, size_t n, uint64_t seed, int *changed) {
    if (n < 32) {
        if (!*changed && memcmp(dst, src, n)) *changed = 1;
        if (*changed) memcpy(dst, src, n);
        return hash_short(src, n, seed);
    }
    struct hash_lanes h;
    hash_start(&h, n, seed);
    int ch = *changed;
    size_t i = 0;
    for (; i + 32 <= n; i += 32) {
        if (!ch && memcmp(dst + i, src + i, 32)) ch = 1;
        if (ch) memcpy(dst + i, src + i, 32);
        hash_block(&h, src + i);
    }
    size_t rest = n - i;
    if (rest && !ch && memcmp(dst + i, src + i, rest)) ch = 1;
    if (rest && ch) memcpy(dst + i, src + i, rest);
    *changed = ch;
    return hash_end(&h, src + i, rest);
}
/* ---- the slot a String's struct is allocated in ------------------------------ */
/* CRuby allocates a String's struct in a slot of one of five sizes -- 40, 80,
 * 160, 320 and 640 bytes on a 64-bit machine (variable-width allocation, five
 * words and its doublings) -- the smallest that holds the header, the bytes
 * and the terminator; one whose bytes do not fit in 640 gets the smallest
 * slot and a buffer of its own. This mirror does the same: the RString C
 * sees is the first `slot` bytes of `as`, and the block is allocated that
 * long (str_take_slot). The slot is chosen once, the first time C sees the
 * String, from its length or the room asked for, and never changes, as an
 * object's slot does not in CRuby. GC::INTERNAL_CONSTANTS reports these sizes
 * (mr_capi_layout), and ObjectSpace.dump the slot (mr_capi_str_layout). */
#define SLOT_COUNT 5
static const long slot_sizes[SLOT_COUNT] = {
    5 * (long)sizeof(VALUE), 10 * (long)sizeof(VALUE), 20 * (long)sizeof(VALUE),
    40 * (long)sizeof(VALUE), 80 * (long)sizeof(VALUE)
};
_Static_assert(sizeof(struct RString) == 5 * sizeof(VALUE), "the smallest slot is an RString");
#define EMBED_HEADER ((long)offsetof(struct RString, as.embed.ary))
static long slot_for(long need, int term, int heap) {
    long size = EMBED_HEADER + need + term;
    if (!heap)
        for (int i = 0; i < SLOT_COUNT; i++) if (size <= slot_sizes[i]) return slot_sizes[i];
    return slot_sizes[0];
}
/* (the block grows to the slot before anything holds a pointer into it: the
 *  first refresh of its head, before rb_mere_* answers the struct) */
static struct mr_mirror *str_take_slot(long number, struct mr_mirror *m, long slot) {
    size_t now = sizeof(struct mr_mirror);
    size_t want = offsetof(struct mr_mirror, as) + (size_t)slot;
    m->slot = slot;
    if (want <= now) return m;
    struct mr_mirror *bigger = realloc(m, want);
    if (!bigger) mr_fatal("out of memory");
    memset((char *)bigger + now, 0, want - now);
    table[number] = bigger;
    return bigger;
}

/* ---- where a String's bytes are -------------------------------------------- */
/* As CRuby keeps them: in the slot, after the header (RSTRING_NOEMBED clear),
 * while they and the terminator fit there, and otherwise in a buffer of their
 * own, as.heap.ptr, of as.heap.aux.capa bytes and room for the terminator. A
 * String that has left the slot stays out until rb_str_resize (or freezing,
 * which resizes) brings it back, as in CRuby. C may put a buffer of its own in
 * as.heap.ptr (ruby's own test extensions do); it is taken over, and freed
 * with the struct. */
static long embed_room(const struct mr_mirror *m) { return (m->slot ? m->slot : slot_sizes[0]) - EMBED_HEADER; }
enum { ROOM_GROW, ROOM_EXACT, ROOM_HEAP };
static int str_embedded(const struct mr_mirror *m) { return !(m->as.basic.flags & RSTRING_NOEMBED); }
static char *embed_ary(struct mr_mirror *m) { return (char *)&m->as.string + offsetof(struct RString, as.embed.ary); }
static char *str_ptr(struct mr_mirror *m) { return str_embedded(m) ? embed_ary(m) : m->as.string.as.heap.ptr; }
/* (the terminator of an encoding index, from the flags alone: the head is
 *  being refreshed and cannot be asked) */
static int term_of_index(int index) {
    rb_encoding *enc = rb_enc_from_index(index);
    int n = enc ? rb_enc_mbminlen(enc) : 1;
    return n > 1 && n <= 4 ? n : 1;
}
static int str_term(const struct mr_mirror *m) {
    return term_of_index((int)((m->as.basic.flags >> RUBY_ENCODING_SHIFT) & RUBY_ENCODING_INLINE_MAX));
}
/* The String's own buffer: let go, made, resized (core.c's big buffers: a
 * buffer of 1 MiB or more is mapped). */
static void own_free(struct mr_mirror *m) {
    mr_big_free(m->own, (size_t)m->own_size, m->own_mapped);
    m->own = NULL;
    m->own_size = 0;
    m->own_mapped = 0;
}
static char *own_alloc(size_t size, int *mapped) {
    char *p = mr_big_alloc(size);
    *mapped = mr_big(size);
    return p;
}
static char *own_resize(struct mr_mirror *m, size_t size) {
    char *p;
    if (!m->own_mapped && !mr_big(size)) p = realloc(m->own, size);
    else {
        int mapped;
        p = own_alloc(size, &mapped);
        if (!p) return NULL;
        memcpy(p, m->own, (size_t)m->own_size < size ? (size_t)m->own_size : size);
        mr_big_free(m->own, (size_t)m->own_size, m->own_mapped);
        m->own_mapped = mapped;
    }
    if (p) { m->own = p; m->own_size = (long)size; }
    return p;
}
/* What C did to the struct's buffer since the mirror last looked. */
static void str_adopt(struct mr_mirror *m) {
    if (str_embedded(m)) {
        /* (C moved the bytes back into the struct) */
        if (m->own) own_free(m);
        return;
    }
    char *p = m->as.string.as.heap.ptr;
    if (p == m->own) return;
    /* (a pointer into its own buffer -- a substring C made by moving it -- keeps the buffer) */
    if (m->own && p > m->own && p < m->own + m->own_size) return;
    own_free(m);
    /* (C's own buffer, from malloc) */
    m->own = p;
    m->own_size = p ? m->as.string.as.heap.aux.capa + 1 : 0;
    m->own_mapped = 0;
}
static long str_capacity(struct mr_mirror *m, int term) {
    return str_embedded(m) ? embed_room(m) - term : (m->as.string.as.heap.ptr ? m->as.string.as.heap.aux.capa : 0);
}
/* Room for `need` bytes and the terminator. ROOM_EXACT makes it exactly that
 * (rb_str_modify_expand, rb_str_buf_new, String.new(capacity:), a read into
 * a buffer); ROOM_GROW doubles as str_buf_cat does, 2 * capa + termlen;
 * ROOM_HEAP is ROOM_EXACT in a buffer even when the slot would hold it
 * (rb_str_init with a capacity: "make noembed always"). New room is not
 * cleared -- as in CRuby, what is past the length is C's to write -- only the
 * terminator's place at the end of it. */
static void string_room(struct mr_mirror *m, long need, int term, int mode) {
    if (need < 0) need = 0;
    long capa = str_capacity(m, term);
    if (str_embedded(m) ? (mode != ROOM_HEAP && need + term <= embed_room(m))
                        : (m->as.string.as.heap.ptr && need <= capa)) return;
    long want = need;
    if (mode == ROOM_GROW && need < LONG_MAX / 2) {
        want = capa > 0 ? capa : 0;
        while (want < need) want = 2 * want + term;
    }
    if (want > LONG_MAX - 8) rb_raise(rb_eArgError, "string size too big");
    /* (four more bytes: the terminator of the widest encoding) */
    size_t size = (size_t)want + 4;
    long len = m->body == T_STRING ? m->as.string.len : 0;
    char *p;
    if (str_embedded(m)) {
        int mapped;
        p = own_alloc(size, &mapped);
        if (!p) rb_memerror();
        memcpy(p, embed_ary(m), (size_t)embed_room(m) < size ? (size_t)embed_room(m) : size);
        m->as.basic.flags |= RSTRING_NOEMBED;
        m->own = p;
        m->own_size = (long)size;
        m->own_mapped = mapped;
    }
    else if (m->own && m->as.string.as.heap.ptr == m->own) {
        p = own_resize(m, size);
        if (!p) rb_memerror();
    }
    else {
        /* (the bytes start inside the buffer: they move to the front of a new one) */
        int mapped;
        p = own_alloc(size, &mapped);
        if (!p) rb_memerror();
        if (m->as.string.as.heap.ptr && len > 0) memcpy(p, m->as.string.as.heap.ptr, (size_t)(len < want ? len : want));
        own_free(m);
        m->own = p;
        m->own_size = (long)size;
        m->own_mapped = mapped;
    }
    memset(p + want, 0, 4);
    m->as.string.as.heap.ptr = p;
    m->as.string.as.heap.aux.capa = want;
}

/* string.c's rb_str_resize on the buffer, the length being `len`: back into
 * the slot when it fits there again, cut down to the length when longer than
 * it by more than the length (or 1 KB). Answers whether it changed anything
 * the length needs to be written for. */
static int str_resize(struct mr_mirror *m, long len, int term) {
    long slen = m->as.string.len;
    if (str_embedded(m)) {
        if (len == slen) return 0;
        string_room(m, len, term, ROOM_EXACT);
    }
    else if (len + term <= embed_room(m)) {
        char *p = m->as.string.as.heap.ptr;
        long keep = slen < len ? slen : len;
        char *ary = embed_ary(m);
        if (keep > 0 && p) memmove(ary, p, (size_t)keep);
        own_free(m);
        m->as.basic.flags &= ~(VALUE)RSTRING_NOEMBED;
    }
    else {
        long capa = m->as.string.as.heap.aux.capa;
        if (capa < len || capa - len > (len < 1024 ? len : 1024)) {
            if (m->as.string.as.heap.ptr == m->own) {
                char *p = own_resize(m, (size_t)len + 4);
                if (!p) rb_memerror();
                m->as.string.as.heap.ptr = p;
                m->as.string.as.heap.aux.capa = len;
            }
            else string_room(m, len, term, ROOM_EXACT);
        }
        else if (len == slen) return 0;
    }
    return 1;
}

/* (inlined where it is used: write_back runs it for every touched struct at
 *  every crossing, and a call there, with the length tested again inside,
 *  cost about five instructions each time -- hold_locals(20000), PR #284's
 *  review) */
static inline __attribute__((always_inline)) uint64_t body_hash(struct mr_mirror *m) {
    if (m->body == T_STRING)
        return hash_bytes(str_ptr(m), (size_t)m->as.string.len, 1);
    return hash_bytes(m->as.array.as.heap.ptr, sizeof(VALUE) * (size_t)m->as.array.as.heap.len, 2);
}

/* (a dmark the collector runs between C calls has nobody to ask: it reads
 *  the struct as last fetched -- sqlite3's database_mark walks its arrays
 *  with RARRAY_LEN after rb_gc_mark on them, at the first GC.start. What the
 *  marked object holds the interpreter marks itself.) */
static int marking;
int mr_capi_mark_unasked(void) { return marking && !mr_capi_calling(); }
/* (a collection is marking: a dmark is running, inside a C call or not) */
int mr_capi_marking(void) { return marking; }
static struct mr_mirror *refresh_head(struct mr_mirror *m, VALUE obj) {
    if (m->head_epoch == mr_epoch) return m;
    VALUE packed = mr_up1(MR_DESCRIBE, obj);
    VALUE flags = m->as.basic.flags;
    /* The type, frozen and the encoding are the interpreter's to say; the
     * user flags are C's own and stay as C left them. */
    VALUE keep = flags & (((VALUE)0x3ff << RUBY_FL_USHIFT) | RUBY_FL_USERPRIV0);
    int type = (int)(packed & 0x1f);
    if (m->data) type = T_DATA;
    flags = keep | (VALUE)type;
    if (packed & 0x20) flags |= RUBY_FL_FREEZE;
    /* (the encoding index in the 7 bits CRuby keeps it in: one that does not
     *  fit -- a dummy encoding defined from C, 127 and on -- is
     *  ENCODING_INLINE_MAX there, and rb_enc_get_index asks for the rest) */
    long enc_index = (long)((packed >> 8) & 0xffff);
    flags |= (VALUE)(enc_index < RUBY_ENCODING_INLINE_MAX ? enc_index : RUBY_ENCODING_INLINE_MAX) << RUBY_ENCODING_SHIFT;
    if (type == T_STRING) {
        /* (RSTRING_NOEMBED is settled below, from the length) */
        /* (the coderange is the interpreter's to say, as far as it knows:
         *  7BIT when the bytes are ASCII alone in an ASCII-compatible
         *  encoding, else unknown -- what C cached may be stale) */
        flags &= ~(VALUE)RUBY_ENC_CODERANGE_MASK;
        if (packed & 0x1000000) {
            rb_encoding *e = rb_enc_from_index((int)((packed >> 8) & 0xffff));
            if (e && rb_enc_asciicompat(e)) flags |= RUBY_ENC_CODERANGE_7BIT;
        }
    }
    if (type == T_ARRAY) flags &= ~(VALUE)RARRAY_EMBED_FLAG;
    if ((type == T_CLASS || type == T_MODULE) && (packed & 0x40)) flags |= RUBY_FL_SINGLETON;
    m->as.basic.flags = flags;
    *(VALUE *)&m->as.basic.klass = m->hidden ? 0 : mr_word(0);
    m->head_epoch = mr_epoch;
    if (type == T_STRING) {
        /* Where the bytes are is in the flags, which C reads before it asks
         * for the bytes (RSTRING_PTR tests RSTRING_NOEMBED first), so it is
         * settled here, from the length the interpreter has now: a String
         * whose bytes the struct does not hold yet is in it when they fit,
         * and one in the struct leaves it when they no longer do. A String
         * String#freeze froze has no use for room: rb_str_freeze resizes it
         * to its length (string.c), which is what it is given here. One C
         * froze with OBJ_FREEZE / rb_obj_freeze keeps its buffer, as in
         * CRuby: C may still hold RSTRING_PTR. */
        long len = (long)(packed >> 32);
        int term = term_of_index((int)((packed >> 8) & 0xffff));
        if (!m->slot) m = str_take_slot(MR_NUMBER(obj), m, slot_for(len > m->reserve ? len : m->reserve, term, m->heap_only));
        int frozen = (packed & 0x20) != 0 && !m->frozen_by_c;
        if (frozen) { m->reserve = 0; m->heap_only = 0; }
        long need = len > m->reserve ? len : m->reserve;
        if (m->body != T_STRING) {
            if (!m->heap_only && need + term <= embed_room(m)) m->as.basic.flags &= ~(VALUE)RSTRING_NOEMBED;
            else m->as.basic.flags |= RSTRING_NOEMBED;
        }
        else {
            str_adopt(m);
            string_room(m, need, term, m->heap_only ? ROOM_HEAP : ROOM_EXACT);
            if (frozen && !str_embedded(m) && m->as.string.as.heap.ptr == m->own) str_resize(m, m->as.string.len, term);
            m->reserve = 0;
            m->heap_only = 0;
        }
    }
    return m;
}
/* ObjectSpace.memsize_of: a typed data object's own count of what it holds
 * (its type's dsize), by handle number -- run inside a C call (MR_RUN_DSIZE).
 * A NULL data pointer holds nothing, as gc.c's rb_objspace_data_type_memsize
 * guards: a wrapper of NULL, or one an extension emptied when it closed. */
long mr_capi_dsize(long number) {
    struct mr_mirror *m = mirror_at(number, 0);
    if (!m || m->data != 2) return 0;
    const rb_data_type_t *type = (const rb_data_type_t *)(m->as.typed.type & TYPED_DATA_PTR_MASK);
    if (!type || !type->function.dsize) return 0;
    void *data = m->embedded ? (void *)&m->as.typed.data : m->as.typed.data;
    if (!data) return 0;
    size_t n = type->function.dsize(data);
    return n > (size_t)LONG_MAX ? LONG_MAX : (long)n;
}
/* rb_obj_hide / rb_obj_reveal: to C, a hidden object has no class (CRuby
 * clears RBasic.klass; the interpreter's object keeps its own). */
void mr_mirror_hide(VALUE obj, int hidden) {
    if (!MR_HANDLE_P(obj)) return;
    struct mr_mirror *m = mirror_at(MR_NUMBER(obj), 1);
    m->hidden = hidden;
    m->head_epoch = 0;
}

struct mr_mirror *mr_mirror_of(VALUE obj) {
    if (!MR_HANDLE_P(obj)) {
        char message[128];
        snprintf(message, sizeof(message), "the VALUE 0x%lx is not an object (nil, an Integer or a Symbol read as one?)", (unsigned long)obj);
        mr_fatal(message);
    }
    return refresh_head(mirror_at(MR_NUMBER(obj), 1), obj);
}
/* (...or a raw Bignum bignum.c made, which is its own struct:
 *  capi/bignum_cruby.c) */
extern int mr_vbig_raw_p(VALUE v);
void *rb_mere_basic(VALUE obj) {
    if (!MR_HANDLE_P(obj) && !RB_SPECIAL_CONST_P(obj) && mr_vbig_raw_p(obj)) return (void *)obj;
    return &mr_mirror_of(obj)->as.basic;
}

/* (every C call that may hold a pointer into the struct watches it: two
 *  Fibers stopped in C calls that took the same String's bytes each write
 *  through their own pointer when resumed, and the watch lasts until the
 *  last of them has ended) */
static void touch(struct mr_mirror *m, VALUE obj) {
    /* (a dmark's read between C calls has no call to watch it for) */
    if (mr_capi_mark_unasked()) return;
    const void *frame = mr_capi_frame();
    if (m->listed)
        for (long i = touched_count - 1; i >= 0; i--)
            if (touched[i].mirror == m && touched[i].owner == frame) return;
    if (touched_count == touched_cap) {
        touched_cap = touched_cap ? touched_cap * 2 : 64;
        touched = realloc(touched, sizeof(*touched) * (size_t)touched_cap);
        if (!touched) mr_fatal("out of memory");
    }
    touched[touched_count].mirror = m;
    touched[touched_count].handle = obj;
    touched[touched_count].owner = frame;
    touched_count++;
    m->listed++;
}

/* Write one struct back when C changed it. Answers whether it did. */
static int write_back(struct mr_mirror *m, VALUE obj) {
    if (!m->body) return 0;
    uint64_t now = body_hash(m);
    if (now == m->hash) return 0;
    struct mr_transit saved;
    mr_transit_save(&saved, -1);
    m->hash = now;
    if (m->body == T_STRING) {
        str_adopt(m);
        if (m->as.string.len < 0 || m->as.string.len > str_capacity(m, str_term(m)))
            mr_fatal("a String's length was set past its capacity");
        mr_put_bytes(str_ptr(m), m->as.string.len);
        mr_up1(MR_STR_SET, obj);
    }
    else {
        if (m->as.array.as.heap.len < 0 || m->as.array.as.heap.len > m->capa) mr_fatal("an Array's length was set past its capacity");
        mr_put_words(m->as.array.as.heap.len, m->as.array.as.heap.ptr);
        m->version = (long)mr_up2(MR_ARY_SET, obj, (VALUE)m->as.array.as.heap.len);
    }
    mr_transit_restore(&saved);
    return 1;
}

void mr_mirrors_flush(void) {
    for (long i = 0; i < touched_count; i++)
        write_back(touched[i].mirror, touched[i].handle);
}
/* The C call `frame` ends: what it touched is no longer watched. (`outermost`:
 *  it is the last call on its stack, and what C touched outside any call --
 *  from a mark function, say -- goes with it.) */
void mr_mirrors_leave(const void *frame, int outermost) {
    long kept = 0;
    for (long i = 0; i < touched_count; i++) {
        if (touched[i].owner == frame || (outermost && !touched[i].owner)) touched[i].mirror->listed--;
        else touched[kept++] = touched[i];
    }
    touched_count = kept;
}
void mr_mirror_forget(VALUE obj) {
    if (!MR_HANDLE_P(obj)) return;
    struct mr_mirror *m = mirror_at(MR_NUMBER(obj), 0);
    if (!m) return;
    m->head_epoch = 0;
    m->body_epoch = 0;
}
/* OBJ_FREEZE / rb_obj_freeze is about to freeze this String: it keeps its
 * buffer (only rb_str_freeze, String#freeze, resizes -- string.c) */
void mr_mirror_frozen_by_c(VALUE obj) {
    if (!MR_HANDLE_P(obj)) return;
    struct mr_mirror *m = mirror_at(MR_NUMBER(obj), 0);
    if (m) m->frozen_by_c = 1;
}

/* A String's bytes, from the interpreter, into its struct. The buffer is
 * the String as far as C can tell, also past its length: what C wrote
 * there (to reveal with rb_str_set_len later) stays, and so does everything
 * when the interpreter has the very bytes the buffer holds. Only a String
 * that changed is copied in, and ends in its encoding's terminator. A new
 * buffer is as long as the String, or as the room the interpreter asked
 * for (String.new(capacity:)). The bytes are compared, copied and hashed
 * in one pass (copy_hash). */
static void str_take(struct mr_give_to *to, const char *bytes, long len) {
    struct mr_mirror *m = mirror_at(to->number, 1);
    int term = str_term(m);
    if (m->body != T_STRING && !str_embedded(m)) {
        m->as.string.as.heap.ptr = NULL;
        m->as.string.as.heap.aux.capa = 0;
    }
    string_room(m, len > m->reserve ? len : m->reserve, term, m->heap_only ? ROOM_HEAP : ROOM_EXACT);
    m->reserve = 0;
    m->heap_only = 0;
    int changed = !(m->body == T_STRING && m->as.string.len == len);
    m->hash = copy_hash((unsigned char *)str_ptr(m), (const unsigned char *)bytes, (size_t)len, 1, &changed);
    if (changed) memset(str_ptr(m) + len, 0, (size_t)term);
    m->as.string.len = len;
    m->body = T_STRING;
}

void *rb_mere_string(VALUE obj) {
    struct mr_mirror *m = mr_mirror_of(obj);
    if ((m->as.basic.flags & 0x1f) != T_STRING) goto wrong;
    if (m->body == T_STRING && m->body_epoch == mr_epoch) return &m->as.string;
    if (m->body == T_STRING) str_adopt(m);
    /* What C wrote through a pointer it kept across a call is not lost to
     * the fetch: it goes back first, and is then what the interpreter has. */
    if (m->body == T_STRING && write_back(m, obj)) {
        m->body_epoch = mr_epoch;
        touch(m, obj);
        return &m->as.string;
    }
    /* (the bytes go into the struct while the request runs: str_take) */
    struct mr_give_to to = { str_take, MR_NUMBER(obj), 0 };
    mr_give_next(&to);
    mr_up1(MR_STR_GET, obj);
    m = mirror_at(MR_NUMBER(obj), 1);
    if (!to.taken) {
        /* (...or they came in transit) */
        const mere_bytes *b = mr_got_bytes();
        str_take(&to, (const char *)b->data, (long)b->len);
    }
    m->body_epoch = mr_epoch;
    touch(m, obj);
    return &m->as.string;
  wrong:
    rb_raise(rb_eTypeError, "wrong argument type %s (expected String)", rb_obj_classname(obj));
}

/* rb_str_new(NULL, len) of a big len: the interpreter makes an empty String,
 * and the zero bytes are made here, in the struct's buffer, where C is about
 * to write them. They reach the interpreter at the next crossing, as any
 * write C makes: the struct is watched, and its hash is not the hash of what
 * the interpreter has. Before, the bytes were zeroed in transit, became a
 * String of zeros in the interpreter, were fetched back into the struct and
 * then written back -- four copies of a String msgpack's recursive packer
 * makes of each level's whole buffer (1.5 GB at the peak of its packer spec
 * on Linux, ruby 0.37 GB). (`enc`: the encoding's index, as make() has it) */
VALUE mr_string_new_zeroed(long len, int enc) {
    mr_put_bytes("", 0);
    mr_put_text(mr_enc_name_of_index(enc));
    VALUE obj = mr_up1(MR_STR_NEW, (VALUE)enc);
    struct mr_mirror *m = mr_mirror_of(obj);
    int term = str_term(m);
    if (m->body != T_STRING && !str_embedded(m)) {
        m->as.string.as.heap.ptr = NULL;
        m->as.string.as.heap.aux.capa = 0;
    }
    string_room(m, len, term, ROOM_EXACT);
    memset(str_ptr(m), 0, (size_t)len + (size_t)term);
    m->as.string.len = len;
    m->body = T_STRING;
    m->hash = body_hash(m) ^ 1;
    m->body_epoch = mr_epoch;
    touch(m, obj);
    return obj;
}

static void array_room(struct mr_mirror *m, long capa) {
    if (m->as.array.as.heap.ptr && capa <= m->capa) return;
    long want = m->capa > 0 ? m->capa : 4;
    while (want < capa) want *= 2;
    VALUE *p = realloc((void *)m->as.array.as.heap.ptr, sizeof(VALUE) * (size_t)want);
    if (!p) rb_memerror();
    for (long i = m->capa; i < want; i++) p[i] = Qnil;
    m->as.array.as.heap.ptr = p;
    m->as.array.as.heap.aux.capa = want;
    m->capa = want;
}

void *rb_mere_array(VALUE obj) {
    struct mr_mirror *m = mr_mirror_of(obj);
    if ((m->as.basic.flags & 0x1f) != T_ARRAY)
        rb_raise(rb_eTypeError, "wrong argument type %s (expected Array)", rb_obj_classname(obj));
    if (m->body == T_ARRAY && m->body_epoch == mr_epoch) return &m->as.array;
    if (m->body == T_ARRAY && write_back(m, obj)) {
        m->body_epoch = mr_epoch;
        touch(m, obj);
        return &m->as.array;
    }
    long len = (long)mr_up2(MR_ARY_GET, obj, m->body == T_ARRAY ? (VALUE)(m->version + 1) : 0);
    if (len >= 0) {
        array_room(m, len);
        VALUE *p = (VALUE *)m->as.array.as.heap.ptr;
        for (long i = 0; i < len; i++) p[i] = mr_word(i);
        m->as.array.as.heap.len = len;
        m->version = (long)mr_word(len);
        m->body = T_ARRAY;
        m->hash = body_hash(m);
    }
    m->body_epoch = mr_epoch;
    touch(m, obj);
    return &m->as.array;
}

/* RFILE(io)->fptr: what an IO is to C. The struct is filled from the IO each
 * time it is asked for -- the descriptor (-1 when closed), how it was opened
 * (the descriptor's own access mode, sync, binmode, tty), the path -- and
 * nothing C writes into it goes back: the functions that take the pointer
 * (rb_io_check_closed, rb_io_set_nonblock, ...) act on the IO it names. Its
 * buffers and converters are CRuby's own and stay empty. */
void *rb_mere_file(VALUE obj) {
    struct mr_mirror *m = mr_mirror_of(obj);
    if (!m->io) {
        m->io = calloc(1, sizeof(struct rb_io));
        if (!m->io) rb_memerror();
    }
    struct rb_io *f = m->io;
    f->self = obj;
    f->pathv = rb_respond_to(obj, rb_intern("path")) ? mr_call(mr_ruby("->(io) { io.path rescue nil }"), "call", 1, obj) : Qnil;
    f->tied_io_for_writing = 0;
    f->timeout = Qnil;
    f->write_lock = Qnil;
    f->writeconv_asciicompat = Qnil;
    f->writeconv_pre_ecopts = Qnil;
    f->encs.ecopts = Qnil;
    int mode = 0;
    if (RTEST(mr_call(obj, "closed?", 0))) f->fd = -1;
    else {
        f->fd = NUM2INT(mr_call(obj, "fileno", 0));
        /* Which directions are this IO's own (bit 1 read, 2 write, 4 append),
         * as the interpreter keeps them: a File's mode string, a descriptor
         * IO's two flags, or the standard stream the descriptor is. Not the
         * descriptor's F_GETFL: an IO.for_fd(fd, "r") on a descriptor opened
         * for both is read-only to ruby. The descriptor still says O_APPEND,
         * which is its own property. */
        int own = NUM2INT(mr_call(mr_ruby(
            "->(io) { m = io.instance_variable_get(:@__f_mode); "
            "r = io.instance_variable_get(:@__io_r); w = io.instance_variable_get(:@__io_w); "
            "if m.is_a?(String) && !m.empty? then a = m.split(':').first.to_s.delete('bt'); "
            "(a.match?(/[r+]/) ? 1 : 0) | (a.match?(/[wa+]/) ? 2 : 0) | (a.include?('a') ? 4 : 0) "
            "elsif !r.nil? || !w.nil? then (r ? 1 : 0) | (w ? 2 : 0) "
            "else case io.fileno when 0 then 1 when 1, 2 then 2 else -1 end end }"), "call", 1, obj));
        int flags = fcntl(f->fd, F_GETFL);
        if (own < 0 && flags != -1) {
            int access = flags & O_ACCMODE;
            own = (access == O_RDONLY || access == O_RDWR ? 1 : 0) | (access == O_WRONLY || access == O_RDWR ? 2 : 0);
        }
        if (own > 0) {
            if (own & 1) mode |= FMODE_READABLE;
            if (own & 2) mode |= FMODE_WRITABLE;
            if (own & 4) mode |= FMODE_APPEND;
        }
        if (flags != -1 && (flags & O_APPEND)) mode |= FMODE_APPEND;
        if (RTEST(mr_call(obj, "sync", 0))) mode |= FMODE_SYNC;
        if (RTEST(mr_call(obj, "binmode?", 0))) mode |= FMODE_BINMODE;
        if (isatty(f->fd)) mode |= FMODE_TTY;
    }
    f->mode = mode;
    m->as.file.fptr = f;
    return &m->as.file;
}
void *rb_mere_match(VALUE obj) { (void)obj; mr_unsupported("RMATCH (the struct behind a MatchData)"); }
void *rb_mere_regexp(VALUE obj) { (void)obj; mr_unsupported("RREGEXP (the struct behind a Regexp)"); }

/* ---- capacity, for the String functions that promise room ------------------ */
/* How many NUL bytes end a String of this one's encoding: 1, or the width of
 * a UTF-16 / UTF-32 code unit. */
int mr_string_terminator(VALUE str) {
    extern int mr_encoding_unit(VALUE str);
    int n = mr_encoding_unit(str);
    return n > 1 && n <= 4 ? n : 1;
}
static struct mr_mirror *string_body(VALUE str) {
    rb_mere_string(str);
    struct mr_mirror *m = mirror_at(MR_NUMBER(str), 1);
    str_adopt(m);
    return m;
}
/* rb_str_capacity: what the buffer holds before the terminator -- the
 * struct's own room when the bytes are in it. */
long mr_string_capacity(VALUE str) {
    struct mr_mirror *m = string_body(str);
    return str_capacity(m, str_term(m));
}
/* string.c's RESIZE_CAPA_TERM (rb_str_modify_expand, rb_str_buf_new): a
 * buffer of exactly `capa` bytes -- also a shorter one than there was -- and
 * the struct's own room while they fit in it. */
void mr_string_reserve(VALUE str, long capa) {
    struct mr_mirror *m = string_body(str);
    int term = str_term(m);
    if (!str_embedded(m) && m->own && m->as.string.as.heap.ptr == m->own
        && capa >= m->as.string.len && capa != m->as.string.as.heap.aux.capa) {
        char *p = own_resize(m, (size_t)capa + 4);
        if (!p) rb_memerror();
        memset(p + capa, 0, 4);
        m->as.string.as.heap.ptr = p;
        m->as.string.as.heap.aux.capa = capa;
        return;
    }
    string_room(m, capa, term, ROOM_EXACT);
}
/* Room for `total` bytes, grown as str_buf_cat grows it (rb_str_cat). */
void mr_string_grow(VALUE str, long total) {
    struct mr_mirror *m = string_body(str);
    string_room(m, total, str_term(m), ROOM_GROW);
}
/* rb_str_resize: the length, and the buffer string.c would leave -- the
 * bytes back in the struct when they fit there again, the buffer cut down
 * to the length when it is longer than the length by more than the length
 * (or 1 KB). */
void mr_string_resize(VALUE str, long len) {
    struct mr_mirror *m = string_body(str);
    int term = str_term(m);
    if (!str_resize(m, len, term)) return;
    m->as.string.len = len;
    memset(str_ptr(m) + len, 0, (size_t)term);
}

/* From the interpreter: the String whose handle has this number is to have
 * room for `capa` bytes -- String.new(capacity:), a read into a buffer
 * (io.c's io_setstrbuf). The buffer is made exactly that long the next time
 * C looks at the String, when its length is known; the interpreter's own
 * String has no buffer to make longer. */
int mr_capi_reserve(int number, CapiWord capa, int heap) {
    struct mr_mirror *m = mirror_at(number, 1);
    long n = (long)capa.mu_w;
    if (n > m->reserve) m->reserve = n;
    if (heap) m->heap_only = 1;
    m->head_epoch = 0;
    return 0;
}

/* GC::INTERNAL_CONSTANTS, as CRuby's collectors report their own: the
 * smallest slot (BASE_SLOT_SIZE), the header every object starts with
 * (RBASIC_SIZE), the largest slot (RVARGC_MAX_ALLOCATE_SIZE) and how many
 * sizes there are (SIZE_POOL_COUNT, the name MMTk's build gives it). */
int mr_capi_layout(int what) {
    switch (what) {
      case 0: return (int)slot_sizes[0];
      case 1: return (int)sizeof(struct RBasic);
      case 2: return (int)slot_sizes[SLOT_COUNT - 1];
      case 3: return SLOT_COUNT;
      default: return 0;
    }
}
/* ObjectSpace.dump and memsize_of of a String (`number` its handle's, or -1):
 * 0 its slot, 1 whether its bytes are in it, 2 the bytes of its buffer with
 * the terminator (0 when in the slot). A String C has seen answers from its
 * struct, with the length the interpreter has now; one C has not seen has no
 * struct and answers 0 (no slot). */
CapiWord mr_capi_str_layout(int number, int what, CapiWord bytesize, int enc_index) {
    long len = (long)bytesize.mu_w;
    int term = term_of_index(enc_index);
    struct mr_mirror *m = number >= 0 ? mirror_at(number, 0) : NULL;
    long slot, room, buffer;
    int in_slot;
    if (m && m->slot) {
        slot = m->slot;
        room = embed_room(m);
        long want = len > m->reserve ? len : m->reserve;
        if (m->body == T_STRING) {
            in_slot = str_embedded(m) && len + term <= room;
            long capa = str_embedded(m) ? 0 : m->as.string.as.heap.aux.capa;
            buffer = in_slot ? 0 : (capa > want ? capa : want) + term;
        }
        else {
            in_slot = !m->heap_only && want + term <= room;
            buffer = in_slot ? 0 : want + term;
        }
    }
    else {
        /* (C has not seen it: there is no struct and no slot, and none is
         *  predicted -- 0, and ObjectSpace says nothing of a slot) */
        CapiWord none = { 0 };
        return none;
    }
    CapiWord w = { what == 0 ? slot : what == 1 ? in_slot : buffer };
    return w;
}

/* ---- data objects ---------------------------------------------------------- */
void mr_mirror_data(VALUE obj, int typed, const rb_data_type_t *type, void *data,
                    RUBY_DATA_FUNC dmark, RUBY_DATA_FUNC dfree, size_t embedded) {
    struct mr_mirror *m = mirror_at(MR_NUMBER(obj), 1);
    if (embedded) {
        /* The struct follows the header in one block, as CRuby embeds it. */
        struct mr_mirror *bigger = realloc(m, sizeof(*m) + embedded);
        if (!bigger) mr_fatal("out of memory");
        memset((char *)bigger + sizeof(*m), 0, embedded);
        table[MR_NUMBER(obj)] = m = bigger;
        m->embedded = embedded;
    }
    m->data = typed ? 2 : 1;
    m->head_epoch = 0;
    if (typed) {
        m->as.basic.flags |= RUBY_TYPED_FL_IS_TYPED_DATA;
        m->as.typed.fields_obj = 0;
        *(VALUE *)&m->as.typed.type = (VALUE)type | (embedded ? TYPED_DATA_EMBEDDED : 0);
        m->as.typed.data = embedded ? NULL : data;
    }
    else {
        m->as.data.dmark = dmark;
        m->as.data.dfree = dfree;
        m->as.data.data = data;
    }
}

/* ---- the collector --------------------------------------------------------- */
static closure_int_int marker;
void mr_mark_value(VALUE v) {
    if (marking && MR_HANDLE_P(v)) marker.fn(marker.env, (long long)v);
}
/* What a live data object keeps alive: its dmark says. */
/* What a handle is to C as a data object (ObjectSpace.dump's "struct"):
 * "\001" none, "" an RData, the typed data's wrap_struct_name. */
char *mr_capi_data_name(int number) {
    struct mr_mirror *m = mirror_at(number, 0);
    if (!m || !m->data) return "\001";
    if (m->data != 2) return "";
    const rb_data_type_t *type = (const rb_data_type_t *)(m->as.typed.type & TYPED_DATA_PTR_MASK);
    return (char *)(type && type->wrap_struct_name ? type->wrap_struct_name : "");
}
int mr_capi_mark(closure_int_int visit, int number) {
    struct mr_mirror *m = mirror_at(number, 0);
    if (!m) return 0;
    if (m->data && mr_without("dmark")) return 0;
    /* (a dmark run between C calls reads what is current: the interpreter
     *  has run since the last call ended, and nothing said so -- every
     *  struct it reads is asked again, of the collector's reader, mr_up) */
    if (!mr_capi_calling()) mr_epoch++;
    closure_int_int before = marker;
    int was = marking;
    marker = visit;
    marking = 1;
    if (m->data == 2) {
        const rb_data_type_t *type = (const rb_data_type_t *)(m->as.typed.type & TYPED_DATA_PTR_MASK);
        void *data = m->embedded ? (void *)&m->as.typed.data : m->as.typed.data;
        if (type && type->function.dmark && data) {
            if (type->flags & RUBY_TYPED_DECL_MARKING) {
                /* dmark is a list of offsets of VALUE members, ended by RUBY_REF_END. */
                const size_t *offsets = (const size_t *)(void *)type->function.dmark;
                for (; *offsets != RUBY_REF_END; offsets++)
                    mr_mark_value(*(VALUE *)((char *)data + *offsets));
            }
            else type->function.dmark(data);
        }
    }
    else if (m->data == 1) {
        if (m->as.data.dmark && m->as.data.data) m->as.data.dmark(m->as.data.data);
    }
    /* An Array's fetched elements are VALUEs C may be holding by address. */
    if (m->body == T_ARRAY)
        for (long i = 0; i < m->as.array.as.heap.len; i++) mr_mark_value(m->as.array.as.heap.ptr[i]);
    marker = before;
    marking = was;
    return 0;
}
/* The handle is gone: its struct goes, and a data object's dfree runs. */
int mr_capi_release(int number) {
    struct mr_mirror *m = mirror_at(number, 0);
    if (!m) return 0;
    table[number] = NULL;
    if (m->listed) {
        for (long i = 0; i < touched_count; i++)
            if (touched[i].mirror == m) {
                memmove(touched + i, touched + i + 1, sizeof(*touched) * (size_t)(touched_count - i - 1));
                touched_count--;
                i--;
            }
    }
    free(m->io);
    if (m->body == T_STRING) { str_adopt(m); own_free(m); }
    if (m->body == T_ARRAY) free((void *)m->as.array.as.heap.ptr);
    int ran = 0;
    if (m->data && mr_without("dfree")) { free(m); return 0; }
    if (m->data == 2) {
        /* Read everything first: a dfree may free the type it came from. */
        const rb_data_type_t *type = (const rb_data_type_t *)(m->as.typed.type & TYPED_DATA_PTR_MASK);
        RUBY_DATA_FUNC dfree = type ? type->function.dfree : NULL;
        void *data = m->embedded ? (void *)&m->as.typed.data : m->as.typed.data;
        if (m->embedded) {
            /* The struct is part of this block: its dfree releases what it
             * points to, never the struct itself. */
            if (dfree && dfree != RUBY_DEFAULT_FREE) { dfree(data); ran = 1; }
        }
        else if (data) {
            if (dfree == RUBY_DEFAULT_FREE) { ruby_xfree(data); ran = 1; }
            else if (dfree) { dfree(data); ran = 1; }
        }
    }
    else if (m->data == 1 && m->as.data.data) {
        RUBY_DATA_FUNC dfree = m->as.data.dfree;
        void *data = m->as.data.data;
        if (dfree == RUBY_DEFAULT_FREE) { ruby_xfree(data); ran = 1; }
        else if (dfree) { dfree(data); ran = 1; }
    }
    free(m);
    return ran;
}
