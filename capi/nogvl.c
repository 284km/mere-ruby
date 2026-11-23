/* rb_thread_call_without_gvl and its kin: the function runs while the other
 * Ruby threads run.
 *
 * This interpreter's Ruby threads take turns on one native thread
 * (m_sched.mere). A C function "without the GVL" -- a select, a socket
 * accept, a long computation -- used to run right there, and every Ruby
 * thread waited for it (nio4r's Selector#select in a thread stopped Puma).
 * Now it runs on a native thread of its own (a worker), and the Ruby thread
 * that called it waits for it the way Ruby waits for an IO: on the read end
 * of a pipe the worker writes to when it is done, through IO#wait_readable,
 * which the scheduler turns into a turn for the other threads.
 *
 *   - The worker blocks every signal: a signal goes to the interpreter's
 *     thread, whose trap runs as usual and may end the wait.
 *   - When the wait ends with an exception (Thread#kill / #raise, Timeout, an
 *     Interrupt from a trap), the unblocking function is called -- for
 *     RUBY_UBF_IO / RUBY_UBF_PROCESS a signal is sent to the worker instead,
 *     whose handler does nothing, so a blocking system call returns EINTR --
 *     again every 100 ms until the worker is done; then the exception goes
 *     on.
 *   - The worker may not touch Ruby objects (the C API's rule without the
 *     GVL), except through rb_thread_call_with_gvl, which hands the call to
 *     the Ruby thread waiting for it and blocks until that has run it.
 *   - A function called without the GVL from a worker runs right there. */
#include "mr_capi.h"
#include "ruby/thread.h"
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <poll.h>
#include <unistd.h>
#include <string.h>

struct job {
    void *(*func)(void *);
    void *data, *result;
    int fds[2];                 /* the worker writes 'D' (done) or 'C' (a call) */
    pthread_t thread;
    pthread_mutex_t lock;
    pthread_cond_t answered;
    void *(*call)(void *);      /* rb_thread_call_with_gvl's, while asked */
    void *call_data, *call_result;
    int call_state;             /* 0 none, 1 asked, 2 answered */
};
static __thread struct job *running_job;   /* the worker's own job */

static void tell(struct job *job, char what) {
    while (write(job->fds[1], &what, 1) < 0 && errno == EINTR) {}
}
static void *worker(void *arg) {
    struct job *job = arg;
    sigset_t all;
    sigfillset(&all);
    pthread_sigmask(SIG_BLOCK, &all, NULL);
    /* (...but the one this file sends to end a blocking call: RUBY_UBF_IO) */
    sigset_t wake;
    sigemptyset(&wake);
    sigaddset(&wake, SIGVTALRM);
    pthread_sigmask(SIG_UNBLOCK, &wake, NULL);
    running_job = job;
    job->result = job->func(job->data);
    running_job = NULL;
    tell(job, 'D');
    return NULL;
}
static void wake_handler(int sig) { (void)sig; }
static void install_wake_handler(void) {
    static int installed;
    if (installed) return;
    installed = 1;
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = wake_handler;   /* (no SA_RESTART: the call returns EINTR) */
    sigemptyset(&sa.sa_mask);
    sigaction(SIGVTALRM, &sa, NULL);
}

/* (the Ruby side of the wait: one turn of IO#wait_readable on the pipe) */
static VALUE wait_once(VALUE io) { return mr_call(io, "wait_readable", 0); }
/* (a call the worker asked for, run here, with the GVL) */
static void answer(struct job *job) {
    pthread_mutex_lock(&job->lock);
    void *(*call)(void *) = job->call;
    void *call_data = job->call_data;
    pthread_mutex_unlock(&job->lock);
    void *result = call(call_data);
    pthread_mutex_lock(&job->lock);
    job->call_result = result;
    job->call_state = 2;
    pthread_cond_signal(&job->answered);
    pthread_mutex_unlock(&job->lock);
}
static void unblock(pthread_t thread, rb_unblock_function_t *ubf, void *ubf_data) {
    if (ubf == RUBY_UBF_IO || ubf == RUBY_UBF_PROCESS) pthread_kill(thread, SIGVTALRM);
    else if (ubf) ubf(ubf_data);
}

static void *without_gvl(void *(*func)(void *), void *data1, rb_unblock_function_t *ubf, void *data2) {
    if (running_job) return func(data1);   /* (from a worker: right there) */
    install_wake_handler();
    struct job job;
    memset(&job, 0, sizeof(job));
    job.func = func;
    job.data = data1;
    if (pipe(job.fds) != 0) rb_sys_fail("pipe");
    pthread_mutex_init(&job.lock, NULL);
    pthread_cond_init(&job.answered, NULL);
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, 8 * 1024 * 1024);
    int failed = pthread_create(&job.thread, &attr, worker, &job);
    pthread_attr_destroy(&attr);
    if (failed) {
        close(job.fds[0]);
        close(job.fds[1]);
        errno = failed;
        rb_sys_fail("pthread_create");
    }
    VALUE io = mr_call(rb_cIO, "for_fd", 1, INT2FIX(job.fds[0]));
    int state = 0, done = 0;
    while (!done) {
        rb_protect(wait_once, io, &state);
        if (state) break;
        char what = 0;
        ssize_t n = read(job.fds[0], &what, 1);
        if (n == 1 && what == 'D') done = 1;
        else if (n == 1 && what == 'C') answer(&job);
    }
    if (!done) {
        /* (the wait ended with an exception: ask the function to end, until
         *  it does -- a call it asks for meanwhile is still answered) */
        unblock(job.thread, ubf, data2);
        while (!done) {
            struct pollfd p = { job.fds[0], POLLIN, 0 };
            int r = poll(&p, 1, 100);
            if (r == 0) { unblock(job.thread, ubf, data2); continue; }
            if (r < 0) continue;
            char what = 0;
            if (read(job.fds[0], &what, 1) == 1) {
                if (what == 'D') done = 1;
                else if (what == 'C') answer(&job);
            }
        }
    }
    pthread_join(job.thread, NULL);
    pthread_mutex_destroy(&job.lock);
    pthread_cond_destroy(&job.answered);
    close(job.fds[1]);
    int close_state = 0;
    rb_protect(rb_io_close, io, &close_state);   /* (closes fds[0]) */
    if (state) rb_jump_tag(state);
    return job.result;
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
 * there, as it already has the GVL. */
void *rb_thread_call_with_gvl(void *(*func)(void *), void *data1) {
    struct job *job = running_job;
    if (!job) return func(data1);
    pthread_mutex_lock(&job->lock);
    job->call = func;
    job->call_data = data1;
    job->call_state = 1;
    pthread_mutex_unlock(&job->lock);
    tell(job, 'C');
    pthread_mutex_lock(&job->lock);
    while (job->call_state != 2) pthread_cond_wait(&job->answered, &job->lock);
    void *result = job->call_result;
    job->call_state = 0;
    pthread_mutex_unlock(&job->lock);
    return result;
}
int ruby_thread_has_gvl_p(void) { return running_job == NULL; }
