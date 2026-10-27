#!/bin/sh
# Every case of tools/loop_rss_check.rb, each in a process of its own: the
# loops whose turns used to keep memory, held to 1.6x the RSS they started
# from (ruby's own leak tests allow 2x). Note 441.
#
#   ./tools/loop_rss_check.sh [path/to/mere-ruby]     exit 1 on any FAIL
set -u
here="$(cd "$(dirname "$0")" && pwd)"
mr="${1:-$here/../mere-ruby}"
n=$(grep -c '^  "' "$here/loop_rss_check.rb")
bad=0
i=0
while [ $i -lt $n ]; do
  "$mr" "$here/loop_rss_check.rb" $i || bad=1
  i=$((i + 1))
done
exit $bad
