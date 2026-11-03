#!/bin/sh
# Build the pinned reference and the test-only extensions an installed Ruby
# does not ship. The caller checks out the requested source revision first.
set -eu
src="$(cd "${1:?usage: build_reference.sh <ruby-src> <prefix>}" && pwd)"
prefix="$2"
mkdir -p "$prefix"
prefix="$(cd "$prefix" && pwd)"
cd "$src"
./autogen.sh
./configure --prefix="$prefix" --enable-load-relative --disable-install-doc \
  --enable-yjit --enable-zjit \
  --with-openssl-dir="$(brew --prefix openssl@3)" \
  --with-libyaml-dir="$(brew --prefix libyaml)" \
  --with-ext=-test-/integer,-test-/file,-test-/iter,-test-/rb_call_super_kw,openssl,psych,+
make -j3
make install-nodoc
arch="$("$prefix/bin/ruby" -rrbconfig -e 'print RbConfig::CONFIG.fetch("arch")')"
"$prefix/bin/ruby" -I "$src/.ext/$arch" -e '
  abort "unexpected reference version" unless RUBY_VERSION == ENV.fetch("REF_RUBY_VERSION")
  %w[-test-/integer -test-/file -test-/iter -test-/rb_call_super_kw].each { |name| require name }
  puts "reference and test extensions ready"
'
"$prefix/bin/ruby" --yjit -e 'abort "YJIT is unavailable" unless RubyVM::YJIT.enabled?'
"$prefix/bin/ruby" --zjit -e 'abort "ZJIT is unavailable" unless RubyVM::ZJIT.enabled?'
