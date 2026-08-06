#!/bin/sh
# Regenerate docs/mere-ruby.wasm from main.mere for the browser playground.
#
#   mere -w main.mere            emits WAT (the uniform-i64 Wasm backend,
#                                Mere v0.1.127+)
#   wat2wasm --enable-tail-call  assembles it (Mere emits return_call_indirect)
#
# The page (docs/index.html) fetches the .wasm next to it and drives it with a
# host that returns the editor's source from read_file "@mere-ruby-playground@"
# and routes puts / print_no_nl to the output panel. See run_cli in main.mere.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
mere -w "$root/main.mere" > "$here/mere-ruby.wat"
wat2wasm --enable-tail-call "$here/mere-ruby.wat" -o "$here/mere-ruby.wasm"
rm -f "$here/mere-ruby.wat"
echo "built $here/mere-ruby.wasm ($(wc -c < "$here/mere-ruby.wasm" | tr -d ' ') bytes)"
