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
  awk 'FILENAME==ARGV[1] {excluded[$0]=1; next} !($0 in excluded)' "$work/excluded" "$work/sorted" > "$work/selected"
else
  cat "$work/sorted" > "$work/selected"
fi
# A file split into units (splits.tsv) is listed as `<file>@<part>`, one line
# per part in part order, in its place.
if [ -f "$here/splits.tsv" ]; then
  # (the table is checked before it is used: a malformed row, a gap in a
  #  file's parts, or a last part that is not the negation of the others is
  #  refused, not skipped -- the negation is what makes the parts cover the
  #  file, so a split without one would drop tests silently)
  awk -F '\t' '$0 ~ /^#/ || $0 == "" {next}
       NF != 3 {print "unittest: splits.tsv line " NR ": not <file> TAB <part> TAB <filter>" > "/dev/stderr"; bad = 1; next}
       {n[$1]++; if ($2 != n[$1]) {print "unittest: splits.tsv line " NR ": part " $2 " of " $1 " out of order" > "/dev/stderr"; bad = 1}
        last[$1] = $3; if (n[$1] > 1 && prev[$1] !~ /^\//) {print "unittest: splits.tsv: only the last part of " $1 " may be a negation" > "/dev/stderr"; bad = 1}
        prev[$1] = $3}
       END {for (f in n) if (n[f] < 2 || last[f] !~ /^!\//) {print "unittest: splits.tsv: " f " needs two parts or more, the last one a negation (!/.../)" > "/dev/stderr"; bad = 1}
            exit bad}' "$here/splits.tsv" || exit 2
  # ...and every file it splits is one this tree has
  for split_file in $(awk -F '\t' '$0 !~ /^#/ && NF == 3 {print $1}' "$here/splits.tsv" | sort -u); do
    [ -f "$src/test/$split_file" ] || { echo "unittest: splits.tsv names test/$split_file, which $src does not have" >&2; exit 2; }
  done
  awk -F '\t' 'FILENAME==ARGV[1] {if ($0 !~ /^#/ && NF == 3) {n[$1]++; part[$1, n[$1]] = $2}; next}
       ($0 in n) {for (i = 1; i <= n[$0]; i++) print $0 "@" part[$0, i]; next}
       {print}' "$here/splits.tsv" "$work/selected"
else
  cat "$work/selected"
fi
