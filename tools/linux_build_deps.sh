#!/bin/sh
# Use working compiler/OpenSSL installations before asking an apt mirror.
set -eu
deps_modules='openssl'
deps_packages='clang libssl-dev pkg-config'
deps_cppflags=''
case "$*" in
  '') ;;
  --with-gem-libraries)
    deps_modules="$deps_modules libxml-2.0 libxslt sqlite3"
    deps_packages="$deps_packages libxml2-dev libxslt1-dev libsqlite3-dev"
    deps_cppflags='-DMERE_WITH_GEM_LIBS=1' ;;
  *) echo 'usage: linux_build_deps.sh [--with-gem-libraries]' >&2; exit 2 ;;
esac
deps_tmp="$(mktemp -d "${TMPDIR:-/tmp}/mere-linux-deps.XXXXXX")"
trap 'rm -rf "$deps_tmp"' EXIT HUP INT TERM
cat > "$deps_tmp/probe.c" <<'C'
#include <openssl/ssl.h>
#include <openssl/crypto.h>
#ifdef MERE_WITH_GEM_LIBS
#include <libxml/parser.h>
#include <libxslt/xslt.h>
#include <sqlite3.h>
#endif
int main(void) {
  SSL_CTX *ctx = SSL_CTX_new(TLS_method());
  if (!ctx) return 1;
  SSL_CTX_free(ctx);
#ifdef MERE_WITH_GEM_LIBS
  xmlInitParser();
  xsltInit();
  xsltCleanupGlobals();
  xmlCleanupParser();
  if (sqlite3_libversion_number() == 0) return 1;
#endif
  return OpenSSL_version_num() == 0;
}
C
deps_ready() {
  command -v clang >/dev/null 2>&1 &&
    command -v pkg-config >/dev/null 2>&1 &&
    pkg-config --exists $deps_modules &&
    clang $deps_cppflags "$deps_tmp/probe.c" -o "$deps_tmp/probe" $(pkg-config --cflags --libs $deps_modules) &&
    "$deps_tmp/probe"
}
if deps_ready >/dev/null 2>&1; then
  echo 'Required native headers, linker and runtime probe passed; no package download needed.'
  exit 0
fi
# An unrelated image-provided repository may reject its index update even
# though the required Ubuntu package indexes were refreshed successfully.
# Attempt authenticated installation, then require the real probe below.
if ! sudo apt-get update; then
  echo 'Some package indexes did not update; attempting required packages and verifying the resulting toolchain.' >&2
fi
sudo apt-get install -y $deps_packages
# A successful installer is insufficient if the headers, linker or runtime
# remain unusable. Propagate a failed real probe instead of running unmeasured.
deps_ready
