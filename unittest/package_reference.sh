#!/bin/sh
# Keep the cached runtime's archive layout in a versioned build definition.
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${1:-$root}"
archive=$(.reference-ruby/bin/ruby -rrbconfig -e 'print RbConfig::CONFIG.fetch("LIBRUBY_A")')
tar -czf reference-runtime.tar.gz .reference-ruby .ruby-tests/.ext \
  .ruby-tests/Makefile ".ruby-tests/$archive" .ruby-tests/enc/unicode/data .ruby-tests/exe/gem
