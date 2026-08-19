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
# MERE overrides the compiler, for a checkout that is not on PATH.
"${MERE:-mere}" -w "$root/main.mere" > "$here/mere-ruby.wat"
wat2wasm --enable-tail-call "$here/mere-ruby.wat" -o "$here/mere-ruby.wasm"
rm -f "$here/mere-ruby.wat"
echo "built $here/mere-ruby.wasm ($(wc -c < "$here/mere-ruby.wasm" | tr -d ' ') bytes)"

# A rebuild picks up the compiler's lowering changes, and a Wasm module does not
# instantiate at all if one import is missing a stub -- which is how the page
# broke the last two times. Ask the module what it wants, and ask the page for it.
# (v0.1.277 added __lang_float_of_str_ok this way: validity comes back separately
# from the value, because the host answers NaN for both "nan" and "not a float".)
missing=""
for name in $(wasm-objdump -x "$here/mere-ruby.wasm" \
              | sed -n '/^Import\[/,/^Function\[/p' \
              | sed -n 's/.*<- env\.//p'); do
  grep -q "$name" "$here/index.html" || missing="$missing $name"
done
[ -z "$missing" ] || { echo "index.html has no stub for:$missing"; exit 1; }
echo "every import has a stub in index.html"

# ... and the page has to AGREE with the native build, not merely run. smoke.mjs
# drives this .wasm with index.html's own host code; a bigger JS stack than
# node's default is the browser-side equivalent of -Wl,-stack_size (PAIN.md §M9).
if [ -x "$root/mere-ruby" ] && command -v node > /dev/null; then
  prog='p [Float("1.5"), Float("-2"), 1.0 / 3]
puts "%.5f" % (2.0 ** 0.5)
p [1, 2, 3].map {|x| x * 2 }.sum'
  if node --stack-size=8000 "$here/smoke.mjs" "$prog" > "$here/.smoke.wasm.out" 2>&1 &&
     "$root/mere-ruby" /dev/stdin > "$here/.smoke.native.out" 2>&1 << RUBY
$prog
RUBY
  then
    if diff -u "$here/.smoke.native.out" "$here/.smoke.wasm.out"; then
      echo "the page's output matches the native build"
    else
      rm -f "$here/.smoke.wasm.out" "$here/.smoke.native.out"
      echo "the page and the native build disagree (above)"; exit 1
    fi
  else
    cat "$here/.smoke.wasm.out" "$here/.smoke.native.out" 2>/dev/null
    rm -f "$here/.smoke.wasm.out" "$here/.smoke.native.out"
    echo "smoke run failed"; exit 1
  fi
  rm -f "$here/.smoke.wasm.out" "$here/.smoke.native.out"
else
  echo "skipping the comparison: it needs ../mere-ruby and node"
fi
