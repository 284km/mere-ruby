#!/bin/sh
# tools/iseq/native/check.sh -- the native ISeq compiler (ic/) against
# lib/iseq_compiler_ext.rb, a file at a time (note 552 §11).
#
#   MERE=<mere.exe> sh tools/iseq/native/check.sh [-k <dir>] file.rb...     (the reference ruby on PATH)
#
# Each file is compiled for the VM by the Ruby compiler under the reference
# ruby (expect.rb: what __vm_file answers) and by the native one (dump.mere),
# and the two are compared as text. A file is
#
#   the same    the same sequences
#   REFUSED     the native compiler does not take it yet (why, counted)
#   DIFF        different sequences -- the first lines that differ
#   FAILED      the native compiler stopped on something else: a defect
#
# and a file the Ruby compiler itself refuses, or ruby does not parse, is
# not counted against either. Exits non-zero on a DIFF or a FAILED.
# -k keeps the texts in <dir>.
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
keep=""
if [ "$1" = "-k" ]; then keep="$2"; shift 2; fi
tmp="${keep:-${TMPDIR:-/tmp}/ic_check.$$}"
mkdir -p "$tmp"
# (MERE may be relative to where this was started -- CI's
#  .mere-compiler/_build/default/bin/mere.exe -- and dump.mere is compiled
#  from this directory: the path is made absolute first)
case "${MERE:?MERE names the Mere compiler}" in
  /*) ;;
  */*) MERE="$(cd "$(dirname "$MERE")" && pwd)/$(basename "$MERE")" ;;
esac
(cd "$here" && "$MERE" -c dump.mere > "$tmp/dump.c") && clang -O1 -w "$tmp/dump.c" -o "$tmp/dump" || { echo "check: build failed"; exit 2; }
ruby "$here/expect.rb" "$root/lib/iseq_compiler_ext.rb" "$tmp" "$@" 2>/dev/null > "$tmp/list.tsv"
# (the n-th file's number and path, the driver's arguments)
"$tmp/dump" "$tmp" "<main>" $(tr '\t' ' ' < "$tmp/list.tsv")
same=0; diff=0; refused=0; failed=0; skipped=0
: > "$tmp/why.txt"
while IFS="$(printf '\t')" read -r n f; do
  exp="$tmp/$n.exp"; got="$tmp/$n.got"
  case "$(head -c 8 "$exp")" in
    REFUSED:|SYNTAX*) skipped=$((skipped+1)); continue ;;
    RUBYFAIL) skipped=$((skipped+1)); echo "RUBY COMPILER FAILED $f: $(head -1 "$exp" | cut -c13-200)"; continue ;;
  esac
  [ -f "$got" ] || { failed=$((failed+1)); echo "FAILED $f: no answer"; continue; }
  case "$(head -c 8 "$got")" in
    REFUSED:) refused=$((refused+1)); head -1 "$got" >> "$tmp/why.txt"; continue ;;
    FAILED:*) failed=$((failed+1)); echo "FAILED $f: $(head -1 "$got" | cut -c1-200)"; continue ;;
  esac
  if cmp -s "$exp" "$got"; then same=$((same+1))
  else
    diff=$((diff+1))
    [ $diff -le "${SHOW:-3}" ] && { echo "DIFF $f"; diff "$exp" "$got" | head -"${LINES_SHOWN:-8}" | cut -c1-220; }
  fi
done < "$tmp/list.tsv"
if [ -s "$tmp/why.txt" ]; then
  echo "-- why the native compiler refused, most common first"
  sed 's/^REFUSED: //' "$tmp/why.txt" | sort | uniq -c | sort -rn | head -"${WHY:-12}"
fi
echo "check: $# files -- $same the same, $refused refused, $diff different, $failed failed ($skipped not compiled by the Ruby compiler either)"
[ -n "$keep" ] || rm -rf "$tmp"
[ $((diff + failed)) -eq 0 ]
