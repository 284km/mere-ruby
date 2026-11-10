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

The standalone availability probe is in `stdlib_availability.tsv`. The next
stdlib work is `uri` and `timeout`, then `net/protocol`, `net/http`, `open-uri`
and `resolv`. External Net::HTTP already exercises the implemented native TLS
provider successfully. These measurements remain optional because they need
an installed gem home; independent OpenSSL format and resource gates run in CI.

The legacy `run.sh <gem-home> <rubygems-checkout> [stdlib-dir]` remains
available; `GEMLIST` selects another gem list for that script. It reports
`SKIP` when its reference cannot load a gem. Use `measure.py` for the pinned
reference, saved logs and bounded process-family measurements above.

Excon 0.110.0 completes trusted HTTPS in both native modes. Its negative-peer
paths hit an interpreter dispatch gap while wrapping the correctly rejected
TLS peer: an implicit `set_backtrace` call in a custom exception initializer
raises `NoMethodError`. Run `gemtest/exception_backtrace_probe.rb` under both
interpreters for the independent minimal reproduction. Reference Excon also
fails its trusted and wrong-CA runs with `EPIPE` in this environment; these
failures remain explicit in the record and are not called matching successes.
The next small core task is that implicit exception-method dispatch, before
the stdlib dependency sequence above.
