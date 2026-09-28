#!/bin/sh
# Print a directory holding a copy of this tree's sources in which a Fiber
# cannot suspend: m_fiber_coro.mere is replaced by m_fiber_nothreads.mere,
# and there is no mere.toml.
#
# Why a copy: the Wasm and RV backends refuse coroutines by name (core Wasm
# cannot switch stacks; the bare-metal runtime has one), and mere.toml's
# `stack` request -- which the C build needs, so that the main stack and every
# fiber's coroutine get the interpreter's 512MB (Q-168) -- is REFUSED by name
# on Wasm and RV32IM. Mere has no conditional compilation, so the choice is
# made by which file sits under the imported name.
#
#   d=$(sh tools/nothreads_tree.sh) && mere -w "$d/main.mere" ...; rm -rf "$d"
set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"
d="$(mktemp -d)"
cp "$here"/*.mere "$d"/
cp "$here/m_fiber_nothreads.mere" "$d/m_fiber_coro.mere"
[ -d "$here/.mere_modules" ] && ln -s "$here/.mere_modules" "$d/.mere_modules"
printf '%s\n' "$d"
