#!/bin/sh
# tools/iseq/vm_check.sh — the ISeq VM (note 548, round 33) against ruby itself.
#
# Each snippet of tools/iseq/vm_snippets.txt (separated by "\n----\n") becomes
# a program that runs
#
#     p RubyVM::InstructionSequence.compile(SRC).eval
#
# once under the reference ruby and once under ./mere-ruby with
# MERE_ISEQ_VM=strict, and the two runs' stdout and stderr are compared byte for
# byte. Strict is the point: a sequence the VM refuses raises NotImplementedError
# naming what it refused, instead of quietly running on the evaluator -- so a
# snippet that matches here matched ON THE VM, and one the VM cannot run fails
# loudly rather than passing for something it is not.
#
# A snippet may start with directive lines (each removed from the source):
#   #pre: <ruby>   run before the compile, outside the sequence -- a def the
#                  sequence calls (a def inside it is not this round's)
#   #opt: <ruby>   the compile option, ISeq.compile's fifth argument
#   #rescue        rescue what eval raises and print "Class: message": for an
#                  error whose BACKTRACE ruby draws with a frame the evaluator
#                  does not (ZeroDivisionError's 'Integer#/'), so the run is
#                  compared on what the VM did, not on that frame
#
#   sh tools/iseq/vm_check.sh [snippets]       (RUBY=, MR_BIN= to override)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUBY="${RUBY:-$HOME/.rbenv/versions/4.0.9/bin/ruby}"
MR="${MR_BIN:-$ROOT/mere-ruby}"
case "$MR" in /*) ;; *) MR="$(pwd)/$MR" ;; esac
SNIPS="${1:-$ROOT/tools/iseq/vm_snippets.txt}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# one program per snippet, s001.rb ...
"$RUBY" - "$SNIPS" "$TMP" <<'SPLIT'
src, dir = File.read(ARGV[0]), ARGV[1]
src.split("\n----\n").each_with_index do |s, i|
  pre = []; opt = nil; resc = false
  lines = s.lines
  while (l = lines.first) && l =~ /\A#(pre|opt|rescue)\b:? ?(.*)\n?\z/
    case $1
    when "pre" then pre << $2
    when "opt" then opt = $2
    when "rescue" then resc = true
    end
    lines.shift
  end
  call = opt ? "RubyVM::InstructionSequence.compile(SRC, nil, nil, 1, #{opt}).eval" : "RubyVM::InstructionSequence.compile(SRC).eval"
  run = resc ? "begin\n  p #{call}\nrescue => e\n  puts \"\#{e.class}: \#{e.message}\"\nend\n" : "p #{call}\n"
  File.write(format("%s/s%03d.rb", dir, i + 1),
             pre.map { |x| x + "\n" }.join + "SRC = <<'__VM_SRC__'\n" + lines.join.chomp + "\n__VM_SRC__\n" + run)
end
SPLIT

n=0; ok=0
for f in "$TMP"/s*.rb; do
  b=$(basename "$f")
  n=$((n + 1))
  (cd "$TMP" && "$RUBY" "$b" > r.out 2> r.err)
  (cd "$TMP" && MERE_ISEQ_VM=strict "$MR" "$b" > m.out 2> m.err)
  if cmp -s "$TMP/r.out" "$TMP/m.out" && cmp -s "$TMP/r.err" "$TMP/m.err"; then
    ok=$((ok + 1))
  else
    echo "== DIFF $b:"
    sed -n "/^SRC = /,/^__VM_SRC__/p" "$f" | sed '1d;$d' | sed 's/^/   | /'
    diff "$TMP/r.out" "$TMP/m.out" | sed 's/^/   out /'
    diff "$TMP/r.err" "$TMP/m.err" | sed 's/^/   err /'
  fi
done
echo "vm_check: $ok/$n"
[ "$ok" = "$n" ]
