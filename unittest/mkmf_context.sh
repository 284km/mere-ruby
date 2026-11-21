#!/bin/sh
# Stage the build tree ruby's test/mkmf expects, for mere-ruby, and print the
# path of a launcher that runs mere-ruby inside it.
#
#   mkmf_context.sh <mere-ruby> <ruby source tree> <directory> <stdlib path>
#
# The reference side of the unit tests runs test/mkmf in the reference's own
# build tree (build_reference.sh). mere-ruby has no such tree -- its headers
# are capi/include beside the executable -- so one is laid out here, of
# links, in the shape mkmf's build-tree mode ($extmk) reads:
#
#   <dir>/source/lib/mkmf.rb         ruby's own, so that its parent's parent is <dir>/source
#   <dir>/source/include          -> capi/include     (ruby.h)
#   <dir>/build/.ext/include/<arch> -> capi/include   (ruby/config.h)
#   <dir>/build/Makefile             written by mere-ruby's own create_makefile
#   <dir>/ruby                       the launcher: mere-ruby -r mkmf_context.rb
#
# Prints nothing and exits 1 when this mere-ruby has no C API to describe.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="$1"; src="$2"; dir="$3"; stdlib="$4"
hdr="$(RUBYLIB="$stdlib" "$mr" -e 'print RbConfig::CONFIG["rubyhdrdir"].to_s')" || exit 1
[ -n "$hdr" ] && [ -f "$hdr/ruby.h" ] || exit 1
arch="$(RUBYLIB="$stdlib" "$mr" -e 'print RbConfig::CONFIG["arch"]')" || exit 1
rm -rf "$dir"
mkdir -p "$dir/source/lib" "$dir/build/.ext/include" || exit 1
cp "$src/lib/mkmf.rb" "$dir/source/lib/mkmf.rb" || exit 1
ln -s "$hdr" "$dir/source/include" || exit 1
ln -s "$hdr" "$dir/build/.ext/include/$arch" || exit 1
{
  printf '#!/bin/sh\n'
  printf 'UNITTEST_MKMF_SOURCE=%s UNITTEST_MKMF_BUILD=%s exec %s -r %s "$@"\n' \
    "'$dir/source'" "'$dir/build'" "'$mr'" "'$here/mkmf_context.rb'"
} > "$dir/ruby" || exit 1
chmod +x "$dir/ruby" || exit 1
# (topdir's Makefile, which test/mkmf/base.rb reads for CC_WRAPPER: the one
#  this interpreter's mkmf writes for an extension of no sources)
(cd "$dir/build" && RUBYLIB="$dir/source/lib:$stdlib" "$dir/ruby" -rmkmf -e 'create_makefile("mkmf_environment")' >/dev/null 2>"$dir/context.err") || exit 1
[ -f "$dir/build/Makefile" ] || exit 1
printf '%s\n' "$dir/ruby"
