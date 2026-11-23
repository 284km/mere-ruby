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
