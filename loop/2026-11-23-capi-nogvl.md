# 2026-11-23: a C function without the GVL runs while the other Ruby threads run

Rails-1's G1 stopped at Puma's real HTTP: nio4r's `Selector#select` in a
thread held every Ruby thread, because `rb_thread_call_without_gvl` ran the
function right there, on the one native thread the scheduler (m_sched.mere)
turns the Ruby threads on. Minimal: `sel.register(r, :r); t = Thread.new {
sel.select.size }; sleep 0.2; w.write "x"; p t.value` hung (ruby: 1).

- **capi/nogvl.c** (new; the old code in capi/system.c is gone): the
  function runs on a worker native thread; the calling Ruby thread waits on
  the read end of a pipe the worker writes to when done, through
  IO#wait_readable, which the scheduler turns into turns for the others.
  The worker blocks every signal but SIGVTALRM, so traps run on the
  interpreter's thread as before. When the wait ends with an exception
  (kill, raise, Timeout, an Interrupt), the unblocking function is called
  -- RUBY_UBF_IO / RUBY_UBF_PROCESS: SIGVTALRM to the worker, whose empty
  handler (no SA_RESTART) makes a blocking call return EINTR -- every 100 ms
  until the worker is done, then the exception goes on.
  rb_thread_call_with_gvl from the worker hands the call to the waiting Ruby
  thread (a 'C' on the pipe) and blocks until it has run; from the
  interpreter's thread it runs right there. A function without the GVL
  called from a worker runs right there. ruby_thread_has_gvl_p says which.
- **StringIO#initialize returns self**, as strio_initialize does: Puma's
  `class IOBuffer < StringIO; def initialize = super.binmode` raised in the
  listen loop. (lib/stringio_ext.rb, m_pathname_lib.mere regenerated.)

Rails-1's two repros on this build: nio1.rb prints 1; http3.rb (a bare
Puma::Server and Net::HTTP) prints ["200", "ok"] and stops. capi/check:
another thread ticks 20 times while the function naps 400 ms, the function
calls back with the GVL, and a kill ends a blocking read -- on both sides.

## Review of #177 (work2026-fd)

- **[Major] after an exception the wait stopped every thread**: it polled the
  pipe itself until the function was done. It waits through the scheduler
  now too -- IO#wait_readable(0.1) under rb_protect, the unblocking function
  again before each turn -- so the other threads run and a trap still
  reaches Ruby. capi/check: a function that ignores its unblocking function
  naps 400 ms; another thread raises into its caller; a ticker goes on
  ticking between the raise and the function's end (ruby too; a count, not
  a rate, so it holds under GC.stress).
- **[Major] a raise in rb_thread_call_with_gvl's call leaked the worker and
  its pipe**: the call runs under rb_protect; the worker gets NULL, the
  function runs to its end, and the exception goes on from
  rb_thread_call_without_gvl. capi/check: three such calls raise the
  callback's error, and the next call works.
- **[Minor] each call made a thread, a pipe and an IO** (0.6 ms): workers
  are kept on an idle list with their pipe and IO (rooted in one Array) and
  used again; a forked child forgets them (pthread_atfork). That removed the
  thread per call, not the cost: 2,000 empty calls still take about 960 ms
  (ruby 1 ms), nearly all of it the interpreter's IO#wait_readable on a pipe
  that is already readable (2,000 of those: 820 ms, ruby 7 ms). That is the
  scheduler's own cost, for a PR of its own.
- **[Minor] rb_thread_call_with_gvl from an extension's own native thread**
  ran right there, beside the interpreter: it is CRuby's [BUG] now.
- Left, and said in capi/nogvl.c: an exception raised while waiting has the
  wait's frames (IO#wait_readable) at the top of its backtrace.
- (re-review) **[Minor] the workers' pipes had no close-on-exec**: a child
  of system / spawn inherited 2 descriptors (ruby 0). Both ends are
  FD_CLOEXEC now. **[Suggestion]** recorded in capi/nogvl.c: before the
  first without-GVL call, with_gvl from a foreign native thread is not
  caught.
- (automated review, mere-pr-review-watch) **[Major] native-thread affinity**:
  every call ran on a worker, so a function that reads a __thread variable
  its caller set (or unlocks a mutex the caller's thread owns) saw another
  thread's (probe: 42 in ruby and on main, 0 here). Now the worker is used
  only when it buys something: when another Ruby thread is alive to run
  meanwhile, or when rb_nogvl is given RB_NOGVL_OFFLOAD_SAFE. With no other
  Ruby thread alive the function runs right there, on the interpreter's
  native thread, as on main, and a trapped signal still reaches its
  unblocking function (main's signal step, kept as inline_call). With other
  threads alive the function's native thread is not the caller's: that is
  the price of running them meanwhile on a one-native-thread interpreter,
  and capi/nogvl.c says so. capi/check: with Thread.list of one, the
  function sees the caller's __thread value (42, as in ruby).
- (re-review) **errno** is thread-local too: on a worker the function's
  errno was not the caller's, and `n = rb_thread_call_without_gvl(...);
  if (n < 0) rb_sys_fail(...)` read the wrong one. The worker keeps errno as
  the function left it and the caller gets it back. capi/check: a read on
  a bad descriptor gives -1 and EBADF to C, alone and with another thread
  alive.
- (re-review 3) **[Minor] alone, a trap does not end a RUBY_UBF_IO call**
  (USR1 to Interrupt: ruby 0.7 s; here, as on main, the read goes on). Taking
  SA_RESTART off the trapped handlers did not help and is gone again: the
  interpreter runs on a second pthread, and a signal from outside goes to
  the first (waiting in pthread_join), so the interpreter's blocking call
  never sees it. Follow-up: forward it to the interpreter's thread with
  pthread_kill (SIGVTALRM, as the worker path does).
- (re-review 4) **[Minor] a raise in a with_gvl call inside a function run
  right there left the trapped handlers replaced** (and a custom unblocking
  function called later on a dead stack -- older than this PR): the call
  runs under rb_protect, and the handlers go back before the exception goes
  on. **[Minor]** stated: once Timeout has been used its thread
  stays alive, and later calls take the worker (and its TLS caveat).
  **[Suggestion]** ruby_thread_has_gvl_p is 0 inside a function run right
  there (1 again inside its with_gvl call).
