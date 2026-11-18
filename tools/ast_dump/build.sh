#!/bin/sh
# Build tools/ast_dump/ast_dump (see main.mere). Needs the Mere compiler
# (MERE, as tools/build.sh) and vendor/prism/obj/libprism.a, which
# tools/build.sh makes.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
MERE="${MERE:-$root/.mere-compiler/_build/default/bin/mere.exe}"
[ -f "$root/vendor/prism/obj/libprism.a" ] || { echo "ast_dump: no vendor/prism/obj/libprism.a (run tools/build.sh once)" >&2; exit 2; }
"$MERE" -c "$here/main.mere" > "$here/ast_dump.c"
clang ${AST_DUMP_OPT:--O1} -w -Wl,-stack_size,0x20000000 -fbracket-depth=1024 -I "$root/vendor/prism/include" \
  "$here/ast_dump.c" "$root/tools/prism_glue.c" "$root/vendor/prism/obj/libprism.a" -o "$here/ast_dump"
