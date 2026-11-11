#!/bin/sh
# Build mere-ruby. Two modes, because they answer different questions.
#
#   ./tools/build.sh            -O2 -- the build that sweeps and the build that ships
#   ./tools/build.sh --fast     -O1 -- the build for "edit, run one witness, edit again"
#   ./tools/build.sh --cc-only  skip the emit and compile the mr.c that is there
#
# Measured 2026-09-22 on this machine (Apple silicon), `/usr/bin/time -p`:
#
#   emit -- mere -c main.mere > mr.c      41s   inside the Mere compiler; not
#                                               reducible from this repository
#   clang -O2                            112s   a corpus program then runs in 0.04s
#   clang -O0                             30s   the same program runs in 0.07s
#
# 3.7x off the build for 1.7x on the run. Fifteen builds in a working day is
# normal here, so --fast is about twenty minutes of a day.
#
# ⚠ --fast WAS -O0, and -O0 stopped being able to run anything (2026-09-29):
# `p 1` died of "stack overflow" in the lexer. lex_go calls itself once per
# token, a tail call that clang turns into a loop at -O1 and above and leaves
# as a frame at -O0 -- and the prelude reached the size where one frame per
# token no longer fits in the 512 MB the interpreter runs on. -O1 keeps the
# tail calls and compiles in about 2 minutes instead of 30 s; still not the
# build for the record (scoreboard refuses anything but -O2).
#
# ⚠ AND IT IS THE WRONG BUILD FOR THE RECORD. The sweep runs the interpreter
# five thousand times and bounds each run in CPU SECONDS, so a binary that is
# 1.7x slower measures a different table -- files near the budget would cross
# it and the record would report a regression that is the compiler's -O level.
# Which build made a binary is not visible in the binary, so this writes it
# down and mspec/scoreboard.sh refuses to sweep a --fast one. A sentence in a
# README cannot refuse anything.
#
# The build line itself lived only in prose, in two dialects (README.md has
# macOS's and Linux's), which is three copies of one rule; see PAIN.md for why
# each flag is load-bearing.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
cd "$root" || exit 2

mode=O2
opt=-O2
emit=1
for a in "$@"; do
  case "$a" in
    --fast|-O1)  mode=O1; opt=-O1 ;;
    --cc-only)   emit=0 ;;
    -h|--help)   sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "build.sh: unknown argument '$a'" >&2; exit 2 ;;
  esac
done

# ⚠ REFUSE rather than half-build. The Mere compiler lives in its own
# repository and is not vendored here; CI puts it in .mere-compiler. With no
# compiler and no --cc-only this would otherwise compile whatever mr.c happened
# to be lying about, which is the most confusing failure available: a binary
# built from a source you did not edit.
MERE="${MERE:-}"
if [ "$emit" = 1 ]; then
  if [ -z "$MERE" ]; then
    for c in "$root/.mere-compiler/_build/default/bin/mere.exe" mere mere.exe; do
      p="$(command -v "$c" 2>/dev/null)" && { MERE="$p"; break; }
    done
  fi
  if [ -z "$MERE" ]; then
    echo "build.sh: no Mere compiler found. Set MERE=<path to mere/mere.exe>, or put one at" >&2
    echo "          .mere-compiler/_build/default/bin/mere.exe (which is where CI builds it)," >&2
    echo "          or pass --cc-only to compile the mr.c already in this directory." >&2
    exit 2
  fi
fi

# The platform differences, in one place instead of two paragraphs of README:
#   -Wl,-stack_size   Mach-O only; on Linux the main thread's stack is `ulimit -s`
#   -fbracket-depth   mainline clang caps nesting at 256 and the emitted C needs
#                     more; Apple's clang allows more by default but the flag is
#                     harmless there. tools/bracket_depth_check.sh is the gate.
#   -lm               Linux needs it spelled out
case "$(uname -s)" in
  Darwin) plat="-Wl,-stack_size,0x20000000 -fbracket-depth=1024" ;;
  *)      plat="-fbracket-depth=1024 -lm"
          # Clang's parser also uses the process stack for the emitted C.
          # Match the interpreter's stack budget during compilation itself.
          ulimit -s 524288 || exit 2 ;;
esac

if [ "$emit" = 1 ]; then
  printf 'emit   %s -c main.mere > mr.c\n' "$MERE"
  "$MERE" -c main.mere > mr.c.new || { echo "build.sh: emit failed" >&2; rm -f mr.c.new; exit 1; }
  mv -f mr.c.new mr.c
fi
[ -f mr.c ] || { echo "build.sh: no mr.c to compile" >&2; exit 2; }

# The native region cache is the compiler's default (64 a thread). Between
# v0.1.727 and v0.1.728 a deep cache handed a region back NOT zeroed, the
# conservative scan read stale handles in it, and prism's snippets_test went
# past 2 GiB -- so the build then pinned eight (#79). v0.1.729 zeroes what a
# cached region was used for and adds mem_trim (GC.start calls it): 64 is
# back at snippets_test's old peak, and the UDP leak checks fit their child's
# 10 seconds again (at eight they do not). Refuse an emitted runtime without
# the zeroing rather than bring the regression back.
if ! grep -q '__lang_mem_trim' mr.c; then
  echo 'build.sh: mr.c predates Mere v0.1.729 (cached regions are not zeroed); use the pinned Mere compiler' >&2
  exit 2
fi
# Reject a runtime that silently changes the compiler's native default.
if ! printf '%s\n' '#include "mr.c"' \
  '#if !defined(__LANG_REGION_CACHE_CAP) || __LANG_REGION_CACHE_CAP != 64' \
  '#error native region cache must use the compiler default of 64' \
  '#endif' | clang -w -E -x c -I "$root" - >/dev/null; then
  echo 'build.sh: compiler does not provide the required native cache policy' >&2
  exit 2
fi

# libprism (vendor/prism, see its README): compiled once into vendor/prism/obj
# and kept, since it changes only when the vendored copy does. Always -O2 --
# it is not the interpreter, and the sweep's CPU bound measures the parser
# the same way whichever build of mr.c is beside it.
pobj="$root/vendor/prism/obj"
plib="$pobj/libprism.a"
pneed=0
[ -f "$plib" ] || pneed=1
if [ "$pneed" = 0 ]; then
  for f in "$root"/vendor/prism/src/*.c "$root"/vendor/prism/src/util/*.c \
           "$root"/vendor/prism/include/prism.h "$root"/vendor/prism/include/prism/*.h \
           "$root"/vendor/prism/include/prism/util/*.h; do
    [ "$f" -nt "$plib" ] && { pneed=1; break; }
  done
fi
if [ "$pneed" = 1 ]; then
  printf 'cc     clang -O2 vendor/prism/src/*.c -> vendor/prism/obj/libprism.a\n'
  rm -rf "$pobj"; mkdir -p "$pobj"
  for f in "$root"/vendor/prism/src/*.c "$root"/vendor/prism/src/util/*.c; do
    clang -O2 -w -I "$root/vendor/prism/include" -c "$f" -o "$pobj/$(basename "$f" .c).o" || { rm -rf "$pobj"; exit 1; }
  done
  ar rcs "$plib" "$pobj"/*.o || { rm -rf "$pobj"; exit 1; }
fi

# Native key, certificate and TLS operations use OpenSSL 3. Its provider
# owns cryptographic objects; no host Ruby interpreter or CLI is involved.
ossl_prefix="${OPENSSL_PREFIX:-}"
if [ -z "$ossl_prefix" ] && [ "$(uname -s)" = Darwin ] && command -v brew >/dev/null 2>&1; then
  ossl_prefix="$(brew --prefix openssl@3 2>/dev/null)" || exit 2
fi
if [ -n "$ossl_prefix" ]; then
  [ -f "$ossl_prefix/include/openssl/ssl.h" ] || { echo 'build.sh: OPENSSL_PREFIX has no OpenSSL headers' >&2; exit 2; }
  set -- "-I$ossl_prefix/include" "-L$ossl_prefix/lib" "-Wl,-rpath,$ossl_prefix/lib" -lssl -lcrypto
elif command -v pkg-config >/dev/null 2>&1 && pkg-config --exists 'openssl >= 3.0'; then
  # pkg-config emits compiler arguments for the selected provider.
  # shellcheck disable=SC2046
  set -- $(pkg-config --cflags --libs openssl)
else
  set -- -lssl -lcrypto
fi
printf 'cc     clang %s %s mr.c tools/*_glue.c libprism.a with OpenSSL -> mere-ruby\n' "$opt" "$plat"
# ⚠ NEVER `cp` OVER A RUNNING BINARY -- the text pages of a process that is
# mid-run are backed by that file, and overwriting them SIGKILLs it or, worse,
# gives it another build's instructions. Build beside it and rename.
# shellcheck disable=SC2086
clang $opt -w $plat -I "$root/vendor/prism/include" mr.c "$root/tools/prism_glue.c" "$root/tools/socket_glue.c" "$root/tools/math_glue.c" "$root/tools/process_glue.c" "$root/tools/openssl_glue.c" -pthread "$plib" "$@" -o mere-ruby.new || { rm -f mere-ruby.new; exit 1; }
/bin/mv -f mere-ruby.new mere-ruby

# ...and say which build this is, where something that must not be misled can
# read it. mspec/scoreboard.sh does.
printf '%s\n' "$mode" > .build_mode
printf 'ok     mere-ruby is an %s build (.build_mode)\n' "$mode"
