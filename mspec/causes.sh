#!/bin/sh
# Rank the recorded DIFF/CRASH causes, most files first.
#
#   ./mspec/causes.sh            # rewrite CAUSES.md from mspec/tags/*.txt
#
# The scoreboard answers "how many files disagree". This answers "how many
# NAMES do they come down to", which is the number that decides what to work on
# next. It reads the tags files only -- no sweep -- so the bucket key can be
# retuned in seconds. That split is deliberate: the key is a judgement call and
# will be wrong at first, and re-measuring 1000 spec files to change a regex is
# not a thing anyone will do twice.
#
# Why it exists: the sweep used to discard each run's output after computing a
# verdict, so 603 DIFFs were 603 unknowns. A batch of failures on this codebase
# has repeatedly come down to a handful of names -- 346 errors that were 194
# instances of one -- and there is no way to see that without classifying first.
#
# Two views, because one key cannot serve both purposes:
#   KIND  the shape, with values masked -- what to work on
#   CAUSE the line as recorded -- what exactly to reproduce
set -u
# LC_ALL=C for the whole script, for the same reason scoreboard.sh pins it on its
# `tr`: the recorded lines carry bytes that are not valid UTF-8 (core/string's
# chars, chr, grapheme_clusters put raw bytes in a failure message). Under a
# UTF-8 locale awk stops on them -- "towc: multibyte conversion failure" -- and
# what it has classified so far is written out as if it were everything. Measured
# in ja_JP.UTF-8 this file claimed to classify 430 records with 24 CRASHes, where
# the tags hold 581 and 29. A record that silently loses a third of its input is
# worse than one that fails, because the ranking still looks plausible.
#
# scoreboard.sh got this fix on 2026-08-19 and this script did not, which is the
# same shape as the bootstraptest SLOW column: one fact about this project, more
# than one place that has to know it, and only one of them told.
LC_ALL=C
export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
tagdir="$here/tags"
out="$here/../CAUSES.md"

[ -d "$tagdir" ] || { echo "no $tagdir -- run scoreboard.sh first" >&2; exit 1; }

tmp="$(mktemp)"
cat "$tagdir"/*.txt 2>/dev/null | awk -F'\t' '
  function bucket(s,   n, a, t) {
    # ERROR: <group desc> <example desc>: <ErrorClass>
    #   -> the class is the only reusable part; the descriptions are per-file.
    if (s ~ /^ERROR: /) {
      n = split(s, a, ": ")
      return "ERROR " a[n]
    }
    # FAILED: <example desc>: expected ..., got ...
    #   -> keep from the matcher onward; the description is per-file.
    if (s ~ /^FAILED: /) {
      t = s
      if (match(t, /: (expected|raised|matcher|flunked)/)) t = substr(t, RSTART + 2)
      else sub(/^FAILED: /, "", t)
      t = mask(t)
      return "FAILED " t
    }
    return mask(s)
  }
  # Mask the values, keep the shape. Without this every line is unique and the
  # ranking says nothing: "expected 1, got 2" and "expected 3, got 4" are one
  # bug, not two. The raw lines are still in the tags files and in the second
  # table below, so nothing is lost -- only pooled.
  function mask(s,   t) {
    t = s
    gsub(/"[^"]*"/, "\"S\"", t)
    gsub(/'"'"'[^'"'"']*'"'"'/, "'"'"'S'"'"'", t)
    gsub(/#<[^>]*>/, "#<OBJ>", t)
    gsub(/-?[0-9]+\.[0-9]+(e[-+]?[0-9]+)?/, "N", t)
    gsub(/-?[0-9]+/, "N", t)
    gsub(/:[a-z_][a-zA-Z0-9_]*/, ":SYM", t)
    return t
  }
  $1 ~ /^(DIFF|CRASH)/ {
    split($1, a, " ")
    if (NF < 2 || $2 == "") { print a[1] "\t(unclassified: swept before causes were recorded)\t(unclassified)" }
    else { print a[1] "\t" bucket($2) "\t" $2 }
  }' > "$tmp"

total="$(wc -l < "$tmp" | tr -d ' ')"
[ "$total" -gt 0 ] || { echo "no DIFF/CRASH rows in $tagdir" >&2; rm -f "$tmp"; exit 1; }

table() {  # $1 = verdict, $2 = field (2 = kind, 3 = raw), $3 = limit (0 = all)
  awk -F'\t' -v v="$1" -v f="$2" '$1 == v {print $f}' "$tmp" \
    | sort | uniq -c | sort -rn \
    | { [ "$3" -gt 0 ] && head -"$3" || cat; } \
    | awk '{ c = $1; $1 = ""; sub(/^ /, "");
             gsub(/\|/, "\\|", $0); gsub(/`/, "", $0);
             printf("| %d | `%s` |\n", c, $0) }'
}

{
  echo "# mere-ruby — what the gap is made of"
  echo
  echo "The records in \`SPEC_STATUS.md\` and \`mspec/tags/\`, grouped by CAUSE rather"
  echo "than by group. A count is a number of spec FILES. The text is the first line"
  echo "where mere-ruby and ruby disagree (DIFF) or the message it aborted with"
  echo "(CRASH), with paths and addresses masked."
  echo
  echo "**KIND** masks the values and keeps the shape -- this is the column that says"
  echo "what to work on. **CAUSE** is the line as recorded, for reproducing one."
  echo
  echo "Regenerate with \`./mspec/causes.sh\` (reads \`mspec/tags/\`, no sweep)."
  echo
  printf 'Classified: %s files.\n' "$total"
  echo
  for v in CRASH DIFF; do
    n="$(awk -F'\t' -v v="$v" '$1 == v' "$tmp" | wc -l | tr -d ' ')"
    [ "$n" -gt 0 ] || continue
    k="$(awk -F'\t' -v v="$v" '$1 == v {print $2}' "$tmp" | sort -u | wc -l | tr -d ' ')"
    echo "## $v — $n files, $k kinds"
    echo
    echo "| files | kind |"
    echo "|---|---|"
    table "$v" 2 0
    echo
    echo "<details><summary>the same rows by exact cause (top 40)</summary>"
    echo
    echo "| files | cause |"
    echo "|---|---|"
    table "$v" 3 40
    echo
    echo "</details>"
    echo
  done
  # The NoMethodError / NameError buckets are the biggest and the least
  # actionable as written: they say a name was absent, not WHICH name. It does
  # not take the exception message to find out -- ruby/spec is laid out as
  # core/<class>/<method>_spec.rb, so the name is in the path that is already
  # recorded. This table is what "implement the next thing" reads.
  echo "## The absent names"
  echo
  echo "Files whose FIRST divergence is NoMethodError or NameError, keyed by the"
  echo "method the spec file is named for. Not every row is a missing method --"
  echo "a spec can raise NoMethodError from a helper -- but most are, and the"
  echo "class column says where the weight sits."
  echo
  echo "| class | absent names (from the spec filenames) |"
  echo "|---|---|"
  awk -F'\t' '$1 ~ /^(DIFF|CRASH)/ && $2 ~ /(NoMethodError|NameError)$/ {
      split($1, a, " ")
      path = a[2]
      n = split(path, seg, "/")
      meth = seg[n]; sub(/_spec\.rb$/, "", meth)
      cls = (n >= 2) ? seg[n-1] : "?"
      if (!(cls "/" meth in seen)) { seen[cls "/" meth] = 1; list[cls] = list[cls] " " meth; cnt[cls]++ }
    }
    END { for (c in cnt) printf("%d\t%s\t%s\n", cnt[c], c, list[c]) }' "$tagdir"/*.txt \
    | sort -rn \
    | awk -F'\t' '{ printf("| %s (%d) | `%s` |\n", $2, $1, substr($3, 2)) }'
  echo
  echo "_Generated by \`mspec/causes.sh\`._"
} > "$out"
rm -f "$tmp"
echo "wrote $out"
