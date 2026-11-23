/* rb_thread_call_without_gvl and its kin: the function runs while the other
 * Ruby threads run.
 *
 * This interpreter's Ruby threads take turns on one native thread
 * (m_sched.mere). A C function "without the GVL" -- a select, a socket
 * accept, a long computation -- used to run right there, and every Ruby
 * thread waited for it (nio4r's Selector#select in a thread stopped Puma).
 * Now it runs on a worker native thread, and the Ruby thread that called it
 * waits for it the way Ruby waits for an IO: on the read end of the worker's
 * pipe, through IO#wait_readable, which the scheduler turns into turns for
 * the other threads.
 *
 *   - Workers are kept and used again (an idle list), each with its pipe and
 *     the IO on its read end: a call costs a hand-over, not a thread.
 *   - A worker blocks every signal but SIGVTALRM: a signal goes to the
 *     interpreter's thread, whose trap runs as usual and may end the wait.
 *   - When the wait ends with an exception (Thread#kill / #raise, Timeout, an
 *     Interrupt from a trap), the unblocking function is called -- for
 *     RUBY_UBF_IO / RUBY_UBF_PROCESS a SIGVTALRM to the worker instead, whose
 *     empty handler (no SA_RESTART) makes a blocking call return EINTR --
 *     and the wait goes on, still through the scheduler, calling it again
 *     every 100 ms until the function is done; then the exception goes on.
 *     (The function's data is on its caller's C stack: it must be done
 *     before that frame unwinds, as in CRuby.)
 *   - The worker may not touch Ruby objects (the C API's rule without the
 *     GVL), except through rb_thread_call_with_gvl, which hands the call to
 *     the Ruby thread waiting for it and blocks until that has run it. If
 *     the call raises, the worker gets NULL, the function runs to its end,
 *     and the exception goes on from rb_thread_call_without_gvl.
 *   - A function called without the GVL from a worker runs right there.
 *     rb_thread_call_with_gvl from a native thread that is neither a worker
 *     nor the interpreter's is CRuby's [BUG].
 *   - Known: an exception raised while waiting has the wait's own frames
 *     (IO#wait_readable) at the top of its backtrace, where CRuby has the C
 *     method's. The interpreter's native thread is learnt at the first
 *     without-GVL call: before it, rb_thread_call_with_gvl from a foreign
 *     native thread is not caught. A call costs IO#wait_readable's own
 *     turn (about 0.4 ms here, 3.5 us in ruby): that is the scheduler's. */
#include "mr_capi.h"
#include "ruby/thread.h"
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

struct worker {
    pthread_t thread;
    int fds[2];                 /* the worker writes 'D' (done) or 'C' (a call) */
    VALUE io;                   /* the read end, as an IO (rooted: see keep) */
    pthread_mutex_t lock;
    pthread_cond_t wake;        /* a job for it, or a call answered */
    /* the job */
    void *(*func)(void *);
    void *data, *result;
    int has_job;
    /* rb_thread_call_with_gvl's call, while asked */
    void *(*call)(void *);
    void *call_data, *call_result;
    int call_state;             /* 0 none, 1 asked, 2 answered */
    struct worker *next_idle;
};
static __thread struct worker *running_worker;   /* the worker's own */
static struct worker *idle;
static VALUE keep = Qnil;       /* the workers' IOs, so none is collected */
static pthread_t interp_thread;
static int interp_known;

static void tell(struct worker *w, char what) {
    while (write(w->fds[1], &what, 1) < 0 && errno == EINTR) {}
}
static void *worker_main(void *arg) {
    struct worker *w = arg;
    sigset_t all;
    sigfillset(&all);
    pthread_sigmask(SIG_BLOCK, &all, NULL);
    /* (...but the one this file sends to end a blocking call) */
    sigset_t wake;
    sigemptyset(&wake);
    sigaddset(&wake, SIGVTALRM);
    pthread_sigmask(SIG_UNBLOCK, &wake, NULL);
    running_worker = w;
    for (;;) {
        pthread_mutex_lock(&w->lock);
        while (!w->has_job) pthread_cond_wait(&w->wake, &w->lock);
        pthread_mutex_unlock(&w->lock);
        w->result = w->func(w->data);
        pthread_mutex_lock(&w->lock);
        w->has_job = 0;
        pthread_mutex_unlock(&w->lock);
        tell(w, 'D');
    }
    return NULL;
}
static void wake_handler(int sig) { (void)sig; }
/* (a forked child has none of the workers' native threads: it starts its
 *  own, and its one thread is the interpreter's) */
static void after_fork_child(void) {
    idle = NULL;
    interp_thread = pthread_self();
}
static void install_wake_handler(void) {
    static int installed;
    if (installed) return;
    installed = 1;
    pthread_atfork(NULL, NULL, after_fork_child);
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = wake_handler;   /* (no SA_RESTART: the call returns EINTR) */
    sigemptyset(&sa.sa_mask);
    sigaction(SIGVTALRM, &sa, NULL);
}
static struct worker *take_worker(void) {
    if (idle) {
        struct worker *w = idle;
        idle = w->next_idle;
        w->next_idle = NULL;
        return w;
    }
    struct worker *w = calloc(1, sizeof(*w));
    if (!w) rb_memerror();
    if (pipe(w->fds) != 0) { free(w); rb_sys_fail("pipe"); }
    /* (a worker lives as long as the process: its pipe is not a child's --
     *  system / spawn / exec do not inherit it) */
    fcntl(w->fds[0], F_SETFD, FD_CLOEXEC);
    fcntl(w->fds[1], F_SETFD, FD_CLOEXEC);
    pthread_mutex_init(&w->lock, NULL);
    pthread_cond_init(&w->wake, NULL);
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, 8 * 1024 * 1024);
    int failed = pthread_create(&w->thread, &attr, worker_main, w);
    pthread_attr_destroy(&attr);
    if (failed) {
        close(w->fds[0]);
        close(w->fds[1]);
        free(w);
        errno = failed;
        rb_sys_fail("pthread_create");
    }
    pthread_detach(w->thread);
    if (NIL_P(keep)) {
        keep = rb_ary_new();
        rb_gc_register_address(&keep);
    }
    w->io = mr_call(rb_cIO, "for_fd", 1, INT2FIX(w->fds[0]));
    rb_ary_push(keep, w->io);
    return w;
}

/* (the Ruby side of the wait: one turn of IO#wait_readable on the pipe,
 *  for good, or for at most 100 ms once the function has been asked to end) */
static VALUE wait_once(VALUE io) { return mr_call(io, "wait_readable", 0); }
static VALUE wait_short(VALUE io) { return mr_call(io, "wait_readable", 1, DBL2NUM(0.1)); }
/* (a call the worker asked for, run here, with the GVL; what it raises is
 *  kept for the end, and the worker gets NULL) */
static VALUE run_call(VALUE arg) {
    struct worker *w = (struct worker *)arg;
    return (VALUE)w->call(w->call_data);
}
static void answer(struct worker *w, int *call_state) {
    int state = 0;
    VALUE result = rb_protect(run_call, (VALUE)w, &state);
    if (state && !*call_state) *call_state = state;
    pthread_mutex_lock(&w->lock);
    w->call_result = state ? NULL : (void *)result;
    w->call_state = 2;
    pthread_cond_broadcast(&w->wake);
    pthread_mutex_unlock(&w->lock);
}
static void unblock(struct worker *w, rb_unblock_function_t *ubf, void *ubf_data) {
    if (ubf == RUBY_UBF_IO || ubf == RUBY_UBF_PROCESS) pthread_kill(w->thread, SIGVTALRM);
    else if (ubf) ubf(ubf_data);
}
/* (what is in the pipe now: 1 done, 0 nothing yet; a call is answered) */
static int drain(struct worker *w, int *call_state) {
    char what = 0;
    ssize_t n = read(w->fds[0], &what, 1);
    if (n == 1 && what == 'D') return 1;
    if (n == 1 && what == 'C') answer(w, call_state);
    return 0;
}

static void *without_gvl(void *(*func)(void *), void *data1, rb_unblock_function_t *ubf, void *data2) {
    if (running_worker) return func(data1);   /* (from a worker: right there) */
    if (!interp_known) { interp_thread = pthread_self(); interp_known = 1; }
    install_wake_handler();
    struct worker *w = take_worker();
    pthread_mutex_lock(&w->lock);
    w->func = func;
    w->data = data1;
    w->result = NULL;
    w->has_job = 1;
    pthread_cond_broadcast(&w->wake);
    pthread_mutex_unlock(&w->lock);
    int state = 0, call_state = 0, done = 0;
    while (!done) {
        rb_protect(wait_once, w->io, &state);
        if (state) break;
        done = drain(w, &call_state);
    }
    /* (the wait ended with an exception: ask the function to end, again
     *  every 100 ms, still waiting through the scheduler -- the other threads
     *  run, and a trap still reaches Ruby) */
    while (!done) {
        unblock(w, ubf, data2);
        int again = 0;
        VALUE ready = rb_protect(wait_short, w->io, &again);
        if (!again && RTEST(ready)) done = drain(w, &call_state);
    }
    void *result = w->result;
    w->next_idle = idle;
    idle = w;
    if (state) rb_jump_tag(state);
    if (call_state) rb_jump_tag(call_state);
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
/* From a worker: the Ruby thread waiting for it runs the call, and the
 * worker waits for the answer. From the interpreter's own thread: right
 * there, as it already has the GVL. From any other native thread: CRuby's
 * [BUG]. */
void *rb_thread_call_with_gvl(void *(*func)(void *), void *data1) {
    struct worker *w = running_worker;
    if (!w) {
        if (interp_known && !pthread_equal(pthread_self(), interp_thread))
            rb_bug("rb_thread_call_with_gvl: called by a native thread that is not Ruby's");
        return func(data1);
    }
    pthread_mutex_lock(&w->lock);
    w->call = func;
    w->call_data = data1;
    w->call_state = 1;
    pthread_mutex_unlock(&w->lock);
    tell(w, 'C');
    pthread_mutex_lock(&w->lock);
    while (w->call_state != 2) pthread_cond_wait(&w->wake, &w->lock);
    void *result = w->call_result;
    w->call_state = 0;
    pthread_mutex_unlock(&w->lock);
    return result;
}
int ruby_thread_has_gvl_p(void) { return running_worker == NULL; }
