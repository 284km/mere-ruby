# mere-ruby — what one change costs, and what has been done about it

The other documents describe the SUBJECT. This one describes the LOOP: how
long it takes to get from an edit to a landed commit, where that time actually
goes, and what each attempt to shorten it was worth.

It exists because the first honest measurement of this loop was a surprise.
The sweep is 95% of a cycle, and more than half of the sweep was the harness
copying a directory tree that never changes. Nobody would have guessed that;
it took a `time` and a look at the split between user and sys.

Every number here was measured on one machine (Apple silicon, 10 cores: 6
performance + 4 efficiency, APFS) and is dated. Absolute values do not port.
The RATIOS and the SHAPE of the breakdown are the parts worth carrying.

⚠ Two kinds of number appear below and they are not the same evidence:
**timed** means `/usr/bin/time -p` around the thing, **observed** means wall
clock read off a polling loop while other work shared the machine. Observed
numbers are marked as such and are only ever used for "before" figures that
were not timed at the time.

## The cycle, measured 2026-09-22

One change to the interpreter, from edit to pushed commit:

| step | cost | how |
|---|---|---|
| emit — `mere -c main.mere > mr.c` | **41s** | timed. 60.2 MB, 301,933 lines of C |
| compile — `clang -O2 -fbracket-depth=1024` | **112s** | timed |
| `run_corpus.sh` (213 programs, both sides) | **79s** | timed, ×2 because the hash index is swept ON and OFF |
| `clitest/run.sh` | **3s** | timed |
| the nine source gates | **29s** | timed; `dead_defs_check.sh` is 25s of it, the other eight total 4s |
| `record_hygiene.sh` | **2s** | timed |
| **the full sweep** (103 groups, 2498 files) | **30 min** | timed: 1809s. Was ~90 min before the change below, and up to 4 hours with the machine loaded (observed) |
| CI | **8-13 min** | observed across the day's pushes |

So a cycle is about **6 minutes of build and gates** and then **the sweep**.
Six sweeps in a day is normal when several arcs land; that was three hours
before the change below and is thirty minutes after it.

## What was wrong: the sweep was copying 4,333 files per spec file

Measured 2026-09-22, one spec file through `mspec/run_spec.sh`:

```
real 2.71   user 0.15   sys 1.89
```

⚠ **user 0.15s.** Both interpreters together are about 0.1s (ruby 0.05,
mere-ruby 0.06 on a small file). Everything else was the filesystem.

`run_spec.sh` cloned the spec tree — `core`, `language`, `library`, `shared`,
`fixtures` — into a private temporary directory for EVERY spec file, so that
`require_relative '../spec_helper'` and the sibling `shared/` and `fixtures/`
directories resolve. That is:

| | count |
|---|---|
| files cloned per spec file | **4,333** |
| spec files in the record | 2,498 |
| clones per sweep | **~10.8 million** |
| the clone alone, timed | **1.46s** of the 2.71s (sys 1.23s) |

⚠ And the second cost was invisible from inside the sweep: that much
filesystem churn holds macOS's **`fseventsd` at 100%+ CPU with 3-6 GB
resident**, and it stays there for hours after the sweep ends. With it in that
state, everything else on the machine — including the next sweep — ran up to
**8× slower**. An hour was lost on 2026-09-21 reading that slowdown as a hang
in the interpreter: a group that normally takes seconds sat for twelve minutes
with no child process visible, which looks exactly like a deadlock. It was
load. `ps aux | sort -k3 -rn | head` named it in one command, and that command
should be the first one run whenever the harness "hangs".

## The change: one tree per sweep (`1b964bc`)

`scoreboard.sh` builds the tree ONCE and hands it to `run_spec.sh` through
`SPEC_TREE`. The per-file `driver.rb` is the only thing still written per file.
A hand-run of a single spec is unchanged and still gets its own tree, because
isolation is what a hand-run wants.

| | before | after | ratio |
|---|---|---|---|
| 68 files (five small groups), timed | 189.8s | **41.2s** | 4.6× |
| one file, timed | 2.71s | **0.64s** | 4.2× |
| the full sweep, timed after / observed before | ~90 min | **30 min** | ~3× |

The full sweep is a smaller ratio than the single file because the groups that
dominate it are the slow ones — files that run to the 60s alarm, and the
`core/argf` specs that wait on stdin — and those were never paying the clone
in proportion.

⚠ **The check is the ANSWERS, not the clock.** A shared tree is only sound if
no spec leaves anything behind in it. After the change, all 103 rows of the
record came back byte-identical and so did every tag file except the two that
carry a clock reading and a random seed. That comparison is the test, it is
cheap (the sweep has to run anyway), and it is where a dirtying spec would
show up.

## What is left, and what each is worth

### 1. Parallelise the sweep — built, 3x, and behind a flag until the bound is CPU time

The sweep is sequential and the machine is not: 1809s of wall clock for 1051s
of CPU (585 user + 467 sys) is **0.58 cores of ten**. Groups are independent
and each writes its own tag file, so the work partitions without contention;
`SPEC_STATUS.md` is merged at the end as it already is.

⚠ The shared tree is what makes this need care. Workers must not share ONE
tree, because a spec that writes into it would then race with another worker
rather than merely follow it. The shape is **one tree per worker** — six
clones, not 2,498 — which keeps today's win and adds the parallelism on top.

Built on 2026-09-22 and it works: `SPEC_JOBS=6` gives one tree per worker,
groups dealt round-robin by position, rows written to one file each and
concatenated in the original order so the table comes out identical.

| | timed |
|---|---|
| eight groups, `SPEC_JOBS=1` | 135.4s |
| eight groups, `SPEC_JOBS=6` | **67.2s** (rows and tags byte-identical) |
| the full sweep, `SPEC_JOBS=6` | **547s — 9 minutes**, from 30 |

⚠ **And then the record moved, twice, without the interpreter changing.**
This is the part worth carrying:

| bounds | what the record said |
|---|---|
| sequential, 25s per side / 60s per file | core/dir 18 DIFF, 1 SLOW — 0 CRASH overall |
| six workers, same bounds | core/dir **14 DIFF, 5 SLOW** — four files crossed a wall-clock bound because five other workers were on the machine |
| six workers, both bounds ×6 | SLOW 13 → 4 and **CRASH 0 → 4** — with more time, the same files reached the MEMORY cap instead |

MATCH was 1764 in all three. The gap moved between DIFF, SLOW and CRASH
according to **which bound fired first**, and both of them are wall clock.
⚠ There are TWO bounds and the first attempt scaled only the outer one
(`scoreboard.sh`'s 60s), which changed nothing, because the four files were
hitting `run_spec.sh`'s own 25s per side. A harness with two limits for one
question will hide one of them from you.

So `SPEC_JOBS` defaults to **1**. The parallel path is committed and is a
genuine 3×, but a record has to be reproducible before it is fast, and this
one is not yet: the same build gives three different tables.

**What would make it sound**: bound CPU TIME, not wall clock. A file that
spends 25 CPU-seconds spends 25 whether one worker runs or six, so the verdict
stops depending on the load. ⚠ It cannot be the only bound: a spec blocked on
stdin (several of `core/argf`) uses no CPU at all and would never be killed.
The shape is a CPU bound at today's numbers for "this does not finish", plus a
generous wall bound purely to catch a blocked process. That is the next piece
of work here, and when it lands the default can flip to 6.

> **SUPERSEDED the same day — see "the bound is CPU time" below.** The CPU
> bound landed and the table is now identical at one worker and at six. Two
> things in the paragraph above turned out to be wrong and are kept here
> because being wrong in writing is the point of this file:
>
> - ⚠ **The `core/argf` premise was false.** Measured: all nine SLOW files are
>   compute-bound (84–99% CPU, except `core/dir/glob` at 49%), and `core/argf`'s
>   stdin specs redirect a fixture into a CHILD — they never read the harness's
>   stdin. The sentence was written from memory of what those specs are about.
> - ⚠ **The default did NOT flip to 6.** The obstacle moved rather than
>   vanishing: it is the MEMORY bound now, and it is a poller.

### 2. `-O0` for the probe loop — 82s off every build — DONE, `tools/build.sh`

| | timed |
|---|---|
| `clang -O2` | 112s |
| `clang -O0` | **30s** |
| running a corpus program, -O2 | 0.04s |
| running a corpus program, -O0 | 0.07s |

The build is 3.7× faster and the result is about 1.7× slower to run. For the
edit → run one witness → edit again cycle that is a clear win; for the build
that sweeps and the build that ships it is not, because the sweep runs the
interpreter 5,000 times. The rule would be: `-O0` while a change is being
shaped, `-O2` for the build that produces the record.

Fifteen build cycles in a day is normal, so this is about twenty minutes.

Landed as `tools/build.sh` (`--fast` for -O0) and re-measured on the day:
**30.6s** for the -O0 link against 112s for -O2, so the 3.7× holds. ⚠ **The
rule is enforced rather than remembered**: which `-O` level made a binary is not visible in the
binary, so build.sh records it in `.build_mode` and `scoreboard.sh` REFUSES to
sweep an -O0 one. Every verdict in the table is bounded in CPU seconds now, so
a 1.7× slower binary would push files across a budget and the record would
report a regression that is a compiler flag. See the dated section below.

### 3. The emit step — 41s

That time is inside the Mere compiler (another repository), turning 30k lines
of Mere into 302k lines of C. It is the largest fixed cost of a build that
cannot be reduced from here.

### Measured and NOT worth doing: caching the reference side

The reference ruby's output for a given spec file is deterministic and could
be cached between sweeps. Before the tree change that would have been worth
minutes; now that one file costs 0.64s of which ruby is 0.05s, the whole cache
would save about **2 minutes of the 30**. ⚠ The order mattered: the same idea
was worth ten times more an hour earlier. Measure the loop again after every
change to it, or you will optimise what the last change already made cheap.

## Process costs, which were larger than they look

Three things cost more time on 2026-09-21/22 than any interpreter bug, and all
three were the instruments rather than the subject.

**The two verdicts.** `run_spec.sh <one file>` prints its own verdict on the
last line, and `scoreboard.sh` computes a different one. The first answers
"do the two outputs differ", the second answers "did it run at all" — a file
where mere-ruby printed no tally is CRASH to the scoreboard and DIFF to
run_spec.sh. Four recorded CRASH rows were read as "does not reproduce
standalone" before the difference was noticed. **When two instruments
disagree, find out what each is measuring before believing the friendlier
one.**

**A harness that changed the subject's fate.** `diff <(ruby prog) <(mere-ruby
prog)` runs both sides CONCURRENTLY. A witness that writes a fixed temporary
file and deletes it at the end therefore has each side deleting the other's
input, and the failure looks exactly like an interpreter bug. Compare
sequentially through files.

**A timing script that was itself broken.** A loop written to time each spec
file reported "HUNG" for a file that finishes in 2.4 seconds. Before believing
a measurement that indicts the subject, run the subject the plain way once.

## How to add to this file

Append a dated section for the change: the number BEFORE, the number AFTER,
how each was obtained (timed or observed), and what was checked to show the
answers did not move. A speedup whose correctness check is not written down is
not a speedup anyone can build on.


## 2026-09-22: the sweep leaves its own litter

`mspec/spec_helper.rb` removes `SPEC_TEMP_DIR` (which is
`rubyspec_temp/<pid>`, per process) when a run finishes normally. A run killed
by either bound does not reach that line, so a sweep with a dozen SLOW files
leaves a dozen directories behind — and there were **1,337** of them after a
day of sweeps. They are what the next day's `fseventsd` is indexing.

Not yet fixed; the one-line version is for the sweep to remove `rubyspec_temp/`
when it finishes, since it is the sweep's own litter. Noted here so the number
is on record: it is small per run and it accumulates.

## 2026-09-22: the bound is CPU time, and the sweep owns all three of its limits

The section above ends "that is the next piece of work here, and when it lands
the default can flip to 6." This is that work.

### First: was the premise true?

The claim was that a CPU bound cannot be the only bound because "a spec blocked
on stdin (several of `core/argf`) uses no CPU at all". ⚠ **That was wrong, and
it was wrong in the direction that makes the work look harder than it is.**
Measured, with the real harness and the alarm raised to 60s per side:

| the nine SLOW files | wall | CPU | CPU/wall |
|---|---|---|---|
| core/array/equal_value | 57.2 | 54.5 | 95% |
| core/dir/glob | 61.1 | **29.8** | 49% |
| core/conditionvariable/signal | 60.6 | 57.3 | 95% |
| core/enumerator/lazy/to_enum | 61.7 | 52.0 | 84% |
| core/enumerator/produce | 60.7 | 59.5 | 98% |
| core/module/define_method | 61.5 | 57.7 | 94% |
| core/thread/report_on_exception | 60.5 | 59.6 | 99% |
| library/stringio/each_line | 60.6 | 59.5 | 98% |
| library/stringio/readlines | 60.6 | 59.4 | 98% |

Every one is compute-bound and every one burns far more than 25 CPU-seconds, so
a 25s CPU bound keeps all nine verdicts. Not one of them is blocked. And
`core/argf`'s stdin specs do not read the harness's stdin at all -- they
redirect a fixture into a CHILD (`ruby_exe(..., args: "< #{@stdin_name}")`).
The sentence had been written from memory of what those specs are about.

### The shape that landed

`mspec/bounds.sh` is new and it owns every limit a spec run has, because there
is more than one and they have to agree:

| | what it answers | default |
|---|---|---|
| `SPEC_CPU` (`ulimit -S -t`, SIGXCPU) | does this FINISH | 25s of CPU per side |
| `SPEC_WALL` (SIGALRM) | is this process RUNNING at all | 120s per side |
| the outer bound in `scoreboard.sh` | did `run_spec.sh` itself return | **derived**: `2*SPEC_WALL + 60` |
| `SPEC_RSS_KB` (`rss_guard.sh`) | did it eat the machine | 6 GB |

Four things about that table are the actual content:

**The outer bound is derived, not chosen.** It was 60 while the inner one was
25, both wall clock, both answering "does this finish" -- and the first attempt
to fix the parallel record scaled the outer one and changed nothing. A number
that is computed cannot drift out of agreement with the number it depends on.

**`SPEC_WALL` must stay above `SPEC_CPU` or it answers first**, and then the
message would say "blocked, not slow" about a file that was busy the whole
time. `bounds.sh` clamps it and says so.

**The two kills are two findings and the record names which.** `SLOW` used to
be one bucket with one message. It is now `OVER CPU BUDGET` (a fact about the
file, and the same fact at one worker or six) or `STUCK ... without burning the
CPU budget` (a fact about the harness or the environment), and the cause
travels into `mspec/tags/` beside the filename.

**The reference side runs under the same bounds and nothing read its status.**
`$tmp/rc_r` was written and never looked at, so a killed ruby left a truncated
tally and the row read DIFF or SKIP -- a claim about ruby, made by the harness,
with nothing saying so. It is rare because ruby is the fast side here, and that
is exactly why it would have been believed.

### Poisoning it

A bound that does not fire is indistinguishable from a subject that finishes,
so each branch was made to fire on purpose before it was trusted:

| poison | what it proved |
|---|---|
| `SPEC_CPU=3` on `core/enumerator/produce` | SIGXCPU is caught, verdict `SLOW`, cause names the CPU budget |
| `MR_BIN=<a script that sleeps>`, `SPEC_CPU=2 SPEC_WALL=8` | SIGALRM is caught and reported as STUCK, not as slow |
| `SPEC_CPU=0` | the REFERENCE-side branch fires and says the file is unmeasured |
| `SPEC_WALL=6 SPEC_CPU=30` | the clamp refuses the overlap and says what it used instead |
| `sb_cpu_works` against `perl -e '1 while 1'` | the limit is actually settable in this shell -- armed before the sweep, once, not once per file |

⚠ The last one matters more than it looks. `ulimit -S -t` failing is silent: the
sweep would simply have no answer to "does this finish" and a runaway file
would look like a hang. The probe costs one CPU-second per sweep and the
fallback (a wall bound at the CPU number -- today's behaviour) prints why.

⚠ And one thing the poison found in the harness rather than the subject: the
"Cputime limit exceeded: 24" line is printed by the shell that REAPS the
process, not by the process, so redirecting the subject's stderr does not
silence it. It would have landed in the recorded output as if the spec had said
it. The braces around the capture are what catches it.

### Two more limits that were not the harness's

**The memory bound was a step in the README, which is not a bound.**
`mspec/rss_guard.sh` is the only thing standing between a runaway spec and a
machine that stops responding, and it was started by hand and died with the
shell that started it. On 2026-09-22 it was down for half a day with nothing
saying so -- and the four CRASH rows the parallel experiment produced that same
morning came from a run where it was UP. The same sweep, two answers, decided
by a process nobody could see. The sweep starts its own now and takes it down
on the way out; an operator's guard is left alone if one is already running.

**The sweep's stdin was the sweep's own work list.** `run_one` did not redirect
it, and the loops that deal groups to workers read that list on stdin, so the
child inherited it. A spec that read `$stdin` would have read the harness's
group list -- making the record depend on WHICH groups were asked for -- and
whatever it consumed would be a line the `while read` loop never sees, losing
groups in silence. Neither had bitten. Both were one `</dev/null` away.

### The litter

`rubyspec_temp/<pid>` is removed on the last line of a normal exit, so every
run killed by a bound leaves one. **1,605 of them** had accumulated by this
morning, and they are what the next day's `fseventsd` is indexing. The sweep
now removes them at both ends of its own run -- and only the ones whose pid no
longer belongs to a live process, so a concurrent run's scratch survives.

Measured: **1,605 directories before the first sweep of the day, 21 after it,
10 after the next pair.** ⚠ Not zero, and the number is not expected to be
zero: a sweep spawns thousands of processes, pids get reused, and a directory
whose pid number now belongs to something else living is skipped by design --
that is the safe direction of the `kill -0` test. The defect was UNBOUNDED
GROWTH, and what the fix buys is a bound, not a clean floor. ⚠ The pid-reuse
explanation is inference from the check's logic and has not itself been
measured; if the count ever climbs again, that inference is the thing to test
first.

### `-O0` for the probe loop, and the refusal that has to come with it

Item 2 of the list above is now `tools/build.sh`:

```sh
./tools/build.sh            # -O2, the build that sweeps and the build that ships
./tools/build.sh --fast     # -O0, the build for edit -> run one witness -> edit
./tools/build.sh --cc-only  # skip the emit, compile the mr.c that is there
```

⚠ **The fast build must never produce the record**, and that is not a matter of
remembering. Every verdict in the table is now bounded in CPU SECONDS, so a
binary that runs 1.7x slower pushes files across a budget they have never
crossed -- the record would report a regression that is a compiler flag. Which
`-O` level made a binary is not visible in the binary, so `build.sh` writes it
to `.build_mode` and `scoreboard.sh` refuses to sweep an `-O0` one
(`SPEC_BUILD_OK=1` overrides). A sentence in a README cannot refuse anything.

The build line also existed only in prose, in two dialects (macOS's and
Linux's, in README.md), which is the same rule written twice; `build.sh` is
where it lives now, and it REFUSES rather than half-building when the Mere
compiler is not on the machine -- the alternative is compiling whatever `mr.c`
happens to be lying there, which is the most confusing failure available.

### Process cost: two harness bugs of my own, both found by running it

Neither was in the interpreter and neither was visible by reading.

**A bare `wait` waits for the memory guard too.** Making the sweep start its own
`rss_guard.sh` made that poller a background child of the same shell, and the
parallel path ends in `wait`. So the sweep measured all eight groups, wrote
every tag file, and then sat there forever with no child process running -- a
FINISHED sweep that is indistinguishable from a hung one. ⚠ The bug existed
only on the path being added (the sequential path has no `wait`) and only
because of a change that had nothing to do with parallelism. `wait "$pid"` per
worker.

**Editing a shell script while it is running.** The first sequential A/B run is
not in the numbers below, because it is void: fifteen lines were inserted near
the top of `scoreboard.sh` while a sweep was ten minutes into it, and **a shell
reads a script incrementally, from a byte offset**. All eight groups had
printed when the offset landed mid-token and the run died with `syntax error
near unexpected token ')'` at the merge step -- so the per-group tag files were
written and `SPEC_STATUS.md` was not. ⚠ The dangerous shape: the expensive work
completed and the record did not, so the output looks like a finished sweep
until its last three lines. The rule was already in this file for the script
being MEASURED; it had not been applied to the script doing the measuring.

### Three bounds, one verdict: a SIGKILL is not the interpreter aborting

Chasing the A/B turned up two rows filed in the wrong column, and the fix is
the same shape as everything else here.

`CRASH` is defined in the table as "mere-ruby aborts where ruby does not" -- a
claim about the INTERPRETER. `SLOW` is "stopped by this harness, working, not
aborting". A run the memory guard SIGKILLs is plainly the second, and it was
recorded as the first, because the scoreboard classifies on "no `pass=` line"
and a killed process prints no tally. So the record said the interpreter
aborted about a file that works and wants 7 GB.

⚠ That is the identical misattribution the SIGALRM case had already been given
its own word for -- the byte bound had simply never been revisited. All three
bounds now produce one verdict, `SLOW`, with the cause naming WHICH:

| the kill | the cause recorded |
|---|---|
| SIGXCPU | `OVER CPU BUDGET: burned this harness's 25s of CPU per side` |
| SIGALRM | `STUCK: 120s of wall clock without burning the CPU budget` |
| SIGKILL | `OVER THE MEMORY CAP: ... see mspec/rss_kills.log` |

and `CRASH` is left meaning exactly one thing.

⚠ **This is a reclassification, not an improvement.** It restores `CRASH 0`,
and nothing about the interpreter changed to earn that. No row in the record
had ever been a memory kill before today, so it rewrites no history -- it
decides where two NEW rows go. The underlying fact (two spec files drive this
interpreter past 6 GB where ruby needs megabytes) is a real gap: it is in the
cause text, and it is named in KNOWN_GAPS.md, which is where a gap belongs.

Poisoned both ways before being believed, through the real scoreboard: a
subject that SIGKILLs itself records `SLOW` naming the memory cap, and a
subject that aborts with a NameError still records `CRASH` with its own
message.

### The A/B, after the reclassification

Eight groups (the ones holding every SLOW file, plus `core/dir`, which is the
group that moved last time), same binary, same spec revision:

| | timed | table | tag rows |
|---|---|---|---|
| `SPEC_JOBS=1` | 645.4s | — | — |
| `SPEC_JOBS=6` | **300.0s (2.15x)** | **IDENTICAL** | 2 lines of 103 files differ |

CPU was the same on both sides (303+230 vs 287+231), which is the check that
the parallel run did the same work rather than less of it.

⚠ **The two lines that differ are the interesting part.** Both are files that
are over the CPU budget AND over the memory cap, so the two bounds race, and
the winner swapped between the runs:

| file | sequential | six workers |
|---|---|---|
| `core/module/define_method_spec` | OVER THE MEMORY CAP | OVER CPU BUDGET |
| `core/enumerator/lazy/to_enum_spec` | OVER CPU BUDGET | OVER THE MEMORY CAP |

The VERDICT is `SLOW` in all four cells -- that is stable, and it is what the
table counts. What varies is which bound got there first, which is a real fact
about a file sitting on two thresholds at once.

⚠ **It CAN swap, not it DOES swap.** In the full sweep an hour later, both
files reported the same bound sequentially and in parallel, and the pair above
did not reproduce. That is what a race looks like, and it is the reason the
claim here is the weaker one.

### ⚠ A polling bound is a wall-clock bound wearing a different hat

Those two lines are the finding, and it was not the one being looked for.

`rss_guard.sh` samples every process's RSS once a second. Whether a file whose
peak straddles the cap gets caught therefore depends on how many samples land
while it is up there -- and that is WALL CLOCK, the exact property the CPU
bound was introduced to remove. ⚠ Note what the data does NOT say: it is not
that six workers cause more memory kills. Each run had one of each, and which
file got which swapped. It is a race between two thresholds a file sits on
simultaneously.

**What would make it sound**: split PROTECTION from JUDGMENT. Keep the poller,
because something has to stop a 15 GB process before the machine does. But take
the VERDICT from the child's own `rusage` peak RSS, which `/usr/bin/time -l`
reports -- peak RSS is a function of how far the file got, and with the CPU
bound fixed, how far it got no longer depends on the load. The poller could
then miss a peak without changing the answer. ⚠ Peak RSS quantises to powers of
two and stops being reproducible above a few GB, both already written down in
this project, so the threshold behaviour has to be measured before this is
believed. That is the next piece of work here, and the claim to check is
narrow and stated: **the two cause lines stop swapping.**

### The full record, and the bound that was still too tight

| | timed |
|---|---|
| full sweep, `SPEC_JOBS=1` (this is the record) | **1829.7s** |
| full sweep, `SPEC_JOBS=6` | **657.0s — 2.8x** |

The record: **103 groups, 2498 files, MATCH 1764, DIFF 694, CRASH 0, SKIP 32,
SLOW 8**, against a baseline of 1764 / 693 / 0 / 32 / 9. ⚠ MATCH did not move,
which is the check that a harness change measured the same interpreter. One
cell did: `core/dir`, where `glob_spec` went SLOW to DIFF because it had been
cut off by a clock while never approaching its CPU budget.

And the first full parallel run found what eight groups could not:

```
core/dir/glob_spec.rb
  seq: DIFF  FAILED: calls #to_path to convert multiple patterns: ...
  par: SLOW  STUCK: 120s of wall clock without burning the CPU budget
```

⚠ **The WALL bound fired, and its message was wrong.** `glob_spec` is 49% CPU
-- it waits on the filesystem -- so at six workers it passed 120s of wall while
nowhere near 25s of CPU, and the harness called a working file "blocked". 120
looked generous and was not: **the same load-dependence the CPU bound was
introduced to remove, sneaking back through the backstop.**

The fix is to stop choosing that number too. It is a MULTIPLE of the CPU bound
now (`sb_cpu * 24`, so 600s), which states the intent instead of a magnitude: a
process that has spent under 1/24th of its wall time on the CPU is waiting, not
computing. ⚠ And the sequential record contains no wall-bound row at all, so
widening it cannot move the record -- which is why this could be fixed after
the record was measured rather than before.

Two other rows differ between the runs and always will: `core/process/
clock_gettime` embeds a clock reading and `core/random/new` embeds a seed.

### So: does the default flip to 6?

The evidence, all of it, with the final bounds:

| comparison | table | tag rows |
|---|---|---|
| 8 groups, seq 645.4s vs par 300.0s | identical | 2 cause lines swapped (CPU vs memory) |
| full, seq 1829.7s vs par 657.0s (wall 120) | `core/dir` moved | + clock, seed |
| full, seq 1829.7s vs par **879.2s** (wall 600) | **identical** | **clock and seed only** |

The last row is the one that counts, and the two lines that differ in it are
the two that differ between ANY two runs: `core/process/clock_gettime` embeds a
clock reading and `core/random/new` embeds a seed. By that measure the parallel
sweep is as reproducible as the sequential one.

**The default stays 1 anyway**, and this is a judgement rather than a forced
conclusion. The reason is the row above it: the two files sitting on both the
CPU and the memory threshold DID swap once in three comparisons, and the record
is the product here. Thirty minutes once a day is cheaper than one unexplained
diff in a checked-in file. `SPEC_JOBS=6` is documented, measured and safe for a
working session, which is where the 2× actually matters.

⚠ Note what the third row cost: 879s, not the 657s of the run before it, and
the difference is almost entirely one file that stalled for ten minutes. The
parallel sweep's wall time now has a long tail that the sequential one does
not.

The section above said "when it lands the default can flip to 6". It landed and
the default did not flip. ⚠ **The obstacle moved rather than vanishing**, and
naming where it moved to is the whole value of having promised the flip: the
time bounds are load-independent now, and the byte bound is not.

### ⚠ A stuck reference — three wrong explanations, then the measurement

`core/exception/interrupt_spec.rb` left the REFERENCE ruby sitting at ten
minutes of wall clock and 0.07 seconds of CPU, but only under six workers. The
spec runs `IO.popen([*ruby_exe, '-e', 'Process.kill :INT, Process.pid; sleep'],
&:read)` — it waits for a child that is supposed to die of its own SIGINT.

Three explanations were written into this file before any was checked. All
three were wrong, and they are kept because the checking is the content:

1. *"It lands in SKIP."* It did not, that time — the row was unchanged.
2. *"`alarm` survives `exec` and ruby HANDLES SIGALRM, so the bound is a nudge."*
   Measured: `mere-ruby` spinning, `ruby` spinning and `ruby` blocked in `sleep`
   all come back **142**. SIGALRM kills. The story was invented to fit.
3. *"Two facts that have not been connected."* Honest at the time, and still an
   unexplained observation rather than a finding.

**The measurement, finally.** A shell sets SIGINT and SIGQUIT to `SIG_IGN` for a
job it starts in the BACKGROUND — and `SIG_IGN` is inherited across `fork` AND
`exec`. The parallel path runs each worker as `( … ) &`, so every spec process
beneath it ignored SIGINT, while at `SPEC_JOBS=1` (foreground) none of them did.
The self-killing child therefore never died, and its parent blocked on `read`
until the wall bound. Shown directly:

| the same popen, run from | result |
|---|---|
| the foreground | child dies, `SIGINT (signal 2)` |
| a background subshell | child never dies |

⚠ **This is the harness changing the SUBJECT**, which is the one thing the
parallel path must never do, and it moved a real row between DIFF and SKIP on
worker count alone. The fix is two lines in the child before `exec`:
`$SIG{INT} = "DEFAULT"; $SIG{QUIT} = "DEFAULT"`. After it, the file completes in
seconds from a background subshell and reports DIFF, exactly as in the
foreground.

It also removed a ten-minute tail from every parallel sweep, which is why the
run that found it took 886s rather than the 657s of the run before.

### So: does the default flip to 6?

The evidence, all of it, with the final bounds:

| comparison | table | tag rows |
|---|---|---|
| 8 groups, seq 645.4s vs par 300.0s | identical | 2 cause lines swapped (CPU vs memory) |
| full, seq 1829.7s vs par 657.0s (wall 120) | `core/dir` moved | + clock, seed |
| full, seq 1829.7s vs par **879.2s** (wall 600) | **identical** | **clock and seed only** |

The last row is the one that counts, and the two lines that differ in it are
the two that differ between ANY two runs: `core/process/clock_gettime` embeds a
clock reading and `core/random/new` embeds a seed. By that measure the parallel
sweep is as reproducible as the sequential one.

**The default stays 1 anyway**, and this is a judgement rather than a forced
conclusion. The reason is the row above it: the two files sitting on both the
CPU and the memory threshold DID swap once in three comparisons, and the record
is the product here. Thirty minutes once a day is cheaper than one unexplained
diff in a checked-in file. `SPEC_JOBS=6` is documented, measured and safe for a
working session, which is where the 2× actually matters.

⚠ Note what the third row cost: 879s, not the 657s of the run before it, and
the difference is almost entirely one file that stalled for ten minutes. The
parallel sweep's wall time now has a long tail that the sequential one does
not.

The section above said "when it lands the default can flip to 6". It landed and
the default did not flip. ⚠ **The obstacle moved rather than vanishing**, and
naming where it moved to is the whole value of having promised the flip: the
time bounds are load-independent now, and the byte bound is not.

### ⚠ A stuck reference, and a causal story that did not survive being measured

In the six-worker re-check, `core/exception/interrupt_spec.rb` left the
REFERENCE ruby sitting at **9 minutes 56 seconds of wall clock and 0.07 seconds
of CPU**. Blocked, not slow, and on the side nobody watches. The spec runs
`IO.popen([*ruby_exe, '-e', 'Process.kill :INT, Process.pid; sleep'], &:read)`
-- it waits for a child that is supposed to die of its own SIGINT.

**Two explanations were written here before either was checked, and both were
wrong.** They are kept because the checking is the content.

1. *"It will land in SKIP: the wall bound kills the reference, no `pass=` line,
   ruby did not run it here."* It did not. The row is byte-identical to the
   sequential one.
2. *"`alarm` survives `exec` and ruby HANDLES SIGALRM, so the bound is a nudge
   rather than a kill."* Measured afterwards, three ways:

   | subject | rc |
   |---|---|
   | `mere-ruby` spinning, `alarm 2` | **142** (killed) |
   | `ruby` spinning, `alarm 2` | **142** (killed) |
   | `ruby` blocked in `sleep 60`, `alarm 2` | **142** (killed) |

   SIGALRM kills ruby. The "it is only a nudge" story was invented to explain
   an observation and would have gone into a document as fact.

⚠ **What is actually known**: a reference process sat for ten minutes using no
CPU, and the recorded row for that file shows no sign of it. Those two facts
have NOT been connected, and the honest state of this is an open question, not
a finding. The candidates worth testing are that the process belonged to a run
whose row was already written, and that the group had been measured before the
stall began -- both checkable by timestamping group completion, which the sweep
does not currently do.

What the episode DOES establish, and this part is measured:

- A spec can leave the reference blocked for as long as the wall bound allows,
  and at six workers this one did. The wall bound is what ends it.
- ⚠ **Nothing in the record says a bound had to fire.** Whatever the row ended
  up being, no artifact anywhere notes that a file took ten minutes longer than
  it should have. A bound that fires should be recorded even when the run then
  completes, and that is the smallest useful next change here.
- The reference-side classification added this morning has still only ever been
  exercised by poison (`SPEC_CPU=0`), not in the wild. ⚠ The poison used a
  subject with no SIGALRM handler, which is the easy case.

### So: does the default flip to 6?

The evidence, all of it, with the final bounds:

| comparison | table | tag rows |
|---|---|---|
| 8 groups, seq 645.4s vs par 300.0s | identical | 2 cause lines swapped (CPU vs memory) |
| full, seq 1829.7s vs par 657.0s (wall 120) | `core/dir` moved | + clock, seed |
| full, seq 1829.7s vs par **879.2s** (wall 600) | **identical** | **clock and seed only** |

The last row is the one that counts, and the two lines that differ in it are
the two that differ between ANY two runs: `core/process/clock_gettime` embeds a
clock reading and `core/random/new` embeds a seed. By that measure the parallel
sweep is as reproducible as the sequential one.

**The default stays 1 anyway**, and this is a judgement rather than a forced
conclusion. The reason is the row above it: the two files sitting on both the
CPU and the memory threshold DID swap once in three comparisons, and the record
is the product here. Thirty minutes once a day is cheaper than one unexplained
diff in a checked-in file. `SPEC_JOBS=6` is documented, measured and safe for a
working session, which is where the 2× actually matters.

⚠ Note what the third row cost: 879s, not the 657s of the run before it, and
the difference is almost entirely one file that stalled for ten minutes. The
parallel sweep's wall time now has a long tail that the sequential one does
not.

The section above said "when it lands the default can flip to 6". It landed and
the default did not flip. ⚠ **The obstacle moved rather than vanishing**, and
naming where it moved to is the whole value of having promised the flip: the
time bounds are load-independent now, and the byte bound is not.

### ⚠ The wall bound is a NUDGE, not a kill — found by predicting wrong

In the six-worker re-check, `core/exception/interrupt_spec.rb` -- which sends
itself SIGINT -- left the REFERENCE ruby sitting at **9 minutes 56 seconds of
wall clock and 0.07 seconds of CPU**. Blocked, not slow, and on the side nobody
watches. It is intermittent: the same file completes every time sequentially
and completed in an earlier parallel run, so it is a signal-handling spec
racing with other processes.

**The prediction written here at the time was that it would land in SKIP** --
the wall bound kills the reference, no `pass=` line, "ruby itself does not run
it here". That was wrong, and the record is kept wrong-then-corrected because
the correction is the finding:

⚠ `perl -e "alarm N; exec @ARGV"` leaves the timer armed across the exec, so
the SUBJECT gets SIGALRM -- and **ruby handles it**. It raised SignalException
inside the spec, finished normally, and exited 0. `rc_r` was never 142, so the
reference branch never fired at all. The row came out byte-identical to the
sequential one, and only by coincidence: the spec's own SIGINT failure and the
harness's SIGALRM both print `SignalException`.

Three things follow, and none of them was visible from the design:

- **The wall bound does not guarantee termination.** It terminates a process
  with no SIGALRM handler (a sleeping `/bin/sh` does die, which is what the
  poison test used) and merely perturbs one that has a handler. "Bound" is the
  wrong word for it; it is a nudge that usually works.
- **A ten-minute stall left NO TRACE in the record.** The verdict was right and
  the row was identical, so nothing anywhere says that one file took 600
  seconds longer than it should have. A bound that fires should be recorded
  even when the subject recovers.
- **The poison test passed for the wrong reason.** `MR_BIN=<a script that
  sleeps>` has no handler, so it died and the branch fired. A subject that
  handles the signal was never tried, and that is the case that actually
  occurs.

Next piece of work here, and it is small: make the wall bound SIGKILL after the
alarm rather than only raising it, and record "a bound fired" even when the run
then completes. ⚠ It cannot change the committed record -- the sequential run
contains no wall-bound row at all -- which is what makes it safe to do
separately rather than in a hurry.


## 2026-09-22 (later): the next five, each with the measurement that sized it

Investigated before planning, because the previous round's plan was built on a
premise that turned out to be false. Two of the five below changed shape once
they were measured, and one of them was my own proposal being refuted.

### 1. Report what was MEASURED, not which alarm rang — and the peak-RSS idea is dead

The plan recorded above was "take the verdict from the child's `rusage` peak
RSS, so the poller can miss a peak without changing the answer". ⚠ **Measured,
it does not work, for a reason that is more interesting than the proposal.**

Peak RSS of the mere-ruby side under the real CPU bound, twice each, guard off:

| file | run 1 | run 2 | spread |
|---|---|---|---|
| `core/module/define_method_spec` | 8323 MB | 7931 MB | 392 MB (4.7%) |
| `core/enumerator/lazy/to_enum_spec` | 9030 MB | 9027 MB | 3 MB (0.03%) |
| `core/array/equal_value_spec` | 5351 MB | 5336 MB | 15 MB (0.3%) |

(And a control: a ruby allocating 500 MB reports 495 MB twice, identically, and
the number survives being measured through the `perl … exec` chain. ⚠ It is
also NOT quantised to a power of two, which is what this project had written
down about peak RSS and does not hold for `rusage`'s maxrss.)

The measurement is reproducible enough. **The problem is that the two ambiguous
files exceed BOTH bounds, by a wide margin** — 8.3 GB and 9.0 GB against a 6 GB
cap, while also burning past 25 CPU-seconds. There is no single true answer to
"which bound", so a better way of OBSERVING which one fired cannot help: any
rule that picks one is arbitrary.

**So the change is to stop asking.** Read `rusage` after each side (CPU seconds
AND peak RSS) and let the cause line state the facts: `CPU 25.0s, peak 8.3 GB
— over both`. Nothing then depends on which alarm rang first, and the third
file above shows the facts separate cleanly when they should (5.3 GB is under
the cap, so it is CPU-only and says so).

- **Worth**: the last two non-reproducible lines go away, so the full record
  becomes byte-identical at six workers and `SPEC_JOBS` can default to 6 —
  the sweep goes 30 minutes to 15.
- ⚠ **Risk**: `/usr/bin/time -l` is BSD and reports bytes; GNU time is `-v` and
  reports kbytes. The sweep is macOS-only today, but `bounds.sh` must degrade
  to current behaviour rather than mis-parse.
- **Check**: the eight-group A/B at 1 and 6 with byte-identical tags, plus a
  poison per quadrant — over CPU only, over memory only, over both, over
  neither.

### 2. Record that a bound fired, even when the run completes

⚠ **The motivation changed when it was measured.** This was going to be "make
the wall bound SIGKILL, because `alarm` only perturbs a process that handles
the signal". Measured three ways, that is false:

| subject | rc |
|---|---|
| `mere-ruby` spinning, `alarm 2` | 142 (killed) |
| `ruby` spinning, `alarm 2` | 142 (killed) |
| `ruby` blocked in `sleep 60`, `alarm 2` | 142 (killed) |

SIGALRM kills. What remains true is the part that has nothing to do with
killing: **a reference process sat for ten minutes at 0.07 seconds of CPU and
no artifact anywhere says so.** The work is a per-sweep log of bound events
(file, side, which bound, the measured numbers), and group-completion
timestamps so a stuck process can be attributed to the run it belongs to —
which is also what would settle the open question recorded above.

### 3. `dead_defs_check.sh`: 22.04s → 0.67s

It is 25 of the 29 seconds the nine source gates take, and the reason is one
line: the loop runs **one `awk` per definition**, each scanning the whole uses
table.

| | |
|---|---|
| top-level definitions (= `awk` forks) | **2,575** |
| distinct identifiers (= lines each scans) | 7,577 |
| line-scans | **19.5 million** |
| current, timed | **22.04s** (user 9.96 + sys 5.75 — the sys is the forks) |
| one-pass join, prototyped and timed | **0.67s** |

⚠ **Not a pure speedup, because the allowlist has ZERO entries**, so
`grep -qx "$name" allow` is a branch that has never fired. Rewriting around a
guard nobody has exercised is how a guard quietly stops working. The check is
an A/B of the output on the current tree PLUS a poison: add a function nobody
calls (both versions must flag it), then allowlist it (both must pass).

**Worth**: ~21 seconds off every cycle, and it is the most self-contained item
here.

### 4. The two corpus passes cannot simply overlap — and now the reason is known

The idea is to run the hash-index-ON and hash-index-OFF passes concurrently,
for ~79s a cycle. ⚠ **Blocked**: `grep` finds **13 corpus programs that write
FIXED `/tmp` paths** (`/tmp/mere_ruby_corpus_105.bin`, `/tmp/mrb_al_source.rb`,
…). Two passes at once would have them delete each other's files, and the
failure would look exactly like an interpreter bug — which is a trap this
project has already fallen into once with `diff <(a) <(b)`.

The runner's OWN temporaries were fixed names and were moved to `mktemp -d`
after two concurrent runs made the gate lie. The programs' were not. So the
prerequisite is to give those 13 unique paths, without changing what they test.

### 5. CI: the C compile is the critical path, and `bracket_depth` is the cheap part

| job | step | timed |
|---|---|---|
| build-linux | Build mere-ruby on Linux | **378s** |
| corpus | Build mere-ruby | **310s** |
| build-linux | bracket_depth | 119s |
| build-linux | setup-ocaml | 105s |
| corpus | Build mere | 98s |
| corpus | run_corpus.sh | 59s |

The two jobs run in parallel, so the 11 minutes is build-linux, and 378s of it
is one `clang` invocation on 302k lines. Cutting that needs the emit split into
several translation units, which is a change in the Mere compiler's repository,
not this one.

The affordable piece is `bracket_depth`, at 119s: it bisects clang's own limit
from scratch on every run. Seeding the range from the recorded value would keep
the answer and skip most of the `-fsyntax-only` passes. ⚠ It must still be able
to report a value ABOVE the seed, or it becomes a check that can only confirm
what it was told.

### Order, and why

**3 first** — biggest ratio, smallest blast radius, and it needs no decision.
**Then 1**, which is the only one that changes what the record says and the
only one that halves the sweep. **Then 2**, which is visibility and also the
tool for the open question above. **4** needs 13 corpus files touched carefully;
**5** is mostly somebody else's repository.

⚠ Not on this list: the emit step's 41 seconds, and `tools/build.sh`'s emit
path, which is still the one thing shipped without being run — the Mere
compiler is not on this machine.

## 2026-09-22 (evening): the five, done — and the first attempt at #1 made it worse

### 3. `dead_defs_check.sh`, landed (`7767794`)

| | timed |
|---|---|
| before | **22.99s** |
| after | **0.64s** |
| the eight source gates together | ~29s → **4.95s** |

One `awk` per definition became one `awk` over both tables. Checked by an
output A/B on the current tree plus two poisons — an uncalled function (both
versions flag it, same text, rc 1) and that function allowlisted (both pass).
⚠ The second poison is the one that mattered: `dead_defs_allow.txt` has ZERO
entries, so the allowlist branch had never once executed.

### 1. Report the classification, and log the numbers — the second design

The plan was "put the measured facts in the cause, so nothing depends on which
alarm rang". Implemented, and the A/B says it **made the record worse**:

| | before the change | after it |
|---|---|---|
| table, 1 vs 6 workers | identical | identical |
| tag rows that differ | **2** (which bound was named) | **7** (every SLOW row) |

The classification did become stable — the two rows that used to swap both read
`over the memory cap` at one worker and at six. But writing `used 25.3s of 25s
CPU, peaked 5.22 GB` into a CHECKED-IN row means the row differs from itself
whenever the last digit moves, and `5.22` against `5.01 GB` is the same fact in
two different bytes. **Two unreproducible rows became seven.**

⚠ The error is worth naming precisely, because it is not a coding mistake: a
record and a measurement want opposite things. A record must read the same
twice; a measurement is interesting exactly where it varies. Putting them in
one field made the field serve neither.

So they are separated:

- **the row** carries the class — `over the CPU budget`, `over the memory cap`,
  `over the CPU budget AND the memory cap`, or the signal when neither bound
  was reached (which means the wall bound fired). Derived from the
  measurements, so it does not depend on which signal arrived.
- **`mspec/bound_events.log`** carries the numbers, per run, truncated at the
  start of each sweep, and gitignored. This is also item 2: a bound that fires
  now leaves a trace, which is the thing that was missing when a reference
  process sat for ten minutes and no artifact said so.

Two measurements were needed to get there, and both were surprises:

⚠ **`/usr/bin/time` loses SIGKILL.** Measured: a child killed by SIGXCPU comes
back as 152 and by SIGALRM as 142, but SIGKILL's 137 arrives as **1**. Wrapping
the subject in `time` to get rusage would therefore have broken the memory-cap
classification — the guard's own kill, the one case that matters most — while
the other two kept working. The real status is written by an inner `sh -c` now.

⚠ **Peak RSS does not settle the ambiguity**, which is what killed the plan
recorded earlier. With no guard running, `define_method_spec` peaks at 8.3 GB
and `lazy/to_enum_spec` at 9.0 GB against a 6 GB cap, while both also burn past
25 CPU-seconds: they are genuinely over BOTH bounds, so there is no single true
answer for a better measurement to find. What fixed it was reporting both
conditions instead of choosing between them.

### 5. `bracket_depth`: a seeded fast path that can only confirm

The check bisects `[1, BUDGET]` on clang's own answer — ten `-fsyntax-only`
passes over 302k lines of C, 119s of every CI run. The answer is the same
number almost every time, so it now tries to PROVE it in two probes: `SEED`
must compile and `SEED-1` must not. Both together pin it exactly; either one
behaving differently means the number moved, and the full bisection runs and
reports the new value.

⚠ The property to preserve is that the fast path can only CONFIRM, never
conclude. A seeded check that could not report a larger number would be a check
that only ever agrees with what it was told.

Measured on THIS machine, both numbers from the same box — ⚠ the first version
of this paragraph compared the new local time against CI's old one, which is
two different machines and exactly the comparison this file exists to refuse:

| | timed here |
|---|---|
| full bisection (`BRACKET_SEED=999`, i.e. a seed that misses) | **75.04s** |
| seeded fast path | **11.97s** |

**6.3×**, and the same answer both ways: 273, "over the mainline default of 256
by 17". The wrong-seed run is also the proof that the fast path cannot weaken
the check — it missed, fell back, bisected, and reported the right number.

CI's copy of this step took 119s on its own hardware, so the saving there is
its own measurement to take, not this ratio applied to that number.

### The default is 6 now

The eight groups that hold every bound-hitting file, same binary, same revision:

| | timed | table | tag rows |
|---|---|---|---|
| `SPEC_JOBS=1` | 627.5s | — | — |
| `SPEC_JOBS=6` | **271.2s (2.31×)** | **IDENTICAL** | **IDENTICAL** |

Byte-identical rows AND causes. That is what `SPEC_JOBS` had been waiting for
since the first parallel experiment, and it took three separate fixes to get
there: the CPU bound, the wall bound expressed as a multiple of it, and the
record carrying a classification rather than a measurement.

### 4. Concurrent corpus passes: the uniquifier cannot come from the program

13 corpus programs write fixed `/tmp` paths, so the two passes cannot overlap.
⚠ And the obvious fix is wrong: `$$` in the program gives the two SIDES
different paths, because they are different processes — and
`138_lexical_file_and_require_relative` prints `File.basename(__FILE__)`, so
the path reaches the output and byte-equality breaks.

**So the concurrency was abandoned, and the redundancy removed instead.**
Measured: all **213** programs give a byte-identical REFERENCE result with and
without `MERE_RUBY_NO_HASH_INDEX` in the environment. The flag is this
interpreter's; ruby does not read it, and the three corpus programs that
enumerate ENV compare sizes against themselves rather than absolutely. So the
second pass was running `ruby` over 213 programs purely to reproduce output it
already had.

`run_corpus.sh --both` runs the reference once and mere-ruby twice:

| | timed |
|---|---|
| two separate invocations | 56.37s + 55.28s = **111.65s** |
| `--both` | **70.55s** |

**41 seconds a cycle**, no concurrency, and not one corpus program touched — so
the 13 fixed `/tmp` paths stay safe, because it is still sequential in one
process. ⚠ The first plan would have edited 13 witness programs to buy less.

### ⚠ The record caught a regression the harness had been warned about

The full sweep after all of the above read **MATCH 1758, not 1764**. Six files,
all in `core/env`, had gone from MATCH to DIFF — `keys`, `values`, `to_a`,
`each_key`, `each_value`, `each_pair` — and the divergence was one expectation:
ruby ran 13 where mere-ruby ran 12.

**One environment variable.** To get the wall bound into an inner shell I had
added `SB_WALL` to `spec_env`'s `env -i` allowlist, and `core/env` COUNTS ENV
KEYS. The two sides build their view of the environment differently (mere-ruby
shells out to `env(1)`), so an extra key is not free even when both sides get
it. ⚠ The comment above `spec_env` says precisely this, and names the five
files it cost the last time. I added the variable anyway.

The first fix — substituting the number into the command text instead of
exporting it — left it off by one, which said the variable was not the only
cause: the extra `sh -c` was a shell level too.

So the shell went away entirely. `perl` was already in the chain for the alarm,
so it now forks, merges the child's stderr into stdout, execs (with a LIST, so
no shell), and on the alarm kills the child and records that the WALL bound
fired rather than the child's own death. Nothing is added to the environment
and there is no reaper printing "Killed: 9" into the captured output.

Two things worth keeping from this:

- ⚠ **The harness is part of the subject when the subject measures the
  harness's environment.** There is no such thing as an invisible helper
  variable in a suite that counts keys.
- **A kill is now a kill.** Tested with a subject that ignores SIGALRM: it is
  killed anyway. That closes the "is the wall bound only a nudge" question
  recorded earlier, and the answer changed because the mechanism changed.

## 2026-09-22 (late): two scheduling ideas, both measured, both rejected

The sweep at six workers uses **2.09 cores of ten** — 662s of wall for 1381s of
CPU, of which **51% is SYSTEM time**. Each worker is therefore blocked about 65%
of the time, on process creation and the filesystem rather than on computing.
Two readings of that number suggested two changes. Both were implemented, both
were measured, and **neither is in the tree**.

### Longest-processing-time-first: slower

Groups run from 118 files (`core/kernel`) down to three, and twenty of the 103
have five or fewer. They were dealt round-robin BY POSITION, so one worker drew
both 118- and 114-file groups. Dealing biggest-first is the textbook fix.

| | timed |
|---|---|
| baseline | 646–662s (three samples) |
| longest-first | **719.87s** |

CPU was unchanged (1386s against 1381s): the same work, more wall clock.

### Ten workers instead of six: slower

If the workers are blocked rather than busy, more of them should overlap the
blocking. They do not:

| | timed | CPU |
|---|---|---|
| six workers | 646–662s | 1381s |
| ten workers | **736.73s** | **1430s** |

⚠ CPU went UP by 50 seconds for the same result. That is contention overhead,
and it says the bottleneck is a SHARED serial resource — almost certainly the
filesystem, given that half the CPU is system time — not a shortage of workers.

### ⚠ The part that is about measuring, not about scheduling

Both numbers came in worse, and both were taken while macOS's
`StorageManagement` was eating **150%+ of CPU** — as it had been, on and off,
all day. Three sweeps at 19:30, 19:57 and 20:12 got progressively slower, which
is a pattern with nothing to do with what was changed, so **both results were
retracted here as unmeasurable.**

Then the control ran: the unchanged harness, default workers, under the same
78%+64% load. **646.16s.** The baseline reproduces across seven hours (657.04,
661.57, 646.16 — a 2.3% spread), so the load is high but STEADY. It is a
constant, not a confound, and the two changes sit 10–14% outside that spread.

**The retraction was wrong and the control is what found that out.** Both
results stand.

Two things to carry, and the second is the uncomfortable one:

- **A before/after pair must be taken in the same window, or a control must be
  run in the window you are doubting.** Three timings hours apart are not a
  comparison. This is the fseventsd lesson from this morning in a new costume,
  and it was walked into twice in one day.
- ⚠ **Doubt was applied asymmetrically.** The load had been visible since 11:50
  and was noted at the time. It was only treated as a possible confound when
  the numbers came out AGAINST the changes. Had longest-first measured 10%
  faster, it would have been committed without a control and this paragraph
  would not exist.

### What this leaves

The sweep's remaining cost is process creation and filesystem work, shared
across workers, and neither scheduling nor worker count moves it. The two
remaining items in the loop are both outside this repository: the 41s emit and
the ~350s `clang` invocation, which needs the emitted C split into several
translation units.
