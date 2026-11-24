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
- **TERM does not stop a single-mode server (5 tests, and the cluster
  hot restart).** With the trap fix the trap runs on the main thread and
  reaches Puma::Server#stop; in most runs (5 of 6 by hand) it then stalls
  before the stop command is written to the server's notify pipe, with the
  server thread still in IO.select. Not understood yet; next.
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
