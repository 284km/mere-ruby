/* Threads, time, files and the few utilities: where the C API meets the
 * operating system through the interpreter. */
#include "mr_capi.h"
#include "ruby/io.h"
#include "ruby/thread.h"
#include "ruby/vm.h"
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* ---- threads -------------------------------------------------------------- */
/* This interpreter's threads take turns on one native thread: there is no
 * lock to give up, and a function "without the GVL" simply runs. Nothing
 * else runs meanwhile.
 *
 * What the unblocking function is for still holds: a signal the program
 * traps must be able to end the wait. While the function runs, every signal
 * the interpreter has a handler for is given one more step -- the
 * interpreter's handler (which notes the signal), then the unblocking
 * function. The trap itself runs when the C function has returned. */
#include <signal.h>
static rb_unblock_function_t *unblock;
static void *unblock_data;
static struct sigaction previous[NSIG];
static void unblocking_handler(int sig, siginfo_t *info, void *context) {
    struct sigaction *old = &previous[sig];
    if (old->sa_flags & SA_SIGINFO) { if (old->sa_sigaction) old->sa_sigaction(sig, info, context); }
    else if (old->sa_handler != SIG_DFL && old->sa_handler != SIG_IGN) old->sa_handler(sig);
    if (unblock && unblock != RUBY_UBF_IO && unblock != RUBY_UBF_PROCESS) unblock(unblock_data);
}
static void *without_gvl(void *(*func)(void *), void *data1, rb_unblock_function_t *ubf, void *data2) {
    rb_unblock_function_t *outer = unblock;
    void *outer_data = unblock_data;
    int wrapped[NSIG] = { 0 };
    if (ubf && ubf != RUBY_UBF_IO && ubf != RUBY_UBF_PROCESS && !outer) {
        for (int sig = 1; sig < NSIG; sig++) {
            struct sigaction current;
            if (sig == SIGKILL || sig == SIGSTOP || sigaction(sig, NULL, &current) != 0) continue;
            if (!(current.sa_flags & SA_SIGINFO) && (current.sa_handler == SIG_DFL || current.sa_handler == SIG_IGN)) continue;
            previous[sig] = current;
            struct sigaction ours = current;
            ours.sa_sigaction = unblocking_handler;
            ours.sa_flags |= SA_SIGINFO;
            if (sigaction(sig, &ours, NULL) == 0) wrapped[sig] = 1;
        }
    }
    unblock = ubf;
    unblock_data = data2;
    void *result = func(data1);
    unblock = outer;
    unblock_data = outer_data;
    for (int sig = 1; sig < NSIG; sig++) if (wrapped[sig]) sigaction(sig, &previous[sig], NULL);
    return result;
}
void *rb_thread_call_without_gvl(void *(*func)(void *), void *data1, rb_unblock_function_t *ubf, void *data2) {
    return without_gvl(func, data1, ubf, data2);
}
void *rb_thread_call_without_gvl2(void *(*func)(void *), void *data1, rb_unblock_function_t *ubf, void *data2) {
    return without_gvl(func, data1, ubf, data2);
}
void *rb_nogvl(void *(*func)(void *), void *data1, rb_unblock_function_t *ubf, void *data2, int flags) {
    (void)flags;
    return without_gvl(func, data1, ubf, data2);
}
void *rb_thread_call_with_gvl(void *(*func)(void *), void *data1) { return func(data1); }
VALUE rb_thread_current(void) { return mr_call(rb_cThread, "current", 0); }
VALUE rb_thread_main(void) { return mr_call(rb_cThread, "main", 0); }
void rb_thread_schedule(void) { mr_call(rb_cThread, "pass", 0); }
void rb_thread_check_ints(void) {}
int rb_thread_interrupted(VALUE thread) { (void)thread; return 0; }
int rb_thread_alone(void) { return NUM2LONG(mr_call(mr_call(rb_cThread, "list", 0), "size", 0)) == 1; }
void rb_thread_sleep(int seconds) { mr_call(mr_main(), "sleep", 1, INT2FIX(seconds)); }
void rb_thread_sleep_forever(void) { mr_call(mr_main(), "sleep", 0); }
void rb_thread_sleep_deadly(void) { mr_call(mr_main(), "sleep", 0); }
void rb_thread_wait_for(struct timeval tv) {
    mr_call(mr_main(), "sleep", 1, rb_float_new((double)tv.tv_sec + (double)tv.tv_usec / 1e6));
}
VALUE rb_thread_wakeup(VALUE thread) { return mr_call(thread, "wakeup", 0); }
VALUE rb_thread_wakeup_alive(VALUE thread) { return RTEST(mr_call(thread, "alive?", 0)) ? mr_call(thread, "wakeup", 0) : Qnil; }
VALUE rb_thread_run(VALUE thread) { return mr_call(thread, "run", 0); }
VALUE rb_thread_kill(VALUE thread) { return mr_call(thread, "kill", 0); }
VALUE rb_thread_stop(void) { return mr_call(rb_cThread, "stop", 0); }
VALUE rb_thread_local_aref(VALUE thread, ID id) { return mr_call(thread, "[]", 1, ID2SYM(id)); }
VALUE rb_thread_local_aset(VALUE thread, ID id, VALUE value) { return mr_call(thread, "[]=", 2, ID2SYM(id), value); }
static VALUE thread_body(VALUE yielded, VALUE data, int argc, const VALUE *argv, VALUE block) {
    (void)yielded; (void)argc; (void)argv; (void)block;
    VALUE (*fn)(void *) = (VALUE (*)(void *))(uintptr_t)NUM2ULONG(rb_ary_entry(data, 0));
    void *arg = (void *)(uintptr_t)NUM2ULONG(rb_ary_entry(data, 1));
    return fn(arg);
}
VALUE rb_thread_create(VALUE (*fn)(void *), void *arg) {
    VALUE data = rb_assoc_new(ULONG2NUM((uintptr_t)fn), ULONG2NUM((uintptr_t)arg));
    return rb_block_call(rb_cThread, rb_intern("new"), 0, NULL, thread_body, data);
}
VALUE rb_mutex_new(void) { return mr_call(mr_const("Thread::Mutex"), "new", 0); }
VALUE rb_mutex_locked_p(VALUE mutex) { return mr_call(mutex, "locked?", 0); }
VALUE rb_mutex_trylock(VALUE mutex) { return mr_call(mutex, "try_lock", 0); }
VALUE rb_mutex_lock(VALUE mutex) { return mr_call(mutex, "lock", 0); }
VALUE rb_mutex_unlock(VALUE mutex) { return mr_call(mutex, "unlock", 0); }
VALUE rb_mutex_sleep(VALUE mutex, VALUE timeout) { return mr_call(mutex, "sleep", 1, timeout); }
struct sync_call { VALUE (*func)(VALUE); VALUE arg; };
static VALUE sync_body(VALUE p) { struct sync_call *c = (struct sync_call *)p; return c->func(c->arg); }
VALUE rb_mutex_synchronize(VALUE mutex, VALUE (*func)(VALUE), VALUE arg) {
    struct sync_call call = { func, arg };
    rb_mutex_lock(mutex);
    return rb_ensure(sync_body, (VALUE)&call, rb_mutex_unlock, mutex);
}

/* ---- at exit ------------------------------------------------------------------ */
static VALUE end_proc_body(VALUE yielded, VALUE data, int argc, const VALUE *argv, VALUE block) {
    (void)yielded; (void)argc; (void)argv; (void)block;
    void (*fn)(VALUE) = (void (*)(VALUE))(uintptr_t)NUM2ULONG(rb_ary_entry(data, 0));
    fn(rb_ary_entry(data, 1));
    return Qnil;
}
void rb_set_end_proc(void (*fn)(VALUE), VALUE data) {
    VALUE pair = rb_assoc_new(ULONG2NUM((uintptr_t)fn), data);
    rb_block_call(mr_main(), rb_intern("at_exit"), 0, NULL, end_proc_body, pair);
}
static VALUE vm_exit_body(VALUE yielded, VALUE data, int argc, const VALUE *argv, VALUE block) {
    (void)yielded; (void)argc; (void)argv; (void)block;
    void (*fn)(void *) = (void (*)(void *))(uintptr_t)NUM2ULONG(data);
    fn(NULL);
    return Qnil;
}
void ruby_vm_at_exit(void (*fn)(ruby_vm_t *)) {
    rb_block_call(mr_main(), rb_intern("at_exit"), 0, NULL, vm_exit_body, ULONG2NUM((uintptr_t)fn));
}

/* ---- time ----------------------------------------------------------------------- */
VALUE rb_time_new(time_t sec, long usec) { return mr_call(rb_cTime, "at", 2, LONG2NUM((long)sec), LONG2NUM(usec)); }
VALUE rb_time_nano_new(time_t sec, long nsec) {
    return mr_call(rb_cTime, "at", 3, LONG2NUM((long)sec), LONG2NUM(nsec), ID2SYM(rb_intern("nsec")));
}
VALUE rb_time_timespec_new(const struct timespec *ts, int offset) {
    VALUE t = rb_time_nano_new(ts->tv_sec, ts->tv_nsec);
    if (offset == INT_MAX) return t;                          /* local time */
    if (offset == INT_MAX - 1) return mr_call(t, "utc", 0);
    if (offset < -86400 || offset > 86400) rb_raise(rb_eArgError, "utc_offset out of range");
    return mr_call(t, "localtime", 1, INT2FIX(offset));
}
VALUE rb_time_num_new(VALUE num, VALUE offset) {
    VALUE t = mr_call(rb_cTime, "at", 1, num);
    return NIL_P(offset) ? t : mr_call(t, "localtime", 1, offset);
}
static struct timespec to_timespec(VALUE num, int interval) {
    struct timespec ts;
    if (RTEST(rb_obj_is_kind_of(num, rb_cTime))) {
        if (interval) rb_raise(rb_eTypeError, "can't convert Time into time interval");
        ts.tv_sec = (time_t)NUM2LONG(mr_call(num, "to_i", 0));
        ts.tv_nsec = NUM2LONG(mr_call(num, "nsec", 0));
        return ts;
    }
    if (!RTEST(rb_obj_is_kind_of(num, rb_cNumeric)))
        rb_raise(rb_eTypeError, "can't convert %" PRIsVALUE " into %s", rb_obj_class(num), interval ? "time interval" : "time");
    if (RTEST(mr_call(num, "<", 1, INT2FIX(0))) && interval) rb_raise(rb_eArgError, "time interval must not be negative");
    VALUE whole = mr_call(num, "floor", 0);
    VALUE nano = mr_call(mr_call(mr_call(num, "-", 1, whole), "*", 1, INT2FIX(1000000000)), "to_i", 0);
    ts.tv_sec = (time_t)NUM2LONG(whole);
    ts.tv_nsec = NUM2LONG(nano);
    return ts;
}
struct timeval rb_time_interval(VALUE num) {
    struct timespec ts = to_timespec(num, 1);
    struct timeval tv = { ts.tv_sec, (suseconds_t)(ts.tv_nsec / 1000) };
    return tv;
}
struct timeval rb_time_timeval(VALUE time) {
    struct timespec ts = to_timespec(time, 0);
    struct timeval tv = { ts.tv_sec, (suseconds_t)(ts.tv_nsec / 1000) };
    return tv;
}
struct timespec rb_time_timespec(VALUE time) { return to_timespec(time, 0); }
struct timespec rb_time_timespec_interval(VALUE num) { return to_timespec(num, 1); }
void rb_timespec_now(struct timespec *ts) {
    if (clock_gettime(CLOCK_REALTIME, ts) != 0) rb_sys_fail("clock_gettime");
}
VALUE rb_time_utc_offset(VALUE time) { return mr_call(time, "utc_offset", 0); }

/* ---- files and IO --------------------------------------------------------------- */
int rb_io_descriptor(VALUE io) { return NUM2INT(mr_call(io, "fileno", 0)); }
VALUE rb_io_get_io(VALUE io) { return mr_call(io, "to_io", 0); }
VALUE rb_io_check_io(VALUE io) { return rb_respond_to(io, rb_intern("to_io")) ? mr_call(io, "to_io", 0) : Qnil; }
VALUE rb_io_wait(VALUE io, VALUE events, VALUE timeout) { return mr_call(io, "wait", 2, events, timeout); }
VALUE rb_io_maybe_wait(int error, VALUE io, VALUE events, VALUE timeout) {
    if (error != EAGAIN && error != EWOULDBLOCK && error != EINTR) return Qfalse;
    return rb_io_wait(io, events, timeout);
}
int rb_io_maybe_wait_readable(int error, VALUE io, VALUE timeout) {
    VALUE r = rb_io_maybe_wait(error, io, INT2FIX(RUBY_IO_READABLE), timeout);
    return RTEST(r) ? NUM2INT(r) : 0;
}
int rb_io_maybe_wait_writable(int error, VALUE io, VALUE timeout) {
    VALUE r = rb_io_maybe_wait(error, io, INT2FIX(RUBY_IO_WRITABLE), timeout);
    return RTEST(r) ? NUM2INT(r) : 0;
}
VALUE rb_io_write(VALUE io, VALUE str) { return mr_call(io, "write", 1, str); }
VALUE rb_io_puts(int argc, const VALUE *argv, VALUE io) { return mr_callv(io, rb_intern("puts"), argc, argv, Qnil, 0); }
VALUE rb_io_print(int argc, const VALUE *argv, VALUE io) { return mr_callv(io, rb_intern("print"), argc, argv, Qnil, 0); }
VALUE rb_io_printf(int argc, const VALUE *argv, VALUE io) { return mr_callv(io, rb_intern("printf"), argc, argv, Qnil, 0); }
VALUE rb_io_gets(VALUE io) { return mr_call(io, "gets", 0); }
VALUE rb_io_getbyte(VALUE io) { return mr_call(io, "getbyte", 0); }
VALUE rb_io_close(VALUE io) { return mr_call(io, "close", 0); }
VALUE rb_io_flush(VALUE io) { return mr_call(io, "flush", 0); }
VALUE rb_io_eof(VALUE io) { return mr_call(io, "eof?", 0); }
/* A File::Stat of a struct stat C filled (stat(2), fstat(2)): the snapshot a
 * File::Stat is here, made of the struct's fields. */
#include <sys/stat.h>
VALUE rb_stat_new(const struct stat *st) {
    VALUE fields = rb_ary_new_from_args(13,
        ULL2NUM((unsigned long long)st->st_dev), ULL2NUM((unsigned long long)st->st_ino), UINT2NUM((unsigned int)st->st_mode),
        ULL2NUM((unsigned long long)st->st_nlink), UINT2NUM((unsigned int)st->st_uid), UINT2NUM((unsigned int)st->st_gid),
        ULL2NUM((unsigned long long)st->st_rdev), LL2NUM((long long)st->st_size), LL2NUM((long long)st->st_atime),
        LL2NUM((long long)st->st_mtime), LL2NUM((long long)st->st_ctime), LL2NUM((long long)st->st_blksize),
        LL2NUM((long long)st->st_blocks));
    return mr_call(mr_ruby("->(f) { s = File::Stat.allocate; s.instance_variable_set(:@h, File::Stat.__fields(f, nil, true)); s }"),
                   "call", 1, fields);
}
VALUE rb_io_binmode(VALUE io) { return mr_call(io, "binmode", 0); }
/* (what takes RFILE(io)->fptr: the IO the struct names is what is asked) */
void rb_io_check_closed(rb_io_t *fptr) {
    if (!fptr || fptr->fd < 0 || RTEST(mr_call(fptr->self, "closed?", 0))) rb_raise(rb_eIOError, "closed stream");
}
void rb_io_check_initialized(rb_io_t *fptr) {
    if (!fptr) rb_raise(rb_eIOError, "uninitialized stream");
}
void rb_io_check_readable(rb_io_t *fptr) {
    rb_io_check_closed(fptr);
    if (!(fptr->mode & FMODE_READABLE)) rb_raise(rb_eIOError, "not opened for reading");
}
void rb_io_check_writable(rb_io_t *fptr) {
    rb_io_check_closed(fptr);
    if (!(fptr->mode & FMODE_WRITABLE)) rb_raise(rb_eIOError, "not opened for writing");
}
void rb_io_set_nonblock(rb_io_t *fptr) {
    rb_io_check_closed(fptr);
    int flags = fcntl(fptr->fd, F_GETFL);
    if (flags == -1) rb_sys_fail(NULL);
    if (!(flags & O_NONBLOCK) && fcntl(fptr->fd, F_SETFL, flags | O_NONBLOCK) == -1) rb_sys_fail(NULL);
}
VALUE rb_io_taint_check(VALUE io) { rb_check_frozen(io); return io; }
void rb_eof_error(void) { rb_raise(rb_eEOFError, "end of file reached"); }
VALUE rb_io_addstr(VALUE io, VALUE str) { mr_call(io, "write", 1, str); return io; }
VALUE rb_io_fdopen(int fd, int flags, const char *path) {
    (void)path;
    return mr_call(rb_cIO, "for_fd", 2, INT2FIX(fd), INT2FIX(flags));
}
VALUE rb_file_open(const char *path, const char *mode) { return mr_call(rb_cFile, "open", 2, rb_str_new_cstr(path), rb_str_new_cstr(mode)); }
VALUE rb_file_open_str(VALUE path, const char *mode) { return mr_call(rb_cFile, "open", 2, path, rb_str_new_cstr(mode)); }
VALUE rb_get_path(VALUE obj) { return mr_call(rb_cFile, "path", 1, obj); }
VALUE rb_get_path_no_checksafe(VALUE obj) { return rb_get_path(obj); }
VALUE rb_file_expand_path(VALUE name, VALUE dir) { return mr_call(rb_cFile, "expand_path", 2, name, dir); }
VALUE rb_file_absolute_path(VALUE name, VALUE dir) { return mr_call(rb_cFile, "absolute_path", 2, name, dir); }
VALUE rb_file_dirname(VALUE name) { return mr_call(rb_cFile, "dirname", 1, name); }
VALUE rb_file_directory_p(VALUE obj, VALUE name) { (void)obj; return mr_call(rb_cFile, "directory?", 1, name); }
int rb_cloexec_open(const char *path, int flags, mode_t mode) {
#ifdef O_CLOEXEC
    flags |= O_CLOEXEC;
#endif
    return open(path, flags, mode);
}
void rb_update_max_fd(int fd) { (void)fd; }
void rb_fd_fix_cloexec(int fd) {
    int flags = fcntl(fd, F_GETFD);
    if (flags != -1 && !(flags & FD_CLOEXEC)) fcntl(fd, F_SETFD, flags | FD_CLOEXEC);
}
int rb_cloexec_dup(int fd) { return fcntl(fd, F_DUPFD_CLOEXEC, 3); }
int rb_reserved_fd_p(int fd) { (void)fd; return 0; }

/* ---- utilities -------------------------------------------------------------------- */
/* A stable merge sort with the comparison's extra argument: the C library's
 * qsort_r takes its arguments in a different order on each platform. */
static void merge_sort(char *base, char *tmp, size_t n, size_t size, int (*cmp)(const void *, const void *, void *), void *d) {
    if (n < 2) return;
    size_t half = n / 2;
    merge_sort(base, tmp, half, size, cmp, d);
    merge_sort(base + half * size, tmp, n - half, size, cmp, d);
    memcpy(tmp, base, half * size);
    size_t i = 0, j = half, k = 0;
    while (i < half && j < n) {
        if (cmp(tmp + i * size, base + j * size, d) <= 0) memcpy(base + (k++) * size, tmp + (i++) * size, size);
        else memmove(base + (k++) * size, base + (j++) * size, size);
    }
    while (i < half) memcpy(base + (k++) * size, tmp + (i++) * size, size);
}
void ruby_qsort(void *base, const size_t nel, const size_t size, int (*cmp)(const void *, const void *, void *), void *d) {
    if (nel < 2 || size == 0) return;
    char *tmp = ruby_xmalloc2(nel / 2 + 1, size);
    merge_sort(base, tmp, nel, size, cmp, d);
    ruby_xfree(tmp);
}
unsigned long ruby_scan_oct(const char *start, size_t len, size_t *retlen) {
    unsigned long v = 0;
    size_t i = 0;
    for (; i < len && start[i] >= '0' && start[i] <= '7'; i++) v = (v << 3) | (unsigned long)(start[i] - '0');
    *retlen = i;
    return v;
}
unsigned long ruby_scan_hex(const char *start, size_t len, size_t *retlen) {
    unsigned long v = 0;
    size_t i = 0;
    for (; i < len; i++) {
        int c = start[i], digit;
        if (c >= '0' && c <= '9') digit = c - '0';
        else if (c >= 'a' && c <= 'f') digit = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') digit = c - 'A' + 10;
        else break;
        v = (v << 4) | (unsigned long)digit;
    }
    *retlen = i;
    return v;
}
char *ruby_strdup(const char *s) {
    size_t n = strlen(s) + 1;
    char *copy = ruby_xmalloc(n);
    memcpy(copy, s, n);
    return copy;
}
char *ruby_getcwd(void) {
    char *buffer = ruby_xmalloc(PATH_MAX + 1);
    if (!getcwd(buffer, PATH_MAX + 1)) { ruby_xfree(buffer); rb_sys_fail("getcwd"); }
    return buffer;
}
double ruby_strtod(const char *s, char **end) { return strtod(s, end); }

/* ruby/util.h: a digit of any base up to 36, by its character (-1: not one) */
const signed char ruby_digit36_to_number_table[] = {
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
     0,  1,  2,  3,  4,  5,  6,  7,  8,  9, -1, -1, -1, -1, -1, -1,
    -1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1,
    -1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
};
