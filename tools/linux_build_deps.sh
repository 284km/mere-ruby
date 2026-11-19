#!/bin/sh
# Use working compiler/OpenSSL installations before asking an apt mirror.
set -eu
deps_tmp="$(mktemp -d "${TMPDIR:-/tmp}/mere-linux-deps.XXXXXX")"
trap 'rm -rf "$deps_tmp"' EXIT HUP INT TERM
cat > "$deps_tmp/probe.c" <<'C'
#include <openssl/ssl.h>
#include <openssl/crypto.h>
int main(void) {
  SSL_CTX *ctx = SSL_CTX_new(TLS_method());
  if (!ctx) return 1;
  SSL_CTX_free(ctx);
  return OpenSSL_version_num() == 0;
}
C
deps_ready() {
  command -v clang >/dev/null 2>&1 &&
    command -v pkg-config >/dev/null 2>&1 &&
    pkg-config --exists openssl &&
    clang "$deps_tmp/probe.c" -o "$deps_tmp/probe" $(pkg-config --cflags --libs openssl) &&
    "$deps_tmp/probe"
}
if deps_ready >/dev/null 2>&1; then
  echo 'Linux compiler and OpenSSL probe passed; no package download needed.'
  exit 0
fi
sudo apt-get update
sudo apt-get install -y clang libssl-dev pkg-config
# A successful installer is insufficient if the headers, linker or runtime
# remain unusable. Propagate a failed real probe instead of running unmeasured.
deps_ready
