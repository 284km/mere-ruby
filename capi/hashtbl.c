/* RHASH_TBL: a Hash as the st_table C asks for (CRuby's Hash is one).
 *
 * The interpreter's Hash is no st_table, so C gets one of its own, filled
 * from the Hash -- the same keys and values (the same objects), in the
 * Hash's order, compared the Hash's way (#hash and #eql?, or identity for a
 * compare_by_identity Hash). C may read it and change it with st.c's
 * functions (st_update, st_insert, st_delete, st_foreach ...).
 *
 * What C changed goes back to the Hash when the C call that asked for the
 * table ends (mr_hash_tables_leave, from core.c): the Hash then has the
 * table's pairs, in the table's order. Asked again in the same call, the
 * same table is answered. Ruby code C runs in between (a block C yields to)
 * sees the Hash as it was when the table was made: the write-back is at the
 * end of the call, not at each step. */
#include "mr_capi.h"
#include "ruby/st.h"
#include <stdlib.h>
#include <string.h>

extern const void *mr_capi_frame(void);

static int view_cmp(st_data_t a, st_data_t b) { return rb_eql((VALUE)a, (VALUE)b) ? 0 : 1; }
static st_index_t view_hash(st_data_t key) {
    VALUE h = rb_hash((VALUE)key);
    if (!FIXNUM_P(h)) h = rb_hash(h);   /* (an Integer's own #hash is a Fixnum) */
    return (st_index_t)FIX2LONG(h);
}
static const struct st_hash_type view_type = { view_cmp, view_hash };

struct view {
    VALUE hash;
    st_table *tbl;
    const void *owner;
    VALUE *before;   /* key, value, key, value ...: the pairs it was made with */
    long count;
};
static struct view *views;
static long view_count, view_cap;

struct fill { st_table *tbl; VALUE *pairs; long n; };
static int fill_i(VALUE key, VALUE value, VALUE arg) {
    struct fill *f = (struct fill *)arg;
    st_insert(f->tbl, (st_data_t)key, (st_data_t)value);
    f->pairs[f->n * 2] = key;
    f->pairs[f->n * 2 + 1] = value;
    f->n++;
    return ST_CONTINUE;
}

st_table *rb_hash_tbl(VALUE hash, const char *file, int line) {
    (void)file; (void)line;
    Check_Type(hash, T_HASH);
    const void *frame = mr_capi_frame();
    for (long i = 0; i < view_count; i++)
        if (views[i].hash == hash) return views[i].tbl;
    int identity = RTEST(mr_call(hash, "compare_by_identity?", 0));
    st_table *tbl = identity ? st_init_numtable() : st_init_table(&view_type);
    long size = RHASH_SIZE(hash);
    struct fill f = { tbl, malloc(sizeof(VALUE) * (size_t)(size * 2 + 2)), 0 };
    if (!f.pairs) rb_memerror();
    rb_hash_foreach(hash, fill_i, (VALUE)&f);
    if (view_count == view_cap) {
        view_cap = view_cap ? view_cap * 2 : 8;
        views = realloc(views, sizeof(*views) * (size_t)view_cap);
        if (!views) mr_fatal("out of memory");
    }
    views[view_count].hash = hash;
    views[view_count].tbl = tbl;
    views[view_count].owner = frame;
    views[view_count].before = f.pairs;
    views[view_count].count = f.n;
    view_count++;
    return tbl;
}
st_table *rb_hash_tbl_raw(VALUE hash, const char *file, int line) { return rb_hash_tbl(hash, file, line); }

/* (does the table still hold exactly the pairs it was made with, in order?) */
struct same { const VALUE *pairs; long n, at; int same; };
static int same_i(st_data_t key, st_data_t value, st_data_t arg) {
    struct same *s = (struct same *)arg;
    if (s->at >= s->n || s->pairs[s->at * 2] != (VALUE)key || s->pairs[s->at * 2 + 1] != (VALUE)value) {
        s->same = 0;
        return ST_STOP;
    }
    s->at++;
    return ST_CONTINUE;
}
/* (the Hash gets the table's pairs, and the view remembers them as written) */
struct put { VALUE hash; VALUE *pairs; long n; };
static int put_i(st_data_t key, st_data_t value, st_data_t arg) {
    struct put *p = (struct put *)arg;
    rb_hash_aset(p->hash, (VALUE)key, (VALUE)value);
    p->pairs[p->n * 2] = (VALUE)key;
    p->pairs[p->n * 2 + 1] = (VALUE)value;
    p->n++;
    return ST_CONTINUE;
}
/* The C call `frame` ends: what C changed in the tables it asked for goes
 * back to their Hashes (this can raise -- a Hash frozen since -- so it runs
 * where core.c catches that). The tables themselves go after, in
 * mr_hash_tables_leave. */
void mr_hash_tables_flush(const void *frame) {
    for (long i = 0; i < view_count; i++) {
        struct view *v = &views[i];
        if (v->owner != frame) continue;
        struct same s = { v->before, v->count, 0, 1 };
        st_foreach(v->tbl, same_i, (st_data_t)&s);
        if (s.same && s.at == v->count) continue;
        VALUE *pairs = malloc(sizeof(VALUE) * (size_t)(v->tbl->num_entries * 2 + 2));
        if (!pairs) rb_memerror();
        free(v->before);
        v->before = pairs;
        v->count = 0;
        rb_hash_clear(v->hash);
        struct put p = { v->hash, pairs, 0 };
        st_foreach(v->tbl, put_i, (st_data_t)&p);
        v->count = p.n;
    }
}
void mr_hash_tables_leave(const void *frame) {
    long kept = 0;
    for (long i = 0; i < view_count; i++) {
        if (views[i].owner == frame) {
            st_free_table(views[i].tbl);
            free(views[i].before);
        }
        else views[kept++] = views[i];
    }
    view_count = kept;
}
