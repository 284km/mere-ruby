#!/bin/sh
# Ask the selected runtime for its own paths before adding reference fallbacks.
# Do not let a caller's Ruby configuration influence this query.
set -eu
RUBYLIB= RUBYOPT= "${1:?usage: runtime_load_path.sh <ruby>}" --disable-gems -e 'print $LOAD_PATH.join(":")'
