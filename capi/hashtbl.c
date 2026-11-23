/* RHASH_TBL: a Hash as the st_table C asks for (CRuby's Hash is one).
 *
 * The interpreter's Hash is no st_table, so C gets one of its own, filled
 * from the Hash -- the same keys and values (the same objects), in the
 * Hash's order, compared the Hash's way (#hash and #eql?, or identity for a
 * compare_by_identity Hash). C may read it and change it with st.c's
 * functions (st_update, st_insert, st_delete, st_foreach ...).
 *
 * The two are kept in step at every request C makes of the interpreter
 * (core.c's mr_up): what C changed in the table goes to the Hash before it
 * (sync_out), and what the interpreter changed in the Hash -- rb_hash_aset,
 * a block C yielded to -- comes back into the table after it (sync_in). So
 * Ruby code never sees a stale Hash, and C never a stale table. At the end of
 * the C call that asked for it, the last changes go back and the table goes.
 * Asked again in the same call, the same table is answered.
 *
 * Every key and value in a table is a root of the collector while the table
 * lives (mr_hash_tables_root_at): one C put only in the table is not lost to
 * a collection before it reaches the Hash. */
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
/* (compare_by_identity: the same OBJECT, as equal? says -- two handles can
 *  name one Bignum, so the handle's bits are not the identity) */
static int ident_cmp(st_data_t a, st_data_t b) {
    return (VALUE)a == (VALUE)b || RTEST(mr_call((VALUE)a, "equal?", 1, (VALUE)b)) ? 0 : 1;
}
static st_index_t ident_hash(st_data_t key) {
    VALUE id = mr_call((VALUE)key, "object_id", 0);
    if (!FIXNUM_P(id)) id = rb_hash(id);
    return (st_index_t)FIX2LONG(id);
}
static const struct st_hash_type ident_type = { ident_cmp, ident_hash };

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
    st_table *tbl = st_init_table(identity ? &ident_type : &view_type);
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
/* (one table's changes into its Hash, if it has any; the caller holds the
 *  syncing guard, so the requests this makes are not synced again) */
static int syncing;
static void sync_out_view(struct view *v) {
    struct same s = { v->before, v->count, 0, 1 };
    st_foreach(v->tbl, same_i, (st_data_t)&s);
    if (s.same && s.at == v->count) return;
    VALUE *pairs = malloc(sizeof(VALUE) * (size_t)(v->tbl->num_entries * 2 + 2));
    if (!pairs) rb_memerror();
    rb_hash_clear(v->hash);
    struct put p = { v->hash, pairs, 0 };
    st_foreach(v->tbl, put_i, (st_data_t)&p);
    free(v->before);
    v->before = pairs;
    v->count = p.n;
}
/* The C call `frame` ends: what C changed in the tables it asked for goes
 * back to their Hashes (this can raise -- a Hash frozen since -- so it runs
 * where core.c catches that). The tables themselves go after, in
 * mr_hash_tables_leave. */
void mr_hash_tables_flush(const void *frame) {
    if (syncing) return;
    syncing = 1;
    for (long i = 0; i < view_count; i++)
        if (views[i].owner == frame) sync_out_view(&views[i]);
    syncing = 0;
}
void mr_hash_tables_leave(const void *frame) {
    syncing = 0;   /* (a write-back that raised -- a frozen Hash -- left it set) */
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

/* ---- keeping the two in step (core.c's mr_up, around every request) ----- */
int mr_hash_tables_live(void) { return view_count > 0 && !syncing; }
/* what C changed in a table goes to its Hash, before the interpreter runs */
void mr_hash_tables_sync_out(void) {
    if (!view_count || syncing) return;
    syncing = 1;
    for (long i = 0; i < view_count; i++) sync_out_view(&views[i]);
    syncing = 0;
}
/* ...and what the interpreter changed in a Hash comes back into its table */
struct reread { VALUE *pairs; long n, cap; };
static int reread_i(VALUE key, VALUE value, VALUE arg) {
    struct reread *r = (struct reread *)arg;
    if (r->n == r->cap) {
        r->cap = r->cap ? r->cap * 2 : 16;
        r->pairs = realloc(r->pairs, sizeof(VALUE) * (size_t)(r->cap * 2));
        if (!r->pairs) mr_fatal("out of memory");
    }
    r->pairs[r->n * 2] = key;
    r->pairs[r->n * 2 + 1] = value;
    r->n++;
    return ST_CONTINUE;
}
void mr_hash_tables_sync_in(void) {
    if (!view_count || syncing) return;
    syncing = 1;
    for (long i = 0; i < view_count; i++) {
        struct view *v = &views[i];
        struct reread r = { NULL, 0, 0 };
        rb_hash_foreach(v->hash, reread_i, (VALUE)&r);
        int same = r.n == v->count;
        for (long k = 0; same && k < r.n * 2; k++) same = r.pairs[k] == v->before[k];
        if (same) { free(r.pairs); continue; }
        st_clear(v->tbl);
        for (long k = 0; k < r.n; k++) st_insert(v->tbl, (st_data_t)r.pairs[k * 2], (st_data_t)r.pairs[k * 2 + 1]);
        free(v->before);
        v->before = r.pairs ? r.pairs : malloc(sizeof(VALUE) * 2);
        v->count = r.n;
    }
    syncing = 0;
}

/* ---- roots: every key and value of every table (capi/gc.c asks) -------- */
static VALUE *root_buf;
static long root_count, root_cap;
static int root_i(st_data_t key, st_data_t value, st_data_t arg) {
    (void)arg;
    if (root_count + 2 > root_cap) {
        root_cap = root_cap ? root_cap * 2 : 64;
        root_buf = realloc(root_buf, sizeof(VALUE) * (size_t)root_cap);
        if (!root_buf) mr_fatal("out of memory");
    }
    root_buf[root_count++] = (VALUE)key;
    root_buf[root_count++] = (VALUE)value;
    return ST_CONTINUE;
}
/* (i == 0 gathers them afresh; Qundef past the last) */
VALUE mr_hash_tables_root_at(long i) {
    if (i == 0) {
        root_count = 0;
        for (long k = 0; k < view_count; k++) st_foreach(views[k].tbl, root_i, 0);
    }
    return i < root_count ? root_buf[i] : Qundef;
}
