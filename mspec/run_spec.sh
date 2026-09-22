#!/bin/sh
# Run a real spec/ruby file through the minimal mspec shim, under BOTH
# mere-ruby and ruby, and diff the outputs. The spec tree (core/, language/,
# shared/, fixtures/) is cloned into a temp dir with the shim installed as
# spec_helper.rb, so every require_relative (../spec_helper,
# ../../spec_helper, sibling shared/, cross-directory shared/) resolves.
#
#   ./run_spec.sh <path/to/some_spec.rb> [--keep]
spec="$1"
[ -f "$spec" ] || { echo "usage: run_spec.sh <spec.rb>"; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
# ⚠ PIN THE REFERENCE HERE, not in the caller. scoreboard.sh sources this, so
# every recorded number is against the pinned ruby -- but a hand-run of ONE
# file did not, and `ruby` on PATH is 3.4.9 while the records are 4.0.6. Every
# per-file check in a working session was then asking a different question from
# the sweep: core/array/detect_spec is `ruby_version_is "4.0"`, so under 3.4.9
# the reference ran ZERO examples and the file read DIFF against a mere-ruby
# that had done nothing wrong. "The reference is part of the subject" only
# holds if the harness pins it itself.
. "$here"/../tools/ref_ruby.sh
# see run_corpus.sh: a candidate build is gated before it takes over the path.
mr="${MR_BIN:-$here/../mere-ruby}"
# ⚠ THE CLONE IS THE SWEEP. Measured 2026-09-22: one spec file costs 2.71s
# real of which 1.89s is SYS and only 0.15s user -- the two interpreters take
# about 0.1s between them and the REST is copying 4,333 files (core, language,
# library, shared, fixtures) that never change. Across 2498 files that is ten
# million clones and roughly an hour of syscalls per sweep, and it is also what
# drives fseventsd to 100%+ for hours, which slowed everything else by up to 8x.
#
# SPEC_TREE lets the caller prepare that tree ONCE and hand it over; scoreboard
# does exactly that. Unset, this behaves as it always has -- a private tree per
# file, which is what a hand-run of one spec still wants.
if [ -n "${SPEC_TREE:-}" ]; then
  tmp="$SPEC_TREE"
  tree_is_shared=1
else
  tmp="$(mktemp -d)"
  tree_is_shared=0
fi
specdir="$(cd "$(dirname "$spec")" && pwd)"
# subpath under spec/ruby (e.g. "language", "core/enumerator"); the spec root.
case "$specdir" in
  */spec/ruby/*)
    sub="${specdir#*/spec/ruby/}"
    specroot="${specdir%/$sub}"
    ;;
  *) sub="language"; specroot="" ;;
esac
if [ "$tree_is_shared" = 1 ]; then
  : # the caller built it; nothing to copy
elif [ -n "$specroot" ]; then
  # clone the relevant trees (APFS copy-on-write when available).
  # ⚠ LIBRARY WAS NOT IN THIS LIST, so not one of ruby/spec's 1516 library
  # files could run: the clone did not contain them and BOTH sides died with
  # `cannot load such file`. Measured that way the whole tree reads 0/1516,
  # which is the instrument's answer and not the subject's -- mere-ruby ships
  # set, pathname, digest, csv, zlib, socket, stringio and more, and
  # library/pathname/absolute_spec is MATCH the moment the directory is there.
  for d in core language library shared fixtures; do
    [ -d "$specroot/$d" ] || continue
    cp -Rc "$specroot/$d" "$tmp/$d" 2>/dev/null || cp -R "$specroot/$d" "$tmp/$d"
  done
else
  mkdir -p "$tmp/$sub"
  cp "$spec" "$tmp/$sub/"
  [ -d "$specdir/fixtures" ] && cp -R "$specdir/fixtures" "$tmp/$sub/fixtures"
  [ -d "$specdir/shared" ] && cp -R "$specdir/shared" "$tmp/$sub/shared"
fi
# ⚠ THE PER-SIDE BOUND IS CPU TIME, and the wall bound beside it is not a
# second opinion about the same question -- see mspec/bounds.sh, which owns
# both numbers and says why there are two. In short: SPEC_CPU answers "does
# this finish", SPEC_WALL answers "is this process running at all".
. "$here"/bounds.sh
# The probe costs a CPU-second, so the sweep runs it ONCE and passes the answer
# down; a hand-run of a single file pays for it itself, where a second is
# nothing. ⚠ Without this the fallback would be silent, and a shell that cannot
# set the limit would give a sweep with no bound on "does this finish" --
# a runaway file would simply look like a hang.
if [ -n "${SPEC_CPU_OK:-}" ]; then
  sb_cpu_ok="$SPEC_CPU_OK"
elif sb_cpu_works; then
  sb_cpu_ok=1
else
  sb_cpu_ok=0
fi
if [ "$sb_cpu_ok" != 1 ]; then
  # No CPU bound available: fall back to what this harness did before, a wall
  # alarm at the CPU number, and SAY SO rather than running unbounded.
  echo "run_spec.sh: this shell cannot set RLIMIT_CPU; falling back to a ${sb_cpu}s WALL bound per side (the verdict will depend on the load)" >&2
  sb_wall="$sb_cpu"
fi

# the shim replaces the real mspec spec_helper. In a shared tree it is already
# there (the caller put it there once); copying it again per file is one more
# write into a directory fseventsd is watching.
[ "$tree_is_shared" = 1 ] || cp "$here/spec_helper.rb" "$tmp/spec_helper.rb"
base="$(basename "$spec" .rb)"
cat > "$tmp/driver.rb" <<EOF
require_relative "spec_helper"
require_relative "$sub/$base"
mspec_report
EOF
# Bound the mere-ruby run HERE, not only in the caller: scoreboard.sh's alarm
# kills this script, but the child would keep spinning (a runaway spec used to
# leave one behind per sweep, and they pile up until the machine is out of
# memory). SIGKILL after the deadline so nothing survives.
# ...and bound the BYTES, on both sides. A command substitution buffers the
# whole output in THIS shell, so a spec that prints without end grows the
# harness rather than the interpreter -- which is why rss_guard.sh, watching
# only processes whose args say mere-ruby, logged no kill on the two occasions
# a sweep took the machine down (2026-09-04). `head -c` stays in the pipe
# because closing it is what stops the producer (SIGPIPE); capturing to a file
# first would trade a bounded run for an unbounded one.
#
# The reference side had no bound at all -- no alarm, no cap. It is one ruby
# loop away from the same crash, and "the reference cannot run away" is an
# assumption, not a property.
#
# The exit status travels beside the output rather than through it: with
# `head -c` in the way, `$?` would be head's.
out_cap=2000000

# BOTH SIDES RUN IN AN ALLOWLISTED ENVIRONMENT, and that is a SAFETY control
# before it is a comparability one.
#
# core/env's specs measure the process environment, and a failure message then
# carries it: ruby's own `ENV.method(:filter).inspect` is 6143 characters of
# environment, and mere-ruby's is 4845. The harness records the first line the
# two sides disagree on, verbatim, into files that are CHECKED IN -- so on
# 2026-09-04 a session token went into a public commit, first key in ENV's
# order, kept by the very clip that was supposed to bound the record.
#
# Masking the record is a mitigation and it is a list of shapes someone thought
# of. This is the elimination: the subprocesses cannot record what they were
# never given. Anything not named below is simply not in their environment, so
# a variable added to this machine tomorrow -- with any name, holding anything
# -- cannot reach a record.
#
# It also closes the drift KNOWN_GAPS has open on this group: core/env's MATCH
# count moved between sessions with no change to the interpreter, because its
# SUBJECT was the session. Now the subject is this list.
#
# Both sides get the SAME environment, so the comparison stays fair. The list
# is what the two interpreters need to start and find their stdlib, plus a
# fixed locale (the record must not depend on the operator's).
# ⚠ The three names at the end are PLATFORM NOISE, not environment: each side
# gets one or two variables it did not ask for, and ENV's specs count keys.
#   - mere-ruby reads the environment by running env(1) through a shell, and
#     the shell exports its own PWD and SHLVL to it (see KNOWN_GAPS).
#   - ruby links CoreFoundation, which puts __CF_USER_TEXT_ENCODING into its
#     process's environ before main runs.
# Neither is about the subject under test, and `env -i` was handing the two
# sides different key SETS -- five core/env files were DIFF for that alone, and
# which five depended on the machine. Naming all three here gives both sides
# the same keys. Their VALUES still differ (mere-ruby's shell overwrites PWD
# and SHLVL with its own), which no spec reads.
# ⚠ IT EXECS. Both call sites are the last command of a subshell that has just
# set the CPU limit, and an extra shell between the limit and the subject would
# be one more process with its own fresh budget -- and one more reaper printing
# "Cputime limit exceeded" into the captured output.
spec_env() {
  exec env -i \
    PWD="${PWD}" \
    SHLVL="${SHLVL:-1}" \
    __CF_USER_TEXT_ENCODING="${__CF_USER_TEXT_ENCODING:-0x0:0x0:0x0}" \
    PATH="$PATH" \
    HOME="$HOME" \
    TMPDIR="${TMPDIR:-/tmp}" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    ${RBENV_VERSION:+RBENV_VERSION="$RBENV_VERSION"} \
    ${RBENV_ROOT:+RBENV_ROOT="$RBENV_ROOT"} \
    ${GEM_HOME:+GEM_HOME="$GEM_HOME"} \
    ${GEM_PATH:+GEM_PATH="$GEM_PATH"} \
    ${RUBYOPT:+RUBYOPT="$RUBYOPT"} \
    ${RUBYLIB:+RUBYLIB="$RUBYLIB"} \
    ${MERE_SPEC_VERBOSE:+MERE_SPEC_VERBOSE="$MERE_SPEC_VERBOSE"} \
    ${MSPEC_RUBY_EXE:+MSPEC_RUBY_EXE="$MSPEC_RUBY_EXE"} \
    "$@"
}
# ⚠ each side must name ITSELF here. mspec's `ruby_cmd` builds a shell command
# out of RUBY_EXE, and a spec that shells out has to reach the interpreter it
# is testing -- not whatever `ruby` the PATH happens to hold. The shim reads
# this; there is nothing in either interpreter that can answer "my own path".
# ⚠ The braces' `2>/dev/null` is not the subject's stderr -- that is already
# folded into the capture by the `2>&1` on the subshell. It is THIS shell's own
# "Cputime limit exceeded: 24", printed when it reaps a process the kernel
# killed, which would otherwise land in the recorded output as if the spec had
# said it.
# ⚠ NO EXTRA SHELL BETWEEN THE LIMIT AND THE SUBJECT. Two earlier attempts put
# one there -- first to read the wall bound from the environment, then to record
# the child's true exit status -- and each cost a key in `env -i`'s allowlist or
# a shell level, which core/env COUNTS: six of its files went DIFF and MATCH
# dropped 1764 to 1758. The record caught it; nothing else would have.
#
# perl already has to be in the chain for the alarm, so it does all of it and
# adds nothing: fork, redirect the child's stderr into stdout, exec, and on the
# alarm KILL the child and remember that it was the wall bound rather than the
# child's own death. `system`/`exec` with a LIST never invokes a shell.
#
# ⚠ This also settles a question left open earlier: the wall bound is now a
# kill, not a signal the subject may choose to handle.
sb_runner='
  my ($wall, $rcf, @cmd) = @ARGV;
  my $pid = fork();
  if (!defined $pid) { exit 127 }
  if (!$pid) {
    # ⚠ RESET THE SIGNALS A BACKGROUND JOB IGNORES. A shell sets SIGINT and
    # SIGQUIT to SIG_IGN for a job it starts in the background, and SIG_IGN is
    # inherited across fork AND exec -- so with SPEC_JOBS>1 every spec process
    # under a worker ignored SIGINT, while at SPEC_JOBS=1 (foreground) it did
    # not. Measured: `core/exception/interrupt_spec` spawns a child that kills
    # itself with SIGINT; in the foreground the child dies, from a background
    # subshell it never does and the parent blocks on read until the wall bound.
    # That is the harness changing the SUBJECT, and it moved a row between DIFF
    # and SKIP depending only on the worker count.
    $SIG{INT} = "DEFAULT"; $SIG{QUIT} = "DEFAULT";
    open(STDERR, ">&", \*STDOUT); exec(@cmd); exit 127
  }
  my $timedout = 0;
  $SIG{ALRM} = sub { $timedout = 1; kill "KILL", $pid };
  alarm $wall;
  waitpid($pid, 0);
  my $st = $?;
  alarm 0;
  my $rc = ($st & 127) ? 128 + ($st & 127) : ($st >> 8);
  $rc = 142 if $timedout;
  if (open(my $fh, ">", $rcf)) { print $fh "$rc\n" }
'
out_m="$( ( ulimit -c 0; ulimit -S -t "$sb_cpu" 2>/dev/null
            MSPEC_RUBY_EXE="$mr"; export MSPEC_RUBY_EXE
            spec_env /usr/bin/time -l -o "$tmp/ru_m" perl -e "$sb_runner" "$sb_wall" "$tmp/rc_m" "$mr" "$tmp/driver.rb"
          ) 2>/dev/null | head -c "$out_cap")"
rc_m="$(cat "$tmp/rc_m" 2>/dev/null || echo 0)"
# the REAL ruby binary, not rbenv's shim: the shim exports RBENV_* and RUBYLIB
# into the process it execs, and a spec that walks ENV then sees a different
# environment from the one mere-ruby was given (see tools/ref_ruby.sh).
out_r="$( ( ulimit -c 0; ulimit -S -t "$sb_cpu" 2>/dev/null
            MSPEC_RUBY_EXE="${REF_RUBY_BIN:-ruby}"; export MSPEC_RUBY_EXE
            spec_env /usr/bin/time -l -o "$tmp/ru_r" perl -e "$sb_runner" "$sb_wall" "$tmp/rc_r" "${REF_RUBY_BIN:-ruby}" -W0 "$tmp/driver.rb"
          ) 2>/dev/null | head -c "$out_cap")"

# ⚠ THREE BOUNDS, ONE VERDICT: "the harness stopped it". A run killed by the
# CPU budget, by the wall alarm or by the memory guard did NOT abort -- and
# CRASH's definition in the table is "mere-ruby aborts where ruby does not",
# which is a claim about the interpreter. For as long as a SIGKILL from the
# memory guard arrived here as "no output", the scoreboard read it as CRASH and
# the record said the interpreter aborted about a file that works and wants
# 7 GB. That is the same misattribution the SIGALRM case was given its own word
# for; the byte bound gets the same treatment, and `timed_out` below is really
# "one of this harness's bounds answered".
#
# The FACT is not lost: it travels as the cause, into mspec/tags/ beside the
# filename, and a file that needs gigabytes where ruby needs megabytes is a
# real gap named in KNOWN_GAPS.md. What changes is which column carries it.
# (Replacing the REFERENCE section instead would make it SKIP -- a claim about
# ruby, which is a third wrong owner.)
# ⚠ ONE SENTENCE FOR ALL THREE BOUNDS, AND IT REPORTS MEASUREMENTS. Which
# signal arrived is a race when a file is above more than one threshold, and
# two of them are: see mspec/bounds.sh. `rusage` says what the file actually
# did, and it says the same thing at one worker and at six.
#
# The rusage line is only a REFINEMENT of the sentence: if it cannot be parsed
# the row still names the signal, because a missing measurement must not become
# a silent one.
sb_ru_m="$(sb_rusage_read "$tmp/ru_m" 2>/dev/null || true)"
sb_stopped=""
timed_out=0
if [ "$rc_m" = "137" ] || [ "$rc_m" = "9" ]; then
  timed_out=1; sb_stopped="SIGKILL (the memory guard, unless something else on this machine sent it; see mspec/rss_kills.log)"
fi
# A run that passed the alarm is SLOW, which is not what CRASH says. With no
# `pass=` line on the mere-ruby side the scoreboard reads CRASH and takes the
# last thing said as the cause, so a file that WORKS and is merely slow was
# recorded as aborting -- core/range/step_spec was, for one walk that never
# ended. The verdict is its own word here, and scoreboard.sh turns it into the
# SLOW column it already has.
# ⚠ TWO KILLS, TWO FINDINGS, and the record has to name which. SIGXCPU means
# the file BURNED the budget: a real "this does not finish", and the same
# verdict whether one worker runs or six. SIGALRM means the process existed for
# SPEC_WALL seconds without burning it -- blocked, not slow -- which is a fact
# about the harness or the environment and not about the interpreter's speed.
# They were one bucket with one message when both bounds were wall clock, and
# that is exactly the distinction that was lost.
if [ "$rc_m" = "152" ] || [ "$rc_m" = "24" ]; then
  timed_out=1; sb_stopped="SIGXCPU (the CPU budget)"
fi
if [ "$rc_m" = "142" ] || [ "$rc_m" = "14" ]; then
  timed_out=1; sb_stopped="SIGALRM (the ${sb_wall}s wall bound, so it was waiting rather than computing)"
fi
if [ "$timed_out" = 1 ]; then
  if [ -n "$sb_ru_m" ]; then
    sb_cpu_used="${sb_ru_m%%	*}"; sb_peak="${sb_ru_m#*	}"
    sb_class="$(sb_rusage_class "$sb_cpu_used" "$sb_peak")"
    sb_bound_log "$spec" mere-ruby "$sb_stopped" "$sb_cpu_used" "$sb_peak"
    # ⚠ THE CLASS, NOT THE NUMBERS -- see mspec/bounds.sh. And the signal is
    # named only when the measurements do NOT account for the stop, which means
    # it was the wall bound: a file over a bound is described identically at one
    # worker and at six, and naming the signal there is what made rows swap.
    case "$sb_class" in
      "neither bound reached") out_m="STOPPED BY THIS HARNESS: $sb_stopped, with $sb_class -- it did not abort on its own" ;;
      *)                       out_m="STOPPED BY THIS HARNESS: $sb_class -- it did not abort on its own" ;;
    esac
  else
    out_m="STOPPED BY THIS HARNESS: $sb_stopped -- it did not abort on its own (rusage unavailable)"
  fi
fi
if [ "${#out_m}" -ge "$out_cap" ]; then
  out_m="RUNAWAY OUTPUT: passed $out_cap bytes and was cut off"
fi
if [ "${#out_r}" -ge "$out_cap" ]; then
  out_r="RUNAWAY OUTPUT on the reference side: passed $out_cap bytes and was cut off"
fi
# ⚠ THE REFERENCE RUNS UNDER THE SAME BOUNDS and its status was never read at
# all -- `$tmp/rc_r` was written and nothing looked at it. A killed reference
# leaves a truncated tally, or none, and the row then reads DIFF or SKIP: a
# claim about ruby, made by the harness, with nothing saying so. It is rare
# (ruby is the fast side here) and that is exactly why it would be believed.
rc_r="$(cat "$tmp/rc_r" 2>/dev/null || echo 0)"
case "$rc_r" in
  152|24|142|14|137|9)
    sb_ru_r="$(sb_rusage_read "$tmp/ru_r" 2>/dev/null || true)"
    if [ -n "$sb_ru_r" ]; then
      sb_bound_log "$spec" reference "signal $rc_r" "${sb_ru_r%%	*}" "${sb_ru_r#*	}"
      out_r="THE REFERENCE was stopped by this harness: $(sb_rusage_class "${sb_ru_r%%	*}" "${sb_ru_r#*	}"). ruby did not fail -- this file is unmeasured."
    else
      out_r="THE REFERENCE was stopped by this harness (signal $rc_r). ruby did not fail -- this file is unmeasured."
    fi
    ;;
esac
echo "--- mere-ruby:"; echo "$out_m"
echo "--- ruby:";      echo "$out_r"
# SLOW carries its reason, so the caller can record WHICH bound answered.
# ⚠ printf, not echo: dash's echo expands \t and bash's does not, and a verdict
# line that is one field in one shell and two in another is a harness that
# answers differently depending on where it runs.
if [ "$timed_out" = 1 ]; then printf 'SLOW\t%s\n' "$out_m"
elif [ "$out_m" = "$out_r" ]; then echo "MATCH"; else echo "DIFF"; fi
# a SHARED tree belongs to the caller, which removes it when the sweep ends.
[ "$tree_is_shared" = 1 ] || [ "$2" = "--keep" ] || rm -rf "$tmp"
