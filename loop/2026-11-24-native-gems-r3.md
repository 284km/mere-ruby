# 2026-11-24: native gems' own suites, round 3 -- puma 8.1.2

The goal (note 558) as in rounds 1 and 2: the native gems Rails uses run their
OWN test suites on mere-ruby the way they run on ruby 4.0.9, and mere-ruby is
fixed where they differ. This round is puma 8.1.2 (minitest, `test/runner`)
and then nokogiri 1.19.7.

## puma 8.1.2: how it is run

The release tag's sources; puma and what its test helper requires (rack
3.2.8, rackup 2.3.1, concurrent-ruby, minitest-retry, minitest-proveit,
minitest-stub-const, minitest-mock, localhost 1.8.0 and its dependencies)
installed into a GEM_HOME per side by `gem install --local`, and a Gemfile per
side naming them, so that `test/runner` (which requires bundler/setup) finds
the same set on both. Each run is `test/runner -v --unit --seed=1` or
`--integration --seed=1` in the source tree, one at a time.

## puma unit tests: 800 runs and 51 skips here, 863 and 7 on the reference

Before this round the unit category was, with the same seed:

| | runs | assertions | failures | errors | skips |
|---|---|---|---|---|---|
| ruby 4.0.9 | 863 | 2517 | 2 | 1 | 7 |
| mere-ruby | 800 | 2200 | 5 | 4 | 51 |

The reference's three are the harness's and are the same on both sides (below).
What differed:

- **puma was built without its TLS** (63 tests not defined, 44 skipped).
  `Puma::HAS_SSL` was false: puma's extconf.rb asks `dir_config('openssl')`,
  then pkg-config, then `have_library('crypto', 'BIO_read')`. The reference
  was configured `--with-openssl-dir=/opt/homebrew/opt/openssl@3`, which mkmf
  reads back out of `RbConfig::CONFIG['configure_args']`; mere-ruby's said
  `''`, there is no pkg-config on this machine, and Homebrew's openssl@3 is
  not on the compiler's paths -- so the library check failed and MiniSSL was
  left out. But mere-ruby IS built against a named OpenSSL (tools/build.sh:
  `OPENSSL_PREFIX` or `brew --prefix openssl@3`), and that is a fact about
  the build, not an invention: the build now passes it in
  (`-DMR_OPENSSL_DIR`, capi/core.c `mr_capi_openssl_dir`) and RbConfig says
  it as configure would have been told it, `'--with-openssl-dir=<prefix>'`
  (m_driver.mere, with the other facts of the C build). Where the build named
  no directory (pkg-config, or the compiler's own paths, as on Linux CI) the
  argument is not said and `''` stands. capi/check/mkmf.rb: an extension's
  extconf finds `openssl/ssl.h`, `-lcrypto` and `-lssl` through
  `dir_config('openssl')`, on both sides.
- **`super` from a `def self.new` of a Hash subclass** made a plain object
  (3 errors, TestCommonLogger). `Puma::Util::HeaderHash < Hash` has
  `def self.new(hash={}) = HeaderHash === hash ? hash : super(hash)`; the
  super fallback for `new` (ESuper's singleton arm, both the with-block and
  block-less copies) went straight to new_obj_wb, which builds a VObj and
  runs #initialize -- and HeaderHash#[]='s `super k, v` then had no Hash#[]=
  to reach. The class dispatch's own `new` arms already back a Hash, Array
  or String subclass's instance with the builtin's storage; `super` now goes
  there for those (super_cls_new: one dispatch past the override with
  bi_skip, as a saved Class#new Method's call does; a Thread subclass still
  starts the thread, everything else is new_obj_wb as before). corpus 909.
- **A spawned child's stdout was non-blocking** (2 failures,
  test_form_data_encoding_windows and _bom). The test spawns curl with
  `out:` an IO.pipe's write end and reads the echo of a 260 KB body; it got
  65536 bytes. IO.pipe's ends are O_NONBLOCK here as in ruby 3+, and ruby's
  child clears O_NONBLOCK on its fds 0, 1 and 2 just before exec
  (process.c, stdfd_clear_nonblock: "many programs cannot deal with
  non-blocking stdin/stdout/stderr"); mere-ruby handed it on, and curl (and
  `head`, in the repro) stopped at the first full pipe with EAGAIN. The flag
  belongs to the open file description, which the parent's copy shares, so
  clearing it in the parent just before the child starts is the same act:
  Process.__std_blocking (m_driver.mere) works out which descriptor becomes
  each of the child's 0, 1 and 2 (the redirect's source, a `[:child, fd]`
  one's, or this process's own) and clears it through a new
  `IO.__fdblock` (tools/process_glue.c `mr_fd_clear_nonblock`: fcntl, which
  no Mere extern can declare). Both spawn paths (posix_spawn and the shell),
  and so system, IO.popen and backticks, go through it. corpus 910.

After these, the same seed:

| | runs | assertions | failures | errors | skips |
|---|---|---|---|---|---|
| ruby 4.0.9 | 863 | 2517 | 2 | 1 | 7 |
| mere-ruby | 863 | 2537 | 3 | 2 | 7 |

Every test runs on both sides, the skips are the same seven (abstract UNIX
sockets, which are Linux's; JRuby-only; a Linux-only thread name; SSLv3).
The two failures and one error the reference has, mere-ruby has too, for the
same reason: the suite expects puma from its own source tree (`lib/` beside
the tests, and a compiled extension there), and this harness loads the
installed gem -- TestBundlePruner compares that path, and TestCLI#test_plugins
looks for a plugin file relative to it. What is left is two tests that are
TIMED, and fail on time, not on an answer:

- **TestMiniSSLSocket#test_write_nonblock_retry_delivers_data_once**:
  `Timeout.timeout(10)` around writing 16 MiB through MiniSSL's
  write_nonblock, retrying with `data.byteslice(n..-1)`. Measured by hand
  with the same loop (scratch script, both sides): ruby 0.04 s, mere-ruby
  12.4 s -- 1071 calls; 3.7 s in the byteslices and 7.1 s in write_nonblock.
  Both are proportional to what is LEFT, so the loop is quadratic here and
  linear in ruby: ruby's byteslice of a tail shares the bytes, this
  interpreter's copies them; and C reads the new String through
  RSTRING_PTR, which fetches a copy of it into the mirror and hashes it at
  each crossing (capi/mirror.c). With 4 MiB it is 1.15 s against 0.01 s; the
  multibyte variant of the same test (6 MiB of euro signs) passes. What it would
  take: a String whose tail shares its source's bytes, or a mirror that lends
  C the interpreter's bytes instead of a copy.
  Looked at again before the push, for a fix that copies less: per 8 MiB,
  the byteslice is 3.1 ms and one C call that reads the new String is
  another 6.7 ms (ruby: both under 0.01 ms). The 6.7 ms is the String's
  bytes made (bytes_of_str), copied into the transit buffer
  (mr_capi_give), copied into the mirror's buffer and hashed, and hashed
  again when the call ends. Two of those could go -- the transit copy, by
  handing C the interpreter's bytes, which since this round live only in
  the request's region (region CUP), so C would read them after they are
  freed; and the separate hash, by hashing while copying -- for perhaps
  half of the 6.7 ms. The loop stays quadratic, and the 16 MiB run would
  still sit at the 10 s bound under load, so it is left as it is: the
  honest fix is the sharing above, not a smaller constant.
- **TestRackUp::RackUp#test_bin**: `IO.popen "rackup -p 0"`, then
  `wait_readable 2`, `sleep 0.7` and one sysread of whatever is there. The
  child is the same interpreter, and from exec to "Use Ctrl-C to stop" it
  takes 2.73 s here against 0.27 s for ruby (measured with the same rackup
  and config.ru); at 2.7 s only the first line has been written. The output
  is the reference's line for line once it is all there. What it would take:
  booting rackup + puma ten times faster -- the interpreter's general speed,
  not something of puma's.

## puma integration tests: per-side source trees, and three more fixes

`test/runner --integration` starts `bin/puma` from the source tree with the
tree's `lib/`, which has no compiled extension: on both sides every server
died of `cannot load such file -- puma/puma_http11`. So each side gets its
own copy of the tree with that side's built `puma_http11.bundle` in
`lib/puma/`, and its Gemfile names the tree (`gem "puma", path: ...`), so
unit and integration tests load the same puma. What that run showed:

- **A long C call that calls back only through the C API held everything
  it asked for until it returned.** The first mere run was killed at 14 GB
  in Http11ParserTest#test_horrible_queries (80 x 1024 identical headers).
  puma's http_field joins a repeated header with rb_str_cat2 + rb_str_cat
  on the String it got from rb_hash_aref; each append fetches the whole
  growing String into the mirror and writes it all back (the interpreter ran
  in between, so the struct is stale). Two things kept every copy:
  - no collection: nothing in those requests is a Ruby statement, so there
    was no safepoint (GC.count advanced by 1 in the call). capi/core.c
    mr_up now sends MR_SAFEPOINT (33) before the requests that make
    something -- a String's bytes fetched, a call, a new String -- with what
    the request has put in transit set aside around it, and not while a
    collection is marking (a dmark's own request) nor for the write-back
    itself (MR_STR_SET / MR_ARY_SET, in the middle of a flush). capi_up
    answers it with gc_point_capi: a collection when one is due, which is
    one in the middle of a statement, rooted as an off-stack collection
    roots any (note 270) -- the interrupted stack is read for VALUEs, C's
    frames and the outer calls' with it, an Array's fetched elements and a
    dmark's are asked, and C's own writes were flushed just before. Under
    MERE_RUBY_GC_STRESS=N it collects at every 16*N-th of these, not every
    N-th: at every one, capi_check's api contracts ran past their 120 s
    bound (a collection every 25 ms of C API calls).
  - the statement's region: what a request makes on the way -- the copy of
    a String's bytes handed to C, the bytes C wrote back before they are a
    String -- went to the region of the statement that called C, which
    stays open for the whole call and which no collection gives back. Each
    request now runs in a region of its own (capi_enter's `up`, region CUP).

  Measured with the same binary otherwise (the "before" is native-gems-r2's
  9aa9a0ce build, what #190 merged), puma's parser on N x 1024 identical
  headers, RSS sampled every 0.25 s from outside:

  | headers | before: peak RSS, collections in the call | after |
  |---|---|---|
  | 12 x 1024 | 5,406 MB, 1 | 276 MB, 33 |
  | 16 x 1024 | 6,759 MB, 1 | 443 MB, 56 |

  (The safepoint alone took 12 x 1024 to 3,157 MB with 32 collections; the
  regions are the rest.) capi/check/api.rb: join_in_c does the parser's join
  400 times with a 64 KB String made and dropped each turn, and the
  collector runs during it, on both sides; hold_locals keeps a String and an
  Array only in C locals across 120 Strings made and 120 calls, and again
  with the call paused halfway in a Fiber while the program makes garbage and
  runs GC.start -- both intact afterwards, on both sides and under
  MERE_RUBY_GC_STRESS=1. capi_check's api file under stress: 33.7 s, the
  same as main's contracts on main's binary (33.5 s).
  The note 553 §7.4 retention (Databases kept by the conservative scan) is
  the same: a Database opened, 20 collations registered, closed, 351 times,
  then GC.start -- 15 Databases left and +25-26 MB on the before binary, 13
  and +25-26 MB after (two runs each; my reconstruction of work2026-fd's
  repro, which counted more: its comparator may differ).
  ⚠ test_horrible_queries itself is NOT run (`--exclude`): its memory is now
  bounded, but its time is not. Every crossing writes back each String C
  touched in the call, which means hashing all of it to see whether C wrote
  -- the 1.1 MB request, 3 crossings per header, 80 x 1024 headers -- and
  the joined header is fetched and written back whole at each append. On
  ruby the test takes milliseconds; here it is hours. What it would take:
  knowing that C wrote into a buffer without reading it all (page
  protection on the mirror's buffer, say), and appending through the
  interpreter when the struct is stale. (Appending by `<<` alone, tried
  this round, was slower: the force_encoding round trip copies.)
- **C's write into a FROZEN String's buffer raised FrozenError** (5 tests
  of Http11ParserTest). puma's parser upcases each header name in place in
  the request it is given -- `X-Strip-Me` becomes `X_STRIP_ME` in the
  caller's String, a frozen literal in these tests, and in ruby the frozen
  String's bytes simply change. Frozen is what rb_str_modify refuses, and
  every function of the C API that changes a String asks it first; the
  write-back (MR_STR_SET, used by nothing else) refused it too. It writes
  the bytes now. capi/check/api.rb: write_frozen.
- **Process.kill with a negative pid** (a process group) answered ESRCH
  for a group that was there. Signals to another process go to kill(1), and
  `kill -s KILL -123` reads `-123` as a second signal ("invalid signal
  specification"); `--` goes before the pid now. The integration helper
  stops an unresponsive server with `Process.kill(:KILL, -pgid)`, so the
  server ran on, its test waited out its 395 s, and the tests after it met
  its leftovers (900-second waits in pumactl and SSL tests that pass alone).
  corpus 911.
- **A trap ran on whichever thread was inside a method, and never while the
  main thread joined.** Signals are delivered at a safepoint "on the main
  thread", and the test for it was `in_thread ()` -- a flag that says a
  Thread body's own statements are running, which every method call clears
  for the method's body (it is the `return` boundary's). puma's TERM trap
  ran on its reactor thread; its stop joined the server thread, which was
  joining the reactor. And a main thread waiting in Thread#join (kind 8)
  was not woken for a signal at all, so a trap whose main thread joins
  never ran. Now delivery asks sig_off_main (in_thread, or under the
  scheduler a thread that is not sch_main), a join is one of the waits a
  signal wakes (sch_trap_wakes) and sch_join runs the waiting trap -- also
  for numbers the scheduler took ("n") -- before it joins on; a thread's
  self-kill from inside a method queues for the main thread too. corpus 912.

## puma 8.1.2 after this round

All reference numbers are ruby 4.0.9 (`~/.rbenv/versions/4.0.9/bin/ruby`,
side.sh's reference side, and the shebang of the binstubs in its GEM_HOME);
mere-ruby is this branch. Each side runs its own copy of the source tree,
with its own built extension in `lib/puma/` and a Gemfile that names it.

Unit (`test/runner -v --unit --seed=1`):

| | runs | assertions | failures | errors | skips |
|---|---|---|---|---|---|
| ruby 4.0.9 | 863 | 2515 | 1 | 1 | 7 |
| mere-ruby | 863 | 2548 | 1 | 1 | 7 |

The reference's two are timing under this machine's load
(test_back_to_back_chunked, test_zero_first_data_timeout_reads_complete_body_without_queue);
both pass here. mere-ruby's two are the timed tests above
(test_write_nonblock_retry_delivers_data_once, RackUp#test_bin). With the
tree's own lib, TestBundlePruner and TestCLI#test_plugins pass on both sides.

Integration (each file on its own, `--exclude=/test_horrible_queries/`,
before the trap fix):

| | runs | failures | errors | skips |
|---|---|---|---|---|
| ruby 4.0.9 | 184 | 6 | 0 | 10 |
| mere-ruby | 184 | 26 | 3 | 10 |

The reference's six are TestWorkerGemIndependence, the same six here: each
runs `bundle install` in a fixture app for other versions of json and
nio4r, which this harness does not fetch. What is left on mere-ruby:

- **prune_bundler (11 tests: 7 cluster, 1 pumactl, 3 preserve_bundler_env).**
  The pruned server re-execs `bin/puma-wild` under
  `Bundler.with_unbundled_env`, which takes bundler's own directory out of
  RUBYLIB; that directory is the reference's stdlib, which is how this
  harness gives mere-ruby its standard library, and puma-wild's
  `require 'rubygems'` then fails. ruby has its stdlib in its own
  rubylibdir, not in RUBYLIB. What it takes: a mere-ruby installed with
  its stdlib at its rubylibdir (MERE_RUBY_STDLIB_FALLBACK only reorders
  directories already on the load path).
- **TERM did not stop a single-mode server (5 tests).** This was the trap
  on the wrong thread (above). After that fix test_integration_single is
  21 runs, 1 failure here against 0 on ruby 4.0.9: the failure is
  test_hot_restart_does_not_drop_connections_threads, whose restarted
  server had not logged its PID when the helper stopped waiting (a slow
  boot, as RackUp#test_bin). By hand -- a mere-ruby puma started from a
  ruby script that does not read its output until the server has had 5 s
  to stop -- TERM still left the server running in 5 of 6 runs, stalled
  in the trap between Server#stop's start and its notify write, with the
  server thread in IO.select; the suite's own helper, which drains the
  output, does not see that. Not understood yet.
- **fork_worker / mold_worker (4 tests)** -- "Worker N failed to check in
  within 2 seconds" and a phase-2 boot not logged in time: a forked
  worker here takes longer than puma's 2 s check-in to start.
- **test_mold_worker_refork_does_not_leak_file_descriptors**: a reforked
  worker has 19 descriptors open where the first had 17 (ruby: equal).
  Observable, not investigated yet.
- **test_horrible_queries** (excluded above), and the two timed unit tests.

## Seen on the way, not fixed

- **`$stdout.reopen(file)` does not share the File's position.** mkmf's
  Logging reopens $stdout onto mkmf.log, and the log came out overwritten
  ("etect_leaks=0 ..." in the middle of a later check). A File here keeps
  its own position and writes through its own buffer (file_write_at,
  `@__f_pos`), so writes to fd 1 after dup2 and the File's own writes land
  at different offsets. ruby's are one open file description. Repro:
  write to the File, reopen $stdout onto it, puts, system("echo"), write
  again -- ruby "A B C D", here "B-via-stD-log\n-child". What it takes:
  a File whose position is the descriptor's.

## Integration on the final binary (a0501bcc's build)

Each file on its own, `--exclude=/test_horrible_queries/`. ruby 4.0.9 first,
then mere-ruby, one at a time. The machine's load average was 10 to 23
(other sessions). The first mere-ruby pass of test_integration_cluster
also ran beside a puma cluster left over from an earlier killed run of
mine: its master had renamed itself, so the runner's pkill missed it, and
a worker had used a core for two hours. The cluster row below is the rerun
after that cluster was killed, with ruby rerun at the same time.

| file | ruby 4.0.9 runs/F/E/S | mere-ruby runs/F/E/S |
|---|---|---|
| test_http11 | 18/0/0/1 | 18/0/0/1 |
| test_integration_cluster (rerun) | 77/0/0/0 | 77/19/1/0 |
| test_integration_helpers | 14/0/0/0 | 14/0/0/0 |
| test_integration_pumactl | 13/0/0/0 | 13/1/0/0 |
| test_integration_single | 21/0/0/0 | 21/1/0/0 |
| test_integration_ssl | 8/0/0/0 | 8/0/0/0 |
| test_integration_ssl_session | 8/0/0/0 | 8/0/0/0 |
| test_plugin | 1/0/0/0 | 1/0/0/0 |
| test_plugin_systemd | 7/0/0/7 | 7/0/0/7 |
| test_plugin_systemd_jruby | 1/0/0/1 | 1/0/0/1 |
| test_preserve_bundler_env | 3/0/0/0 | 3/3/0/0 |
| test_redirect_io | 2/0/0/0 | 2/0/0/0 |
| test_skip_sigusr2 | 1/0/0/0 | 1/0/0/0 |
| test_skip_systemd | 1/0/0/1 | 1/0/0/1 |
| test_url_map | 1/0/0/0 | 1/0/0/0 |
| test_web_concurrency_auto | 2/0/0/0 | 2/0/0/0 |
| test_worker_gem_independence | 6/6/0/0 | 6/6/0/0 |

Mere-only, with a one-line cause:

- prune_bundler, 12: cluster's nio4r/json-not-required (3), prune_bundler_*
  (2) and load_path_* (2), pumactl's prune_bundler_with_multiple_workers, and
  preserve_bundler_env's 3 -- puma-wild cannot `require 'rubygems'` once
  Bundler.with_unbundled_env takes the reference stdlib (this harness's
  RUBYLIB) away. Harness; needs an installed rubylibdir.
- cluster, phase-N boot not logged in time (mold_worker_phased_restart_retires_mold,
  mold_worker_reforks_at_each_threshold, mold_worker_refork_completes_after_mold_dies_during_promotion,
  phased_restart_does_not_drop_connections_threads{,_fork_worker,_mold_worker},
  stuck_external_term_spawn, fork_worker_refork_waits_for_all_workers_after_worker_dies)
  and the fork_worker checks (refork_phased_restart_with_fork_worker_and_high_worker_count,
  fork_worker_after_refork): not understood. The pass before the trap fix had
  fewer of these (12 failures and 1 error in the whole file, against 19 and
  1 now), so the trap fix may have changed how the master reacts to
  URG/USR1/TERM/CHLD; to be measured.
- cluster test_thread_log (INFO, "Thread: TID-" not logged): not understood.
  By hand, INFO to a `-w 1` master under mere-ruby logs the threads.
- cluster test_mold_worker_refork_does_not_leak_file_descriptors (19 against
  17 descriptors in a reforked worker): not understood.
- hot_restart_does_not_drop_connections_threads (single and cluster): the
  restarted server had not logged its PID when the helper stopped waiting.
  Not understood; the variant without threads passes.

## Paused (2026-11-24)

The user paused all sessions.

- Done and committed: everything up to the per-file integration table above
  (puma fixes 8e73b184, 761f7d85, a0a5cb43, 8f75e0cc, the merge of main
  cd2fdb4b, and the records). The test_write_nonblock look is in the timed
  tests section above: no fix taken, recorded.
- The integration run had completed: every file on both sides, and the
  cluster file once more on both sides, with the numbers in the table
  above. Nothing was running when the pause came, and no process of this
  work is left.
- Next on resume: rerun puma's full integration suite on both sides, one at
  a time (use the scratch runner that kills renamed masters); look into the
  cluster reforks and signals that the trap fix may have changed; then the
  test_write_nonblock look again if wanted; then nokogiri at corpus 915,
  after asking the coordinator for numbers.

## Resumed (2026-11-25): the cluster file

The reference is ruby 4.0.10 from here on (`~/.rbenv/versions/4.0.10/bin/ruby`,
#208): side.sh's REF, a fresh GEM_HOME per side with the same puma gem set
installed by `gem install --local`, the reference tree's extension built by
4.0.10, and the binstubs' shebangs. main merged twice (91251a0b, b95ccc97:
#237's libdir and #238's hidden IDs), built with the CI-pinned Mere
(mere-wt-9dec, 9dec2ff6), and puma's and nio4r's extensions rebuilt on the
mere side after #237.

Taken one group at a time (the mold_worker tests, 13), the cluster failures
were not the trap fix itself but two things it uncovered:

- **A signal taken on a busy thread waited for the main thread for ever.**
  8f75e0cc delivers a trap only on the main thread, and a thread that takes
  the signal at a statement leaves it queued for it. Only the scheduler's
  idle wait (sch_sig_check) woke the main thread for it, so in a process
  whose threads never all wait -- a puma worker serving requests, its main
  thread joining the server thread -- the trap never ran: the master logged
  "Promoting worker N to mold" and the worker never became one. sig_poll
  now wakes the main thread the same way when it waits in a wait a trap
  may run in the middle of (a sleep, a join, a queue). Repro: a thread busy in `n += 1 until $stop`, the
  main thread joining it, USR2 from outside -- ruby 4.0.10 runs the trap
  on the main thread; this hung. corpus 916.
- **accept(2) on a listener another process accepts on.** A cluster's
  workers all accept on one listener; readiness says a connection waits,
  another worker takes it, and accept(2) says EAGAIN -- or ECONNABORTED for
  a client gone before it was taken. The runtime's tcp_accept folds errno
  into three codes, and every refusal was SocketError "accept failed":
  puma logged it as a "Listen loop" error, 60 in one mold test group. Now
  accept goes through tools/socket_glue.c `mr_sock_accept` (-errno), and
  BasicSocket#__accept_now answers as ext/socket/init.c does: nonblocking,
  EAGAIN/EWOULDBLOCK is IO::EAGAINWaitReadable and ECONNABORTED/EPROTO the
  Errno with IO::WaitReadable (`exception: false`: :wait_readable);
  blocking, EAGAIN waits again; anything else is its Errno. TCPServer,
  UNIXServer and Socket. Repro: a connection
  taken by a forked process, then accept_nonblock and a blocking accept;
  and three forked processes accepting 120 connections on one listener,
  which hung here. corpus 917.

With both, the mold_worker group (13 tests) went from 6 failures to 3 on
mere-ruby, measured at a load average of 36 to 53 on this 10-core machine
(other sessions' measurements); ruby 4.0.10 passes all 13 at the same load.
Still open in the group:
- test_mold_worker_refork_replaces_workers_forked_by_previous_mold and
  test_mold_worker_reforks_at_each_threshold: a phase-2 (or phase-1) worker
  not booted in time. In each log the master first says "Out-of-sync worker
  list, no <pid> worker" twice for the worker it has just TERMed: it has
  dropped that worker from its list before the worker's last pipe messages
  came in. Neither Process.wait2 nor Process.kill(0, pid) on a grandchild
  differs from ruby (checked by hand), so the cause is not found yet.
- test_mold_worker_refork_does_not_leak_file_descriptors: 19 descriptors
  in a reforked worker against 17. Not investigated yet.

### Before and after, against main's build

main 2e402b94 built in a spare worktree with the same compiler
(mere-wt-9dec), and the two corpus cases run on ruby 4.0.10, main's build
and this branch's, each bounded at 20 s (`perl -e 'alarm 20; exec @ARGV'`;
exit 142 is that bound):

| case | ruby 4.0.10 | main 2e402b94 | this branch |
|---|---|---|---|
| 916 busy-thread trap | `true`, `[true]` | no output, exit 142 | `true`, `[true]` |
| 917 accept errno | 4 lines, `120`, `[]` | the first 4 lines, then exit 142 in the three-process race | the same 6 lines as ruby |

On main, 917's single-process part already matched: there the listener is
no longer ready when the other process has taken the connection, and the
old readiness check answered EAGAIN. The race is what main gets wrong: a
connection taken between readiness and accept(2) went to the blocking
accept, which waited for the next connection, and the children never
reported.

### test_integration_cluster in groups, on three builds

Each group alone, one build at a time: ruby 4.0.10, this branch, and main
2e402b94 built with the same compiler, with a GEM_HOME and puma tree of
its own (puma's extension built by main's own mkmf, so without MiniSSL:
main's RbConfig says no OpenSSL directory). The load average was 25 to 45
throughout (once 140), from other sessions; every failure below that hit a
time limit is listed apart from the others.

| group (tests) | ruby 4.0.10 | this branch | main 2e402b94 |
|---|---|---|---|
| mold_worker (13) | 0 | 3 F | 5 F |
| fork_worker (14) | 0 | 4 F, 1 E | runner ends in test_fork_worker_coalesces_pending_reforks (twice); the other 13: 3 F, 1 E |
| prune_bundler, load_path, not_required (7) | 0 | 7 F | 7 F |
| the rest, half 1 (22) | 0 | 1 E | 2 E |
| the rest, half 2 (21) | 0 | 0 | 1 F |

"Listen loop: SocketError accept failed" lines: 50 in main's mold_worker
group, 0 on this branch. test_thread_log passes on this branch.

## Left

Each with its cause and main's build on the same test (above).

Failures that are not time limits:
- **prune_bundler (cluster 7, pumactl 1, preserve_bundler_env 3).**
  puma-wild cannot `require 'rubygems'` once Bundler.with_unbundled_env
  removes the reference stdlib from RUBYLIB, which is how this harness
  gives mere-ruby its stdlib. Main: the same 7 of 7 in the cluster group.
  What it takes: a mere-ruby installed with its stdlib at its rubylibdir.
- **test_mold_worker_refork_does_not_leak_file_descriptors**: a reforked
  worker has 19 descriptors open, ruby's 17. Main: the same (19 against 17).
  Not investigated.

Failures at a time limit (a log line not seen in time, TestTookTooLong, or
puma's 2 s worker check-in):
- mold_worker: refork_replaces_workers_forked_by_previous_mold (phase 2 not
  booted; main the same), reforks_at_each_threshold (phase 1; main the same).
  Both logs show "Out-of-sync worker list" for the worker just TERMed; cause
  not found.
- fork_worker: phased_restart_with_fork_worker_worker_order and
  refork_phased_restart_with_fork_worker_and_high_worker_count ("Worker N
  failed to check in within 2 seconds"), fork_worker_refork_waits_for_all_workers_after_worker_dies
  ("cluster ready" not logged): main fails all three the same way.
  phased_restart_with_fork_worker_and_high_worker_count (TestTookTooLong
  here; main failed it once and passed it once) and
  fork_worker_phased_restart_does_not_wait_for_check_interval (failed once
  and passed once here; main passed twice) are flaky at this load.
- hot_restart_does_not_drop_connections (cluster): TestTookTooLong; main
  errs on it and on its _threads variant.
- test_integration_single's hot_restart_does_not_drop_connections_threads:
  from the full run before the pause; not rerun on main's build yet.
- Unit: test_write_nonblock_retry_delivers_data_once (16 MiB through
  MiniSSL, quadratic here; see above) and RackUp#test_bin (boot takes 2.7 s
  against 0.27 s). Main's build has no MiniSSL at all (no OpenSSL directory
  in its RbConfig), so the first is not run there.
- test_horrible_queries (excluded): bounded memory now, quadratic time.

Checks on this build (b95ccc97 + the two fixes, built with mere-wt-9dec):
`run_corpus.sh --both` -- the gates, then 887/887 with the hash index on
and off; `tools/iseq/vm_corpus.sh` -- 887 on the VM, 0 fell back, 0 FAIL.
capi_check, capi_spec_check, capi_mkmf_check, puma's full integration run
and the gem check are still to be run on it, after asking.

### Unit at 4.0.10 (0238f6ef)

This replaces the 4.0.9 unit table above. `test/runner -v --unit --seed=1`, ruby 4.0.10
first, then mere-ruby built at 0238f6ef (puma's extension rebuilt with its
mkmf first), each with its own tree and GEM_HOME, one at a time. Load
average 11.1 at the start, 6.6 at the end.

| | runs | assertions | failures | errors | skips |
|---|---|---|---|---|---|
| ruby 4.0.10 | 863 | 2526 | 0 | 0 | 7 |
| mere-ruby 0238f6ef | 863 | 2527 | 1 | 1 | 7 |

- Error, TestMiniSSLSocket#test_write_nonblock_retry_delivers_data_once:
  Timeout::Error at the test's 10 s bound -- 16 MiB through MiniSSL, where
  `byteslice(n..-1)` copies the tail and RSTRING_PTR fetches it again, so
  the loop is quadratic here (see the timed tests above).
- Failure, TestRackUp::RackUp#test_bin: the one read at 2.7 s finds only
  "Puma starting in single mode..."; booting rackup + puma takes 2.7 s here
  against 0.27 s (see above).
- The skips are the same seven on both sides: SSLv3, three JRuby-only,
  two abstract UNIX sockets, a Linux-only thread name.

## Checks on 0238f6ef (main 8b1b9525 merged, reference ruby 4.0.10)

Gates, bracket_depth and record_hygiene pass; `run_corpus.sh --both` 900/900
with the hash index on and off; `tools/iseq/vm_corpus.sh` 900 on the VM, 0
fell back, 0 FAIL; capi_check (both sides, under stress, controls fail),
capi_spec_check and capi_mkmf_check pass.

capi_gem_check failed twice in a row, on the reference side: ruby 4.0.10's
own `gem install prism` was killed at the 2 GiB limit (2,118,784 KB after
6.7 s at load 28.78 → 32.34; 2,109,760 KB after 5.2 s at load 20.27 →
14.57). RubyGems adds `-j<nprocessors>` (10 here) to make when MAKEFLAGS has
no `-j` (rubygems/ext/builder.rb:46-47); the check removes MAKEFLAGS and
measures the whole process tree, so prism's C files compile ten at a time.
The reference side does not run this branch's build: the same install
peaked at 1,922,944 KB and passed in the morning's run for #253, at load 59,
where the compiles overlapped less. So `use` differs only in prism's two
lines (the reference falls back to its default prism 1.8.2; mere-ruby
installed 2.1.0, 797,680 KB, 28 s); the other 171 lines are the same and
every other gem installs on both sides. The check is not changed here.
