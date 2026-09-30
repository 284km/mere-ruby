#!/bin/sh
# Does the DRIVER behave like ruby's? Everything else here asks about the
# language; this asks about argv, and nothing else did.
#
#   ./clitest/run.sh [reference-ruby]
#
# Why it is separate from the corpus: a corpus program is always run as
# `mere-ruby FILE`, so every other gate exercises exactly ONE of the shapes a
# caller can use. `-e`, `-`, `-v` and an unrecognised option were all missing
# and no gate could have said so -- the corpus would have gone on passing with
# the driver accepting nothing but a path. rbenv and rubygems both start by
# asking `ruby -v`, so the gap was load-bearing.
#
# The reference does the judging wherever a reference can: each case runs under
# BOTH interpreters and the outputs are compared. Two cases cannot be compared
# that way and say so:
#   * the version STRING -- ruby prints its own, and agreement is only expected
#     when the reference happens to be the version mere-ruby models. So the
#     reference-free half is checked always (`-v` must equal
#     RUBY_DESCRIPTION, because two copies of one string drift), and the
#     comparison is made only when the versions match, and SKIPped out loud.
#   * the bare invocation at a TERMINAL -- ruby waits for a program on stdin,
#     mere-ruby prints usage (a person at a silent prompt is the case it is
#     for). A gate has no terminal, so what is checked here is the other half:
#     with stdin redirected, both read the program from it. The wait is
#     bounded, so a run that blocks fails instead of never returning.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
# see run_corpus.sh: a candidate build is gated before it takes over the path.
mr="${MR_BIN:-$here/../mere-ruby}"
ref="${1:-ruby}"
[ -x "$mr" ] || { echo "clitest: no $mr"; exit 2; }
command -v "$ref" > /dev/null || { echo "clitest: no reference ruby ($ref)"; exit 2; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# -Eutf-8 for the same reason run_corpus.sh pins it: the reference's default
# external encoding otherwise depends on the caller's locale.
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"; export RUBYOPT
pass=0; fail=0; skip=0; diverge=0
mkdir -p "$tmp/inc"
echo 'MARKER = "inc"' > "$tmp/inc/mylib.rb"
printf 'require "mylib"\np MARKER\np ARGV\np __FILE__\n' > "$tmp/s.rb"

# cmp NAME -- ARGS...   : run ARGS under both, require byte-identical output+status
cmp_both() {
  name="$1"; shift; [ "$1" = "--" ] && shift
  go=$("$mr" "$@" 2>&1); grc=$?
  ro=$("$ref" "$@" 2>&1); rrc=$?
  if [ "$go" = "$ro" ] && [ "$grc" = "$rrc" ]; then
    pass=$((pass+1)); printf 'MATCH   %s\n' "$name"
  else
    fail=$((fail+1))
    printf 'FAIL    %s\n  mere(%s): %s\n  ruby(%s): %s\n' "$name" "$grc" "$go" "$rrc" "$ro"
  fi
}
# stdin variant: the program arrives on stdin, not in argv.
cmp_stdin() {
  name="$1"; prog="$2"; shift 2
  go=$(printf '%s\n' "$prog" | "$mr" "$@" 2>&1); grc=$?
  ro=$(printf '%s\n' "$prog" | "$ref" "$@" 2>&1); rrc=$?
  if [ "$go" = "$ro" ] && [ "$grc" = "$rrc" ]; then
    pass=$((pass+1)); printf 'MATCH   %s\n' "$name"
  else
    fail=$((fail+1))
    printf 'FAIL    %s\n  mere(%s): %s\n  ruby(%s): %s\n' "$name" "$grc" "$go" "$rrc" "$ro"
  fi
}

cmp_both "-e one"            -- -e 'puts 1+1'
cmp_both "-e glued"          -- -e'puts "glued"'
cmp_both "-e twice = 1 scope" -- -e 'a = 41' -e 'puts a + 1'
cmp_both "-e sees __FILE__"   -- -e 'p __FILE__'
cmp_both "-e then ARGV"       -- -e 'p ARGV' x y
cmp_both "-I<dir> FILE ARG"   -- "-I$tmp/inc" "$tmp/s.rb" hello
cmp_both "-I <dir> FILE ARG"  -- -I "$tmp/inc" "$tmp/s.rb" hello
# ★ The one that regressed silently: flags AFTER the script are the SCRIPT's.
# Option scanning used to run to the end of the list and eat them.
cmp_both "flags after FILE -> ARGV" -- "-I$tmp/inc" "$tmp/s.rb" -Ilib --foo
cmp_both "-- ends options"    -- "-I$tmp/inc" -- "$tmp/s.rb" -v
cmp_stdin "- reads stdin"     'puts "stdin ok"' -
cmp_stdin "- then ARGV"       'p ARGV' - a b
# The loop switches: here stdin is the program's INPUT, and -e the program.
lines='a b
c:d'
cmp_stdin "-n"                "$lines" -n -e 'puts $_.size'
cmp_stdin "-p"                "$lines" -p -e '$_ = $_.upcase'
cmp_stdin "-ne glued"         "$lines" -ne 'print $.'
cmp_stdin "-nl chomps"        "$lines" -nl -e 'p $_'
cmp_stdin "-lpe and \$\\"   "$lines" -lpe '$_ += "!"'
cmp_stdin "-na splits"        "$lines" -na -e 'p $F'
cmp_stdin "-naF: separator"   "$lines" -naF: -e 'p $F'
cmp_stdin "-n BEGIN / END"    "$lines" -n -e 'BEGIN { puts :hi }; print $_; END { puts :bye }'
cmp_stdin "-n chomp / chop"   "$lines" -W0 -n -e 'chomp; chop; p $_'
cmp_stdin "-p next skips"     "$lines" -p -e 'next if $_.start_with?("a")'

cmp_stdin "-n with an integer flip-flop" "$lines" -ne 'print if 2..2'
printf 'a\nxb\ny\nz\n' > "$tmp/ff.txt"
cmp_both "-n with a regexp flip-flop" -- -ne 'print if /x/../y/' "$tmp/ff.txt"

# The switches beyond the loop ones. Each prints what it set, so a switch
# that is accepted and does nothing reads as a mismatch.
cmp_both "-s globals"         -- -s -e 'p $n, $_name, ARGV' -- -n --name=x y
cmp_both "-0 octal"           -- -072 -e 'p $/, $-0'
cmp_both "-00 paragraph"      -- -00 -e 'p $/'
cmp_both "-0777 slurp"        -- -0777 -e 'p $/'
cmp_both "-d"                 -- --disable-gems -d -e 'p [$DEBUG, $-d, $VERBOSE]'
cmp_both "-c"                 -- -c -e 'puts 1' -e 'x = 2'
cmp_both "-K source encoding" -- -Ke -e 'p __ENCODING__, Encoding.default_external'
cmp_both "-E ext:int"         -- -E euc-jp:Shift_JIS -e 'p Encoding.default_external, Encoding.default_internal'
cmp_both "-U"                 -- -U -e 'p Encoding.default_internal'
cmp_both "-C dir"             -- -C / -e 'p Dir.pwd'
cmp_both "--disable=LIST"     -- --disable=gems,frozen-string-literal -e 'p "a".frozen?'
printf 'junk\n#!ruby\np __LINE__\n' > "$tmp/x.txt"
cmp_both "-x"                 -- -x "$tmp/x.txt"
# RUBYOPT: read after the command line, which keeps what it decided
cmp_env() {
  name="$1"; ev="$2"; shift 2; [ "$1" = "--" ] && shift
  go=$(env RUBYOPT="$ev" "$mr" "$@" 2>&1); grc=$?
  ro=$(env RUBYOPT="$ev" "$ref" "$@" 2>&1); rrc=$?
  if [ "$go" = "$ro" ] && [ "$grc" = "$rrc" ]; then
    pass=$((pass+1)); printf 'MATCH   %s\n' "$name"
  else
    fail=$((fail+1))
    printf 'FAIL    %s\n  mere(%s): %s\n  ruby(%s): %s\n' "$name" "$grc" "$go" "$rrc" "$ro"
  fi
}
cmp_env "RUBYOPT -I -W0"      "-Eutf-8 -I/nonexistent/q -W0" -- -e 'p $:[0], $VERBOSE'
cmp_env "RUBYOPT under a CLI -W1" "-Eutf-8 -w" -- -W1 -e 'p $VERBOSE'

# Failure shapes: a wrong exit STATUS is what a caller in a pipeline sees.
for bad in -Z --nope; do
  go=$("$mr" "$bad" 2>&1); grc=$?
  ro=$("$ref" "$bad" 2>&1); rrc=$?
  if [ "$grc" -ne 0 ] && [ "$rrc" -ne 0 ]; then
    pass=$((pass+1)); printf 'MATCH   invalid option %s (both non-zero)\n' "$bad"
  else
    fail=$((fail+1)); printf 'FAIL    invalid option %s: mere rc=%s ruby rc=%s\n' "$bad" "$grc" "$rrc"
  fi
done
# ...and the ones ruby refuses with a RuntimeError before anything runs (the
# message names the interpreter, so only the status is compared)
for bad in "-Eascii:ascii -U" "--encoding=a:b:c"; do
  go=$("$mr" $bad -e 1 2>&1); grc=$?
  ro=$("$ref" $bad -e 1 2>&1); rrc=$?
  if [ "$grc" -ne 0 ] && [ "$rrc" -ne 0 ]; then
    pass=$((pass+1)); printf 'MATCH   refused %s (both non-zero)\n' "$bad"
  else
    fail=$((fail+1)); printf 'FAIL    refused %s: mere rc=%s ruby rc=%s\n' "$bad" "$grc" "$rrc"
  fi
done
go=$(env RUBYOPT=-a "$mr" -e 1 2>&1); grc=$?
ro=$(env RUBYOPT=-a "$ref" -e 1 2>&1); rrc=$?
if [ "$grc" -ne 0 ] && [ "$rrc" -ne 0 ]; then
  pass=$((pass+1)); echo "MATCH   RUBYOPT=-a refused (both non-zero)"
else
  fail=$((fail+1)); printf 'FAIL    RUBYOPT=-a: mere rc=%s ruby rc=%s\n' "$grc" "$rrc"
fi
go=$("$mr" -e 'a{' 2>&1); grc=$?
ro=$("$ref" -e 'a{' 2>&1); rrc=$?
case "$go" in
  *SyntaxError*) if [ "$grc" -ne 0 ] && [ "$rrc" -ne 0 ]; then pass=$((pass+1)); echo "MATCH   syntax error is a SyntaxError, non-zero"
                 else fail=$((fail+1)); printf 'FAIL    syntax error: mere rc=%s ruby rc=%s\n' "$grc" "$rrc"; fi ;;
  *) fail=$((fail+1)); printf 'FAIL    syntax error does not say SyntaxError: %s\n' "$go" ;;
esac
go=$("$mr" "$tmp/nope.rb" 2>&1); grc=$?
ro=$("$ref" "$tmp/nope.rb" 2>&1); rrc=$?
if [ "$grc" -ne 0 ] && [ "$rrc" -ne 0 ]; then
  pass=$((pass+1)); echo "MATCH   missing file (both non-zero)"
else
  fail=$((fail+1)); printf 'FAIL    missing file: mere rc=%s ruby rc=%s\n' "$grc" "$rrc"
fi

# -v, the half that needs no reference: ONE string, asked two ways.
v1=$("$mr" -v 2>&1)
v2=$("$mr" -e 'puts RUBY_DESCRIPTION' 2>&1)
if [ "$v1" = "$v2" ]; then
  pass=$((pass+1)); echo "MATCH   -v == RUBY_DESCRIPTION"
else
  fail=$((fail+1)); printf 'FAIL    -v != RUBY_DESCRIPTION\n  -v: %s\n  const: %s\n' "$v1" "$v2"
fi
# ...and the half that does. Only comparable when the reference IS the modelled
# version; otherwise the disagreement is the point, not a defect.
refv=$("$ref" -e 'print RUBY_VERSION' 2>&1)
mrv=$("$mr" -e 'print RUBY_VERSION' 2>&1)
# ...but SKIP only when the two versions are both VERSIONS. Pointed at a binary
# with no -e, `$mrv` came back as the literal "-e" and this branch reported
# "SKIP: reference is 3.2.2, modelled is -e" -- a degenerate expectation
# wearing the face of a legitimate skip. Nothing was hidden (the check above
# failed) but the message pointed away from the cause.
case "$mrv" in
  *.*) : ;;
  *) fail=$((fail+1)); printf 'FAIL    RUBY_VERSION is not a version: %s\n' "$mrv"; mrv="" ;;
esac
if [ -n "$mrv" ] && [ "$refv" = "$mrv" ]; then
  rv=$("$ref" -v 2>&1)
  if [ "$v1" = "$rv" ]; then pass=$((pass+1)); echo "MATCH   -v byte-equals ruby -v"
  else fail=$((fail+1)); printf 'FAIL    -v differs\n  mere: %s\n  ruby: %s\n' "$v1" "$rv"; fi
else
  skip=$((skip+1)); printf 'SKIP    -v vs ruby -v (reference is %s, modelled is %s)\n' "$refv" "$mrv"
fi

# -h has to exist: the invalid-option message names it, and a diagnostic that
# points at a flag the binary does not have is worse than no diagnostic.
h=$("$mr" -h 2>&1); hrc=$?
case "$h" in
  usage:*) if [ "$hrc" -eq 0 ]; then pass=$((pass+1)); echo "MATCH   -h prints usage"
           else fail=$((fail+1)); echo "FAIL    -h rc=$hrc"; fi ;;
  *) fail=$((fail+1)); printf 'FAIL    -h did not print usage: %s\n' "$h" ;;
esac
inv=$("$mr" -Z 2>&1)
case "$inv" in
  *-h*) pass=$((pass+1)); echo "MATCH   invalid-option message names -h" ;;
  *) fail=$((fail+1)); printf 'FAIL    invalid-option message does not name -h: %s\n' "$inv" ;;
esac

# Bare invocation, stdin redirected: the program is read from it, as ruby
# does. Bounded, so a run that blocks FAILS rather than hanging the gate.
for bin_src in "" 'p [1, ARGV, __FILE__]'; do
  bo=$(printf '%s' "$bin_src" | perl -e 'alarm 10; exec @ARGV' "$mr" 2>&1); brc=$?
  br=$(printf '%s' "$bin_src" | "$ref" -Eutf-8 2>&1); brrc=$?
  if [ "$brc" -eq 142 ] || [ "$brc" -eq 14 ]; then
    fail=$((fail+1)); echo "FAIL    bare mere-ruby BLOCKED on stdin (alarm fired)"
  elif [ "$bo" = "$br" ] && [ "$brc" -eq "$brrc" ]; then
    pass=$((pass+1)); echo "MATCH   bare invocation reads the program from stdin (${bin_src:-empty})"
  else
    fail=$((fail+1)); printf 'FAIL    bare invocation, stdin %s: mere-ruby rc=%s %s / ruby rc=%s %s\n' "${bin_src:-empty}" "$brc" "$bo" "$brrc" "$br"
  fi
done

printf '\n%s pass / %s fail / %s skip / %s deliberate-diverge\n' "$pass" "$fail" "$skip" "$diverge"
[ "$fail" -eq 0 ] || exit 1
