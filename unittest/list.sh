#!/bin/sh
# Discover files without requiring a built interpreter or running a test.
# Default: the historical files.txt selection (directories are shallow).
# Explicit paths: recursive, including files excluded from the default record.
# --all: named candidates plus audited standalone bodies in extra_files.txt.
set -eu
LC_ALL=C; export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
src="${1:?usage: list.sh <ruby-src> [--all | path under test/ ...]}"
shift
src="$(cd "$src" && pwd)"
[ -d "$src/test" ] || { echo "unittest: $src has no test/" >&2; exit 2; }
default=0
recursive=1
if [ "$#" -eq 0 ]; then
  default=1
  recursive=0
  set -- $(awk 'NF && $0 !~ /^[#-]/ {print}' "$here/files.txt")
elif [ "$1" = "--all" ]; then
  [ "$#" -eq 1 ] || { echo "unittest: --all cannot be combined with paths" >&2; exit 2; }
  set -- .
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
: > "$work/files"
for path in "$@"; do
  case "$path" in
    /*|..|../*|*/../*|*/..|--*) echo "unittest: invalid test path: $path" >&2; exit 2 ;;
  esac
  if [ -d "$src/test/$path" ]; then
    find_path="./$path"
    [ "$path" != "." ] || find_path=.
    if [ "$recursive" -eq 1 ]; then
      (cd "$src/test" && find "$find_path" -type f \( -name '*_test.rb' -o -name 'test_*.rb' \) ! -name 'test_helper.rb') >> "$work/files"
    else
      (cd "$src/test" && find "$find_path" -maxdepth 1 -type f \( -name '*_test.rb' -o -name 'test_*.rb' \) ! -name 'test_helper.rb') >> "$work/files"
    fi
  elif [ -f "$src/test/$path" ]; then
    printf '%s\n' "$path" >> "$work/files"
  else
    echo "unittest: no test/$path in $src" >&2
    exit 2
  fi
done
# Extra bodies follow the same directory scope as named candidates. Missing
# entries fail before execution instead of quietly shrinking a pinned suite.
if [ "$recursive" -eq 1 ] && [ -f "$here/extra_files.txt" ]; then
  awk 'NF && $0 !~ /^#/ {print}' "$here/extra_files.txt" > "$work/extra"
  while IFS= read -r extra; do
    case "$extra" in
      /*|..|../*|*/../*|*/..|--*|*[!a-zA-Z0-9_./-]*) echo "unittest: invalid extra path: $extra" >&2; exit 2 ;;
    esac
    for path in "$@"; do
      if [ -d "$src/test/$path" ]; then
        scope="$(cd "$src/test/$path" && pwd)"
        case "$src/test/$extra" in
          "$scope"/*) selected=1 ;;
          *) selected=0 ;;
        esac
        if [ "$selected" -eq 1 ]; then
          [ -f "$src/test/$extra" ] || { echo "unittest: missing audited test/$extra" >&2; exit 2; }
          printf '%s\n' "$extra" >> "$work/files"
        fi
      fi
    done
  done < "$work/extra"
fi
sed 's|^\./||' "$work/files" | sort -u > "$work/sorted"
if [ "$default" -eq 1 ]; then
  awk '/^-/ {print substr($0,2)}' "$here/files.txt" > "$work/excluded"
  # grep's exit 1 means an empty selection, not an I/O error.
  awk 'FILENAME==ARGV[1] {excluded[$0]=1; next} !($0 in excluded)' "$work/excluded" "$work/sorted"
else
  cat "$work/sorted"
fi
