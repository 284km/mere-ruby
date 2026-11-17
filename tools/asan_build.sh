#!/bin/sh
# An AddressSanitizer build of mere-ruby that also sees region REUSE.
#
#   ./tools/asan_build.sh [out]          # default: ./mere-ruby-asan
#
# Mere's arenas hand memory back without free(): a block region goes back to
# a cache and is bump-reset, a map's private region is wound back to its seed
# by *_recycle. Plain ASan sees neither, so a value read after its arena was
# reused looks fine to it. tools/asan_patch.py edits the emitted C so that
# reuse POISONS the memory and every allocation unpoisons what it hands out,
# and so that a report also prints the interpreter's own innermost call names.
# It found note 269's heap overflow (a recycled map's arena claimed 4 KB of a
# smaller block) from a silent hang.
#
# Run what you suspect with ASAN_OPTIONS=detect_leaks=0:halt_on_error=1, and
# add poison_history_size=4096 to see what poisoned the memory a report names.
# The build takes about 5 minutes and 7 GB at -O1.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
out="${1:-$root/mere-ruby-asan}"
MERE="${MERE:-}"
if [ -z "$MERE" ]; then
  for c in "$root/.mere-compiler/_build/default/bin/mere.exe" mere; do
    if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then MERE="$c"; break; fi
  done
fi
[ -n "$MERE" ] || { echo "asan_build: no Mere compiler (set MERE=)" >&2; exit 2; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# (Ruby's C API header the capi/*.c sources include, as tools/build.sh writes it)
(cd "$root" && "$MERE" --ffi-header m_capi_api.mere > capi/mere_capi.h)
(cd "$root" && "$MERE" -c main.mere > "$tmp/mr.c")
python3 "$here/asan_patch.py" "$tmp/mr.c" "$tmp/mr_asan.c"
# The sources, libraries and platform flags tools/build.sh links (the glue,
# Ruby's C API in capi/, libprism, OpenSSL as it finds it); built once there.
plib="$root/vendor/prism/obj/libprism.a"
[ -f "$plib" ] || { echo "asan_build: no $plib (run tools/build.sh once)" >&2; exit 2; }
case "$(uname -s)" in
  Darwin) plat="-Wl,-stack_size,0x20000000" ;;
  *)      plat="-lm -rdynamic -ldl"; ulimit -s 524288 || exit 2 ;;
esac
ossl_prefix="${OPENSSL_PREFIX:-}"
if [ -z "$ossl_prefix" ] && [ "$(uname -s)" = Darwin ] && command -v brew >/dev/null 2>&1; then
  ossl_prefix="$(brew --prefix openssl@3 2>/dev/null)" || exit 2
fi
if [ -n "$ossl_prefix" ]; then
  set -- "-I$ossl_prefix/include" "-L$ossl_prefix/lib" "-Wl,-rpath,$ossl_prefix/lib" -lssl -lcrypto
elif command -v pkg-config >/dev/null 2>&1 && pkg-config --exists 'openssl >= 3.0'; then
  # shellcheck disable=SC2046
  set -- $(pkg-config --cflags --libs openssl)
else
  set -- -lssl -lcrypto
fi
# -D__LANG_CORO_ASAN: the runtime tells ASan about each coroutine switch, which
# it needs once a collection runs on a coroutine of its own (note 270) -- every
# collection, in a build that has them
# shellcheck disable=SC2086
clang -O1 -fsanitize=address -fno-omit-frame-pointer -D__LANG_CORO_ASAN $plat \
  -fbracket-depth=1024 -w -I "$root/vendor/prism/include" "$tmp/mr_asan.c" \
  "$root/tools/prism_glue.c" "$root/tools/socket_glue.c" "$root/tools/math_glue.c" "$root/tools/process_glue.c" \
  "$root/tools/openssl_glue.c" "$root/tools/nkf_glue.c" \
  -DMR_CAPI_BUILD -I "$root/capi/include" -I "$root/capi" -I "$root/capi/vendor" "$root"/capi/*.c \
  -pthread "$plib" "$@" -o "$out"
echo "asan_build: $out"
