# Gem and HTTPS measurements

`measure.py` runs the existing 29-gem list in separate processes under a pinned
Ruby 4.0.9 reference and mere-ruby, with and without an external stdlib. Both
interpreters use the same installed gem home and RubyGems source checkout.
Each process family is limited to 120 seconds and 2 GiB; stdout, stderr, exit,
resource limits and reference availability are recorded. Use a fresh output
directory for every run.

```sh
python3 gemtest/measure.py --binary ./mere-ruby \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --gem-home /path/to/installed/gem-home \
  --rubygems /path/to/ruby-source-3e93b23 \
  --output /tmp/gem-measure-new
```

The Ruby source checkout must be `3e93b23afcec3433f6aecc34b5d832799d754238`.
The external stdlib comes from the reference installation's `rubylibdir` and
installed bundled/default gem `lib` directories. Installed gem libraries are
available in both native modes; “bundled” means no additional stdlib `-I`,
not an empty gem home. Loading a gem does not establish that its operations
work. Reference-unavailable gems are recorded separately from divergences.

On 2026-11-10, the reference loads 23 of 29 gems. Both native modes load all
23, with no timeouts, crashes or memory-limit hits. The other six require
Rails application setup or native dependencies unavailable to the reference.
`latest.json` records each result, exclusions, binary identity and a digest
of the installed gemspec manifest. The manifest itself stays local.

`https_measure.py` uses a local Python TLS server and independently generated
reference certificates. It checks real binary HTTP responses, explicit trust,
wrong trust and hostname rejection. The server sends TLS `close_notify`;
clients never disable certificate validation. Each child is bounded to 30
seconds and 1 GiB. It records missing libraries and operational errors as
distinct results.

```sh
python3 gemtest/https_measure.py --binary ./mere-ruby \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --gem-home /path/to/installed/gem-home \
  --rubygems /path/to/ruby-source-3e93b23 \
  --output /tmp/https-measure-new
```

Omit both `--gem-home` and `--rubygems` to measure SSLSocket and Net::HTTP
alone. With them, the existing Excon gem is measured too. See
`https_latest.json` for successes and remaining client failures.

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
