#!/bin/sh
# tools/iseq/vm_corpus.sh — the corpus with each FILE on the ISeq VM
# (MERE_RUBY_VM, note 552).
#
# Every corpus program is run by ./mere-ruby with MERE_RUBY_VM=1: the main
# script and each file it requires run on the VM when the compiler and the
# VM take the whole file, and on the evaluator otherwise. The run's stdout
# and exit status are compared with the reference ruby's, as run_corpus.sh
# compares them. Which of the two ran the main script is asked apart, with
# MERE_RUBY_VM=why (it answers "mere-ruby: vm: <file>: <why>" and does not
# run the program) -- a note on the run's own stderr would be read by the
# programs that start a child ruby and compare what it wrote.
# Each program is then one of
#
#   vm        the main script ran on the VM and the run matches ruby
#   fallback  the main script ran on the evaluator (why is counted) and the
#             run matches ruby
#   FAIL      the run differs from ruby -- a defect of the VM or the
#             compiler, since the same program matches without MERE_RUBY_VM
#
# and the script exits non-zero when there is a FAIL. The fallbacks are the
# list of what the compiler and the VM do not take yet, most common first.
#
# A fallback is also held to a list kept in the repository,
# tools/iseq/vm_fallbacks.txt: one corpus program a line, the reason after a
# tab. The script exits non-zero when a program falls back that is not
# listed (a change made the VM decline it), and when a listed program now
# runs on the VM (the line is to be removed). A fallback passes the
# comparison with ruby -- the evaluator ran it -- so without the list a
# program that stopped running on the VM was a number nobody was asked to
# read, and what the VM got wrong in it went unseen: round 62's test_hash.
# Only the programs of this run are held to the list.
#
#   sh tools/iseq/vm_corpus.sh [-j N] [corpus/NNN_*.rb ...]
#       (RUBY=, MR_BIN= to override -- RUBY defaults to tools/ref_ruby.sh's;
#        VM_CORPUS_OUT=<dir> keeps the outputs; VM_FALLBACKS=<file> is
#        another list, VM_FALLBACKS=none none at all)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
# the reference is run_corpus.sh's: tools/ref_ruby.sh checks its version and
# names it (REF_RUBY_BIN -- on CI the one built with the test extensions). A
# path of this machine's own here made every program a FAIL on CI's runners:
# "ruby exited 127", read as 841 VM failures (main's run 45240819455).
if [ -z "${RUBY:-}" ]; then
  . "$ROOT/tools/ref_ruby.sh"
  RUBY="$REF_RUBY_BIN"
fi
# ...and a reference that does not run stops the sweep, before any verdict:
# a FAIL is a difference of the VM's, not a missing ruby
if ! "$RUBY" -e 'exit 0' > /dev/null 2>&1; then
  echo "vm_corpus: the reference ruby does not run: $RUBY" >&2
  exit 2
fi
MR="${MR_BIN:-$ROOT/mere-ruby}"
JOBS=4
if [ "${1:-}" = "-j" ]; then JOBS="$2"; shift 2; fi
OUT="${VM_CORPUS_OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
[ -n "${VM_CORPUS_OUT:-}" ] || trap 'rm -rf "$OUT"' EXIT
if [ $# -gt 0 ]; then FILES="$*"; else FILES="$(ls corpus/*.rb)"; fi

# one program: its verdict on one line, "<verdict>\t<file>\t<why>"
cat > "$OUT/one.sh" <<'ONE'
#!/bin/sh
f="$1"; b="$(basename "$f" .rb)"
rrc=0; "$RUBY" -Eutf-8 "$f" > "$OUT/$b.exp" 2>/dev/null || rrc=$?
mrc=0; MERE_RUBY_VM=1 perl -e 'alarm 900; exec @ARGV' "$MR" "$f" > "$OUT/$b.got" 2> "$OUT/$b.err" || mrc=$?
why="$(MERE_RUBY_VM=why perl -e 'alarm 120; exec @ARGV' "$MR" "$f" 2>&1 < /dev/null | grep -a "^mere-ruby: vm: $f: " | head -1 | sed "s|^mere-ruby: vm: $f: ||")"
[ "$why" = "on the VM" ] && why=""
if cmp -s "$OUT/$b.exp" "$OUT/$b.got" && [ "$rrc" = "$mrc" ]; then
  if [ -n "$why" ]; then printf 'fallback\t%s\t%s\n' "$f" "$why"; else printf 'vm\t%s\t\n' "$f"; fi
else
  printf 'FAIL\t%s\t%s\n' "$f" "ruby exited $rrc, mere-ruby $mrc${why:+; fell back: $why}"
fi
ONE
export RUBY MR OUT
printf '%s\n' $FILES | xargs -P "$JOBS" -n 1 sh "$OUT/one.sh" > "$OUT/verdicts.tsv"

total=$(wc -l < "$OUT/verdicts.tsv" | tr -d ' ')
nvm=$(grep -c "^vm	" "$OUT/verdicts.tsv")
nfb=$(grep -c "^fallback	" "$OUT/verdicts.tsv")
nfail=$(grep -c "^FAIL	" "$OUT/verdicts.tsv")
grep "^FAIL	" "$OUT/verdicts.tsv" | sort | while IFS='	' read -r v f why; do
  echo "FAIL $f ($why)"
  diff "$OUT/$(basename "$f" .rb).exp" "$OUT/$(basename "$f" .rb).got" | head -8 | sed 's/^/     /'
  grep -av '^mere-ruby: vm: ' "$OUT/$(basename "$f" .rb).err" | head -4 | sed 's/^/     err: /'
done
echo "-- why a main script fell back, most common first"
grep "^fallback	" "$OUT/verdicts.tsv" | cut -f3 | sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -rn | head -40

# the list of fallbacks: a program not on it that fell back, and one on it
# that ran on the VM
LIST="${VM_FALLBACKS:-$ROOT/tools/iseq/vm_fallbacks.txt}"
nlist=0
if [ "$LIST" != none ]; then
  [ -f "$LIST" ] || { echo "vm_corpus: no list of fallbacks at $LIST" >&2; exit 2; }
  grep -v '^#' "$LIST" | grep -v '^[[:space:]]*$' | cut -f1 | sort -u > "$OUT/listed.txt"
  grep "^fallback	" "$OUT/verdicts.tsv" | sort -t '	' -k2,2 > "$OUT/fell.tsv"
  while IFS='	' read -r v f why; do
    if ! grep -qxF "$f" "$OUT/listed.txt"; then
      echo "UNLISTED fallback $f ($why): the VM declines a program it is not listed to decline -- make it run on the VM, or add a line to $(basename "$LIST") saying why"
      nlist=$((nlist + 1))
    fi
  done < "$OUT/fell.tsv"
  grep "^vm	" "$OUT/verdicts.tsv" | cut -f2 | sort -u > "$OUT/ran.txt"
  while read -r f; do
    if grep -qxF "$f" "$OUT/ran.txt"; then
      echo "LISTED but on the VM: $f runs on the VM now -- remove its line from $(basename "$LIST")"
      nlist=$((nlist + 1))
    fi
  done < "$OUT/listed.txt"
fi
echo "vm_corpus: $total programs -- $nvm on the VM, $nfb on the evaluator (fell back), $nfail FAIL${nlist:+, $nlist against the list of fallbacks}"
[ "$nfail" = 0 ] && [ "$nlist" = 0 ]
