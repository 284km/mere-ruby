#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
mode=${1:-native}
source=${2:?provide the pinned Ruby source checkout}
output=${3:?provide a fresh output directory}
reference=${REF_RUBY_BIN:-$(ruby -rrbconfig -e 'print RbConfig.ruby')}
mkdir -p "$output"
python3 unittest/nkf_sources_check.py
if [ "$mode" = browser ]; then
  python3 unittest/nkf_api_check.py --ruby "$reference" --wasm --output "$output/api"
  python3 unittest/nkf_wasm_check.py --ruby "$reference" --output "$output/browser"
elif [ "$mode" = native ]; then
  python3 unittest/nkf_api_check.py --ruby "$reference" --output "$output/api"
else
  echo 'mode must be native or browser' >&2; exit 2
fi
python3 unittest/nkf_boundary_check.py --ruby "$reference" --output "$output/boundary"
python3 unittest/nkf_upstream_check.py --ruby "$reference" --ruby-source "$source" --output "$output/upstream"
python3 unittest/nkf_memory_check.py --output "$output/memory"
python3 unittest/nkf_tool_check.py --ruby "$reference" --source "$source" --output "$output/tool"
