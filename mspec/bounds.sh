#!/bin/sh
# The harness's limits, in ONE file, because there is more than one of them and
# they have to agree with each other.
#
# ⚠ WHY THIS FILE EXISTS. There were two bounds -- run_spec.sh's per-side alarm
# and scoreboard.sh's per-file alarm -- and both were WALL CLOCK. Measured
# 2026-09-22 with one and the same binary:
#
#   sequential, 25s / 60s      core/dir 18 DIFF, 1 SLOW; 0 CRASH overall
#   six workers, 25s / 60s     core/dir 14 DIFF, 5 SLOW  (four files crossed a
#                              bound because five other workers shared the CPU)
#   six workers, 150s / 360s   SLOW 13 -> 4, CRASH 0 -> 4 (with more time those
#                              same files reached the MEMORY cap instead)
#
# Three different records, no change to the interpreter: the harness was
# deciding the answer. And the first attempt to fix it scaled only the OUTER
# bound, which changed nothing, because the four files were hitting the inner
# one. A harness with two limits for one question will hide one of them.
#
# So the limits live here, there is one owner for each question, and the outer
# one is DERIVED rather than chosen, so it can never be the one that fires
# first.
#
#   SPEC_CPU   how much CPU one side may BURN. This is the "does this finish"
#              bound. A file that spends 25 CPU-seconds spends 25 whether one
#              worker runs or six, so the verdict stops depending on the load.
#   SPEC_WALL  how long one side may EXIST. This is only for a process that is
#              not running at all -- blocked on a read, waiting on a child that
#              never exits. It is far above anything a working spec needs: if
#              THIS is what fires, the finding is about the harness.
#   the outer bound (scoreboard.sh) covers run_spec.sh itself -- two sides plus
#              the driver it writes -- and is computed from SPEC_WALL.
#
# ⚠ RLIMIT_CPU is per PROCESS, not per process tree. A spec that shells out
# (mspec's `ruby_cmd`) gives each child its own fresh budget, so the total a
# file may burn is not bounded by SPEC_CPU alone. SPEC_WALL is what bounds
# that case, which is a second reason it cannot simply be removed.
sb_cpu="${SPEC_CPU:-25}"
case "$sb_cpu" in ''|*[!0-9]*) sb_cpu=25 ;; esac
# ⚠ AND IT HAS TO BE FAR ABOVE THE CPU BOUND, not merely above it. 120s looked
# generous and was not: measured 2026-09-22, `core/dir/glob_spec` is 49% CPU --
# it waits on the filesystem -- so at six workers it passed 120s of WALL while
# still nowhere near 25s of CPU, and the harness called a working file "stuck".
# That is the same load-dependence the CPU bound was introduced to remove,
# sneaking back in through the bound that was supposed to be a backstop.
#
# So it is expressed as a MULTIPLE of the CPU bound, because that states the
# intent: a process that has spent less than 1/24th of its wall time on the CPU
# is not computing, it is waiting. A working spec cannot reach that; a wedged
# one does.
sb_wall="${SPEC_WALL:-$(( sb_cpu * 24 ))}"
case "$sb_wall" in ''|*[!0-9]*) sb_wall=$(( sb_cpu * 24 )) ;; esac
# ⚠ AND THEY MUST NOT OVERLAP. If the wall bound is not comfortably above the
# CPU bound it preempts it, and the harness is back to two limits answering one
# question -- worse than before, because the message would then say "blocked,
# not slow" about a file that was busy the whole time. Clamped rather than
# refused, because a hand-run passing SPEC_WALL wants a bound, not an argument.
if [ "$sb_wall" -le "$sb_cpu" ]; then
  echo "bounds.sh: SPEC_WALL ($sb_wall) must be above SPEC_CPU ($sb_cpu) or it answers first; using $(( sb_cpu * 4 ))" >&2
  sb_wall=$(( sb_cpu * 4 ))
fi
sb_outer=$(( 2 * sb_wall + 60 ))
# ...and the third bound, BYTES, which mspec/rss_guard.sh enforces by polling
# because macOS has no `ulimit -v`. It is here with the other two because it is
# part of the record in exactly the same way: a run with no guard records a
# machine that swapped, and a run with a tighter guard records CRASH rows for
# files that finish. 6 GB is the number the table was measured with.
sb_rss_cap="${SPEC_RSS_KB:-6291456}"
case "$sb_rss_cap" in ''|*[!0-9]*) sb_rss_cap=6291456 ;; esac

# ⚠ ARM THE INSTRUMENT BEFORE THE EVENT, and prove it is armed. `ulimit -S -t`
# is POSIX and works in bash, dash and zsh, but a shell or a container that
# refuses it would leave the sweep with NO bound on "does this finish" and say
# nothing -- the harness would simply wait, and a runaway file would look like
# a hang. So it is measured, once, against a program that is guaranteed to run
# forever: a second of CPU for an answer that the rest of the run depends on.
#
# Exit status 152 is 128 + SIGXCPU(24), which is what the kernel sends when the
# soft limit is passed; with `ulimit -c 0` there is no core file. Some shells
# report the signal number itself.
#
# ⚠ ...and the DIAGNOSTIC is printed by the shell that reaps the process, not
# by the process, so redirecting the subject's own stderr does not silence it.
# The braces are what catches "Cputime limit exceeded" here, and the same shape
# is what keeps it out of the captured output in run_spec.sh.
sb_cpu_works() {
  sb_probe_rc="$( { ( ulimit -c 0; ulimit -S -t 1
                      exec perl -e 'my $x = 0; $x++ while 1'
                    ) >/dev/null 2>&1; echo "$?"; } 2>/dev/null )"
  [ "$sb_probe_rc" = 152 ] || [ "$sb_probe_rc" = 24 ]
}
