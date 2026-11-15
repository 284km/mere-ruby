#!/bin/sh
# tools/iseq/vm_corpus.sh — the corpus with each FILE on the ISeq VM
# (MERE_RUBY_VM, note 552).
#
# Every corpus program is run by ./mere-ruby with MERE_RUBY_VM=report: the
# main script and each file it requires run on the VM when the compiler and
# the VM take the whole file, and on the evaluator otherwise, saying so on
# stderr ("mere-ruby: vm: <file>: <why>"). The run's stdout and exit status
# are compared with the reference ruby's, as run_corpus.sh compares them.
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
#   sh tools/iseq/vm_corpus.sh [-j N] [corpus/NNN_*.rb ...]
#       (RUBY=, MR_BIN= to override; VM_CORPUS_OUT=<dir> keeps the outputs)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
RUBY="${RUBY:-$HOME/.rbenv/versions/4.0.9/bin/ruby}"
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
mrc=0; MERE_RUBY_VM=report perl -e 'alarm 300; exec @ARGV' "$MR" "$f" > "$OUT/$b.got" 2> "$OUT/$b.err" || mrc=$?
why="$(grep -a "^mere-ruby: vm: $f: " "$OUT/$b.err" | head -1 | sed "s|^mere-ruby: vm: $f: ||")"
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
echo "vm_corpus: $total programs -- $nvm on the VM, $nfb on the evaluator (fell back), $nfail FAIL"
[ "$nfail" = 0 ]
