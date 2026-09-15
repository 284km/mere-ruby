#!/bin/sh
# rx_clear_caps only reaches as far as the high-water mark rx_cap_set keeps, so
# a write that goes around the setter leaves a capture behind: the NEXT match
# would answer with a group belonging to the one before it.
set -u
cd "$(dirname "$0")/.." || exit 2
bad=$(grep -n 'map_set rx_caps' ./*.mere | grep -v 'and rx_cap_set' | grep -v 'map_set rx_caps (g \* 4 + kind) v')
if [ -n "$bad" ]; then
  echo "rx_caps: write(s) that skip rx_cap_set (the high-water mark would not see them):"
  echo "$bad" | sed 's/^/    /'
  exit 1
fi
n=$(grep -c 'rx_cap_set ' ./*.mere | awk -F: '{s+=$2} END{print s}')
echo "rx_caps: all writes go through rx_cap_set ($n call sites)"
