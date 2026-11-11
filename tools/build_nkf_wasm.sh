#!/bin/sh
# Use WASI SDK 34.0 (clang 23.1), https://github.com/WebAssembly/wasi-sdk.
# Building never downloads a toolchain implicitly.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${WASI_SDK_PATH:?set WASI_SDK_PATH to the extracted wasi-sdk-34.0 directory}"
cc="$WASI_SDK_PATH/bin/clang"
"$cc" --version | head -1 | rg 'clang version 23\.1\.' >/dev/null || {
  echo 'NKF reactor requires WASI SDK 34.0 / clang 23.1' >&2; exit 1;
}
set --
for name in reset options convert guess result encoding_bytes base_encoding_bytes clear_result cleanup wasm_alloc wasm_free; do
  set -- "$@" "-Wl,--export=mr_nkf_$name"
done
if [ "${NKF_WASM_TEST:-0}" = 1 ]; then
  set -- "$@" -DMR_NKF_TEST -Wl,--export=mr_nkf_test_fail_after -Wl,--export=mr_nkf_test_allocations
fi
"$cc" -O2 -DMR_NKF_WASM -mexec-model=reactor "$root/tools/nkf_engine.c" "$@" -o "${NKF_WASM_OUTPUT:-$root/docs/nkf.wasm}"
