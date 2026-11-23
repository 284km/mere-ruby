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
