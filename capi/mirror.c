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
    long reserve;               /* room the interpreter asked for (mr_capi_reserve), not yet made */
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

static uint64_t hash_bytes(const void *p, size_t n, uint64_t seed) {
    const unsigned char *s = p;
    uint64_t h = seed ^ (n * 0x9E3779B97F4A7C15ULL);
    while (n >= 8) {
        uint64_t k;
        memcpy(&k, s, 8);
        h = (h ^ k) * 0xFF51AFD7ED558CCDULL;
        h ^= h >> 32;
        s += 8; n -= 8;
    }
    while (n--) h = (h ^ *s++) * 0x100000001B3ULL;
    return h ^ (h >> 29);
}
/* ---- where a String's bytes are -------------------------------------------- */
/* As CRuby keeps them: in the struct itself, after `len` (RSTRING_NOEMBED
 * clear), when they and the terminator fit in its 16 bytes -- what CRuby's
 * smallest slot holds -- and otherwise in a buffer of their own, as.heap.ptr,
 * of as.heap.aux.capa bytes and room for the terminator. A String that has
 * left the struct stays out until rb_str_resize brings it back, as in CRuby.
 * C may put a buffer of its own in as.heap.ptr (ruby's own test extensions
 * do); it is taken over, and freed with the struct. */
#define EMBED_ROOM ((long)(sizeof(struct RString) - offsetof(struct RString, as.embed.ary)))
enum { ROOM_GROW, ROOM_EXACT };
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
/* What C did to the struct's buffer since the mirror last looked. */
static void str_adopt(struct mr_mirror *m) {
    if (str_embedded(m)) {
        /* (C moved the bytes back into the struct) */
        if (m->own) { free(m->own); m->own = NULL; m->own_size = 0; }
        return;
    }
    char *p = m->as.string.as.heap.ptr;
    if (p == m->own) return;
    /* (a pointer into its own buffer -- a substring C made by moving it -- keeps the buffer) */
    if (m->own && p > m->own && p < m->own + m->own_size) return;
    free(m->own);
    m->own = p;
    m->own_size = p ? m->as.string.as.heap.aux.capa + 1 : 0;
}
static long str_capacity(struct mr_mirror *m, int term) {
    return str_embedded(m) ? EMBED_ROOM - term : (m->as.string.as.heap.ptr ? m->as.string.as.heap.aux.capa : 0);
}
/* Room for `need` bytes and the terminator. ROOM_EXACT makes it exactly that
 * (rb_str_modify_expand, rb_str_buf_new, String.new(capacity:), a read into
 * a buffer); ROOM_GROW doubles as str_buf_cat does, 2 * capa + termlen. New
 * room is not cleared -- as in CRuby, what is past the length is C's to
 * write -- only the terminator's place at the end of it. */
static void string_room(struct mr_mirror *m, long need, int term, int mode) {
    if (need < 0) need = 0;
    long capa = str_capacity(m, term);
    if (str_embedded(m) ? need + term <= EMBED_ROOM : (m->as.string.as.heap.ptr && need <= capa)) return;
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
        p = malloc(size);
        if (!p) rb_memerror();
        memcpy(p, embed_ary(m), (size_t)EMBED_ROOM);
        m->as.basic.flags |= RSTRING_NOEMBED;
    }
    else if (m->own && m->as.string.as.heap.ptr == m->own) {
        p = realloc(m->own, size);
        if (!p) rb_memerror();
    }
    else {
        /* (the bytes start inside the buffer: they move to the front of a new one) */
        p = malloc(size);
        if (!p) rb_memerror();
        if (m->as.string.as.heap.ptr && len > 0) memcpy(p, m->as.string.as.heap.ptr, (size_t)(len < want ? len : want));
        free(m->own);
    }
    memset(p + want, 0, 4);
    m->own = p;
    m->own_size = (long)size;
    m->as.string.as.heap.ptr = p;
    m->as.string.as.heap.aux.capa = want;
}

static uint64_t body_hash(struct mr_mirror *m) {
    if (m->body == T_STRING)
        return hash_bytes(str_ptr(m), (size_t)m->as.string.len, 1);
    return hash_bytes(m->as.array.as.heap.ptr, sizeof(VALUE) * (size_t)m->as.array.as.heap.len, 2);
}

static void refresh_head(struct mr_mirror *m, VALUE obj) {
    if (m->head_epoch == mr_epoch) return;
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
         * and one in the struct leaves it when they no longer do. */
        long len = (long)(packed >> 32);
        int term = term_of_index((int)((packed >> 8) & 0xffff));
        long need = len > m->reserve ? len : m->reserve;
        if (m->body != T_STRING) {
            if (need + term <= EMBED_ROOM) m->as.basic.flags &= ~(VALUE)RSTRING_NOEMBED;
            else m->as.basic.flags |= RSTRING_NOEMBED;
        }
        else {
            str_adopt(m);
            string_room(m, need, term, ROOM_EXACT);
            m->reserve = 0;
        }
    }
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
    struct mr_mirror *m = mirror_at(MR_NUMBER(obj), 1);
    refresh_head(m, obj);
    return m;
}
void *rb_mere_basic(VALUE obj) { return &mr_mirror_of(obj)->as.basic; }

/* (every C call that may hold a pointer into the struct watches it: two
 *  Fibers stopped in C calls that took the same String's bytes each write
 *  through their own pointer when resumed, and the watch lasts until the
 *  last of them has ended) */
static void touch(struct mr_mirror *m, VALUE obj) {
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
    mr_up1(MR_STR_GET, obj);
    const mere_bytes *b = mr_got_bytes();
    long len = (long)b->len;
    int term = str_term(m);
    /* The buffer is the String as far as C can tell, also past its length:
     * what C wrote there (to reveal with rb_str_set_len later) stays, and
     * so does everything when the interpreter has the very bytes the
     * buffer holds. Only a String that changed is copied in, and ends in
     * its encoding's terminator. A new buffer is as long as the String, or
     * as the room the interpreter asked for (String.new(capacity:)). */
    if (m->body != T_STRING && !str_embedded(m)) {
        m->as.string.as.heap.ptr = NULL;
        m->as.string.as.heap.aux.capa = 0;
    }
    string_room(m, len > m->reserve ? len : m->reserve, term, ROOM_EXACT);
    m->reserve = 0;
    if (!(m->body == T_STRING && m->as.string.len == len && !memcmp(str_ptr(m), b->data, (size_t)len))) {
        memcpy(str_ptr(m), b->data, (size_t)len);
        memset(str_ptr(m) + len, 0, (size_t)term);
    }
    m->as.string.len = len;
    m->body = T_STRING;
    m->hash = body_hash(m);
    m->body_epoch = mr_epoch;
    touch(m, obj);
    return &m->as.string;
  wrong:
    rb_raise(rb_eTypeError, "wrong argument type %s (expected String)", rb_obj_classname(obj));
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
        char *p = realloc(m->own, (size_t)capa + 4);
        if (!p) rb_memerror();
        memset(p + capa, 0, 4);
        m->own = p;
        m->own_size = capa + 4;
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
    long slen = m->as.string.len;
    if (str_embedded(m)) {
        if (len == slen) return;
        string_room(m, len, term, ROOM_EXACT);
    }
    else if (len + term <= EMBED_ROOM) {
        char *p = m->as.string.as.heap.ptr;
        long keep = slen < len ? slen : len;
        char *ary = embed_ary(m);
        if (keep > 0 && p) memmove(ary, p, (size_t)keep);
        free(m->own);
        m->own = NULL;
        m->own_size = 0;
        m->as.basic.flags &= ~(VALUE)RSTRING_NOEMBED;
    }
    else {
        long capa = m->as.string.as.heap.aux.capa;
        if (capa < len || capa - len > (len < 1024 ? len : 1024)) {
            if (m->as.string.as.heap.ptr == m->own) {
                char *p = realloc(m->own, (size_t)len + 4);
                if (!p) rb_memerror();
                m->own = p;
                m->own_size = len + 4;
                m->as.string.as.heap.ptr = p;
                m->as.string.as.heap.aux.capa = len;
            }
            else string_room(m, len, term, ROOM_EXACT);
        }
        else if (len == slen) return;
    }
    m->as.string.len = len;
    memset(str_ptr(m) + len, 0, (size_t)term);
}

/* From the interpreter: the String whose handle has this number is to have
 * room for `capa` bytes -- String.new(capacity:), a read into a buffer
 * (io.c's io_setstrbuf). The buffer is made exactly that long the next time
 * C looks at the String, when its length is known; the interpreter's own
 * String has no buffer to make longer. */
int mr_capi_reserve(int number, CapiWord capa) {
    struct mr_mirror *m = mirror_at(number, 1);
    long n = (long)capa.mu_w;
    if (n > m->reserve) m->reserve = n;
    m->head_epoch = 0;
    return 0;
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
static int marking;
void mr_mark_value(VALUE v) {
    if (marking && MR_HANDLE_P(v)) marker.fn(marker.env, (long long)v);
}
/* What a live data object keeps alive: its dmark says. */
int mr_capi_mark(closure_int_int visit, int number) {
    struct mr_mirror *m = mirror_at(number, 0);
    if (!m) return 0;
    if (m->data && mr_without("dmark")) return 0;
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
    if (m->body == T_STRING) { str_adopt(m); free(m->own); }
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
