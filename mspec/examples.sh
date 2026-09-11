#!/bin/sh
# What is actually failing, example by example.
#
#   ./mspec/examples.sh <spec-root>        # writes EXAMPLES.md
#
# CAUSES.md groups the RECORD; this runs the specs again and asks the harness
# to name the examples. The two answer different questions, and the difference
# is why this exists:
#
#   a row in mspec/tags/ is ONE line -- the FIRST place the two sides diverge
#   in that file. It is not the diagnosis, and reading it as one is how three
#   separate repairs in a single session went at rules that were already
#   right: `mutex/lock :: expected ThreadError` (the recursive-lock rule was
#   implemented; the failing example needed Fiber), `method/arity :: expected
#   -1, got -4` (arity agreed with ruby on nine shapes; a def had leaked out of
#   an earlier example), `unboundmethod/super_method :: undefined method
#   'owner'` (owner agreed on eight shapes; the alias was searching for its own
#   name). Each cost a build and a measurement to disprove.
#
# It is SLOW -- every recorded DIFF file, both sides -- so it is not part of a
# sweep. Run it when choosing what to work on next.
#
# ⚠ The output is CHECKED IN, so every line goes through mask.sh, and
#   EXAMPLES.md is listed in record_hygiene.sh. A record nobody listed is a
#   record nobody checks -- and note that record_hygiene reads `git ls-files`,
#   so a BRAND NEW record is not checked until it is tracked. The first run of
#   this script produced a file the hygiene check reported clean without ever
#   opening it.
set -u
# ⚠ BYTES, not characters. A recorded cause can carry a raw invalid UTF-8 byte
#   -- core/symbol/inspect_spec's `quotes BINARY symbols` prints one -- and
#   under a UTF-8 locale sed and read give up on that line, so the file
#   contributed NOTHING and the walk passed over it in silence. It was found
#   only because the visited count came back 145 of 146. record_hygiene.sh
#   sets this for the same reason.
LC_ALL=C
export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$here"/mask.sh
spec="${1:-}"
[ -d "$spec" ] || { echo "usage: examples.sh <spec-root>   (the dir holding core/ and language/)" >&2; exit 2; }
mr="${MR_BIN:-$root/mere-ruby}"
[ -x "$mr" ] || { echo "no mere-ruby at $mr" >&2; exit 2; }

tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT
rows="$tmp/rows"

# The files to visit come from the RECORD, so this cannot drift from what the
# sweep last measured -- and a file that has since gone green shows up here as
# a row with nothing failing, which is the signal that the record is stale.
awk -F'\t' '$1 ~ /^DIFF/ { sub(/^DIFF[ \t]*/, "", $1); print $1 }' "$root"/mspec/tags/*.txt \
  | awk '{print $1}' | sort -u > "$rows"
total=$(wc -l < "$rows" | tr -d ' ')
[ "$total" -gt 0 ] || { echo "no DIFF rows in the record" >&2; exit 2; }

n=0
: > "$tmp/out"
while read -r f; do
  n=$((n + 1))
  printf '\r%s/%s %-52s' "$n" "$total" "$f" >&2
  if [ ! -f "$spec/$f" ]; then
    printf '%s\t(no such file under the spec root)\n' "$f" >> "$tmp/out"
    continue
  fi
  # ⚠ < /dev/null. The spec run reads STDIN, and inside a `while read` loop
  #   that is THIS LIST: the first version of this script consumed 88 of its
  #   137 files that way and reported the other 49 as if they were all of them.
  #   A tally that does not match `total` is the only thing that catches it,
  #   which is why the count is printed at the end.
  lines=$(env MERE_SPEC_VERBOSE=1 MR_BIN="$mr" sh "$here"/run_spec.sh "$spec/$f" 2>&1 < /dev/null \
          | sed -n '2,8p' | grep -aE '^(FAILED|ERROR|pass=)' | head -4)
  if [ -z "$lines" ]; then
    printf '%s\t(nothing failed -- the record may be stale)\n' "$f" >> "$tmp/out"
  else
    # ⚠ ONE CAUSE PER LINE, with the file repeated. Joining a file's causes into
    #   a single cell made rows of up to four clipped causes -- over 900
    #   characters -- and record_hygiene refuses a recorded line above 340 on
    #   the grounds that it is a dump rather than a cause. The bound is right;
    #   the shape was wrong. One fact per line also greps.
    printf '%s' "$lines" | strip_noise | while read -r l; do
      printf '%s\t%s\n' "$f" "$(clip_cause "$l")" >> "$tmp/out"
    done
  fi
done < "$rows"
printf '\r%-72s\r' '' >&2

# ...and the tally counts FILES, not lines: one file can contribute several.
visited=$(cut -f1 "$tmp/out" | sort -u | wc -l | tr -d ' ')
out="$root/EXAMPLES.md"
{
  echo "# mere-ruby — the examples that actually fail"
  echo
  echo "One row per recorded DIFF file, holding the first few FAILED / ERROR"
  echo "lines the harness prints for it. \`CAUSES.md\` groups the record; this"
  echo "runs the specs again, because a recorded row is the first DIVERGENCE in"
  echo "a file and not the diagnosis."
  echo
  echo "Regenerate with \`./mspec/examples.sh <spec-root>\` (slow: it runs every"
  echo "file below, both sides). Paths and addresses are masked by mask.sh."
  echo
  echo "Visited **$visited** of **$total** recorded DIFF files."
  echo
  echo '| file | what fails |'
  echo '|---|---|'
  sed 's/|/\\|/g; s/\t/ | /' "$tmp/out" | sed 's/^/| /; s/$/ |/'
} > "$out"

echo "wrote $out ($visited of $total files)"
[ "$visited" = "$total" ] || { echo "VISITED $visited BUT THE RECORD HAS $total -- the walk lost files" >&2; exit 1; }
