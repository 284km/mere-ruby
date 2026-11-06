#!/bin/sh
# Regenerate vendor/prism from a Ruby source tree (see vendor/prism/README.md).
#
#   sh tools/gen_prism_src.sh <ruby-src>
#
# The generated C and headers come from prism/templates/template.rb, run with
# the reference ruby (tools/ref_ruby.sh); the hand-written ones are copied.
# The Ruby half (lib/prism/*.rb) is not vendored: the load path carries it.
set -eu
src="${1:?usage: tools/gen_prism_src.sh <ruby-src>}"
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
out="$root/vendor/prism"
[ -f "$src/prism/prism.c" ] || { echo "gen_prism_src: $src has no prism/prism.c" >&2; exit 2; }
# shellcheck disable=SC1091
. "$here/ref_ruby.sh"
ruby="${REF_RUBY:-ruby}"

rm -rf "$out/include" "$out/src"
mkdir -p "$out/include/prism/util" "$out/src/util"
for f in include/prism/ast.h include/prism/diagnostic.h \
         src/diagnostic.c src/node.c src/prettyprint.c src/serialize.c src/token_type.c; do
  (cd "$src/prism" && "$ruby" templates/template.rb "$f" "$out/$f")
done
for f in prism.c encoding.c regexp.c options.c static_literals.c pack.c; do
  cp "$src/prism/$f" "$out/src/$f"
done
cp "$src/prism/util/"*.c "$out/src/util/"
cp "$src/prism/prism.h" "$out/include/prism.h"
for h in "$src/prism/"*.h; do
  b="$(basename "$h")"
  [ "$b" = prism.h ] || cp "$h" "$out/include/prism/$b"
done
cp "$src/prism/util/"*.h "$out/include/prism/util/"
ver="$(sed -n 's/^#define PRISM_VERSION "\(.*\)"/\1/p' "$out/include/prism/version.h")"
echo "gen_prism_src: vendor/prism is now Prism $ver from $src"
