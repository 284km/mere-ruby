# Gem and HTTPS measurements

`measure.py` runs the existing 29-gem list in separate processes under a pinned
Ruby 4.0.9 reference and mere-ruby, with and without an external stdlib. Both
interpreters use the same isolated gem home and RubyGems source checkout.
Each process family is limited to 120 seconds and 2 GiB; stdout, stderr, exit,
resource limits and reference availability are recorded. Use a fresh output
directory for every run.

```sh
python3 gemtest/measure.py --binary ./mere-ruby \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --gem-home /path/to/snapshot \
  --rubygems /path/to/ruby-source-3e93b23 \
  --snapshot-lock gemtest/snapshot.lock.json \
  --output /tmp/gem-measure-new
```

The Ruby source checkout must be `3e93b23afcec3433f6aecc34b5d832799d754238`.
The external stdlib comes from the reference installation's `rubylibdir` and
installed bundled/default gem `lib` directories. Installed gem libraries are
available in both native modes; “bundled” means no additional stdlib `-I`,
not an empty gem home. Loading a gem does not establish that its operations
work. Reference-unavailable gems are recorded separately from divergences.

The source environment is independent of the user's Ruby installation. Restore
it from the committed lock into a fresh directory with the pinned reference:

```sh
/path/to/ruby-4.0.9/bin/ruby gemtest/restore_snapshot.rb \
  --lock gemtest/snapshot.lock.json --output /path/to/snapshot \
  --cache /path/to/package-cache
```

The lock records 278 package archives, versions, runtime dependencies and source
tree SHA256 digests. Public archives come from RubyGems; a replay refuses changed
archives or extracted source. `measure.py --snapshot-lock` verifies sources
before and after the complete run and preserves the per-row gemspec guard.
Packages are extracted without rebuilding native extensions, keeping the prior
load-only boundary. Implicit stdlib roots such as logger are included. The
original version inventory is only needed when regenerating a lock with
`--inventory`; `--private-archive` can then supply the exact private package.
Archives and extracted sources remain outside this repository. This lock keeps
the original macOS package platforms; it does not establish Linux gem loading.

On 2026-11-10, the reference loads 22 of the unchanged 29-name list. Both native
modes load all 22, with no timeouts, crashes or memory-limit hits. Six cases
require Rails setup or unavailable native dependencies. Private sidekiq-pro
7.2.0 could not be recovered after the old shared home disappeared; it remains
an explicit source-unavailable case, with no replacement package. The prior
23-case result remains in Git history. `latest.json` records current rows,
exclusions, final binary identity, lock digest and gemspec manifest digest.
A source-mutation negative control and a fresh locked replay were verified.

`https_measure.py` uses a local Python TLS server and independently generated
reference certificates. It checks real binary HTTP responses, explicit trust,
wrong trust and hostname rejection. The server sends TLS `close_notify`;
clients never disable certificate validation. Each child is bounded to 30
seconds and 1 GiB. It records missing libraries and operational errors as
distinct results.

```sh
python3 gemtest/https_measure.py --binary ./mere-ruby \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --gem-home /path/to/snapshot \
  --rubygems /path/to/ruby-source-3e93b23 \
  --output /tmp/https-measure-new
```

Omit both `--gem-home` and `--rubygems` to measure SSLSocket and Net::HTTP
alone. With them, the existing Excon gem is measured too. See
`https_latest.json` for all 21 passing cases on the same final binary and locked sources.

`uri` 1.1.1, `timeout` 0.6.0, `net/protocol` 0.2.2, `net/http` 0.9.1,
`open-uri` 0.5.0 and `resolv` 0.7.2 are embedded from the pinned Ruby source,
with licensed `net/ftp` 0.3.9 and `resolv-replace` 0.1.1 dependencies.
`stdlib_availability.tsv` records standalone loading without external paths.
Use `--require-bundled` to make standalone Net::HTTP mandatory; `--modes`
selects a subset. CI runs independent DNS peers, standalone HTTPS and the
30 nonempty upstream test files on both macOS and Linux. Reference tests use
`UNITTEST_REF_EXT_PATH="$PWD/vendor/network/lib"` to prevent RubyGems from
activating a newer installed network library than the pinned source.

The legacy `run.sh <gem-home> <rubygems-checkout> [stdlib-dir]` remains
available; `GEMLIST` selects another gem list for that script. It reports
`SKIP` when its reference cannot load a gem. Use `measure.py` for the pinned
reference, saved logs and bounded process-family measurements above.

Excon 0.110.0 now passes verified HTTPS, wrong CA and wrong hostname in
reference, native bundled and native external modes. Implicit native Exception
methods dispatch correctly from custom initializers; the independent witness is
`exception_backtrace_probe.rb` and corpus/582. The earlier reference EPIPE was
isolated to nonblocking localhost fallback: localhost resolves to IPv6 then
IPv4, while the fixture listens on IPv4. Both interpreters pass with an explicit
IPv4 endpoint and `ssl_verify_peer_host: 'localhost'`, retaining hostname and
SNI verification. Blocking reference Excon also passed. The measurement now
uses that controlled endpoint; it never disables verification.

The shipped Wasm host supports URI operations and DNS/IP value codecs. It
reserves 512 MiB because this combined program uses about 259 MiB of heap.
`Timeout.timeout(0/nil)` works; nonzero asynchronous deadlines raise
`NotImplementedError` on the target without suspending fibers. Browser sockets,
TLS and DNS transport remain unavailable. `network_wasm_check.py` executes the
actual shipped HTML host and Wasm artifact.
