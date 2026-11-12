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

## Everything that changed, and what each was worth

One line per change, with the measurement that justified it. The sections below
are chronological and carry the reasoning, the poison tests, and the wrong turns.

| change | before | after | where |
|---|---|---|---|
| one spec tree per sweep, not per file | ~90 min | 30 min | *one tree per sweep* |
| the bound on "does this finish" is CPU time | record moved with the load | record is load-independent | *the bound is CPU time* |
| the wall bound is 24× the CPU bound, and SIGKILLs | misread a busy file as "stuck" | only a stuck process trips it | *the bound that was still too tight* |
| the outer bound is derived, not chosen | two numbers, one question | one owner per question | *the shape that landed* |
| the sweep starts its own memory guard | a README step, down half a day | a bound the harness owns | *two more limits* |
| a SIGKILL is not CRASH | "the interpreter aborted" | SLOW, naming the bound | *three bounds, one verdict* |
| the row carries a class, the log the numbers | 2 unstable rows → 7 | rows reproduce | *the second design* |
| background jobs' SIGINT no longer inherited | a row moved on worker count | subjects behave identically | *a stuck reference* |
| `SPEC_JOBS` defaults to 6 | 1829.7s | 646–662s | *the default is 6 now* |
| `dead_defs_check.sh` in one pass | 22.99s | 0.64s | *dead_defs_check.sh, landed* |
| `bracket_depth` seeded fast path | 75.04s | 11.97s | *a seeded fast path* |
| `run_corpus.sh --both` | 111.65s | 70.55s | *concurrent corpus passes* |
| `tools/build.sh --fast` (-O0) | 120.5s | 30.6s | *-O0 for the probe loop* |
| the sweep removes its own litter | 1,605 dirs | bounded | *the litter* |

**Measured and NOT adopted** — kept because the next reader will have the same
ideas:

| idea | measured | verdict |
|---|---|---|
| cache the reference side between sweeps | would save ~2 min of 30 | not worth it after the tree fix |
| take the verdict from peak RSS | the two ambiguous files exceed BOTH bounds | cannot resolve what has no answer |
| put the measured numbers in the row | 2 unstable rows became 7 | a record and a measurement want opposite things |
| deal the biggest groups first | 719.9s vs 646–662s | slower |
| ten workers instead of six | 736.7s, CPU +50s | slower; the bottleneck is shared and serial |
| unique `/tmp` paths per corpus process | `138` prints `File.basename(__FILE__)` | breaks byte-equality; the two sides are two processes |

**Closed 2026-11-04, outside this repository**: the 41s emit and the ~350s
`clang` invocation were the Mere compiler writing the same code many times
over, not the size of the interpreter. See the dated section at the end:
the emit is about 5s, and `clang -O2` about 50s on 37 MB of C.

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

The rest of these were learned by getting them wrong in this very file.

**Pair the before and the after in the same window.** Two timings taken hours
apart are not a comparison, because the machine is shared with whatever macOS
decided to index today. If you are doubting a number, run the CONTROL — the
unchanged thing, now, under the load you are doubting. ⚠ And decide whether to
doubt from HOW it was measured, never from which way it came out: on
2026-09-22 a background indexer at 150% was noticed at 11:50, ignored all day,
and promoted to "a confound" only once the numbers came out against the change
being tested. The control then showed the baseline was stable and the
retraction was the error.

**Write the open question, not a plausible story.** A stuck reference process
was left in here as "two facts that have not been connected" because that was
all that was known. Three tidier explanations had been written before it and
all three were wrong. The honest placeholder is what made the real cause
findable later; a confident wrong sentence would have closed the question.

**Keep the wrong turns, with their corrections attached.** Six ideas in this
file were measured and rejected, two of them proposed here a few hours before
being disproved here. That is the most reusable content in the document: the
next reader will have the same ideas, and the measurement that killed one is
worth more than the reasoning that suggested it.

⚠ **When a conclusion is superseded, say so AT the old one and check for other
copies.** This file is append-only, so an edit that replaces a section leaves
the earlier version in place unless you go and find it. Three successive edits
left THREE copies of one section, all answering a live question the way it had
stopped being true, and a reader hits the oldest first. Either mark the old
section `SUPERSEDED — see <name> below` and leave the reasoning, or remove it
and say in the replacement what was removed and why.

**`mspec/record_hygiene.sh` refuses a document with two sections of the same
title**, which is the signature of exactly that mistake. It is a check, not a
convention, because this went wrong three times in one day without anyone
noticing.

**Keep the index at the top current.** A thousand lines of narrative has the
detail and no way to see the list. Every change gets a row; so does every idea
that was measured and not adopted.


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
./tools/build.sh --fast     # -O1, the build for edit -> run one witness -> edit
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

### The default: 1 at the time, 6 by the end of the day

This section used to answer "no, and here is why", three times over — the file
had accumulated three identical copies of that answer from successive edits,
all of them saying the default stays 1. ⚠ That was true when written and wrong
by the evening; see **The default is 6 now** below, which is the live answer.

Two superseded sections were removed with them: an earlier telling of the stuck
reference above, and one claiming the wall bound is "a nudge, not a kill" —
refuted by measurement (`mere-ruby`, `ruby` spinning, and `ruby` blocked all
return 142) and fixed outright, since the bound now SIGKILLs.

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
translation units. (2026-11-04: neither needed splitting -- see the last
section.)

## 2026-09-30: a hung spec can empty the rest of a sweep

The first full sweep after merging eight parallel clusters recorded **308 SKIPs**
where the record had none: from the middle of `core/argf` on, every file's
reference side printed no tally, across all six workers. Swept again one group
at a time, every one of those groups ran normally (`core/io` 0 → 77/81). The same
run had three files the harness had to stop:

- `core/process/spawn_spec` -- `run_spec.sh` itself past the outer 1260 s bound.
  `spawn(..., close_others: true)` ignored the option, the child kept a pipe's
  write end, and the parent waited on a read for an end of file; the child it
  had started was left polling for a file nobody would delete.
- `core/process/exit_spec` and `core/kernel/exit_spec` -- the 600 s wall. `exit`
  in a thread never reached the main thread, which slept on.

With the three fixed, the next full sweep had **0 SKIPs** and MATCH 2717 (2722
after two follow-ups). The link between the hangs and the collapse is inferred
from that before/after, not traced.

- ⚠ **Read the SKIP column before the MATCH column.** A SKIP means the
  reference did not run: a block of them says "the instrument broke here", and
  recorded as it stood the table would have shown hundreds of files lost.
- Compare the new table to the recorded one group by group (MATCH down, SKIP
  up) before replacing it. `scoreboard.sh <root> <group> ...` re-sweeps only the
  named groups and keeps every other row.
- A file stopped by a bound is found example by example with a throwaway tree
  whose shim prints each example's name to stderr before running it.
- ⚠ **`--fast` is -O1 now.** -O0 could no longer run the prelude at all (the
  lexer's per-token tail call is a frame at -O0), and `scoreboard.sh` refuses
  an O1 build as it refused O0.

## 2026-11-04: the C was large because it was written many times over

Mere's CI compiles this interpreter's emitted C with clang 18 on Linux (the
downstream compile check), and it had crept to 1031-1144 s against a
1200-second limit. clang's `-ftime-report` put 88% of it in one pass, SROA,
and `-ftime-trace` put almost all of that in one function: `eval_e`, 2,807
lines of Mere and **70.8 MB of C** with about 970,000 locals.

The size was the compiler's, not the interpreter's. Splitting `eval_e` would not
have helped:

- **A guarded match arm wrote the arms below it twice** -- after a failed
  pattern and after a failed guard -- so each `when` doubled everything under
  it. The tell was in the counts: the literal `"=="` appeared 24,576 times
  (3 x 2^13) in `eval_e`. Fixed in Mere 0.1.699.
- **A curried lambda's two-argument entry wrote its second stage again**, and
  when that stage was another `fn`, each stage doubled the ones below it
  (Fibonacci in the arity; `invoke_val_c0`, seven parameters, was 14 copies of
  5.6 MB in the LLVM IR). Fixed in Mere 0.1.701.

Timed on the same source, same machine, under load:

| | Mere 0.1.697 | Mere 0.1.701 |
|---|---|---|
| emitted C | 132 MB | **37 MB** |
| emit (`mere -c`) | 41s (2026-09-22) | **5.3s** |
| `clang -O2` (Apple clang), user | 452s | **53s** |
| `clang -O2` (clang 18, Linux image) | 893s (SROA 785s) | 115s (0.1.699) |
| Mere CI, this repository's row | 1031-1144s | **74s** |
| LLVM IR (`mere -ll`) | 261 MB (0.1.699) | **59 MB** |

The corpus and the two benchmarks take the same user time on both binaries.

- ⚠ **Count the repeats before splitting a big function.** A literal or a
  call that appears a power of two times in the emitted code, when the source
  writes it a handful of times, is a code generator copying a continuation per
  branch. The cure is in the compiler and helps every program it compiles
  (mbrowse's C went from 26 MB to 5 MB with the same change).
- The LLVM build of this interpreter did not link at -O1 or -O2 with 0.1.697-0.1.700:
  LLVM's tail-recursion pass broke a `musttail` in `rxp_count_rep`, which also
  holds an accumulating self-call. Mere 0.1.701 marks such self-calls `notail`;
  the LLVM build matches the C build on all 482 corpus programs.


## 2026-11-05: Enumerator walks its #each; the regexp engine's entry, not its steps

**An Enumerator's block-taking Enumerable methods ran their source to the end
first.** `str.to_enum(:scan, re).map { $& }` answered the last match four
times: the elements were collected into an Array and the Array's map ran
after. They walk #each now, one element at a time (the prelude's `__gen_map`
and twenty more, written to enum.c's two ways of yielding: values kept apart,
or packed into one and spread over a lambda), each block answering nil to the
source as enum.c's do. Their frames read as ruby's C methods
(`Enumerable#map`). Under it were two older faults: **a `break` in
String#scan's block was dropped**, and **a `break` in the block of
`Enumerator.new {}.each` was a StopIteration nothing caught** (it now unwinds
to that #each as a flow, past the generator's own `loop` and `rescue`).

Also: public_send is a frame of its own; `method(:eval).call` reads its
caller; a wrapped load's self carries main's extended modules; `&:sym` and an
explicit receiver respect a singleton class's private and protected methods
(main's included); parameters list required keywords first; a regexp split
leaves `$~` nil. core/kernel: 113 of 118 match.

**The regexp engine was slow at its entry, not in its steps.** Thirteen
workloads against ruby (`bench/regexp.sh`) put `/i`, an alternation, a
literal in a long text and `=~` on small strings at 15-120x, where the
engine's own steps (scan, gsub) were 3-6x. A profile of `=~` on small strings:
the collector 40%, writing the MatchData's ivars, the encoding check; the VM
under 5%. What changed:

- the bytes a match can start with are a set, and other positions are
  skipped without running the program;
- `/i` on an ASCII character is a class of its two cases;
- the MatchData is a record until `$~` is read;
- a greedy loop over one character runs in place, pushing the same choices in
  the same order -- none when the byte after it is one the body never reads --
  and counts its steps toward the match cache (without them `/a+z/` over a
  million a's was quadratic: test_match_cache_with_peek_optimization);
- the search before is reused when the pattern is the same.

| workload | ruby | before | after |
|---|---|---|---|
| ci `scan(/ALPHA\|BETA/i)` | 0.007 | 0.89 | 0.014 |
| alternation | 0.012 | 0.21 | 0.033 |
| nomatch | 0.005 | 0.056 | 0.009 |
| literal_find | 0.004 | 0.125 | 0.049 |
| gsub_digits | 0.013 | 0.074 | 0.026 |
| scan_words | 0.034 | 0.13 | 0.099 |
| anchored (`=~` on 20,000 small strings) | 0.007 | 0.33 | 0.22 |

- ⚠ **Measure the workloads before the engine.** A single adversarial case
  measures the VM's step; it says nothing about the search's entry or the
  objects a match leaves, which is where the typical uses spent their time.
- ⚠ **Two sides computed by this interpreter can agree by both being wrong.**
  test_lazy_to_enum_lazy_methods compares an Enumerator's answer with a Lazy's;
  fixing the Enumerator made it red, because the Lazy had the same fault.
- Left: anchored and match_lines are the interpreter's call and loop, not the
  engine; literal_find wants memchr from an offset, which Mere's `str_index_of`
  does not take; scan_email starts at every letter of a word where Onigmo
  searches for the `@` first.


## 2026-11-05 (2): the regexp search finds the literal a match must hold first

**A search runs the program only where a match can reach its literal.** The
compiler records, for each pattern, the longest run of ASCII characters every
match holds -- preferring one at a bounded distance from the match's start --
and the least and most bytes before it (`rxq_store`; a top-level sequence,
opening groups and atomic groups, never an alternative). The search finds the
literal and tries only the starts in that window, then the literal's next
place (`rxv_search_lit`). Onigmo does the same with its optimization info.
Not for a multibyte encoding other than UTF-8 (its character boundaries are
not the bytes'), `/i` (the literal has more than one spelling) or `\G`.

**String#index on an ASCII string skips the character walks.** After the
search, literal_find spent its time turning the byte offset back into a
character index by copying the prefix and counting it. A string the
interpreter already knows is ASCII answers the byte offset.

**An opening class loop skips the rest of its run after a failed start.**
`/[a-z]+@/` failing at the first letter of a word fails at every later one:
the attempts from there are a subset of the ones already made, so long as
nothing in the pattern reads where the match started (a backreference, a
condition, a call, an absent operator or `\G`).

| workload | ruby | before | after |
|---|---|---|---|
| literal_find `index(/key_3999/)` | 0.004 | 0.055 | 0.003 |
| scan_email `scan(/[a-z]+@[a-z]+\.com/)` | 0.065 | 0.175 | 0.120 |
| nomatch | 0.005 | 0.010 | 0.001 |

The other ten did not move. corpus 487 holds forty-four patterns over twelve
subjects (a literal at a fixed, bounded and unbounded distance, a multibyte
subject, `/i`, a backreference, `\G`, binary, ISO-8859-1 and EUC-JP), each
read eight ways (ten on an ASCII subject), all as ruby's.

- Left as they were: `=~` with `\K` answers the position after `\K` where ruby
  answers the attempt's start, and String#rindex with a regexp on a multibyte
  string can answer a byte-shaped index (`"あいう key_9 えお key_3999 かき".rindex(/[^ ]+ key/)`
  is 13, ruby's 11). Both were there before this change; corpus 487 reads
  rindex only on ASCII subjects.
- Left: scan_words and gsub_digits run the VM at every match, and the VM is
  about 40% of scan_words; rebuilding it would gain at most 1.5x there.


## 2026-11-06: what every statement and every call paid, and an Enumerator over one value

**Each statement paid for work that had not changed.** A profile of an empty
`while` loop showed four costs on every statement, none of them the loop's:

- the file name was set again (`SFile`), with the lookups behind it, though it
  was the file already current;
- the safepoint summed the bytes of every store to decide whether to collect;
  it now sums them only when an allocation counter moved, or once in 64 calls
  (`gc_bytes_due`);
- `undef_blocked`, the builtin alias lookup and the singleton check behind an
  arity message walked their tables for names no program had undefined,
  aliased or defined (each now asks a map of the names first);
- the regexp's last-search state was eight string keys in a map, written at
  every search; it is a vector of eight slots.

Two more were Mere's, fixed there in 0.1.705: every region a statement took
was charged to a table of sites that is only printed under
`MERE_REGION_STATS`, and string equality was `strcmp` where the length is
already stored before the bytes (now a length check and `memcmp`).

| per iteration, microseconds | before | after |
|---|---|---|
| `while` with an empty body | 1.08 | 0.59 |
| `while` + `a.size` | 2.85 | 1.76 |
| `while` + `f(i)` | 2.96 | 1.84 |
| `while` + `pr.call(i)` | 4.06 | 2.80 |
| `times { yield-ish }` | 1.52 | 0.91 |

**An Enumerator over a source that yields one value walks it with one
parameter.** `n.times.select { }`, `ary.each.map { }` and their kind went
through the generic walk, which packs each yield's values into an array for
blocks that may take several. For Integer#times, Array#each, an Integer
Range#each and String#each_line / each_char / each_byte, when the program has
not redefined the source, `count`, `map`, `select`, `reject` and `filter_map`
use a walk that yields `x` (`__gen1_*` in the prelude), and `to_a` / `first` /
`take` build the elements without running the source (`gen1_take`).

| N = 20000, seconds | before | after |
|---|---|---|
| `times.count { }` | 0.156 | 0.037 |
| `times.select { }` | 0.171 | 0.042 |
| `times.sum { }` | 0.138 | 0.016 |
| `times.to_a` | 0.111 | 0.000 |
| `map.with_index` | 0.294 | 0.205 |

**`=~` with `\K` and String#rindex with a regexp answer as ruby's.** Both
were left in the entry before this one:

- `=~` answers where the successful attempt began, which a `\K` leaves behind
  (`rxv_att`); it answered the match's own start.
- String#rindex tried attempts from inside a UTF-8 character, which matched
  its trailing bytes (`"aあbあb".rindex(/[^ ]b/)` was 5). It now skips
  continuation bytes. index and rindex count characters in the subject's own
  encoding (binary, ISO-8859-1, EUC-JP, UTF-16), where they counted UTF-8's.

The regexp workloads (bench/regexp.sh, best of three):

| workload | ruby | before | after |
|---|---|---|---|
| match_lines | 0.003 | 0.130 (37x) | 0.047 (13x) |
| anchored | 0.007 | 0.210 (28x) | 0.088 (12x) |
| scan_words | 0.035 | 0.101 | 0.070 |
| capture_log | 0.014 | 0.048 | 0.038 |
| scan_email | 0.058 | 0.114 | 0.100 |

corpus 488 reads `\K` and rindex over UTF-8, binary, ISO-8859-1, EUC-JP and
UTF-16 subjects; corpus 489 reads the one-value walk next to sources that yield
several values, a generator, break / next / return / raise in the block, `$~`
in the block and programs that redefine the source. Both are as ruby's.

- Found and left, all there before this change:
  - a lambda passed to `map` over a source that yields several values
    (`each_with_index`, `with_index`, `[[1, 2]].each`) raises ArgumentError;
  - `select(&:itself)` over a generator that yields two values raises
    ArgumentError;
  - aliasing the builtin Integer#times and then redefining it gives
    NoMethodError for the alias.
- Left: scan_words is now about 30% the VM, 14% entering a search and 15-20%
  the collector. Rebuilding the VM is still worth at most 1.4x there.
  match_lines and anchored are now the interpreter's loop and call.

## 2026-11-06 (2): how an Enumerable method yields several values, aliases of a builtin iterator, and three smaller costs

**The three differences left in the entry before this one, measured against
ruby 4.0.9 method by method.** A source that yields several values at once
(`each_with_index`, a generator's `y.yield 1, 2`, a Hash's `each`) reaches
the block of an Enumerable method in one of three ways, as enum.c's
`enum_yield` hands them:

- apart (`rb_yield_values2`): map, flat_map, count, inject, to_h,
  each_with_object and their kind;
- packed and given as to a proc, even when the block is a lambda
  (`rb_yield_force_blockarg`): select, find, reject, the `*_by` family,
  partition, drop_while, take_while, each_entry, cycle, zip -- a lambda's
  parameters are cut to the values' number or padded with nil, and a Symbol's
  proc or a Method's is given the packed array as its one argument;
- packed and given as they are: sum, chunk, slice_before, slice_after,
  each_slice, each_cons.

mere-ruby spread them for every method. The first of the entry's three was
not a difference: a lambda wanting one value, given to `map` over such a
source, raises ArgumentError in ruby too (map hands the values apart). What
differed was the second way: `select(&:itself)` raised, a lambda wanting one
raised, and count and to_h packed values they should spread. The prelude's
walks now ask `__fb_prep` for a lambda's parameters and yield through
`__fb_fit`; `blk_spread_for` knows the methods of each way, and that a call
through `send` is the method's own. each_with_index and each_entry answer
their receiver, whatever walked it.

**An alias of a builtin iterator, called without a block, is an Enumerator.**
`alias old_times times; 3.old_times` was NoMethodError, as were upto, downto,
step, each_slice, map and the rest: the alias went to a layer with no
blockless form. When the class has redefined the name since, the alias with a
block reaches the builtin (the user's body is skipped for that one call), and
without one it is an Enumerator over the name, whose #each reaches the new
method, as ruby's does.

corpus 490 is the matrix: 5 sources (a generator, each_with_index, a Hash's
each, a generator yielding one array, a Hash) by 38 methods by 9 blocks
(lambdas of 1, 2, rest, optional and keyword parameters, two Symbol procs, a
proc, a Method), and the edge cases (to_ary, a Range's and an Array's zip, the
receiver each_with_index answers). corpus 491 is the aliases. Both are as
ruby's.

**Three smaller costs.**

- An Integer in a string interpolation is written without the dispatcher,
  when no refinement is active and Integer has neither a prepended module nor
  a `to_s` of the program's. anchored's timed loop is 20% fewer instructions.
- The string store's bytes are kept rather than walked at each safepoint: a
  page is measured again only after something wrote to it, and the page being
  appended to only once a megabyte has been added since. match_lines' timed
  loop is 6-10% fewer cycles; a loop making 5 MB strings peaks at 432-570 MB
  where it peaked at 638-786, collecting 42 times where it collected 28.
- The literal prefilter searches from a later position with Mere 0.1.707's
  `str_index_from` (memchr from an offset), where only the first search, from
  the start, used `str_index_of`. A literal search workload is 18% fewer
  instructions.

Instructions retired, whole process (the machine was loaded; the seconds
moved by more than the change):

| workload | before | after |
|---|---|---|
| match_lines | 2315M | 1904M |
| anchored | 2844M | 2209M |
| capture_log | 2342M | 1980M |
| scan_words | 2836M | 2400M |
| scan_email | 3614M | 3085M |
| literal_find | 1720M | 1319M |

The round: 10 gates, corpus 493/493 with the hash index on and off, stderr and
GC_STRESS differing from the previous binary on 490 and 491 only (both now
ruby's), stdlib the same, 1007 specs the same, and every unit test file the
same count as before (alias, struct and gc run on both binaries).

- Found and left:
  - Enumerable#zip with a lambda wanting more parameters than the tuple has
    raises ArgumentError; ruby pads with nil.
  - `Integer.include M` with an `M#to_s` changes what `"#{1}"` gives in
    mere-ruby ("vM") and not in ruby ("v1"); it did before this change too.
- Left: the VM. scan_words is 2.0x ruby's and the VM about 30% of it, so
  rebuilding it would gain at most 1.4x there; match_lines and anchored are the
  interpreter's loop and call.

## 2026-11-06 (3): what CRuby's tests still found -- a trap in the middle of a wait, a zone object, ENV under default_internal

The candidates left from the record of 2026-10-31 (sweep 485) were run one by
one against ruby 4.0.9. Most already passed: the rounds since had fixed them
(the m17n regexps, sprintf with a named encoding, Rational's subclass and
power overflow, the regexp match cache, require's FIFO, `\K`). What still
differed:

- **A trap that runs while the main thread waits.** A signal delivered while
  the main thread was in `Queue#pop`, a Mutex or the autoload of another
  thread was left for later ("none of them looks again at what woke it"), so
  `trap(:INT) { q.push 1 }` with the main thread in `q.pop` fell into the
  deadlock fatal. Those waits do look again: the main thread is woken for the
  signal, runs the trap in the middle of the wait (sch_block) and waits on, or
  stops when the trap gave it what it waited for. Thread.stop and a condition
  wait are left as they were. And when the last other thread ends while the
  main one sleeps for ever, the scheduler now looks for a marked signal every
  20 ms there too (`thread_next` slept a second at a time and never looked):
  `loop { sleep }` outlived the TERM that ends it.
- **Two threads waiting on one child.** Process.wait computed the children it
  waits for once; the one another thread reaped stayed in the list and the
  waiter polled for ever. It asks again after each wait, and with none left it
  is ECHILD, as waitpid(2) answers.
- **`$stdin` read from a thread** was read(2) on descriptor 0 for every thread:
  it now waits for the descriptor to be readable first, a millisecond at a
  time, when other threads are alive. `$stdin.close` closes it (`closed?` was
  always false), and a reader waiting on it in another thread gets "stream
  closed in another thread".
- **A Time with a zone object**: `dst?` asks the zone's `dst?` (with the time in
  UTC, as zone_set_dst does), `to_a`'s isdst is `isdst` (it was always false,
  local times in daylight saving too), and a zone NAME given to
  `Time.now(in:)` / `Time.at(in:)` goes through the class's `find_timezone` as
  Time.new's does.
- **ENV under a default_internal** is transcoded to it, not relabelled: the
  bytes were UTF-8 tagged Windows-31J. A name or value that does not go across
  stays UTF-8, as rb_external_str_new_with_enc leaves it. The methods that
  filter ENV with a block run on a copy and write it back; the copy's
  transcoded names are written back as the bytes they came from (they made a
  second variable beside each). `ENV.key` answers a frozen string like the
  other reads.
- **Kernel#inspect bound to a Struct or an immediate** (`bind_call`) is
  Kernel's `#<S:0x... @a=1>`, not the value's own inspect.
- **TracePoint :script_compiled** for a String eval, instance_eval and
  class_eval, with `eval_script` and `instruction_sequence`.
- **A call with more than 131,000 literal arguments** raises SystemStackError
  when it is made (ruby pushes them on a VM stack of 131,072 slots); it was an
  ArgumentError from the callee.
- **ObjectSpace's finalizers at exit** were taken one `Hash#shift` at a time,
  and each shift rewrote the rest of the table (quadratic): the table is now
  taken whole and walked.

corpus 492 reads each of them against ruby (the old binary stops at the
deadlock fatal of the first).

The round: 10 gates, corpus 494/494 (496/496 after the rebase onto the
PRs merged meanwhile) with the hash index on and off, GC_STRESS and stderr
differing from the previous binary on 492 only (under GC_STRESS too it is
ruby's), stdlib the same, 600 specs the same (eval_script now MATCH; thread's
list_spec counts a loop and differs on both). Unit tests against the previous
binary or the record, none down: exception 95, object 65, env 92, time_tz
155/155, settracefunc 97 (95), signal 22, thread 96, thread_queue 41,
thread_cv 14, process 155 (153), io 243 (242 on the previous binary),
io_m17n 159, objectspace 36, eval 39, m17n 126, string 439, struct 100.

- Left:
  - A FIFO opened from one thread while another is its other end: refused
    (every thread is one OS thread, and open(2) waits).
  - A million `define_finalizer` (test_finalizer) still takes 99 s and 6.6 GB:
    a kept closure costs about 7 KB, most of it the 4 KB arena of its frame.
  - `Hash#shift` rewrites the rest of the hash, so emptying one with it is
    quadratic (20,000 entries: 7.4 s, ruby 0.06 s).

## 2026-11-07: the three left on 11-06, and what zip, a core class and a hash's count still differed on

The three left by the entry before, and what turned up on the way:

- **`Hash#shift` was quadratic.** Mere's `map_set` copied the stored list
  into the map's arena again every time, and the new value of the hash's
  list is the old one with its head dropped. Mere 0.1.711 keeps a tail the
  map already holds; `Hash#empty?` looks at the head instead of counting.
  Emptying 20,000 entries: 7.4 s to 0.1 s (a million: 5.4 s, ruby 0.35 s).
- **`Hash#size` counted the list.** Each hash now keeps its pair count: a
  new key adds one, a delete takes one, any other rewrite of the list drops
  the count and the next `size` counts again. `size` called while a hash
  grows to 30,000 entries: 17.4 s to 0.14 s.
- **A kept closure cost about 7 KB**, most of it the 4 KB first block of its
  frame's map. The frame a closure captured is compacted when its call ends,
  and Mere 0.1.711 sizes a compacted map's first block to what moved into it
  (512 bytes to 4 KB). 200,000 procs: 1,437 MB to 683 MB; a million
  `define_finalizer`: 99 s / 6.6 GB to 74 s / 4.7 GB (still over
  test_finalizer's 60 s: every collection marks every kept closure, which
  wants a generational GC).
- **A FIFO opened between threads.** The read side opens without blocking
  and waits for a writer while the other threads run; the write side waits
  for a reader thread of this process to open it. A FIFO another process
  made (the parent of assert_separately) is known by its stat type, looked
  at only while threads are alive. test_open_fifo_does_not_block_other_threads
  and ruby/spec's File.open on a FIFO pass. Opened to read, it is an IO, not
  a File (as `File.open(fd)` is, before and now).
- **zip and the force_blockarg family pass a lambda its tuple as a proc
  would.** ruby's enum_yield cuts the values to a lambda's parameters or pads
  them with nil (Enumerable#zip, select, find and the rest); a Symbol or
  Method proc still takes the packed array. Array#zip is strict, as
  rb_ary_zip yields plainly, and an Enumerator's zip, which goes through it,
  keeps the fit.
- **A module included into a core class after its method.** With
  `Integer.include M` and `M#to_s`, `1.to_s`, `"#{1}"` and
  `1.method(:to_s).owner` are Integer's, as the core class's own method
  comes first in its ancestors; the module wins only where ruby 4.0.9's
  table names it the owner. The owner is moved for `obj.method(name)` only:
  put first into what makes every Method, it moved a bind too, and
  `Kernel.instance_method(:inspect).bind_call` on a String's subclass came
  out as String#inspect (corpus 320 caught it, after the round below had
  run on the binary before that change).

corpus 498 reads the tails, the closures, the FIFO, zip and the core
method against ruby.

Not done: test_hash's `*_memory_leak` (the heap grows in steps until the GC
collects -- 100k to 300k iterations: 173 to 189 MB -- not a leak; passing
them means retuning the GC's thresholds).

The round (on the binary before the owner change and Mere 0.1.711): 10
gates, corpus 497/497 with the hash index on and off, stderr and GC_STRESS
differing from the previous binary on 498 only (it is ruby's), stdlib the
same, 706 specs with 705 the same and File.open's up (127 to 129 passing,
the FIFO). Unit tests against the previous binary, none down: hash 297,
enum 89, enumerator 70, lazy_enumerator 64, array 459, range 67, proc 117,
method 97, module 192, object 65, io 244 (243), objectspace 36, gc 28,
thread 97 (96), process 155, require 51, settracefunc 97, string 439,
eval 39, struct 100, integer 38, alias 17. On the final binary (Mere
0.1.711, the owner moved for `obj.method` only, rebased onto the
Random.urandom PR): 10 gates, corpus 498/498, 492, 498 and 320 under
GC_STRESS as ruby, and twelve of the unit tests again with the same counts
(hash, method, module, object, proc, array, struct, eval, enum, enumerator,
string, integer). The corpus program was 494 until the PR took that number.

## 2026-11-07 (2): `require "prism"` -- libprism compiled in, Prism's own Ruby reading its answer

The first of note 511's two Prism steps (the second is the parser in Mere
behind the same five externs). `test/prism` was 63 files and 13,546 cases
all RED on one `LoadError`; it is now measured.

- **What was built.** Prism 1.8.2 as Ruby 4.0.9 ships it, with the files
  Ruby's build generates from `prism/templates`, vendored under
  `vendor/prism/` (MIT) and compiled once into `vendor/prism/obj/libprism.a`
  by `tools/build.sh` (4 s, kept until a vendored file is newer). Five
  `extern fn` in m_state.mere -- parse / lex / comments / parse_lex
  serialized, `parse_success?`, "does the stream parser want more",
  `StringQuery`, the version -- with `tools/prism_glue.c` on the C side.
  Prism's Ruby half (prism.rb and prism/**/*.rb, 40,000 lines) is shipped
  like json's, generated by `tools/gen_prism_lib.rb`; `lib/prism_ext.rb`
  answers `require "prism/prism"` as Prism's FFI backend would, over the
  externs instead of FFI::MemoryPointer.
- **Three things the compiler's boundary decided.** A `bytes` RETURNED by an
  extern is used as it is (a `str` return is copied), so the glue owns one
  static buffer and the Mere side copies it into a Ruby string before any
  ruby runs. A boundary `int` is C's 32-bit int, so no pointer crosses:
  lengths travel inside the bytes. And `mere --ffi-header main.mere` prints
  nothing for this program, so the glue declares the `mere_bytes` layout
  itself behind `__has_include`.
- **⚠ A top-level `let` nests the rest of the program.** The first
  generator cut node.rb into 400-line pieces, each its own top-level `let`,
  to keep a `++` chain short; the emitted C's bracket depth went 488 → 1017
  (the build passes 1024) because every top-level `let` opens a block the
  rest of the program sits inside. The chain was never the cost: the
  compiler folds a chain of LITERALS into one (20,000 lines fold in 1.5 s).
  One chain per file inside the function, as json's generator does: 826.
- **⚠ A shipped file's `require_relative` arrives ABSOLUTE.** The parser
  resolves it against the fiction directory (`__builtin_relpath`), so
  do_require saw `/usr/lib/ruby/4.0.0/prism/node` and no shipped name
  matched it. The shipped name is the path under the stdlibdir fiction.
- **What test/prism found in the interpreter.** `super` from a module
  prepended to String did not reach the builtin `unpack1` (Prism's polyfill
  does exactly that): pack / unpack / unpack1 were not prim_method's, and
  super_missing has the three arms now. `String.instance_method(:unpack1).parameters`
  was `[[:req], [:rest]]` where ruby's is `[[:req, :fmt], [:key, :offset]]`
  -- the builtins ruby writes in Ruby have NAMED parameters, now the 5th
  column of `m_internal_ruby.mere` (`tools/gen_internal_ruby.rb`), asked
  first by bm_params; a builtin singleton (`Dir.method(:glob)`) is named by
  its frame label as #owner names it. `@x = 1, 2` was a syntax error
  (parse_expr alone; a local's path used parse_rhs_list). `<<~` counted a
  tab as one column; parse.y counts it to the next multiple of 8 and keeps a
  tab that would overshoot the width.
- **The record.** corpus 504/504 with the hash index on and off, 499 under
  GC_STRESS=50 the same, 10 gates ok (bracket depth 826 of 1024). Unit
  tests against the previous binary, none down: method 97, module 192,
  object 65, proc 117, string 439, array 459, eval 39, require 51; pack 52
  → 54 and assignment 26 → 29 up. test_literal's test_hash_value_omission
  is RED on origin/main's binary too (`local_variable_set(:self, ..)` on a
  binding that shares its frame rebinds the method's self), not this
  change's. test/prism, which the default record does not carry: **14,535
  cases, MATCH 10,430, RED 3,116** (BOTH 472 and EXTRA 517 are the two
  files the reference runs zero tests of). snippets 3,833/3,833, dump
  980/980, node_id and overlap 978/978, newline_offsets 978/978,
  source_location 152/152, errors 1,170/1,254, fixtures 931/970. The 3,116
  are: Ripper 2,910 (lex_test, magic_comment_test, ripper_test, bom_test
  compare against it -- note 511's stage 5), `RubyVM::InstructionSequence`
  52 (newline_test), this interpreter's own parser 127 (84 invalid programs
  it accepts, 39 fixtures it refuses, 4 implicit arrays), warnings 13,
  encodings 15.
- **The cycle.** The emit now carries 2.2 MB of Prism's Ruby as literals:
  emit + clang -O2 was 55 s on this machine (the C is 39.8 MB), libprism
  itself 4 s once. test/prism takes about 40 minutes under the harness
  (dump_test 103 s, snippets and ripper_test the long ones) and is not in
  files.txt; CI's measurement of all 758 files carries it.

## 2026-11-07 (3): `require "ripper"` -- Prism's Ripper translation as ::Ripper, and what loading it found

Note 511's stage 5. test/prism's lex_test (968) and ripper_test (946)
compare Prism against Ripper, and test/ripper (457) is Ripper itself.

- **What was built.** `::Ripper` is `Prism::Translation::Ripper`, as on
  TruffleRuby. lib/ripper_ext.rb -- shipped under "ripper", "ripper.so" and
  the four names ripper's own files are required by -- adds the Ruby half
  the reference layers on its C core: `Ripper::Lexer` (tokenize / lex /
  scan over `Prism.lex_compat`, with the `on_sp` tokens Prism leaves out
  filled back in from the source, in source order so a heredoc's lines do
  not hide a gap), `Ripper.tokenize` / `lex` / `slice`, `Ripper::Filter`,
  `dedent_string`, `end_seen?`, `encoding`, and the C core's default event
  handlers, which answer their first argument where the translation's
  answer nil. `Ripper.new(src).parse` through the translation, so a
  subclass's `on_*` overrides see Prism's walk of the tree.
- **What it found in the interpreter**, each a witness in corpus/500:
  - `$~` had no frame of its own in a class body, a module body, a
    singleton class body or a required file's top level (ruby's each is its
    own svar scope). prism's SexpBuilder is `grep(/\Aon_/) { $'.to_sym }`
    in a class body of a required file: the match was made under the
    builtin call's frame and the block swapped in frame 0's stale value.
    Each is a frame now (`rx_call_enter` around it) -- keyed "__rxfid", not
    "__fid", because the first try put "__fid" on a required file's env
    and `eval "return"` at its top level became "unexpected return".
  - `super` from an override of `==`, `!=`, `!` or `===` on a plain object
    ran out of chain (BasicObject's live in the primitive table): Prism's
    `Lexer::State#==` is `super or to_int == i`.
  - `class C < Al::Sub` with `Al = M::In`, and `class C < Ripper::Filter`
    with Ripper bound to the translation: the superclass was looked up by
    the NAME "Al::Sub", which no constant has (`named_class_of` resolves
    the head segment to the class it is bound to now). Two more of the
    same family are noted and not fixed: `class Outer` with `Outer =
    M::Inner` defines a new class instead of reopening, and `class A::B`
    where B is an autoload constant defines instead of loading.
  - `yield` in a class_eval / instance_eval body was "no block given":
    the body runs as class-body statements with no block of its own. The
    enclosing method's rides in the env under "__yblk" (test/ripper's
    DummyParser hooks events with `define_method(name) { yield(name) }`
    inside `class_eval`).
  - `[[1]] == [delegator]` was false: an Array element against an object
    was compared structurally; ruby's rb_ary_equal asks the object when it
    answers #to_ary (Prism's lex tokens are SimpleDelegators over arrays).
  - A magic comment's spaces are ISSPACE: a vertical tab too.
- **The record.** test/prism's lex_test 968/968 and ripper_test 946/946
  (both compare Prism with Ripper), bom_test 10/10, magic_comment_test
  990/991 (3 → 965 → 946 → 10 → 990 of the files that required Ripper).
  test/ripper, 457 cases: 155 on the first binary, **324** on the last --
  filter 7/7, sexp 57/58, scanner_events 51/64, parser_events 165/202,
  lexer 18/29, ripper 24/39, test_files_* 2/58 (the translation reads what
  the callbacks return). corpus 506/506 with the hash index on and off, 499 and 500
  under GC_STRESS=50 the same, 10 gates ok (bracket depth 826). Thirty-four
  unit test groups against the previous binary, none down: syntax 168
  (167 on the "__fid" try, back with "__rxfid"), super 50, lambda 27,
  yield 13, iterator 32, class 60, module 192, object 65, eval 39, method
  97, proc 117, require 51, string 439, array 459, hash 297, regexp 161,
  m17n 126, marshal 230, struct 100, settracefunc 97, enum 89, parse 102,
  literal 30, pack 54, assignment 29. What is RED in them is the known set:
  the memory_leak tests time out under a loaded machine, callcc, and the
  compaction ones.
- **The cycle.** Each of the seven rebuilds was 55-60 s; test/ripper takes
  25 minutes under the harness (test_files_* run `-rripper` children over
  lib/), the four Prism files 30. The dependence on CI's Mere pin bit once:
  PR #29 moved MERE_REF to 991f299b while mere.toml still says >= 0.1.711,
  and a 0.1.711 build failed to link the UDP externs. Build with the
  pinned ref (mere-wt-712).

## 2026-11-07 (4): where a command may stand -- the parser's 127, and what parse.y refuses that this one took

Note 511's parser gaps, measured against test/prism's fixtures with
`RubyVM::InstructionSequence.compile`: 39 fixtures (valid programs) this
parser refused, and 84 of test/prism/errors (invalid programs) it accepted.
After the round: 15 refused (4 are ruby 3.3-only syntax ruby 4.0 refuses
too, so 11), 23 accepted (3 are version-gated, so 20).

- **Valid programs it refused** (24 shapes, each a line of corpus/501 or
  of the fixtures): an endless range before `&&`/`==`/`?`/`=>`
  (`(1..) && 2`), an operator method after `::` (`A::+`, `a::[]`),
  `Foo::Bar &baz`, `C do ... end`, a const or splat in a pattern after
  `::`, `**` in a hash pattern, pinned `_1`, a bare array stopping at
  `and`/`or`, block-locals after `;` in def and lambda params, `->a:`
  across a newline, `for *v in`, `not` across a newline, `defined?` with
  its operand on the next line, `def (a)::b`, anonymous `*` as an index,
  bare `**` in a hash literal, `*`/`**` alone as a command's argument,
  `case 1 in 2; when`, `do` before `:` is a label, `foo if: 1`, `class`
  and `module` as arguments, `z = x y rescue c d`, trailing `=> k: v`
  pairs after a flow keyword's value, `%w` and friends closed by a
  vertical tab, `elsif x in pat`, `rescue => A[]`, and `c ? foo do |n| n
  end : 0` -- which needed the lexer: a `:` a space away from `end`,
  `self`, `nil`, `true` or `false` is never that keyword's label, so it
  comes out as " :" and the label arms do not see it.
- **Invalid programs it accepted** -- the big one is where a paren-less
  call (a COMMAND) may stand. parse.y lets one be the statement, the
  whole value of an assignment, the sole argument of a call, an operand
  of `and`/`or`/`not`/`!`; everywhere else it is "unexpected local
  variable or method". The parser now marks the end of a paren-less
  argument list ("lastcmd", set by parse_puts_args, not by `raise(X)`
  through the same path), every place that reads an operand clears the
  mark before and checks it after (binary operands, elements, hash
  values, one argument among several, defaults, `when` and `rescue`
  lists, ranges, `defined?`, ternary branches, splat operands), and a
  statement clears it on the way in and out, with "stmtcmd" carrying it
  to the `in` / `and` modifiers that are parsed after the statement
  returns. The first version marked `raise(X)` too and refused the
  prelude at boot: the flag must say "bare and non-empty".
- **The small ones**, each a line: parameter order (required, optional,
  `*`, post-required, keywords, `**`, `&`, `...` last; an optional after
  the post-required ones), trailing commas in def and lambda parameters
  and after `|&b,|`, `*` after keyword arguments, an argument after a
  block argument, a `,` at the start of a line, `_1` as a target, `foo!
  += 1`, `case` with no clause, `for` with no index or no `do`, `class A
  < B end`, `if 0 0`, `::foo`, `A::$b`, `alias $a b`, `foo(alias x y)`,
  `defined?()` with the paren glued on, `1.. || 2` (`||` after `..` is
  two `|`s to ruby), `def @foo`.
- **Still accepted (20)**: `! ! a b`, `true && not true`, `def a = b
  rescue c d`, `a, b = c = d f`, `->a=b c{}`, block-param defaults with a
  unary operator, `in -1**2`, `a=>b, *,`, `p(...1...)`, duplicate names in
  destructured params, and the five void-value `(return)` shapes.
  **Still refused (11)**: `def foo = puts "x" do ... end`, `A::__END__`,
  three heredoc shapes, `foo :a, :b if bar? or baz and qux` in a file
  (alone it parses), `^({ a: })`, `0..` + `; a..`, `a:b` as a bare
  argument, and the `%` strings spanning heredoc newlines.
- **Checked**: corpus 508/508 with the hash index on and off, corpus 501
  under GC_STRESS=50, the 10 gates, and the parser-side unittest groups
  at their known counts (syntax 168, parse 102, literal 30, lambda 27,
  proc 117, method 97, iterator 32, yield 13, assignment 29, class 60,
  module 192, string 439, array 459, hash 297, eval 39, object 65, super
  50, defined 39, pattern_matching 30, range 67). test_call and
  test_keyword show EXTRA because the reference side needs the `-test-`
  C extensions this tree never built. Build 60 s; 14 builds in the
  round.

## 2026-11-08: what test/prism's encoding and warnings tests found -- vcalls, instance_eval's constants, a symbol's escapes, the sign after a name, and parsing as a file

Note 511's stage 3 again, from note 512 §4's "encodings 15" and
"warnings_test 13": test/prism/encoding (encodings 10, string 16, symbol 8)
and test/prism/result/warnings_test (29). Before: 2 / 13 / 4 / 16. After:
all of them (63/63). Each is a line of corpus/502.

- **A bare name an object's class answers through method_missing.**
  `def f; zzz; end` with a `method_missing` was "undefined local variable
  or method": the zero-argument self-call asked `respond_to?` (so a class
  with respond_to_missing? worked) and never method_missing itself. ruby's
  vcall asks it whatever respond_to? says. encodings_test evals every
  identifier of an encoding against a BasicObject whose method_missing
  answers the name -- `_0`, `p`, each letter -- and a bare `p` on a
  BasicObject goes there too, not to Kernel#p.
- **A constant in a string instance_eval'd on an object** is looked up
  through the object's class (its cref is the singleton class), so that
  class's `const_missing` answers before the NameError. The block form
  keeps the enclosing scope, as ruby's does.
- **A quoted symbol's encoding follows its escapes**, as a double-quoted
  string's does: `\u{80}` forces UTF-8, `\x80` in a US-ASCII source is
  binary, in a Windows-1253 source the source's, and `\x80\u{80}` in any
  non-UTF-8 source is "UTF-8 mixed within". The lexer reads such a `:"..."`
  as the string and `.to_sym` -- one rule, the string's. `\M-x` counts as
  a byte past ASCII (`"\u{80}\M-\C-?"` is the same refusal). A byte past
  ASCII in a US-ASCII source's string or symbol literal is "invalid
  multibyte character 0xC4", as prism says it.
- **`foo -1` is foo(-1).** After a name that is no local, no keyword and no
  literal, ` -x` / ` +x` (space before, none after) is the argument's
  sign -- ruby's "ambiguous first argument; put parentheses or a space"
  under -w -- where after a local or a literal it stays the operator. It
  was the operator everywhere: `foo -1` called foo() and subtracted. A
  capitalized name too (`A -1` is "undefined method 'A'"). The lexer
  marks it " -" as it marks " *"; the call parsers take it and the
  operator layer reads it as the plain operator when no call did.
- **RubyVM::AbstractSyntaxTree.parse reads its source as a file.** It ran
  the eval behind ISeq.compile's syntax check, whose warnings are an
  eval's: no unused variables, no void statements, no indentation check.
  A flag the shim sets ("evfile") makes that one eval parse as a file,
  under the name "(none)" as ruby's does, with prism's wording for the
  two ambiguity warnings there ("'&' interpreted as argument prefix";
  ruby's own files and evals keep "ambiguous `&` has been interpreted",
  which corpus/345 pins). And the warnings that were missing or went to
  the wrong place: "END in method" wrote to fd 2 past a swapped $stderr
  (warn_note now); "Float ... out of range" only for a float without a
  fraction; `if` / `unless` / `elsif` with the condition on the next line
  was a SyntaxError ("'if' at the end of line without an expression");
  "literal in condition" for a Float, Rational, Complex and __ENCODING__;
  "found '= literal' in conditional" under `!` and `not`; `... at EOL`
  with a comment or a form feed after it, and in an endless def's body;
  `\v` and `\f` are whitespace; `a &:sym` warns nothing.
- **Checked**: corpus 510/510 both ways, 502 under GC_STRESS=50, the 10
  gates, and the unittest groups at their known counts (syntax 168, parse
  102, eval 39, object 65, ast 1706, string 439, symbol 59, m17n 126,
  float 63, method 97, module 192, class 60, among others). 8 builds.

## 2026-11-08 (2): test/ripper's remaining differences -- a constant inside `class A::B`, and the Ripper layer's loose ends

Note 513 §4. test/ripper (minus the test_files_* sweeps): 322 → 337 of
399. parser_events stays at 165/202: its 37 are the translation's
(errors reach on_parse_error, not on_assign_error / on_param_error /
compile_error; `arguments&.any?` on a callback's answer; no warn hooks).

- **`Ripper::Lexer` inside `class TestRipper::Ripper` was the test class's
  own.** The lexical walk for a qualified name's HEAD took every prefix of
  the cref's path as a scope -- "TestRipper" is not one: the nesting of
  `class TestRipper::Ripper` is [TestRipper::Ripper] alone, and `Ripper`
  there is the top-level one (an alias of Prism::Translation::Ripper). The
  bare-name path already dropped a hit in a scope that is not on the
  nesting; the qualified path did not. And a head that is itself
  qualified (`Ripper::Lexer::State` with Ripper an alias) is read as the
  constant it names, through the same arm one segment shorter. corpus/503.
- **The Ripper layer** (lib/ripper_ext.rb): a source that answers #gets
  is read at parse time, line by line, a line that is no String its
  TypeError then (test_ripper's Input); Lexer#error?; the whitespace
  after the last token and `\ ` are on_sp (after a final newline with the
  state the line ended in); an unterminated heredoc has no end token; the
  `__END__` token is the marker line alone; yydebug writes bison's
  "Next token is token ..." lines on debug_output, named as parse.y names
  them.
- **Left, all the translation's or prism's**: lexer states after a heredoc
  (BEG vs END), `}` as on_embexpr_end, error recovery around heredocs,
  the regexp-option encoding check (prism says the opposite of parse.y
  for `/[\xC0-\xF0]/u` and `/n`), parse.y's wording for
  `def req(a?:)`, words_sep splitting, `?\\` as a CHAR, `$\` and the
  invalid-escape tokens, and the no_memory_leak timeouts.
- **Checked**: corpus 511/511 both ways, the 10 gates, and the constant-
  related unittest groups (const, module 192, class 60, autoload, syntax
  168, parse 102, eval 39, object 65, method 97, refinement, require 51,
  struct 100, marshal 230) with prism's ripper_test 946 and lex_test 968.

## 2026-11-08 (3): an implicit array is a statement's right side, a scoped constant takes one, an explicit `o.[]=(0, 1)` is a call

The small prism files left (note 512 §4's "implicit array 4" and bom 3):
bom_test 7 → 10, implicit_array_test 6 → 10, attribute_write_test 6 → 7.

- **`x = *b` as a condition, an argument, a flow keyword's value or
  another assignment's value** is parse.y's "multiple assignment is not
  allowed in this context"; this parser took it anywhere (`if a = *b
  then end` ran). The expression-level arms that read a splat value mark
  "mrhs" the way a paren-less argument list marks "lastcmd"; the places
  that may not hold one clear the mark before their operand and refuse it
  after. A statement's own right side (`a = *b`, `o.a = *b`, parens) is
  untouched. `A::A = *b` and `A::A = 1, 2` were refused outright: the
  scoped-constant assignment read one expression where the plain one read
  a list. corpus/504.
- **`o.[]=(0, 1)` answers what the method answers** -- it is a call,
  where `o[0] = 1` answers 1 -- so the explicit spelling goes through
  public_send instead of the setter rule.
- **Ripper's whitespace gaps are matched as bytes**, so a source with a
  BOM or invalid UTF-8 lexes (bom_test).

## 2026-11-08 (4): Pathname is ruby's own -- test/pathname 144 → 285, and what shipping it found

Note 511's stage 3, "pathname 143". Ruby 4.0 has Pathname in its core,
written in Ruby (pathname_builtin.rb, with `<=>` and `sub` as C primitives
that the file itself defines in Ruby when absent). mere-ruby shipped a
hand-written approximation: no `descend`, no `del_trailing_separator`, a
`cleanpath` of its own that took `/..` to `/..`, a `parent` of `.` that was
`.`. lib/pathname_ext.rb is now pathname_builtin.rb and lib/pathname.rb
(find, rmtree, mktmpdir) byte for byte, generated into m_pathname_lib.mere
(tools/gen_pathname_lib.rb) with lib/find_ext.rb and lib/fileutils_ext.rb
-- ruby's lib/find.rb and lib/fileutils.rb, which Pathname#find and
#rmtree require, and which `require "fileutils"` found nowhere before --
answered after the prism library. Each of
the interpreter's own faults it ran into is a line of corpus/505:

- **`Module#method_defined?(name, false)` counted Object's builtins**:
  `Pathname.method_defined?(:<=>, false)` was true, so the file's
  `unless method_defined?(:<=>, false)` never defined its Ruby `<=>` (nor
  `sub`), every Pathname compared nil and `sort` failed. With the
  ancestors left out, a builtin counts only when the class owns it (its
  own row, or a primitive the class answers): a user class says no.
- **`File.path(obj)` with neither #to_path nor #to_str** was a
  NoMethodError from asking #to_path anyway; ruby's TypeError "no implicit
  conversion of Object into String" (pathname rewords it).
- **`obj =~ re` on a plain object** answered nil; Object#=~ is gone since
  ruby 3.2 and `!~` already raised. NoMethodError, unless the class
  answers =~ or method_missing.
- **Proc#binding was a snapshot**: `blk.binding.local_variable_set` wrote
  into a copy, and so did `eval("$~ = m", blk.binding)` -- which is how
  pathname_builtin.rb hands the match to the caller's block in
  Pathname#sub. It is live now (bnd_live, as Kernel#binding's).
- **An eval under a binding ran under the CALLER's `$~` frame**, so even a
  live binding's `$~ =` landed in the method that called eval. The eval
  enters the binding's home frame (rx_home_fid of its env; frame 0 is the
  main program's) and leaves it as a call does, on a raise too.
- **A stat under a directory that cannot be searched** was ENOENT; EACCES
  (test_find under a chmod 0 directory).
- **Left (2)**: `File.singleton_class.prepend(mod)` does not override a
  builtin File.split (test_split), and test_realpath's own helper hits an
  ENOTDIR this parser's File.realpath does not reproduce standalone.
- **Checked**: corpus 514/514 both ways (505 under GC_STRESS=50 and with
  the hash index off), the gates, test/pathname 285/287, fileutils
  112/117 and find 18/19 (the same as before the stdlib files were
  shipped), and the unittest groups at their known counts.

## 2026-11-08 (5): StringIO and StringScanner as their tests ask -- stringio 77 → 99, strscan 135 → 149

Note 511's stage 3, "stringio" and "strscan". Both classes lived as
strings inside m_eval_leaf.mere; they are lib/stringio_ext.rb and
lib/strscan_ext.rb now, generated into m_pathname_lib.mere with pathname,
find and fileutils (tools/gen_pathname_lib.rb), and corpus/506 is the
witness. test/stringio 102: 77 → 99, the 3 left are the chilled-string
tests, gated on ObjectSpace.dump. test/strscan 149: 135 → 149.

- **`StringIO.new` and `StringIO.new(nil)` spell the same default**: the
  null device is only the explicit nil (a private mark is the default),
  reads nothing (`read` nil, `read(0)` ""), and `write` answers 0.
- **`dup` and `reopen(strio)` SHARE the struct behind the stream** -- the
  string, the position, the line number: a getc on either copy moves both
  (ruby's strio_copy). Only the open/closed flags are the object's own.
  The state is one object (`@st`) the copy points at.
- **A frozen StringIO**: `puts`, `string=` and `reopen` are FrozenError
  "can't modify frozen StringIO", before the mode is looked at.
- **A write that cannot be converted into the stream's encoding** was
  stored as its own bytes; ruby refuses it unless it is ASCII:
  Encoding::CompatibilityError "incompatible character encodings:
  Windows-31J and UTF-8". An ASCII-only buffer labelled US-ASCII still
  takes the first non-ASCII string's encoding.
- **A limit never splits a character in any encoding**: `gets(1)` on
  "a".encode("utf-16be") is the 2-byte "a" (the cut moves until the piece
  is valid, at most a character's bytes); it was UTF-8-only before.
- **`pread(0, offset, buf)`** is "" (or the buffer, untouched) before the
  offset is looked at: `pread(0, -10)` is not EINVAL. The EINVAL text is
  ruby's "pread: Invalid offset argument: -1".
- **The rest of the stringio round** (from the first pass): `string` is
  nil on the null device; "BOM|UTF-8" in set_encoding; a mode's spelling
  (`rbt`, `r+b`, `rb+` are fine, `x` and `rx` are "invalid access mode");
  `read(nil, buf)` keeps the buffer's encoding; `pread` past the end is
  EOFError; gets with a limit and a non-String separator is TypeError; the
  separator is encoded into a non-ASCII-compatible buffer's encoding; the
  byte search for a separator; paragraph mode counts "\r\n" as a blank
  line and chomps only when a separator was found; ungetc on the null
  device is nil and on a frozen buffer IOError "not modifiable string";
  `write` at MAX_LENGTH is "pos + len overflows"; a frozen buffer is "not
  opened for writing"; `read_nonblock(len, buf, exception:)`.
- **StringScanner** (lib/strscan_ext.rb, Version 3.1.6): the scanner
  re-measures when the string's bytesize changed under it (`__sync`);
  an uninitialized scanner (allocate) is ArgumentError "uninitialized
  StringScanner object" and inspects as "#<StringScanner (uninitialized)>";
  eos?/rest/rest_size/bol? read the live bytesize; an anchored regexp
  with a fixed encoding (`/./e`) keeps it; `[]` takes negative indexes
  and an unknown name is IndexError; getch/get_byte at the end are nil.
- **Checked**: corpus 515/515 both ways (506 under GC_STRESS=50), the
  gates, stringio 99/102, strscan 149/149, pathname 285/287, fileutils
  112/117, find 18/19, tmpdir 3/10, and the unittest groups at their
  known counts (syntax 168, parse 102, eval 39, object 65, method 97,
  module 192, class 60, string 439, io 244, regexp 161, require 51,
  marshal 230, struct 100, proc 117, m17n 126, symbol 59, const 5,
  autoload 27). Corpus 394 once lost ruby's own `[:outer, false]` line
  while the unittest batch loaded the machine: the REFERENCE side raced
  its SIGINT; alone, both print it.

## 2026-11-08 (6): tmpdir is ruby's own -- test_tmpdir 3 → 9, and the gate the last push broke

Note 511's stage 3, "tmpdir 7". Dir.mktmpdir was a string of this
interpreter's own in m_eval_leaf.mere (a standalone FileUtils fallback, no
candidate walk for Dir.tmpdir, a traversal in the prefix left as it was),
over a Dir.tmpdir primitive that answered $TMPDIR and nothing else.
lib/tmpdir_ext.rb is ruby 4.0.9's lib/tmpdir.rb byte for byte, generated
with pathname (tools/gen_pathname_lib.rb); its `def self.tmpdir` on Dir
replaces the primitive once required. corpus/507 is the witness.
test_tmpdir 10: 3 → 9; the one left is test_ractor (Dir.mktmpdir inside a
Ractor, held open across a port -- this Ractor runs the block through).

- **The gate the last push broke**: tools/tmpdir_fileutils_check.sh ran
  unittest/repro/tmpdir_fileutils_dependency_error.rb, which put a
  fileutils.rb that raises LoadError on the $LOAD_PATH and expected
  `require "tmpdir"` to surface it -- the rule for the OLD fallback ("only
  an absent FileUtils permits it"). With FileUtils shipped, a shipped
  feature is named from its name alone, over a file of the same name on
  the $LOAD_PATH (do_require's rule since the digest/sha2 round), so the
  repro's LoadError never fires and it has no subject. Retired; the other
  three repros (both load orders against the reference's FileUtils, and
  tmpdir with the $LOAD_PATH cleared) stand. ⚠ It was not run before the
  push: the "10 gates" are the nine tools/*_check.sh the LOOP.md rounds
  name PLUS this one, and ci.yml also runs unicode_normalize, psych_scalar
  and yaml_store. All thirteen pass now.
- **`File::Stat#world_writable?` / `#world_readable?`** answered the low
  twelve bits (01777 for /tmp); ruby answers the permission bits alone
  (0777 → 511).
- **`Etc.systmpdir`** was `$TMPDIR || "/tmp"`; ruby's is
  confstr(_CS_DARWIN_USER_TEMP_DIR) on macOS (what `getconf
  DARWIN_USER_TEMP_DIR` prints) and /tmp elsewhere. tmpdir.rb asks for
  $TMPDIR itself, in front of it.
- **Left**: test_ractor. And the errno under an UNSEARCHABLE directory
  (chmod 0) is wrong across File and Dir: ruby says EACCES for open,
  delete, chmod, rename, chown, readlink, utime, Dir.open (ours: ENOENT,
  ENOTDIR, or a nil from Dir.open), and a symlink loop is ELOOP for
  File.open/File.read (ours ENOENT), and lchown on a dangling link works
  (ours ENOENT). That is the 5 of fileutils and the 1 of test_find, next.

## 2026-11-08 (7): the errno for a path an operation could not reach -- EACCES under a chmod 0 directory, ELOOP for a loop, worked out once for every file operation

Note 511's stage 3, fileutils's 5 and test_find's 1. The file builtins hand
back no errno (m_state.mere's note at proc_last_errno: it is gone by the
time Mere can read it), so every file operation that failed reasoned about
the cause on its own, and all of them reasoned "not there" as ENOENT: open,
read, write, unlink, chmod, rename, chown, utime, readlink under a
directory that cannot be searched (chmod 0) were ENOENT where ruby says
EACCES; Dir.children/entries said ENOTDIR and Dir.open opened the
directory and listed nothing; a symbolic link that leads only to links was
ENOENT for open/read/chmod/utime where ruby says ELOOP; a create in a
directory that cannot be written died below the level that has a ruby
exception ("error (StandardError)"). corpus/508 is the witness (it skips
itself as root).

- **One classifier, fs_absent_name** (m_eval_leaf.mere, beside
  raise_sysopen): a trailing slash on a file or a prefix that is there and
  is not a directory is ENOTDIR; a link chain past forty is ELOOP
  (fs_sym_loop, through file_readlink); the nearest prefix that is there
  (by lstat too) and is a directory that cannot be searched (fs_access -x)
  is EACCES; else ENOENT. fs_absent_raise names ruby's C function
  ("apply2files", "rb_sysopen", "dir_initialize", ...), and
  raise_sysopen_absent keeps the path's encoding as raise_sysopen does.
- **Where it is asked**: file_open_obj's three "not there" arms, File.read,
  File.write (a parent that is there and cannot be written is EACCES, as
  is a create in one), File.delete, File.chmod, File.rename (the source
  that is not there names the error, else the destination), Dir.open
  (refused at the open when the directory cannot be read, as opendir
  refuses, not at the first entry) and dir_open_fail, and the prelude's
  chown, utime, readlink and File::Stat's miss (its ENOTDIR walk stays,
  the rest is File.__absent -- one owner).
- **lchown is the link itself** (chown -h): a dangling link is a path that
  is there. It was chown, which asked File.exist? and said ENOENT.
- **Checked**: corpus 518/518 both ways, 508 under GC_STRESS=50, the 13
  gates (name_len 3767), fileutils 112 → 117/117, find 18 → 19/19, and
  pathname 285, tmpdir 9, tempfile 37, dir 38, io 244, process 155,
  require 51, syntax 168, object 65, method 97 at their known counts
  (test_file / test_file_exhaustive are EXTRA on this machine: the
  reference needs its -test- extensions).

## 2026-11-08 (8): what test/optparse and test/cgi found -- a splat of an Enumerator, `===` and Method on a subclass of Hash, a singleton method on a dup'd IO, a block on an extended Array or a class method; cgi/escape is ruby's own

Note 511's stage 3, the two it had not measured. optparse here is ruby's
own lib/optparse.rb (the harness's RUBYLIB), so every one of its 30 red
tests was the interpreter's: 289 → 319/319. cgi/escape was a
hand-written CGI in m_eval_leaf.mere; it is ruby 4.0.9's lib/cgi/escape.rb
byte for byte now (lib/cgi_escape_ext.rb, through tools/gen_pathname_lib.rb;
its `require 'cgi/escape.so'` is a LoadError the file rescues itself), with
lib/cgi_ext.rb for `cgi` and `cgi/util` (the escape library plus ruby's
$VERBOSE warning): test_cgi_escape 435: 392 → 423. corpus/509 is the
witness.

- **A splat spread an Enumerator as [the Enumerator]**: `[*opt.each_line]`
  (optparse's separator lines) and `f(*enum)`. The splat asked only a
  user-defined to_a (has_meth) or a user respond_to?; it asks `responds`
  now, which sees the builtin to_a as well.
- **`H === H.new` was false for `class H < Hash`** (optparse's
  `CompletingHash === pattern`): case_eqq asked class_name, which is the
  builtin's name for a tagged value; dispatch_cls_of names the subclass.
- **`H.new.method(:conv)` for a module the subclass includes** had no owner
  (bm_owner_of looked at the subclass's OWN table, then the builtin's
  ancestors, never the subclass's ancestors) and its call re-dispatched by
  name on a Hash: NoMethodError. The subclass's ancestors come first.
- **An IO given a singleton method stopped answering its builtins**:
  `s = $stdout.dup; def s.tty?; true; end` left `s.respond_to?(:write)`
  false, and `$stdout = s` refused it (optparse's help pager). responds_x0
  asked builtin_obj_has of the singleton class's name; it asks the class
  under it too (sng_base_cls).
- **A singleton method on a String/Array/Hash called WITH a block** --
  `def ary.m; yield; end; ary.m { }`, or `ARGV.extend(Arguable);
  ARGV.options { }` -- fell through to the builtin iterators and was a
  NoMethodError (without a block it worked). The block dispatcher's
  primitive arm asks the value's singleton class first, as invoke_val_c0
  does.
- **A class method that takes no block, called with one** (`Encoding.list
  { }`, `String.name { }`) was a NoMethodError: the block dispatcher's
  class arm ended in prim_method, which knows no class. It ends in the
  plain dispatch, block in hand.
- **Left**: `(($stdout = x) rescue y)` -- a parenthesized assignment under
  a rescue modifier is rewritten as `$stdout = (x rescue y)`, so a refusal
  by the SETTER escapes (ruby rescues it; the parens are gone by the time
  apply_modifier looks); `a, b = *enum` (the multiple assignment's own
  spread does not ask to_a); cgi's 13: the regexp engine on UTF-16/32 and
  IBM037 strings (a regexp built from an interpolated UTF-16 string keeps
  US-ASCII; a `Regexp.new` of one matches nothing).
- **Checked**: corpus 519/519 both ways, 509 under GC_STRESS=50, the 13
  gates, optparse 319/319 (all 16 files), cgi 423/435, and the
  dispatch-sensitive groups at their known counts or above (syntax 168,
  parse 102, eval 39, object 65, method 97, module 192, class 60, proc
  117, lambda 27, enumerator 70, enum 89, array 459, hash 297, string 439,
  io 244, encoding 15, refinement 121, marshal 230, struct 100, require
  51, iterator 32, case 6, assignment 29, super 50, symbol 59, range 67,
  set 60, exception 94, variable 32). Corpus 436 caught the first cut of
  the singleton arm: it took a SUBCLASS tag for a singleton and ran the
  override a builtin's Method had asked to skip (bi_skip); the arm asks
  is_sng_cls and bi_skip_pass now.

## 2026-11-08 (9): test/date, first round -- Date moves to lib/date_ext.rb; names and printers are US-ASCII, a Date has no clock, Marshal in ruby's shape; a %w list indented with tabs; a 100,000-digit to_i

Note 511's stage 3, "date 103". test/date: 143 tests over 12 files,
45 → 71 (measured on both binaries). The Date library (1,100 lines of Ruby inside a Mere string in
m_eval_leaf.mere, grown in layers) is lib/date_ext.rb now, through
tools/gen_pathname_lib.rb with the rest; the first generation reproduced
the old literal byte for byte, and every change since is a Ruby edit.
corpus/510 is the witness. Two of the interpreter's own came out first:

- **A `%w` list broken across lines and indented with tabs held a word of
  tabs** (`%w(sunday? ... wednesday?\n\t\t\t\t thursday? ...)` in
  test_date_attr): the word reader ended a word at a space or a newline
  only. Any white space does (pw_ws), in %w, %i, %W and %I, and after a
  backslash.
- **`("1" + "0" * 100_000).to_i` never returned** -- test_date_parse's
  too-long-year test, which took the whole file down (27 red): the bignum
  path multiplied the growing decimal by ten per digit, quadratic. VBig is
  a decimal string, so a long run of base-10 digits is taken whole (a
  second for 100,000 digits).

The date side, cluster by cluster:

- MONTHNAMES / DAYNAMES and their abbreviations, to_s, inspect, strftime
  (when ASCII), zone, rfc3339/2822, httpdate are US-ASCII.
- A Date has no hour / min / sec / sec_fraction / zone / offset; those were
  on Date (so `Date#respond_to?(:hour)` was true) and are DateTime's. The
  Date printers read midnight at +00:00 through __hour/__minute/__second/
  __offset, which DateTime answers from its fields.
- Marshal: marshal_dump is [0, jd, df, sf, of, sg] (the UTC day, seconds
  into it, nanoseconds, offset seconds, the reform); marshal_load reads
  that and the 1.6 ([ajd, sg]) and 1.8 ([ajd, of, sg]) shapes, which
  Date._load (Marshal's `u` type) hands it; a frozen date refuses.
  initialize_copy takes any Date (a DateTime copied from a Date is that
  date's midnight) and refuses the rest with TypeError.
- DateTime.ordinal / .commercial with a time of day; a negative month
  counts back from December; Date.commercial's negative week and day
  counted back for validation but the jd was made from the negatives; a
  non-number anywhere (Date.new/jd/ordinal/commercial, julian_leap?,
  gregorian_leap?) is TypeError "expected numeric"; a Float with no
  fraction is its integer.
- The string parsers take `limit:` and refuse a longer string
  (ArgumentError "string length (N) exceeds the limit 128"): _parse,
  parse, _iso8601, _rfc3339, _xmlschema, and the new _rfc2822/_rfc822/
  _httpdate/_jisx0301 and rfc3339/xmlschema/httpdate/jisx0301 class
  methods (the limit, then the general parser).
- jisx0301 for Date and DateTime(n): the era letter from Meiji 6
  (1873-01-01), T/S/H/R at ruby's Julian Days, ISO 8601 before that.
- strftime: `%^P` and `%#P` are upper case; a width of 8192 or more, or a
  year of more than 2048 digits, is Errno::ERANGE as ruby's buffer makes
  it; DateTime#to_date is a Date (it answered self); a negative year
  prints as -0001.
- **Left (72)**: fractional seconds inside a DateTime's jd (sec_fraction
  through `+ Rational`, %L/%N from a parsed fraction), the offset in `%z`
  for a parsed DateTime, the calendar reform (Date::ITALY/ENGLAND periods,
  `civil__reform`, `different_alignments`), Date._parse and _strptime
  against ruby's date_parse.c (21 + 11), `<=>` across Date/DateTime and
  Infinity, deconstruct_keys with the clock, `===`, a DateSub subclass's
  identity, DateTime.now's sub-second, Date#to_time for a Julian date,
  test_date_compat's DateTime.
- **Checked**: corpus 523/523 both ways, 510 under GC_STRESS=50, the 13
  gates, test/date 71/143, and syntax 168, parse 102, literal 30, integer
  38, marshal 230, object 65, method 97, string 439, array 459 at their
  known counts; test_time.rb (which requires date) 22/42 on both the old
  and the new binary.

## 2026-11-08 (10): Date's readers and `time` are ruby's own -- test/date 71 → 111, test_time 22 → 42

Note 511's stage 3, date's second round. Date._parse and the format
readers are date_parse.c ported to Ruby (lib/date_parse_ext.rb), and
Date._strptime with date_core.c's frag completion (rt_rewrite_frags,
rt_complete_frags, d_new_by_frags) is date_strptime.c ported
(lib/date_strptime_ext.rb). Both were written against ruby 4.0.9 as the
oracle: tools/date_checks/check_parse.rb compares 37,079 calls (every call
test_date_parse.rb makes, every string literal in it through every reader,
and 31,620 generated inputs) and check_strptime.rb 18,363, with no
difference; replayed through the shipped Date under mere-ruby, the 36,954
parse cases with ruby's answers all agree. The generator wraps both in
`class Date` as private constants (Date::MereDateParse,
Date::MereDateStrptime) and drops their magic comments, which ruby warns
about in the middle of a file (assert_separately saw the warning).
Date.parse / strptime / iso8601 / rfc3339 / xmlschema / rfc2822 / httpdate
/ jisx0301, for Date and DateTime, go hash -> new_by_frags -> [jd, df, sf,
of] as date_core does. `require "time"` is ruby's lib/time.rb byte for
byte now (lib/time_ext.rb); it reads through those, and test_time went
22 → 42/42. corpus/511 is the witness.

- **DateTime.new dropped its calendar** (the 8th argument): the start a
  parsed DateTime was asked for was ITALY again. Passed through.
- **Integer() of a long decimal was quadratic**: 100,000 digits took 74
  seconds (a bignum multiply-and-add per digit). A plain run of decimal
  digits is the bignum's text, taken whole. String#to_i's fast path took
  the digits one character at a time into a growing string; one substring.
- **The parse port's digit scan and character-class test** went a
  character at a time (`s[j]` per character, a block call per byte):
  Date._parse of a 100,000-digit year took 2.6 s against the test's 3 s
  timeout. One search each; 0.06 s.
- **Left in test/date (32)**: the model -- fractions of a second and of a
  day carried by Date and DateTime (`Date.new + 1/2r`, jd(..., 3/8)), the
  calendar reform for civil/ordinal/commercial and to_time, new_offset,
  ===, <=> with Infinity and sub-millisecond, a subclass's identity
  through arithmetic, Marshal's 1.8 / 1.9.2 shapes with objects, memsize.
- **Checked**: corpus 524/524 both ways, 511 under GC_STRESS=50, the 13
  gates, test/date 111/143, test_time 42/42, ruby/test_time 87,
  test_time_tz 155, integer 38, float 63, rational 52, numeric 27, string
  439, literal 30, parse 102, syntax 168, marshal 230, json all green, and
  psych identical on the old and the new binary (86/538, its C side is
  stage 7′).

## 2026-11-08 (11): one Date model, date_core's -- test/date 111 → 143/143; strftime's width and a negative year, Marshal and a Numeric subclass

Date's third round. The layers of lib/date_ext.rb held four shapes of
object (a Date with a day and nothing else; a DateTime with its own clock
fields; DateTime.new ignoring its calendar; arithmetic rebuilding objects
by name). A last layer now gives both classes date_core's one model: the
local Julian Day, the seconds into it, the fraction of a second (a
Rational), the offset in seconds and the calendar reform, set through one
`__init`, with civil / ordinal / commercial / weeknum read on the reform's
calendar (the 1582 and 1752 gaps), the clock checks and fractions of
date_core's constructors, `+`/`-`/`>>`/`<<` keeping the class (a DateSub
stays one) and the fraction, `<=>` and `===` with Numeric and
Date::Infinity, new_offset, new_start/julian/gregorian, deconstruct_keys
with the clock, marshal_dump in ruby's shape. (It was drafted by a workflow
agent that hit its limit before reporting; its draft was rebuilt from its
transcript and finished here.) The parser layer of round (10) stays on
top: its [jd, df, sf, of] quadruple is built with `__init`. corpus/516 is
the witness. Three outside the library:

- **strftime's width and a negative number**: `%5Y` of -200 was -00200;
  an explicit width counts the sign (-0200), and a year's default width is
  its digits', so the sign is one more (%Y -0200, %_Y " -200"), while %C's
  is not (-2). Time's strftime is the same engine and had the same bug.
- **Marshal refused a Numeric subclass of the program's own** in an `o`
  record (Date::Infinity, in the 1.8 / 1.9.2 dumps of a Date): only the
  builtin numbers are refused now. The old shapes' ajd is UTC, which
  marshal_load had moved by the offset.
- **DateTime.parse with an offset past a day** drops it with ruby's
  verbose-mode warning ("invalid offset is ignored").
- **Checked**: corpus 531/531 both ways, 516 under GC_STRESS=50, the 13
  gates, test/date 143/143, test_time 42/42, ruby/test_time 87,
  test_time_tz 155, marshal 230, strftime of Date and Time against ruby
  over 20 directives on negative, small and five-digit years, psych
  identical on the old and the new binary.

## 2026-11-08 (12): what test/ruby/enc found -- a search in any encoding runs where the engine folds, ISO8859-N, the carriers' emoji

Note 511's stage 3, "ruby/enc 117". Measured first: 219 tests, 151 green
(case_comprehensive is stage 4's). corpus/518 is the witness.

- **The regexp engine folds case and reads properties in UTF-8 only.** A
  one-byte encoding's upper half had no case (`/^(\xC1)\1$/i` in ISO-8859-7
  against "\xE1\xC1" -- Greek alpha), ß did not meet "ss" there, a CJK
  encoding's full-width letters did not fold, `\p{Hiragana}` named nothing
  in Shift_JIS or EUC-JP, and UTF-16/32 could not be cut at all
  (cgi/escape's table on UTF-16). Such a search now runs on UTF-8: the
  subject and the pattern transcoded, the positions (match, groups, the
  attempt start) mapped back. Where: in rxv_search, by the cut the caller
  set, for an ASCII-compatible encoding under /i or with a property (a
  UTF-8 cut, nearly every search, is asked one comparison more); in
  rxv_search_e for UTF-16/32. The pattern is read as bytes with \xHH above
  127 standing for its byte, and cut by the encoding's own characters (a
  GBK or Shift_JIS character's second byte may be ASCII: `(\x81@)`); every
  other escape is itself. A subject that does not decode keeps the
  engine's own reading. The transcoded pattern's program answers the
  callers that read a pattern's group count by its key through an alias
  (rx_tc_alias, rx_ng_of) -- registering it under the original key made a
  later byte-mode search of the same pattern find it (ISO-8859-8's
  undefined \xFC).
- **The ISO8859-N alias** a magic comment may spell was not canonical: a
  regexp from `# encoding: iso8859-1` was "ISO8859-1" (Regexp#encoding
  answered that string) and met an ISO-8859-1 string as another encoding.
- **=~ in a one-byte encoding** answered the character position counted as
  UTF-8 ("x\xCE\xB1y" =~ /y/ in ISO-8859-7 was 2, ruby 3).
- **The carriers' emoji** (UTF8-/SJIS-DoCoMo, KDDI, SoftBank and
  ISO-2022-JP-KDDI) were names with no tables: UTF8-KDDI decoded byte by
  byte. They are their bases now (UTF-8, Windows-31J, ISO-2022-JP) with the
  carrier's codes over them, and String#encode passes each character
  through ruby's exchange table between the companies and Unicode
  (enc/trans/emoji-exchange-tbl.rb): mapped, undefined there
  (UndefinedConversionError in ruby's words, :undef => :replace, a
  fallback consulted by the encoder), or itself. The tables are
  m_emoji.mere, generated by tools/gen_emoji_tables.rb under ruby 4.0.9:
  the exchange read as data, the SJIS and ISO-2022-JP overlays measured
  (every two-byte code decoded both ways, every BMP character encoded both
  ways, the differences kept). ISO-2022-JP-KDDI's runs join as
  ISO-2022-JP's do.
- **The default replacement** is U+FFFD only into a Unicode encoding (UTF-8,
  UTF-16/32, CESU-8); UTF8-MAC and the carriers' UTF8-* take "?".
- **Left**: a non-ASCII pattern matched against an ASCII subject of another
  encoding should be read in the regexp's encoding (the core search knows
  only the subject's); and in ruby/enc: Integer#chr for an undefined but
  well-formed CJK code (Big5 0xA1A1, CP949, EUC-TW, GBK 0x8140), CESU-8's
  surrogate pairs (valid_encoding?, ord, left_adjust), UTF-16/32's newline
  and surrogate handling, `\p{Hiragana}` with `{0}` in EUC-JP, String#
  case options through pp, case_mapping's reorder_unfold.
- **Checked**: corpus 532/532 both ways, 518 under GC_STRESS=50, the 13
  gates; ruby/enc 151 → 197/219 (emoji 11 → 33, iso_8859 3 → 15, koi8,
  windows_1251/1252 all green), cgi/escape 423 → 427, and transcode 98,
  econv 84, encoding 15, io_m17n 159, m17n 126, m17n_comb 82, regexp 161,
  string 439, symbol 59, parse 102 at their counts.
- ⚠ **test_syntax's test_invalid_symbol_in_hash_memory_leak fails on main
  since PR #40** (bc76f79, "build disassembly with buffer"; #39 before it
  passes, bisected over five builds): #40 lowered startup RSS, the
  denominator of the test's 2x ratio, and the ~115 MB an eval of a syntax
  error grows by in the loop now crosses it (rss 99 MB -> 216 MB). The
  growth itself is older -- a stage 4 item, not this round's.

## 2026-11-08 (13): the rest of ruby/enc, cgi, erb, uri, monitor, did_you_mean -- a wide string's methods through UTF-8, nil's string is US-ASCII before it is interned

Note 511's stage 3: "ruby/enc", "cgi", "erb 4", "uri 3", "monitor 3",
"did_you_mean 3", "etc 5". corpus/524 and 525 are the witnesses.

- **A UTF-16/32 string's chomp, count, split, ord, casecmp(?) and
  gsub/sub/scan with a regexp** run on the string as UTF-8 and come back in
  its encoding: the arguments of the same encoding converted, a regexp in
  the string's encoding as its source in UTF-8, a replacement table's
  strings too (cgi's escapeHTML on UTF-16 gsubs with a Hash). A table key
  in another encoding never equals a match in this one, even when its
  bytes are ASCII, and is left out (corpus 518's ISO-8859-7 keys).
  gsub with a replacement of an incompatible encoding raises ruby's
  "incompatible character encodings", unless nothing matched or
  everything did. A string that does not decode keeps the engine's
  reading; ord on a broken first character is "invalid byte sequence".
- **A multibyte literal is one atom** in a regexp of its encoding:
  `/^あ+$/` in EUC-JP repeated the last byte (`"ああ" =~` was nil), and so
  `\p{Hiragana}+` could not match either. A property search on UTF-8
  reads characters as UTF-8 (uprop_enc stayed the subject's).
- **CESU-8** has its own shape (surrogate halves as two three-byte
  sequences, no four-byte UTF-8): valid_encoding?, length, ord. GB18030's
  chop finds the start of the last character from the left (Onigmo's
  state machine, gb18_left_adjust). Integer#chr in Big5, CP949, GBK,
  EUC-TW and their kin takes a well-formed code that is not in the table.
- **Encoding::Converter.asciicompat_encoding** answers the pairs it
  lacked: CESU-8 → UTF-8, CP50220/50221 → CP51932, ISO-2022-JP-KDDI →
  its stateless form, IBM037 → ISO-8859-1 (cgi's escapeHTML on a dummy
  encoding works in that one). Time#strftime refuses a UTF-16/32 format.
  The Cyrillic letters U+1C80..U+1C88 fold with their plain forms.
- **nil.to_s was interned as UTF-8 and relabelled US-ASCII after**: the
  canonical "" was then what a frozen "" literal's UTF-8 key found, and
  every `''.dup` in a frozen_string_literal file was US-ASCII once a nil
  had been interpolated anywhere -- uri's test_build failed only after
  test_find_proxy_no_proxy, where IPAddr builds "invalid address: #{@addr}"
  with @addr nil. PR #47 (9b7befb) made the same fix meanwhile and its
  version is kept; this round adds nil.inspect as a fresh string, as
  ruby's, and true/false's inspect interned as US-ASCII.
- **Marshal asked the dumped object's own equal?** (`obj.equal?(::ENV)`,
  `v.equal?(:__undef)`): erb's AlwaysEqual answered true and was dumped
  as ENV, then loaded as a bad link. The receivers are the known objects.
- **`def CONST.m` in a class body** with the constant holding an Array or a
  String defined on a "(sng:CONST)" nothing reaches (libexec/erb's
  `def ARGV.switch` inside `class ERB`): the constant's value is the
  receiver, as a local's is.
- **`include A::B::C` whose qualifier comes from const_missing** recorded
  the text (URI::REGEXP is RFC2396_REGEXP through URI.const_missing) and
  matched no module; such a name is evaluated as the constant expression
  it is. **`defined?(A::B::C)`** with A::B a const_set alias of another
  module asks the module A::B evaluates to (URI::PATTERN::ESCAPED).
- **A method named `lambda` (or `proc`) on self** is that method:
  did_you_mean's HumanTypo has `attr_accessor :lambda` and `(lambda / 2)`
  raised "tried to create Proc object without a block".
- **private_methods** lists Kernel's private instance methods and
  BasicObject's (kernel_private_fill): did_you_mean offers `raise` for
  `raiae` called privately. Struct's "no member" NameError carries the
  name and the receiver.
- **Monitor** belongs to a fiber, as ruby's since 3.0 (another fiber's
  try_enter is false); a timed wait that runs out is false; the mixin's
  initialize forwards with `(...)`, so a parent's keyword initialize gets
  its keywords.
- **Etc**: a uid or gid is a uid_t -- nobody's -2 in /etc/passwd is
  4294967294, and getpwuid(-2) finds it.
- **Left**: cgi's two NativeExt tests ask for the C extension; etc's three
  Ractor tests (an unsafe call raising in a Ractor, a parallel run);
  Tempfile's eight (next round: an anonymous file needs a descriptor that
  outlives its name, and mere-ruby's File is a path and a buffer).
- **Checked**: corpus 536/536 both ways, 524 and 525 under GC_STRESS=50,
  the 13 gates; 123 unittest files (6018 tests) against the same set under
  be480af's binary: MATCH 5898 → 5944, no file lower. ruby/enc 194 →
  216/219 (every test ruby passes; the three left fail in ruby too),
  cgi/escape 427 → 433/435, erb 76 → 80/80 and erb_command 0 → 2/2,
  uri/common 14 → 16, uri/generic 25 → 26, did_you_mean 3 → 0 red,
  monitor 11 → 14/14, etc 11 → 13. test_array's one flip is
  test_shared_marking, a five-second GC test that the REFERENCE failed in
  one run and passed in the other (mere-ruby skips it both times).

## 2026-11-08 (14): Tempfile is ruby's own -- test_tempfile 37 → 45/45; a File's clone, a lone splat's to_a

Note 511's stage 3, "tempfile 8". corpus/526 is the witness.

- **Tempfile was mere-ruby's own** (140 lines in m_eval_leaf.mere): unlink
  and close! left the path set, Tempfile.open's #open did not answer the
  reopened File, and an anonymous file could not be made. It is ruby
  4.0.9's lib/tempfile.rb now, byte for byte (lib/tempfile_ext.rb through
  tools/gen_pathname_lib.rb, as Pathname and tmpdir are), DelegateClass(File)
  and all; every test but the anonymous two passed with it as it is.
- **An anonymous file** (`Tempfile.create(anonymous: true)`) is ruby's
  create-and-unlink: a descriptor that outlives its name. mere-ruby's File
  is a path and a buffer, and a file unlinked under it cannot be read back
  (File#fileno reopens the path). One method is redefined after ruby's
  file, marked as mere-ruby's: the file keeps its generated name until it
  is closed (or the process exits) and answers its path as ruby's does,
  the directory's (`File.join(tmpdir, "")`).
- **File#clone shared the original's state**: closing a clone closed the
  original (IO's clone is initialize_copy, a dup of the descriptor, as
  dup is). It is File#dup's copy, with the modules the File was extended
  with and its frozen state.
- **`a, b = *x` with a lone splat** asked only a user-defined to_a: an
  Enumerator, a Hash, a Range bound themselves to `a`. A builtin that
  answers to_a splats into its elements (a String does not answer it).
- **Checked**: corpus 543/543 both ways, 526 under GC_STRESS=50, the 13
  gates; 136 unittest files (7033 tests, the wide set plus IO, File, Dir,
  ARGF, process and require) against dcbdbf0's binary: test_tempfile
  37 → 45, no file lower (test_dir's test_symlink failed once while both
  runs shared the machine and passes alone, twice); the assignment-heavy
  files (assignment, array, hash, enumerator, range, syntax, struct, call,
  iterator, yield, proc, lazy enumerator, io) at their counts.
- **Left** (interpreter): `(($stdout = x) rescue y)` -- the parentheses
  vanish before the rescue modifier sees the assignment, so the rescue
  wraps the value and the setter's TypeError escapes; `x = a = *b` should
  be a SyntaxError ("multiple assignment is not allowed in this context").

## 2026-11-09 (15): a Fiber scheduler answers for a non-blocking fiber's waits, I/O, names and children -- test/fiber 59 → 95/95

Note 511's stage 3, "fiber scheduler ~77" (first measured: 95 tests, 59
green). corpus/527 is the witness.

- **Waits.** A Mutex, Queue/SizedQueue, ConditionVariable or Thread#join
  that blocks a non-blocking fiber of a thread with a Fiber scheduler is
  the scheduler's `#block(blocker, timeout)`, and the waker calls its
  `#unblock(blocker, fiber)` (ruby's sync_wakeup). One primitive does it:
  `blk_wait` puts the fiber in the object's line (`fsw_tbl`, a GC root,
  "kind:obj" → [seq, fiber, scheduler, blocker]) and calls #block; the
  wakers (`fsw_wake_one` / `fsw_wake_all`) unblock fibers in line before
  waking threads. The thread path (`sch_block`) is unchanged. A raise into
  the waiting fiber (Fiber#raise from another) leaves the line on its way
  out -- the entry left behind was #unblock'ed on a closed scheduler at the
  next unlock. Mutex#sleep in such a fiber is `#kernel_sleep(timeout)` and
  takes the lock back even when something was raised into the sleep
  (ruby's ensure), so a condition wait's synchronize can unlock. A blocking
  fiber facing a mutex another fiber of its thread holds is still ruby's
  deadlock error.
- **Thread#join** ends for fiber joiners while the thread ends
  (`sch_ending`: done to the join, live to the scheduler) -- the joiners
  are #unblock'ed from the ending thread, which may sleep in #unblock
  (test_thread_join_hang); an #unblock that raises is the thread's
  exception, which its join raises (test_broken_unblock).
- **An autoload** loaded by such a fiber is that fiber's
  (`al_me`): the thread's other fibers wait for the load through the
  scheduler instead of reading the constant half made (test_autoload's
  file sleeps). autoload_settle wakes fibers and threads.
- **sleep** is #kernel_sleep and answers the whole seconds slept, whatever
  the hook returns. **getaddrinfo** asks `#address_resolve` for a name
  (not a number, not with AI_NUMERICHOST): each address it gives is looked
  up as a number, nil or none left is EAI_NONAME (IPSocket.getaddress,
  Addrinfo.tcp and getnameinfo go the same way). **Process.wait** (and so
  system) asks `#process_wait`, whose answer must be a Process::Status
  (rb_waitpid's TypeError). A forked child starts with no scheduler.
  set_scheduler warns when #fiber_interrupt is missing (ruby 4.0).
- **I/O.** A File's flush hands its bytes to `#io_write` and its read asks
  `#io_read` (File#__sched_write / #__sched_read; the hook's own writes
  through the File land where the bytes belong, @__f_hook); a descriptor
  stream's fill and flush do the same, and EAGAIN asks `#io_wait`, raising
  the hook's errno when it says no. IO::Buffer#read/#write take LENGTH as
  the least to move (0 is one call up to the rest of the buffer), read and
  write a descriptor stream's descriptor itself (past its read-ahead,
  -errno on failure, -EAGAIN from a non-blocking one with nothing ready),
  and go to the scheduler's hooks; #pread / #pwrite are new.
- **Fiber#backtrace / #backtrace_locations**: the current fiber's is the
  running code's ('Fiber#backtrace' on top, as Thread's), a finished
  fiber's [], another's [] (its suspended stack is not read).
- **Checked**: corpus 545/545 both ways, 527 under GC_STRESS=50, the 13
  gates; 162 unittest files (7413 tests: the wide set, IO and its
  neighbours, test/fiber, socket, monitor, thread_queue, autoload,
  io_buffer) against 67b7e08's binary: MATCH 6948 → 6988, test/fiber
  59 → 95/95, ruby/test_io_buffer 47 → 52, no file lower (pathname's
  test_lutime compared two clock readings while both runs shared the
  machine; alone it passes, twice).
- **Next in stage 3**: socket (58 red: tcp_server_sockets, getifaddrs,
  recvmsg/sendmsg, a chosen local port, send with a destination, the
  Happy Eyeballs timing tests, memory-leak tests too slow here),
  io/console 27, net/http 3 (+ https 19, openssl: stage 7), resolv 1,
  io/wait 1.

## 2026-11-09 (16): socket is a Ruby file now -- datagrams with recvmsg/sendmsg, a bound datagram socket keeps its port, ruby's Socket.tcp -- test/socket 147 → 194/209

Note 511's stage 3, "socket ~84" (first measured: 209 tests, 147 green).
corpus/528 is the witness.

- **The socket library moves to lib/socket_ext.rb** (2,250 lines that were
  a Mere string in m_eval_leaf.mere), shipped through
  tools/gen_pathname_lib.rb like Pathname and Tempfile. Its one
  interpolation -- the platform's constant table -- is a primitive now,
  Socket.__consts_text (m_unicode.mere's sock_consts). The move alone
  changed no result.
- **Datagrams.** One helper takes one datagram (`__dgram_take`: the
  runtime's recvfrom, MSG_DONTWAIT when non-blocking, one byte more than
  asked for so a longer datagram is seen -- macOS's recvfrom answers what
  it copied), and recvmsg / recvmsg_nonblock (MSG_TRUNC; macOS's
  MSG_DONTWAIT back in the flags), recvfrom_nonblock (UDPSocket's array,
  Socket's Addrinfo), recv_nonblock on a datagram socket and Socket#recvfrom
  stand on it. sendmsg / sendmsg_nonblock are send (ancillary data is
  NotImplementedError: the runtime has no sendmsg). Socket#send to an
  address sends to it (it was EDESTADDRREQ).
- **A BOUND datagram socket that connects keeps its descriptor**: the
  runtime's connect makes a new socket, so the port the peer was told
  about went away and test/socket's udp_pair never received anything. The
  peer is remembered instead (send without an address, getpeername,
  peeraddr use it); an unbound socket takes the runtime's connected one as
  before. A stream Socket connected already answers EISCONN (0 without
  exceptions) -- a second connect_nonblock made a second connection.
- **Ruby's own code, as it is**: Socket.tcp with Happy Eyeballs v2
  (tcp_with_fast_fallback, the resolution threads and stores; every
  hostname-resolution test passes), tcp_server_sockets, udp_server_*,
  ip_sockets_port0, UDPSource; Socket.tcp_fast_fallback(=) as socket.c
  keeps it.
- **Smaller ones**: a NUL in a host, a service or a UNIX path is ruby's
  ArgumentError; getnameinfo takes an Addrinfo; UDPSocket#bind / #connect
  read the host with #to_str and check the socket after (IOError when the
  conversion closed it, as getsockopt and listen do now); EMSGSIZE names
  the host and port; BasicSocket.for_fd(-1) is EBADF; Socket.pair /
  UNIXSocket.pair with a block yield and close; getpeereid from
  LOCAL_PEERCRED (SO_PEERCRED on Linux) and the xucred's inspect;
  Socket::Option.ipv4_multicast_loop / _ttl; getifaddrs is ruby's
  NotImplementedError (the runtime gives addresses, not interfaces).
- **UNIXSocket.pair / Socket.pair IGNORED THEIR BLOCK**, so every test
  written as `UNIXSocket.pair { |i, o| ... }` passed without running a line
  -- test/fiber's test_io_close among them. Running, they showed that a
  stream closed under a waiter did not interrupt it: a fiber waiting in its
  scheduler's io_wait is now interrupted through #fiber_interrupt with the
  IOError (the stream keeps who waits on it), and a thread parked waiting
  for readiness raises "stream closed in another thread".
- **Left** (the runtime): file descriptors over SCM_RIGHTS and
  SO_TIMESTAMP (sendmsg/recvmsg with ancillary data), connecting from a
  chosen local port (connect(2) on an existing descriptor), getifaddrs;
  the memory-leak tests (a child doing 100,000 binds) time out here.
- **Checked**: corpus 549/549 both ways, 528 under GC_STRESS=50, the 13
  gates; 182 unittest files (7733 tests: the wide set with net, resolv,
  io/wait and open-uri) against 96dac90's binary: MATCH 7285 → 7334,
  test/socket 147 → 194/209, no file lower (test_array's shared_marking
  and test_thread's priority are the reference's flakes, as before).

## 2026-11-09 (17): what net/http, resolv, zlib and io/wait found -- Array and Hash keys holding user-hashed objects, an alias of Class#new, `raise exc, msg`, a deflate stream's tail, a FIFO with O_NONBLOCK

Note 511's stage 3, "net/http 3, resolv 1, io/wait 1". corpus/530 is the
witness.

- **An Array (or Hash) key holding objects with their own #hash and #eql?
  was never found again**: Hash asked only whether the Array itself had a
  user #hash and otherwise compared structure -- identity, for an object.
  resolv's DNS name compression keys its table by arrays of Label::Str,
  so every name was written out in full (test_caa_roundtrip). Such a key
  now takes the hash protocol (`elems_user_hash`), its #eql? is the
  builtin's, which asks the elements', and Hash#hash sums its pairs' #hash
  answers when any of them has its own (it was structural, so two #eql?
  hashes hashed apart).
- **`class << HTTP; alias newobj new; end` and then `def HTTP.new`**: the
  alias of the builtin reached the later definition (net/http's newobj
  read ENV's proxy). A class-level alias of `new` whose class now defines
  `new` is Class#new itself: allocate, then #initialize.
- **`raise exc, msg` on the lightweight exception pair kept the old
  message** (make_exc): net/http's "Failed to open TCP connection to
  host:port (...)" around a SocketError lost its text. The copy carries the
  new message, as exc.exception(msg) does.
- **Zlib::Inflate**: the bytes after the end of a deflate stream are not
  output and not counted in total_in (zstream_run stops at Z_STREAM_END) --
  net/http's body read "hello\r\n" for "hello"; data fed after the end is
  kept in the buffer and not answered by that call; the stream's lock is a
  Mutex, so another thread waits and an inflate from inside its own block
  is the mutex's ThreadError ("deadlock; recursive locking").
- **A FIFO opened with an Integer mode holding O_NONBLOCK** does not wait:
  the reading end opens at once (read-write first, as __fifo_open_r does,
  since the runtime's open takes no flags), the writing end is ENXIO until
  a reader here has it open (`File.__fifo_has_reader`), and each is a File
  over its descriptor (test/io/wait's test_fifo_wait).
- **Left**: io/console's 27 need a pty, termios on any descriptor and the
  window size ioctl -- with socket's ancillary data, a connect on an
  existing descriptor and getifaddrs, a round of runtime builtins in Mere.
- corpus/527's order line was the clock's (two fibers waking from 10 ms
  sleeps; ruby itself answered both orders): the mutex's exclusion is
  printed as the fact, the rest sorted.
- **Checked**: corpus 551/551 both ways, 530 under GC_STRESS=50, the 13
  gates; 184 unittest files (7847 tests: the wide set with zlib) against
  d4b5233's binary: MATCH 7402 → 7408 (net/http 116 → 119/119, resolv
  green, io/wait 7/8 with the eighth failing in ruby too, zlib 53 → 54),
  no file lower.

## 2026-11-09 (18): the top-level test files -- Forwardable, Shellwords and Singleton are ruby's own, a builtin put back with define_singleton_method -- test/*.rb 381 → 435/478

Note 511's stage 3, "test直下 116" (measured now: 22 files, 478 tests, 381
green). corpus/532 is the witness.

- **Forwardable, Shellwords and Singleton were mere-ruby's own** (smaller
  versions in m_eval_leaf.mere): ruby's lib/forwardable.rb, shellwords.rb
  and singleton.rb are shipped now, byte for byte, through
  tools/gen_pathname_lib.rb (lib/*_ext.rb). test_forwardable 18 → 27/27,
  test_shellwords 5 → 11/11, test_singleton 11 → 13/13. Two interpreter
  holes came with singleton.rb: undef_method of Module's private hooks
  (`extend_object`, `append_features`, ...) on a singleton class was a
  NameError, in both the statement and the method (`sng_module_hook`); and
  extending with a module whose singleton undefined extend_object is
  ruby's NoMethodError (its call of the hook).
- **`define_singleton_method(:name, original)`** where original is a Method
  of a builtin taken before the name was overridden: the override stayed
  ahead (the Method is looked up by owner and name, which was now the
  override's). A builtin Method (@__m_bi) puts the builtin back: the
  override is removed. test_timeout's mocked Fiber.current_scheduler
  stayed installed, and every later reader thread asked the mock for
  io_wait: 0 → 35/35.
- **A Hash literal with keys of their own #hash** collapses by that
  protocol, as `h[k] = v` does (test_ipaddr's test_hash: eight IPAddrs,
  five distinct).
- **A class's alias of a builtin ahead of an included module's method**
  (`class Hash; include TSort; alias tsort_each_node each_key`): an
  explicit call reaches the alias now (`alias_first`); the implicit-self
  call and `method(:name)` still reach the module's -- TSort's 3 are left.
- SecureRandom has ruby's gen_random / gen_random_urandom /
  gen_random_openssl; RbConfig::MAKEFILE_CONFIG keeps rubylibdir and
  rubyarchdir unexpanded, as configure writes them.
- **Left**: test_pty 15 (a pty: the runtime round), test_pp 5 (pp of a
  recursive Struct, iv hiding, the AST node), test_trick 5 (the TRICK
  entries' syntax), open3's pipeline (Process::Waiter#join), test_tsort 3,
  weakref 2 (a recycled reference), rbconfig's sitelibdir, extlibs 2
  (coverage, pty), delegate 1 (Exception#== asking #exception), tmpdir's
  Ractor.
- **Checked**: corpus 552/552 both ways, 532 under GC_STRESS=50, the 13
  gates; 201 unittest files (8174 tests: the wide set with the top-level
  files) against 8341bb4's binary: MATCH 7673 → 7730, no file lower
  (test_dir's test_symlink failed on the baseline's side, under load, as
  before).

## 2026-11-09 (19): the rest of the top-level files -- a builtin iterator gets no frame block, a class's builtin alias ahead of a module's method, WeakMap is weak, the TRICK entries' syntax -- test/*.rb 435 → 458/478

The rest of note 511's "test直下" after (18). corpus/533 is the witness.

- **A builtin iterator was handed the frame's block** as the block its own
  block ran under: `def f(ws) = ws.each(&:join); f([w]) { 1 }` called
  `join` with f's block (open3's pipeline waited on that), and
  `[1].map { |x, &b| b }` answered the frame's block where ruby says nil.
  A user `yield` already passed no block there; the 24 builtin sites now
  do the same (`blk_noblk`). yield and block_given? inside the block body
  read the environment, not that argument. test_open3 25 → 30/31.
- **A class's alias of a builtin ahead of a module's method**, the half
  (18) left: `method(:name)` owns it by the class that made the alias
  (`alias_owner`), and Method#call and the implicit-self call reach it by
  name (`alias_first`). test_tsort 5 → 8/8.
- **ObjectSpace::WeakMap is weak.** It was a Hash, so nothing it held was
  ever collected and WeakRef#weakref_alive? was always true. The entries
  live in the interpreter (`weak_k` / `weak_v` by entry number, found by
  map id and key identity), which the collector does not mark: after
  marking, `gc_weak_prune` drops an entry whose map, key or value was not
  reached (the gc roots gate lists the two maps with that reason).
  WeakKeyMap is no longer a WeakMap subclass -- ruby's superclass is
  Object -- and keeps its Hash. test_weakref 3 → 5/5 (its 150,000-WeakRef
  leak test runs inside the 60 s now).
- **pp** (31 → 35/36): pp keeps the objects it is printing in
  `Thread.current[:__recursive_key__][:inspect]`, the table ruby's own
  #inspect consults, so an #inspect a pretty_print calls stops at them --
  Array, Hash, Struct and plain objects read it once a program has
  written that key (`insp_pp_held`). A singleton
  #instance_variables_to_inspect wins over the Kernel default on a bare
  call. Struct's own #members / #size / #to_a bound to a struct answer
  from its member table, even when a member of that name replaced the
  method (`Struct.new(:members, :class)`), and the Struct prelude reads
  the names through `Struct.__members_of` for the same reason (no slower:
  one dispatch, as the bare call was).
- **TRICK** (17 → 22/22): a backslash at the end of a line inside a
  double-quoted string is a continuation (it kept the newline -- 02-mame's
  quine came out a different program); braces inside a %-literal in an
  interpolation are text (`find_close_brace` skips `%@..@`, `%q(..)`;
  `interp_close` now delegates to it); after `..` a local followed by ` -1`
  is the subtraction (`lvt_prev_local` took the range's dot for a call's);
  `x ||= v` as an expression declares x as the statement does; `[a] *
  2000.0` truncates the count; a bare `select` with no arguments is
  Kernel's ArgumentError where self is no Enumerable.
- **Exception#==** follows exc_equal: an object of another class is asked
  for its #exception, which must be of the receiver's class (a
  SimpleDelegator equals the exception from both sides). The duplicate,
  unreachable copy of the arm is gone. test_delegate 36 → 37/37.
- RbConfig::MAKEFILE_CONFIG names sitedir / sitelibdir under site_ruby,
  as configure writes them. test_rbconfig 4 → 6/6.
- **Left** (none of them this stage's): test_pty 15 and extlibs' pty (a
  pty: the runtime round); open3's capture3_flip -- the child mere-ruby's
  write to a full non-blocking pipe raises EAGAIN where ruby waits, which
  is Mere's print (the runtime round); extlibs' coverage and pp's
  RubyVM::AbstractSyntaxTree (stage 10); tmpdir's Ractor.
- **Checked**: corpus 557/557 both ways, 533 under GC_STRESS=50, the 13
  gates; 207 unittest files (8470 tests) against 8341bb4's binary: MATCH
  7942 → 8017. Two files read one lower and are the load's: test_method's
  kwarg_eval_memory_leak (an RSS ratio, 1.24 against 1.2; the baseline
  failed it the same way when run again) and test_pathname's EXTRA 1 (its
  reference side).

## 2026-11-09 (20): bootstraptest and tool/test -- a require lock, a /o site built once, a binding's block, yield's scope, STDIN's output, EAGAIN on an inherited descriptor

Note 511's stage 3 "bootstrap 173 / tool/test 5". The numbers are CI's at
8341bb4 (bootstrap-report, tool-report); of bootstrap's red, test_ractor's
63 are stage 9, test_insns' 1 stage 10 and test_yjit's 21 stage 11, which
left 33 here. Measured locally through ruby's own runner
(bootstraptest/runner.rb, tool/test/runner.rb) as the CI jobs run them.
corpus/536 is the witness.

- **bootstraptest 33 → 0** (every file but test_ractor and test_insns
  passes whole):
  - **the require lock**: a second thread requiring a file another thread
    is still loading found it marked and went on before anything was
    defined. It waits until that load ends (`req_wait_other`, over the
    req_loading / req_loading_thr the loader already kept) in short timed
    sleeps -- so it reads as stopped, which test_require's race_exception
    waits for (a Thread.pass loop hung the whole file) -- and then asks
    again: a load that raised was taken back out, and the waiter loads it.
  - **`yield` and its scope**: one in a class, module or singleton-class
    body is refused wherever that body is, a def included
    (`class_yield_stmts`); a file's top-level yield is refused when the
    file is parsed (`yield_refuse_file`; it was a LocalJumpError at run
    time); in an eval, a top-level yield is refused only outside a method,
    so `binding.eval("yield")` of a method's binding is the method's. A
    method's `binding` keeps the block the method was given (`bind_yblk`,
    marked with the binding) and Binding#eval yields to it.
  - **a proc in a class body** returns from the method or lambda the
    `class` statement ran in: the body's env does not continue the
    enclosing chain, so the statement hands its frame over through a
    one-shot slot (`cls_home_note` / `cls_home_take`, `__ret_home`).
  - **STDIN's print / puts / printf / putc** went to standard output; they
    are IO's now, through its #write (refused while it reads, the
    reopened stream once IO#reopen made it writable).
  - **the at-exit flush** of a writer nobody closed waited for ever on a
    pipe whose reader had gone with the threads (test_io's ten
    copy_stream-under-SIGINT runs timed out): at exit a write that would
    block ends the flush.
  - **a `/.../o` site** runs its pieces once: the cache is consulted before
    the interpolation, and a thread arriving while another builds the site
    waits for it and takes its result (`rx_once_gate` / `rx_once_eval`).
  - **the main thread's locals** were lost once a second thread existed:
    Thread.current did not boot the main fiber's root mark, so the slot
    changed (`fb_tl_base` boots it).
  - eval's refusals in ruby's words: a flow word in a rescue body (`eval
    "0 rescue break"`), a range's end (`0..$1=1`), `{*0}`, two splats in
    one target group (`v0,(*,v1,) = 0`), an invalid byte ahead of an
    unterminated string, and an empty file name given to eval names the
    message `:0:` as ruby's does; `def m() :m end` inside a block or
    parens (`paren_closes_def_params` reads the words before the `(`);
    `__FILE__` carries the file's frozen_string_literal comment, and
    `load` now reads that comment at all (only require did).
- **tool/test 5 → 1**: test/unit's parallel worker read its stdin -- a
  pipe the parent made non-blocking -- and EAGAIN raised: the descriptor
  layer waited only on descriptors it had made non-blocking itself, and an
  EAGAIN can only come from a non-blocking one, so it is a wait now
  (read and write). Regexp#=~ reads an object through #to_str (minitest's
  assert_match), and refuses one without it. Left: test_commit_email,
  which needs nkf -- a C extension, stage 7'.
- **Checked**: corpus 561/561 both ways (492 needs a UTF-8 locale on the
  reference side: after a reboot the shell had none and ruby's ENV strings
  came back BINARY, the baseline binary differing the same way), 536 under
  GC_STRESS=50, the 13 gates; 247 unittest files (10361 tests: ruby/,
  json, the top level and the libraries of the last rounds) against
  f3ef3b7's binary, MATCH 9716 → 9716 + the files above. Two files read
  lower: test_method (kwarg_eval_memory_leak, an RSS ratio both binaries
  fail alike when run again) and test_require, 51 → 0 -- the Thread.pass
  wait above, which hung the file -- and 51 again with the timed wait.

## 2026-11-09 (21): the spec record measured again against 4.0.9's own spec tree; Kernel, BasicObject and Module; eval's frames; csv loads -- spec DIFF 133 → 104, the stdlib record's CRASH 48 → 6

Note 533 is the re-plan of what stage 3 still has; this is its round 1.
corpus/546 is the witness.

- **The record is 4.0.9's now.** SPEC_STATUS.md and SPEC_STATUS_STDLIB.md
  were measured (2026-10-26) against ruby master's spec tree
  (`84a27934cf53`). The reference is 4.0.9, so 4.0.9's own tree is the
  subject (its file counts differ, which the guard refuses:
  `SPEC_TOTALS_OK=1`, deliberately, once). Re-measured before any change:
  DIFF 133 + 32, CRASH 4 + 48.
- **The shim's method matchers asked a different question.** mspec's
  `have_private_instance_method(m, inc)` is
  `private_instance_methods(inc).include?(m)`; the shim asked
  `private_method_defined?(m)` and dropped `inc`. ruby itself failed
  core/kernel/syscall_spec under it. The eight matchers ask the lists now.
- **csv did not load** (42 of the stdlib record's CRASHes): forwardable --
  ruby's file since (18) -- generates `def pos=(...)`, and a setter's
  `(...)` was not read as one.
- **BasicObject** had no row of builtins: its `*_method_defined?` were
  false about what its method lists named (`bo_defines`, the reference's
  owner table); BasicObject::BasicObject is a constant; a class with no
  Object above it does not see the top level (`const_defined?`,
  `defined?`); `remove_method :method_missing` on it is accepted; a
  singleton class is `instance_of?(Class)`.
- **Kernel's functions on Kernel and on a module**: `Kernel.block_given?`,
  `.__dir__`, `.system` are the bare call in the caller's frame (they were
  sent to main); `mod.send(:puts, x)` / `self.send(:block_given?)` in a
  module method reach Kernel's function (`kernel_by_name`, as an object's
  do) unless the class has its own class method of the name, up its
  superclasses; a bare `fail` is a bare `raise`; under -n/-p chomp, chop,
  sub and gsub are module functions.
- **A class's own builtin precedes an ancestor's method**:
  `Module.public_method_defined?(:include)` found the shim's private
  top-level `def include` on Object first (`anc_past`).
- **eval draws its frames**: the eval method's ('Kernel#eval',
  'Binding#eval', 'Kernel.eval') at the call, and the code's above it,
  labelled like the frame it runs in, or the binding's (`eval_framed`,
  `bind_lbl`). The code ran IN the caller's frame, so `caller` lost the call
  and warn's uplevel counted from the wrong frame. ⚠ The first version
  made test_method's kwarg_eval_memory_leak fail every time (RSS ×1.6
  against ×1.2): the eval method's frame runs no statement, so its
  statement watermark kept what an earlier frame at that depth had left,
  and the collector rooted everything built since. A frame's interval
  starts at its entry now, as a block's does for a builtin caller.
- Smaller: Module#constants lists a prepended module's; a frozen class
  refuses define_method from a class_eval block; `define_method(:m) { |a,|
  }` takes one argument; a singleton's builtin alias is in its methods
  lists; `%c`, eval's file and line answer ruby's conversion refusals
  ("can't convert X to String (X#to_str gives Y)"); main's private_methods
  has its own six; ARGFClass, Enumerable__Impl and IO::POPEN_IO_KEYS are
  private constants (they were the program's).
- **Left** in these groups: object_id of two equal Bignums (a Bignum is a
  value here), IO#reopen replacing a singleton class, open-uri and
  RubyGems under the shipped record, a C extension that fails to load
  (stage 7'), `load(f, true)` with `using`, define_method of an
  UnboundMethod with a nested def. Found on the way: `MF.open(path)` for a
  File subclass is a TypeError (pre-existing).

## 2026-11-09 (22): language, command_line, proc, method, exception -- super in a builtin iterator's block, a proc's &param from `&pr`, a vcall's method_missing super, a proc's return at a loaded file's top level, class in a method body

Round 2 of note 533. corpus/555 is the witness.

- **`super()` inside a block a builtin iterator runs** (`1.times { super() }`,
  `[1].map { super }`, `tap { super }`) lost the method's block: since (19)
  such a block gets no frame block, and only a body that YIELDS carries the
  method's (blk_capture asks bare_yield_stmts). A super that passes the block
  on asks the same question now -- for the capture only, not as a yield for
  the syntax check (yscan_defined).
- **A proc's `&b` is the proc passed with `&`**: `->(x, &b) { b }.(1, &l)`
  answered a copy, so `.equal?(l)` was false (language/lambda_spec's two
  `evaluate` blocks). The Proc call notes the source proc (amp_src_note) for
  the binding that follows, as a method's `&b` already took it
  (pending_srcproc).
- ⚠ **`pending_srcproc` outlived its call**: `{}.each(&pr)` never runs a
  block, so nothing cleared it, and a later `Proc.new { :lit }` answered pr.
  EMethodB with a literal block clears it, as ECallB's arm did.
- **A method_missing reached by a bare name** (a vcall -- it could have been a
  local) raises NameError "undefined local variable or method" from its
  `super`; it was NoMethodError (test_exception's
  method_missing_reason_clear, Bug #10969). try_self_call marks the call,
  the door into method_missing takes the mark (mm_reason_take, mm_priv 2).
- **A proc's return at a loaded file's top level** (`proc { return }.call`
  in a file `load`ed or `require`d) has no method to leave and ends the file;
  it unwound past the load and ended the whole program silently
  (language/return_spec counted one assertion fewer and nothing failed).
  top_return_taken, in rb_load and do_require.
- **`class`/`module` in a method body is a SyntaxError** ("unexpected class
  definition in method body"), a block or lambda in one included; `class <<
  obj` may stand there and its body is no method body. It was accepted.
- **`class expr::Name` with a method call for expr** (`class
  singleton_class::A`) opens the class under the call's value
  (class_scoped_by, as the keyword forms did); it was the constant
  "singleton_class::A". `nil`, `true`, `false` and `self` keep their path.
- **Method equality and a class's methods**: `c.method(:new) ==
  Class.instance_method(:new).bind(c)` -- a class's builtin that is an
  instance method of Class/Module is owned there (builtin_frame_label, as
  #owner says); a singleton's alias of a builtin (`class << self;
  alias_method :n, :new`) is that builtin -- respond_to?, #method and #== now
  see it; a singleton that only made a builtin private holds no body.
  `String.method(:include)` is Module's builtin ahead of the shim's private
  top-level `def include` on Object (#owner and #inspect).
- Smaller: Proc#=== takes a block by send; Proc#inspect is BINARY like #to_s;
  `$/ =` (and `$-0`) keeps a new frozen String, or the String itself when it
  already is one with no ivars (4.0); `-r` libraries do not run for a script
  that is not there.
- **Left**, each with its reason: `break` in a Thread body raises
  LocalJumpError AT the break in ruby -- here the break leaves the block as a
  value, and whether a loop between catches it is a static fact the
  evaluator does not keep; a heredoc's interpolation reports the statement's
  line (lines are statement-level, SLine); binding.local_variables lists a
  local assigned AFTER the call in ruby (the parse-time local table --
  methods and blocks would need their body at hand); `proc { |_:, _: 2| }`
  reads a block's keyword default by bare name (the defaults are decoded
  from the body's prologue); `$:` starts empty -- RbConfig's directories
  come from GEM_HOME and may be a real ruby's, whose files `require` would
  then load (-I/RUBYLIB "at the front" and predefined's $: examples);
  `defined?(Gem)` (RubyGems is not shipped); `import_methods Zlib` refuses
  C methods in ruby and Zlib is Ruby here; $0 does not set the process title
  (Mere runtime); test_exception's errinfo_encoding_in_debug (an EUC-JP
  class name in $DEBUG's line). `File.readlines` is 3 ms a call here
  (region blocks zeroed per statement list, Mere's allocator), which
  test_blocking_backtrace's 10000 raises feel.

## 2026-11-09 (23): the I/O family -- IO::Buffer's values, copies and slices (test_io_buffer 52 → 78/80), a program's own class methods of File, Dir.send(:open) with a block, realpath's EACCES, a chilled string in StringIO

Round 3 of note 533. corpus/556 is the witness.

- **IO::Buffer had no value API past get_value**: set_value, get_values,
  set_values, values, each_byte, copy and size_of were missing, and so were
  the 128-bit types (pack has no directive for them: read and written
  byte by byte) and NETWORK_ENDIAN. A value converts BEFORE the write -- its
  #to_int may free what a slice looks into, and the write then finds the
  slice invalid, as ruby's does. ruby's words for the range refusals ("Type
  extends beyond end of buffer! (offset=N > size=M)", the offset shown as
  C's size_t). The prelude's methods are written as Ruby and escaped into
  the string by a script, which is the safe way to grow a class this size
  in m_driver.
- **A slice is a SLICE** (ruby 4.0): neither EXTERNAL nor INTERNAL. It was
  EXTERNAL, and a resize of the MAPPED buffer under it moved the memory and
  left the slice valid (a generation, `__gen`, now says it was cut from
  memory that moved). A slice resized is a buffer of its own; one whose
  source is gone is InvalidatedError. `dup` is a writable INTERNAL copy
  (`IO::Buffer.for(s).dup.and!(mask)` was "not writable"); a transferred
  `for` buffer writes into its string until the string is frozen; the
  hexdump's hex column is 47 wide; clear takes a byte (`clear(260)` is 4)
  and refuses what is not an Integer; get_string converts its encoding
  first (its #to_str may free the buffer); for, string and map refuse
  what is not theirs; map flushes what was written to the file first.
- **A program's own class method of File, IO or FileTest comes before the
  builtin**: `class << File; def dirname` and a module prepended to File's
  singleton (pathname's test_split) were never asked -- the builtin arms
  answered first. Only a definition the program wrote (sng_user_owner): the
  prelude's are the builtins, and a module INCLUDED in the singleton comes
  after the builtin, as in ruby.
- **`Dir.send(:open, d) { |dir| }` yielded a File**: send with a block on a
  class receiver asked the class for INSTANCE methods and found
  Kernel#open. A class's methods are its singleton's.
- realpath through a directory that cannot be searched is EACCES (the walk
  asks fs_absent_name why a name is not there); pathname 285 → 287/287.
- **A chilled literal in StringIO**: ObjectSpace.dump says `"chilled":true`
  (without it test_stringio's three chilled-string tests were never defined
  -- ABSENT, 99 → 102/102), and StringIO#set_encoding leaves a chilled
  string's encoding alone (String#__chilled?), as strio_set_encoding does.
- Smaller: the standard streams answer #to_i; `lineno = nil` is NUM2INT's
  "from nil to integer"; IO.try_convert says "to IO"; Dir.glob and Dir[]
  refuse a keyword they do not take (kw_stray_refuse, warn's rule made
  general); StringIO.open with nothing is over "".
- **The shim's MockObject** answered #to_s and #inspect as
  `#<MockObject name>`; mspec's defines neither, so they are Object's (with
  the address). io/puts_spec and stringio/puts_spec read
  `object.inspect.split(" ")[0]` and failed on BOTH sides.
- **Left**: File.new(fd) answers the IO (a File here is a path, not a
  descriptor); File#size and #stat of a file deleted while open need
  fstat(2) on its descriptor (Mere has stat by path only -- the runtime
  round); IO#reopen(io) does not turn a File into an IO; test_io_buffer's
  test_shared (a MAP_SHARED mapping a forked child writes into -- the
  runtime round) and test_bug_21210 (GC.compact, stage 9); test_tmpdir's
  test_ractor (stage 9); `def` in File's singleton then `remove_method`
  leaves no method in ruby (the C method was replaced in the same table),
  and the builtin here. A warning raised inside a shipped library that is
  a C extension in ruby (StringIO's `<<` on a chilled string) names the
  library's line, where ruby names the caller's.

## 2026-11-09 (24): thread, fiber, tracepoint -- a thread killed from a rescue or ensure clause, TracePoint#parameters in a :b_call hook, the "(X#m gives Y)" refusals, the main script's directory after Dir.chdir

Round 4 of note 533, verified with round 3 (one cycle). corpus/557 is the
witness.

- **`rescue; Thread.exit` killed the PROGRAM** ("exception re-raised past all
  rescues"; core/thread/kill_spec and terminate_spec CRASHed). The kill is
  the scheduler's park signal, a pair (`__ThreadPark`), and raised while $!
  was set it was given a cause -- exc_with_cause made it an object, and no
  runner knew that object: it went on as the thread's exception, up past
  every rescue. The park signal takes no cause.
- **TracePoint#parameters in a :b_call hook was always []**: the HOOK's own
  block runs through run_block_tp too, which set the block being traced and
  then REMOVED it before the hook's body ran -- so `tp.parameters` in the
  hook found nothing. It is put back as it was.
- **`trace.enable(target: proc)` for none of a block's events** (`:call`) is
  "can not enable any hooks".
- **The main script's `__dir__` and `require_relative` after `Dir.chdir`**:
  a script run by a relative path (`ruby subdir/x.rb`) has its directory
  read against where the program STARTED (cwd0) -- it was read against the
  current directory, so after `Dir.chdir __dir__` the sibling was looked for
  in subdir/subdir. Three places read PWD for it: `__dir__`'s parse-time
  form, `__builtin_relpath` (the parser's require_relative) and do_require.
- "can't convert X to Y (X#m gives Z)": seven refusals said "into" -- ruby
  says "into" only for its other two forms ("no implicit conversion of X
  into Y", "can't convert nil into Float"). Fiber#raise with nothing is a
  RuntimeError with no message (Thread#raise's), not "unhandled exception".
- **Left**: `block (N levels)` counts the envs a block's frame sits under,
  not its lexical nesting -- a thread's block under the shim's describe/it
  is 6 levels where ruby says 4, and a thread inside a lambda inside a block
  one short (report_on_exception_spec's order example); `break` in a thread
  body (round 2); handle_interrupt_spec and list_spec differ only in the
  reference's own tallies (ruby fails two handle_interrupt examples here; a
  timing count); native_thread_id is nil for a green thread (the spec
  allows it); core/signal/trap_spec's EPIPE from a child's write (the
  runtime round, with print's EAGAIN).

## 2026-11-09 (25): numbers and strings -- a number's === asks an object, Rational#quo and Complex#quo through #coerce, "%#o" with a precision, ObjectSpace.dump's fstring; an eval's synthetic file name

Round 5 of note 533, verified with rounds 3 and 4 (one cycle). corpus/558 is
the witness (and 557 for the last two points below).

- **`1 === obj` is `obj == 1`** (num_equal): `==` asked the object and `===`
  -- which IS `==` for a number -- did not, so `case obj when 7` never
  matched an object that says it equals 7 (core/integer and core/float
  case_compare). case_eqq takes the reverse question for every number.
- **Rational#quo is Rational#/**: through #coerce the pair is asked `/` (it
  was asked quo, which the coerced object need not have). Complex#quo and
  #/ with an object that coerces but is no Numeric reached the plain
  division and answered ZeroDivisionError or 2 (cpx_obj_applies takes it
  now; the pair is asked #quo, `(2/1)`).
- **`"%#.8o" % 1` is "00000001"**: the precision's leading zero is the one
  `#` asks for; another was put in front (test_sprintf_comb, 3).
- Integer, Bignum and Float #inspect are US-ASCII, as their #to_s is.
- ObjectSpace.dump says `"fstring":true` for the interned copy of a text
  (String#__fstring?: the intern table names this very string) --
  test_string's test_uplus_minus.
- **A relative file name is the main script's or an eval's**: round 4 read
  every relative name against where the program started, and an
  `instance_eval(src, "foo.rb")`'s require_relative is read against where
  it is NOW (require_relative_spec). rel_file_base tells the main script
  (load_ctx "script0") from the rest; a synthetic name has no
  absolute_path. A TracePoint target that is no Method, UnboundMethod or
  Proc is "specified target is not supported".
- **Left**: a Regexp is a value here -- no ivars (Marshal of one with
  ivars), no #extend (Marshal.load of an extended one); `Time.dup` is a
  class without Time's builtin class methods (`c.now`); Enumerable#map
  hands #each its own block, arity -2, where ruby passes the user's (arity
  2); Lazy#grep's $~; Enumerator.new(size) { }; Complex#fdiv through
  #coerce; `b.local_variable_set(:self, x)` -- the env keeps the receiver
  under that key, so the local replaced self (test_literal's
  hash_value_omission); core/time/new's timezone protocol;
  locale_charmap from LC_ALL; numeric/step_spec is over the CPU budget.

## 2026-11-10 (26): the small core items and the libraries -- object keys in the hash index, the timezone protocol's #local_to_utc, Numeric#step's edges, Array#== under the cycle guard, a clone's define_method closures, `x&.m(&pr)`, Kernel.load from a class with its own #load

Rounds 8 and 9 of note 537, verified in one cycle. corpus/559 is the
witness.

- **A plain object key is its identity in the hash index.** hkey_digest
  answered "" for every object, so a hash keyed by objects was never
  indexed and every store scanned: 20,000 inserts took 48 s (0.08 s now;
  ruby 0.004). An object with a #hash of its own (or a Time, a MatchData)
  still answers "" and goes the protocol way -- main.mere answers through
  a forward hook (hkey_obj_ident_fwd), where the method tables are.
- **Time.new with a zone object**: a Time that #local_to_utc answers is its
  INSTANT (ruby's extract_time), not the wall clock #utc_to_local's answer
  is read as -- `+09:00` came back as offset 0; an offset of a day or more
  is "utc_offset out of range"; a zone with no #local_to_utc is read as an
  offset and refused (TypeError) where it fell back to #utc_to_local; and a
  `{}` in the zone's place is a zone, not keywords (only a keyword hash is
  stripped).
- **Numeric#step**: `1.0.step` walks without end; from an infinity toward
  the same infinity it yields nothing (ruby's count is NaN), and from an
  infinite begin toward a finite end it yields the begin until the block
  breaks; `42.step(Float::INFINITY, 1)` stays an Integer walk (num_step's
  `inf`); a step that is no number makes a plain Enumerator, not an
  ArithmeticSequence; `1.step(5, 1, to: 5)` is "to is given twice"; a
  Float receiver's `by: "1"` is compared with 0. core/numeric/step was SLOW
  (`Float::INFINITY.step(Float::INFINITY, 1)` never ended) and MATCHes.
- **Array#== under the cycle guard** with an element that answers #==
  itself: two arrays that each hold themselves recursed forever
  (core/array/equal_value was SLOW). cmp_cycle_guard is rb_eq's eq_seen.
- **#clone keeps what a singleton method was written in**: the copy took
  the method bodies and none of the side tables keyed by them (copy_meth_src
  -- a define_method body's closure, its block, its source), so every
  OpenStruct accessor on a frozen clone read `name` as a method call and
  answered nil (library/openstruct/frozen).
- **`x&.m(&pr)` passes pr** -- the block-pass marker ran as a literal
  block, so the block never ran. resolv's Hosts#each_address is exactly
  that (`@name2addr[name]&.each(&proc)`), and every /etc/hosts lookup was
  empty (resolv's 4 files).
- **`Kernel.load(f)` inside a class that defines #load** called itself
  forever: the module function was answered as a bare call in the caller's
  frame, where self's own method comes first. With such a method the call
  runs with Kernel as self in a child frame (both the `Kernel.x` shortcut
  and the by-name door). irb's IRB::Locale#load is this; Binding#irb is
  ruby's prelude method now, and irb gets as far as Reline, which needs
  IO#winsize -- the runtime round.
- A CLASS receiver's protected singleton method is not respond_to?
  (weakref delegated to it). Hash#merge keeps the receiver's subclass;
  update / merge! / replace refuse a frozen receiver before #to_hash.
  String#=== asks an object with #to_str; String#to_str of a subclass is a
  String; an invalid Emacs-Mule byte encodes as "?". A program's own class
  method of a core class (Time.now, Process.pid, Math.sqrt, ...) is asked
  before the builtin (round 4's File/IO/FileTest rule, for every core class
  with a singleton: name_set "core_sng_cls"). Encoding.locale_charmap
  reads LC_ALL, LC_CTYPE, LANG. A C extension that IS there fails as ruby's
  dlopen does -- a LoadError with no #path -- not as a missing file.
- Libraries: cgi's escapeURIComponent(nil) is TypeError; logger is ruby's
  own (the logger gem 1.7.0, lib/logger_ext.rb) in place of a smaller one
  of ours (psych's `!ruby/exception` came with #72's vendored psych, which
  replaced the edit made here); WeakKeyMap keeps [key, value]
  pairs (and the LATER of two equal keys, as ruby does).
- Cost: is_kernel_builtin built a 70-name list and walked it with str_eq on
  every call, and is_a? walked the ancestors each time; a table and a memo
  on the class generation. Object.new 3.7 → 3.3 us (ruby 75 ns), and
  WeakKeyMap's Bug #20691 test 18.9 → 14.5 s, still over its 10 s: the rest
  is per-call dispatch, a performance arc of its own.
- **The shim**: mspec's `eql` matcher was missing -- 112 spec files use it,
  and those examples died on BOTH sides, measuring nothing. Measured, they
  found three: Rational#to_i floored (`Rational(-7, 4).to_i` was -2);
  Float#divmod floored a quotient flodivmod ROUNDS (`(x - fmod) / y` lands
  a hair under the whole number, `0.59.divmod(7.761021455128987e-11)` was
  one short); Numeric#eql? on a program's own Numeric was identity, where
  ruby asks #==. Also in the shim: a mock whose
  #method_missing is mocked answers respond_to? for that name (mspec's
  keeps Object's, and rb_check_funcall forwards); a stub keeps the
  singleton's own method and puts it back. ⚠ The MockObject #to_s /
  #inspect change (23) describes was LOST from 8fc6b70: a `git checkout` of
  the shim, used to undo a trace, took it back out. It is in now.
- **Left**: `Time.dup` and IO#reopen's new singleton class (round 11);
  Enumerator.new's block local and $LOADED_FEATURES' matching of relative,
  non-canonical and C-extension names (require_spec, 24 -- round 10);
  RubyGems (`-rrubygems`, Gem.bin_path) and open-uri, whose uri is not
  shipped -- no stdlib is; irb (IO#winsize) and test_blocking_backtrace
  (File.readlines' 3 ms) are the runtime round.
- **Checked**: spec DIFF 65 → **53** (SLOW 2 → 0, CRASH 2; 65 is the
  record after #72's psych), the stdlib record's DIFF 32 → **26** (CRASH 6).
  corpus 574/574 both ways after the rebase onto #72, 559 and #72's 550
  under GC_STRESS=50, the 13 gates; 247 unittest files against round 5's
  binary, MATCH 9755 → 9754 -- the one is test_kwarg_eval_memory_leak, an
  RSS ratio round 5's binary fails as well when run again; the numeric,
  hash, time, array and range files again with the final binary,
  unchanged; psych's 635 (#72) 635.

## 2026-11-10 (27): the interpreter's structure and the stream's class -- the block #each is given, a block's own locals, block labels as written, `break` in a Thread body, $LOADED_FEATURES as ruby matches it, $: with ruby's shape, pp shipped

Rounds 10 and 11 of note 537, verified in one cycle. corpus/560 is the
witness.

- **Enumerable#map gives #each a block of the user block's arity** (ruby's
  enum_collect, rb_lambda_call): an #each that asks `block.arity` saw -2 for
  every block. Proc.__ifunc makes that proc (its arity in proc_arity, no
  lambda), and Hash#each yields such a proc the key and the value APART when
  its fewest arguments are two or more (rb_block_pair_yield_optimizable for an
  ifunc). Hash#map, which is native here, does the same for a block that takes
  two -- a lambda too: `{1 => 2}.map(&obj.method(:two))` and
  `.map(&->(k, v) { })` refused the pair.
- **A name a block assigns is the block's own when the enclosing scope does
  not have it yet.** `e = Enumerator.new { |y| r = y.yield 3 }; r = []`: the
  block wrote the outer r when #each ran it later. parse_block lists the
  names a block's own statements assign as `;<chr 2>name` (only for a block
  with parameters -- an empty list is what lets `it` and `_1` in), and the
  block literal keeps as `;name` each one the enclosing env does not hold
  when it is made (blk_own_locals: ECallB / EMethodB / ESafeB / ESuperB).
  Shallow (top-level statements) and decided at capture, AFTER the receiver
  and the arguments (`(s << m = 58).lines { m += n }` -- trick2013's mame --
  assigns m before the block): a miss is the old behaviour. A `;` entry is no
  parameter anywhere a parameter list is read as one -- Proc#ruby2_keywords'
  check (delegate.rb's delegating lambda warned), and define_method with a
  proc or a lambda (`define_method(:x, lambda { |*a| t = 1 })` took only one
  argument). define_method's method takes no `;` entries as parameters --
  `define_method(:g) { |x; z| }` was arity 2 before any of this.
- **A second `_`-name is a parameter of its own** (`|_, _ = 1, _:, _: 2|`,
  `-> _, _, _ = 1 {}`): named apart as it is read (bp_under_name), so its
  default and its `:` no longer land on the first -- parameters said
  [:opt, :_] three times and [:key, :_] twice.
- **A def inside a proc that define_method installed goes where the proc was
  written**: the frame's parent is that scope (`__in_dm`), and its self names
  the class.
- **main.using in a wrapped load**: the wrapped self (Module#__wrap_main's copy
  of main, marked @__wmain) is main to `using`, so `load(f, true)` with a
  top-level `using` works and the method / module-body forms are main.using's
  RuntimeError (main_like).
- **Block labels count the blocks as written** -- `block (6 levels)` for a
  block four deep once the blocks around it had been passed on as `&b` and
  run by instance_exec (mspec's describe/it). A level is a frame a block
  invocation made (run_block's `__bki`) or a define_method body's, not every
  env with a parent; END { } keeps its extra level by marking its own.
- **`break` in a Thread body is LocalJumpError where it is** (the body's own
  rescue sees it): run_block marks a Thread body's frame `__thrbody`, and a
  while loop in it counts itself (`__wd`) so a `break` there is the loop's.
- **Thread#raise(e)** with a rescued pair: the pair's backtrace lives beside
  the thread that rescued it, so it goes over as an object carrying it, and
  Exception#== takes a pair of the class as one (class, message, backtrace).
- **`K.raise { }`** for a class with its own `def self.raise`: the Kernel#raise
  arms asked the class's INSTANCE methods (recv_defines).
- **Lazy**: #with_object (lazy_super), and grep's `$~` is the `$~` of the code
  walking the lazy -- the collector block's home was the top level, so inside
  a method the match went to the top level's `$~`.
- **TracePoint#enable(target_line:)**: an Integer through #to_int, and a line
  in the target's range ("can not enable any hooks").
- **Location#absolute_path** is the loaded file's realpath as it was at load
  (file_rp): a symlink's target, even once the link is removed.
- **A byte that is no UTF-8 in a UTF-8 source** is "invalid multibyte
  character 0xFF" (a UTF-16 file with a BOM), not a bare syntax error.
- **$LOADED_FEATURES as ruby matches it** (rb_feature_p): an entry that IS
  the name asked for (`./f.rb`, `../f.rb`, `code/../code/f.rb`, a `code/f`
  with no extension -- while no .rb of it is found); a bare name whose entry
  is `<dir>/<name>.rb` with dir on $: now, through its symlinks
  (lf_under_load_path), even when an earlier dir has the file; a .so/.bundle
  entry does not stand for a .rb that is found (req_rb_found); an unreadable
  file is LoadError. require_spec 32 → 0 (the rest of its DIFF is the count
  of ruby's encdb/transdb entries, which have no file here).
- **$: has ruby's shape**: after -I and RUBYLIB, the versioned site, vendor
  and library directories with their arch directories, named under the
  stdlib fiction RbConfig tells (/usr/lib/ruby/4.0.0) -- never under a
  GEM_HOME the prefix may come from, and not the bare site_ruby/vendor_ruby a
  Linux host's own ruby fills. None of them exists to find anything in.
  RbConfig's sitelibdir was the prefix itself; it and sitedir, sitearchdir,
  vendordir, vendorlibdir, vendorarchdir, archdir have ruby's layout.
  `$LOAD_PATH.resolve_feature_path` is $:'s singleton method (`def
  $LOAD_PATH.m` looked the global up without its alias, and defined a bare
  method), answering a shipped library under the fiction and as the
  extension ruby's is (cext_feature).
- **pp and prettyprint are shipped** (ruby's own files, lib/pp_ext.rb and
  lib/prettyprint_ext.rb): `require "pp"` was a LoadError.
- **Round 11**: `File.new(fd)` / `File.open(fd)` is a File (the descriptor
  layer answers File as it answers IO, fdio_cls); IO#reopen(io) takes the
  other's mode and class (IO.__reclass, rb_io_reopen's RBASIC_SET_CLASS) --
  and does so for a stream with a singleton method too: fdio_route read the
  singleton class as the class (`def io.to_io` sent #reopen to the standard
  streams', which kept the old mode: "not opened for reading"). RbConfig's
  MAKEFILE_CONFIG names sitearchdir, vendordir, vendorlibdir, vendorarchdir
  and archdir as configure does ($(sitearch)).
- An Errno's message holding a binary path is BINARY (`e.message.include?
  (path)` raised Encoding::CompatibilityError).
- **Left** (with the reason): binding.local_variables' later locals of a
  block with no parameters (the parser has no table that `it` cannot be
  confused by); an interpolation's line in a heredoc (no expression-level line
  mark that is set before the expression); TracePoint's thread_begin inspect
  (a new Thread runs before Thread.new returns here); import_methods refusing a
  C extension's methods (a shipped C extension is Ruby here, and nothing marks
  it as the extension it stands for); a Hash with a singleton #each under
  #map (native); Module#constants, gc/stat, symbol/all_symbols,
  thread/list ... are counts of the reference's own; Gem and DidYouMean (not
  shipped). Round 11's values: a Regexp, an Integer past a word and a File
  of a path are values (or a handle) here, with no identity of their own to
  hold instance variables, a singleton module, an object_id, or a FRESH
  singleton class after #reopen; a File of a path cannot become an IO; a copy
  of Time (`Time.dup`) is not answered by Time's arms, which ask is_a?(Time),
  and answering them through is_a? would make the copy's instances Times.
  `$0`'s process title, File#size / File.stat on a deleted open
  file (fstat by fd) and SIGPIPE's SYSTEM_DEFAULT are the runtime round.
- **Checked**: corpus 575/575 with the hash index on and off; the 13 gates;
  corpus/560 under MERE_RUBY_GC_STRESS=50 and with no hash index; the 247
  unittest files 9754 = 9754 against round 9's binary (test_method +1;
  test_thread -1, which is 97 for both binaries on a rerun -- a flake;
  test_trick's mame and test_rbconfig, which the first run of this round
  broke, are whole again); the spec records, swept again on main with #74's
  OpenSSL under this: base DIFF 53 -> 31 (SLOW 0, CRASH 2 -> 1; x509 name /
  store and scrypt's CRASH are #74's), stdlib DIFF 26 (CRASH 6) unchanged.
  library/etc/getgrgid was DIFF in both sweeps and MATCH alone each time (the
  load flake of (26)), and is recorded as MATCH. After the rebase: corpus
  582/582 both ways and the gates again.

## 2026-11-10 (28): the runtime round -- a pty and a terminal's settings, a child with a controlling terminal, fstat, a peer's ids, descriptors over a socket, connect(2) on a socket that exists, the interface list, a stdout its parent made non-blocking, the title

Round 12 of note 537: what needed the runtime, which Mere v0.1.724
(merelang/mere#64) and v0.1.725 (#65, sendmsg's destination) now have as
general host calls -- the structs kept in the runtime and crossing as text,
as sock_getopt does -- and memu 7564b42 answers fstat on RISC-V. corpus/561
is the witness. mere >= 0.1.725.

- **PTY** (lib/pty_ext.rb, over pty_open): PTY.open is [master IO, slave
  File], the slave 0600 as pty.c's no_mesg leaves it, both closed after a
  block; PTY.spawn / getpty run the command with the slave by path as 0, 1 and
  2 in a NEW SESSION whose controlling terminal it is (Process.spawn's
  internal __pty_session: proc_spawn's group -2), [read File, write File,
  pid], the child detached after a block; PTY.check (nil while it runs, the
  status, ChildExited with raise). The master is closed in the child (holding
  it there, the slave never hangs up and `cat` never ends -- ruby's master is
  close-on-exec), and both ends are non-blocking as IO.pipe's are, so a read
  that would block waits in the readiness loop and other threads run.
  test_pty 0 -> 15/15.
- **The controlling terminal was the runtime's to give, and posix_spawn
  cannot**: Darwin applies the file actions BEFORE POSIX_SPAWN_SETSID, so the
  slave was opened by a process that led no session yet, and the child had a
  session and no terminal (/dev/tty ENXIO). Mere's group -2 forks, calls
  setsid, applies the actions and TIOCSCTTY, then execs (pty.c's order). The
  first probe passed anyway: its child was a shell, which takes a terminal on
  its own. The probe's child is stty reading /dev/tty now.
- **io/console** (lib/io_console_ext.rb, over tty_attrs / tty_set_attrs /
  tty_winsize / tty_set_winsize / tty_flush, the termios bits the platform's):
  raw / raw! (console.c's set_rawmode: cfmakeraw less ECHOE|ECHOK, min / time
  / intr), cooked / cooked!, echo= / echo? / noecho, getch (a character in the
  stream's buffer first, IO.select's wait otherwise), getpass, winsize /
  winsize= (2 or 4), iflush / oflush / ioflush, cursor (the "\e[6n" report)
  and the cursor movements, beep, IO.console (/dev/tty, kept, :close, a
  Symbol sent to it). io/console/size (ruby's own file). Under intr: the
  terminal's interrupt key is SIGINT, which this interpreter catches only when
  trapped, so for the block ruby's default handler is the trap (Interrupt,
  message ""), unless the program set one. IO.console's descriptor is
  non-blocking too: a blocking read held the signal off. io/console 3 ->
  27/27 (the 24 that need PTY ran for the first time).
- **expect** (ruby's own expect.rb). library/expect CRASH -> MATCH.
- **fstat** (file_fstat): File#size and File#stat ask the descriptor. A File
  here is a path and a buffer whose descriptor is opened when asked
  (file_fd_of), so deleting a path first gives the Files open on it their
  descriptor (file_open_paths, file_hold_open) -- after the delete there is no
  name to open. core/file/size and stat DIFF -> MATCH.
- **Sockets**: getpeereid over sock_peer_ids, and no getpeereid on an
  IPSocket (ruby undefines it); sendmsg / recvmsg with control messages
  (sock_sendmsg / sock_recvmsg): SCM_RIGHTS descriptors become IOs with
  scm_rights: true and are closed without it (rsock_discard_cmsg_resource),
  UNIXSocket#send_io / recv_io (klass, mode, nil for the number); a stream's
  recvmsg names an empty-sockaddr sender (AF_UNSPEC) and is nil at the end;
  a UDP recvmsg carries SO_TIMESTAMP, and AncillaryData#timestamp and its
  inspect name the level, the type, the descriptors and the time.
  connect(2) on the socket that exists (sock_connect): UDPSocket#connect kept
  its family no longer (udp_open made an IPv6 socket for an AF_INET one),
  Socket#connect waits under the IO's timeout (IO::TimeoutError),
  connect_nonblock is EINPROGRESS / EISCONN as rsock_connect_nonblock says
  them, and a socket bound to a port first connects from it (Addrinfo
  #connect_from / connect_to were NotImplementedError). Socket.getifaddrs
  (sock_ifaddrs) and Socket::Ifaddr; a scoped address is named by its
  interface (fe80::1%lo0). sendmsg to an address with control data (a UDP
  server's IP_PKTINFO reply: test_socket's test_udp_server, which getifaddrs'
  NotImplementedError used to omit). BasicSocket.for_fd asks SO_TYPE; Socket.pair's
  unknown family / type is SocketError; Socket.gethostbyname /
  gethostbyaddr (deprecated, warned under Warning[:deprecated]).
- **A stdout its parent made non-blocking** (ruby's IO.pipe makes both ends
  so; a child of Open3.capture3 inherits them): Mere's print_no_nl /
  print_err now wait on EAGAIN, and STDERR.print here (err_raw) writes all of
  a string with the same wait (fd_put_wait). test_open3's capture3_flip.
- **SIGPIPE**: Signal.trap('PIPE', 'SYSTEM_DEFAULT') is the OS's action, and
  IO.pipe no longer puts the do-nothing handler back over a trap the program
  set; PIPE's DEFAULT is ignore again. core/signal/trap.
- **$0**: Mere's proc_set_title measured the area from the last title, so
  after a short one every later title was cut to its length.
  language/predefined's "actually sets the program name".
- A read into a buffer keeps the buffer's encoding (io_read with a length).
- **A bare `mere-ruby` on a terminal reads its program from it**, as ruby
  does (it printed the usage line there), and a terminal's ^D is not the
  last word: the next read waits for more. test_rubyoptions'
  test_script_from_stdin, which PTY now lets run.
- **Left** (with the reason): IO::Buffer's SHARED mapping across fork (a
  buffer here is a String; sharing it needs the class's storage to live in
  shared memory); callcc that re-enters (a continuation here can only escape:
  re-entering needs the interpreter's stack copied, test_array's 16
  *_with_callcc); a UNIX datagram socket made by for_fd under recvfrom; the
  short netmask BSD hands over is shown as the mask it means
  (255.0.0.0), where ruby shows the 5 bytes; gethostbyaddr's two IPv6
  examples; irb (not shipped); ancillary data to a non-IP address
  (NotImplementedError). #76's bound-UDP connect (Socket.__udp_connect, in
  the glue) and sock_connect now do the same thing two ways; they are left as
  they are, the bound path being #76's.
- **Checked**: rebased onto #76 (the network stdlib) and checked there: corpus
  588/588 with the hash index on and off; the 13 gates; corpus/561 under
  MERE_RUBY_GC_STRESS=50 (round 11's binary cannot load pty). The 247
  unittest files 9754 -> 9789 (test_pty 15, test_https 19 from #74-#76); two
  that read RED, test_io_m17n's each_codepoint_need_more and test_object_id's
  Ractor race, fail the same with round 11's binary on a rerun (load).
  test_rubyoptions 65 MATCH, 3 BOTH. The runtime set (test_pty, io/console,
  test_open3, test/socket, test_io_buffer): MATCH 303 -> 352 of 362, the rest
  test_shared (left), test_bug_21210 (a skip) and four memory-leak timeouts
  (stage 4). Mere's three probes on C and LLVM, macOS and the CI's Linux. The
  spec records: base DIFF 31 -> 26, CRASH 1 -> 0 (expect; core/kernel/open
  is #76's open-uri); stdlib DIFF 26 -> 11 (CRASH 6, coverage and fiddle).

## 2026-11-10 (29): the small items of stage 3 -- a binding's local named self, a re-raised SystemStackError's frames, a run-time Regexp's own state, a copy of Time, defined? and the parse shapes test_compile_prism names, OpenSSL::KDF's refusals, a copy_stream that waits

Round 13 of note 541 (the leftovers of stage 3, re-surveyed after note 540).
corpus/576 is the witness. No Mere change.

- **A binding's local named self** (and one named for a keyword): it is kept
  under a key of its own (bnd_lv_key), because "self" in an env is the
  receiver -- `b.local_variable_set(:self, v)` changed what `self` meant for
  the rest of the method. `{self:}` (hash value omission) reads it, or calls
  #self. test_literal's test_hash_value_omission.
- **`raise e` of a rescued SystemStackError keeps its frames** (15000 of them,
  not the 26 of the re-raise), as ruby keeps a backtrace an exception already
  has; the exception is an object (raise_stack_too_deep), so it carries them.
  test_exception's test_stackoverflow.
- **IO.copy_stream waits on its descriptors** (IO.__park with them): when
  every thread waits, the scheduler's idle wait is a poll(2) on all of them
  (sch_iofd), not a millisecond sleep -- a reader of an empty pipe used 6% of
  a CPU. test_io's copy_stream_no_busy_wait. The waiter list ends in a space,
  and the first version woke a waiter by `int_of_str` of the empty word after
  it, which failed: corpus/260's accepting thread died with "(ruby exception
  raised)". Only "fd:bits" words are read now.
- **A Regexp made at run time has a self of its own**: instance variables,
  #extend and its singleton class, an object_id (`Regexp.new("x")` twice was
  one id), and Marshal's dump / load / restore of one with ivars or modules;
  a literal is frozen (FrozenError).
- **A copy of Time answers Time's class methods** (`Time.dup.at(0)`,
  cls_copy_of): the arms asked `is_a?(Time)` of the class, which a copy is
  not. core/time/dup.
- **test_compile_prism's eight**: `alias $a $b` and a backtick method in a
  class body; `defined?` of `__FILE__`, `%x[]`, `:"#{}"`, a named-capture `=~`
  and `1 => 1` (expression); `defined?(yield)` in a class body; a literal's
  element as a multiple-assignment target (`_, {}[:k] = 1`); `Const op= v` in
  a class body; `return *a, **kw`; InstructionSequence#to_a's misc hash
  (node_id, code_location) and compile_file's errno naming only the path.
  182/182.
- **OpenSSL::KDF's refusals**: an iteration count that is no Integer is
  NUM2INT's TypeError, an unknown digest DigestError, iterations <= 0 and an
  N / r / p scrypt refuses KDFError, scrypt's missing and unknown keywords
  ArgumentError. library/openssl/kdf.
- **write_nonblock leaves the stream non-blocking** (#nonblock? true after
  it), except a socket on Linux, which ruby writes with MSG_DONTWAIT.
- gethostbyname / gethostbyaddr warn with no category (ruby always warns).
- **Moved to round 15** (they need Mere): a UNIX datagram to a path
  (unixsocket/recvfrom_spec's for_fd) and fpathconf (test_etc's pathconf).
- **Checked**: corpus 589/589 with the hash index on and off; the 13 gates;
  corpus/576 under MERE_RUBY_GC_STRESS=50, and it fails on round 12's binary.
  The 247 unittest files plus test_compile_prism and test_etc: nothing new is
  RED; test_exception's stackoverflow and test_literal's hash_value_omission
  are MATCH (and three that were RED under load in round 12's run read MATCH:
  test_io_m17n's each_codepoint_need_more, test_https' max_version,
  test_rubyoptions' script_from_stdin). test_compile_prism 182/182. The spec
  records: base DIFF 26 -> 20 (marshal x3, time/dup, kdf x2), CRASH 0;
  stdlib DIFF 11 -> 10 (basicsocket's write_nonblock), CRASH 6.

## 2026-11-11 (30): callcc goes back in -- a continuation taken inside an Array method that refuses re-entry, called after the method returned

Round 14 of note 541. corpus/577 is the witness. No Mere change: the stack
copy (Mere's `cont_capture` / `cont_resume`) is for later, behind the same
Ruby API (note 541 §2).

- **The shape**: a `callcc` taken inside an Array method whose C refuses to
  be re-entered -- permutation, product, combination, repeated_permutation,
  repeated_combination, sort / sort! with a block, and #to_ary asked by
  flatten -- and called after that method returned, while the method frame
  that called it still runs. ruby goes back into the block, its C notices it
  is finished and raises "permute reentered" (and so on) at the call, the
  frame's own `rescue` gets it, and the frame carries on with its locals as
  they are now -- test_array's *_with_callcc count a local down 1000 times.
- **Here**: while `require "continuation"` is loaded (cont_on), each call of
  such a method is a guard for as long as it runs (cont_guarded, at the doors
  the builtins come through: dispatch_prim, builtin_iter, and invoke_val_c /
  invoke_with_block for flatten and sort with a block): its message, the
  nearest live method frame below it, the line of the call. callcc keeps the
  innermost one. Continuation#call after its callcc returned unwinds to that
  frame with a flow signal no rescue sees ("contre", as a return's), the
  frame runs its body again from the top-level statement holding the line
  (cont_from_line: the last SLine at or before it), and the same method,
  called from that frame, raises the guard's RuntimeError instead of running.
  `require "continuation"` warns as ruby's continuation.so does.
- **Different from ruby** (KNOWN_GAPS): what the block had left to run after
  the callcc is not run again, and the statement holding the call is run
  from its start. Every other re-entry -- reject's two tests (they go back
  into reject's own loop), a continuation whose frame has returned -- still
  raises NotImplementedError by name.
- test_array 16 -> 4 RED (reject x2, and test_shared_marking x2, stage 9).

## 2026-11-11 (31): what needed Mere v0.1.726 -- IO::Buffer's shared memory across fork, fpathconf, a datagram to a path

Round 15 of note 541. merelang/mere#67 (v0.1.726) adds `mmap_anon` and its
handle-checked byte calls, `sock_unix_sendto` and `fd_pathconf` (by name, with
`fd_pathconf_var` / `fd_pathconf_names`), general host calls; and
sock_recvfrom names an unbound AF_UNIX sender "unix 0 " on Linux too.
corpus/578 is the witness. mere >= 0.1.726.

- **IO::Buffer MAPPED | SHARED** is a shared anonymous mapping (@__h): @s is
  a copy __raw reads again and __store writes through, so a forked child's
  set_string is what the parent's get_string reads. free / transfer /
  initialize_copy / resize keep track of the handle; a resize that
  reallocates (not Linux within its pages, #77's mremap rule) leaves the
  memory the process's own -- shared? false, as ruby has it (it said true
  before) -- and one Linux keeps in place is a new shared mapping of the new
  size. test_io_buffer's test_shared.
- **IO#pathconf and Etc::PC_*** by the host's own names and numbers; nil for
  no limit, Errno for a refusal. test_etc's test_pathconf.
- **Socket#send to a sockaddr_un / Addrinfo.unix** (Socket.__unix_sendto),
  and UNIXSocket#recvfrom of a datagram names its sender (the path, "" for an
  unbound one) instead of always "". library/socket/unixsocket/recvfrom.

## 2026-11-11 (32): what the parse knows and the runtime did not -- a scope's later locals, a heredoc interpolation's line; the first thread's turn, import_methods' refusals, a Hash's own #each, WeakKeyMap's million stores

Round 16 of note 541. corpus/579 is the witness.

- **binding.local_variables lists a scope's locals from where it begins**, as
  ruby's parse-time table has them (`binding.local_variables; a = 1` is
  [:a]). A source that names `binding` (lex_src looks for the word) puts a
  mark at the head of its block and def bodies -- after a block's parameter
  defaults (lvd_head), and after the opening-line and file markers a block's
  readers look for first (a lambda's source_location read the mark and said
  the line of `->`, corpus/397) -- and run_stmts turns it into the names the rest of
  the body assigns (env "__lvdecl", deep_targets). The scope that has them
  lists its parameters first and then them, in the body's order (the env's
  own order is a hash's, and adding the key reordered it). The prelude's
  sources get no mark; a source without the word pays nothing. Not done:
  ruby lists the OUTER scopes' later locals too (the main script's).
  core/binding.
- **An interpolation in a heredoc's body runs at its own line**: the body is
  lexed apart, at the line of `<<ID`, so a `#{}` there names how many lines
  below it is (`(__hdline d) && __hdpop((code))`); the parser makes it a line
  from tok_line, and __hdpop puts the statement's line back once the value is
  made. language/heredoc. (The flag saying a heredoc's body is being lexed
  is cleared at each lex_src: a lex that failed inside one left it set, and
  test_syntax's invalid_break / invalid_next read the next source wrong.)
- **The first Thread.new returns before the thread begins**: the scheduler's
  slice count started at 0, so the statement keeping what Thread.new
  answered handed over first, and a thread with nothing to do had begun and
  ended (its :thread_begin hook saw no Thread to compare) before the program
  had it. The first thread made sets a whole slice. core/tracepoint/inspect.
  That moved test_deadlock_backtrace's deadlock into the other thread, where
  the builtin register (bi_reg) a fiber switch did not keep came back as the
  wrong one: fb_ctx_save / fb_ctx_restore keep it now (bit 41).
- **Refinement#import_methods refuses what is not Ruby code**: a method with
  no source file (the prelude's), one a library standing in for a C extension
  defines (zlib, continuation, etc, stringio, strscan, io/nonblock, io/wait,
  pty, nkf, fcntl, coverage, objspace -- the wholly-C ones), and a
  define_method's. Zlib's module functions are private instance methods too
  (rb_define_module_function). core/refinement/import_methods. Comparable
  lists no instance methods here, so importing it is not refused.
- **A Hash with a singleton #each goes through it** for what Enumerable gives
  a Hash (map, flat_map, count, min_by ...), with a block or without, and not
  for what Hash answers itself (select, reject, any?, to_a, include? ...).
- **ObjectSpace::WeakKeyMap#[]= with no Ruby frame** while it is the
  prelude's (invoke: wkm_aset, the same store `h[k] = v` makes): Bug #20691's
  million stores went 18 s -> under 8 s, inside assert_normal_exit's 10.
  test_weakkeymap's test_clear_bug_20691.
- **Checked** (rounds 14 to 16 together, on Mere v0.1.726): corpus 596/596
  with the hash index on and off; the 13 gates and #77's gc_roots_check;
  corpus/577 to 579 under MERE_RUBY_GC_STRESS=50. The 247 unittest files plus
  test_compile_prism, test_etc and test_weakkeymap: MATCH 10002 -> 10007 over
  round 13's run (callcc x14, test_shared, pathconf, test_clear_bug_20691),
  and nothing RED that was not RED after round 13 (test_syntax, test_thread,
  test_fiber and test_backtrace read as before). The spec records: base DIFF
  20 -> 16 (binding/local_variables, refinement/import_methods,
  tracepoint/inspect, language/heredoc), CRASH 0; stdlib DIFF 10 -> 9
  (unixsocket/recvfrom), CRASH 6. library/etc/getgrgid reads SLOW or DIFF
  under load on main's binary as well (six at once); its record is kept.
- **After the push**: CI's embedding stress check (#77) read allocation
  growth with the number of evaluations (scalar 1,000 -> 100,000: 34.5 MB ->
  36.1 MB in the default region). The driver set lvd_st "main" before each
  main-script parse and deleted it after, and a key deleted and set again is
  copied into the default region each time. The flags keep their keys and say
  0 / 1 (flag_on), and the heredoc line stack keeps its depth under key -1
  and overwrites its slots. Flat at 34,477,920 for 1,000 to 100,000; corpus
  596/596, the gates, test_syntax as before.

## 2026-11-11 (33): stage 4 begins -- Mere v0.1.727's region cache, zlib under its archdir name, and what every eval copied into the default region

Round 17 of note 543 (stage 4, memory and time).

- **Mere v0.1.727** (merelang/mere#70): the per-thread cache of released block
  regions is 64 deep instead of 8. The interpreter nests a region per
  statement, method body and block at each level of a call, and a release
  past the cache gave back the region's 1 MB seed, which on Darwin is a kept
  mapping filled with 0xAA as it is kept and zeroed as it is handed out: two
  1 MB memsets per region per call. Marshal.load(1) 0.6 -> 0.1 ms; corpus
  190.6 -> 186.0 s, peak RSS summed 50.5 -> 45.0 GB (largest the same,
  1.29 GB). test_udp's bind / connect / send no-leak loops now finish inside
  their 10 s (5.9 / 5.4 / 2.7 s). test_addrinfo's marshal loop is 5x faster
  and still over (20,000 loads, about 47 s).
- **A library standing in for a C extension is loaded under its archdir
  name too**: zlib's feature is `<stdlib>/<platform>/zlib.bundle` (DLEXT) in
  $LOADED_FEATURES beside the .rb, and `-r` of that path loads the library.
  test_zlib's gunzip_no_memory_leak looks the path up to run its child with
  it: it passes (6.8 s).
- **Three things every Kernel#eval wrote into the default region**, found
  because v0.1.727 lowered test_kwarg_eval_memory_leak's starting RSS (the
  kept seeds of round 16 had been filling it before the measurement began)
  and the ratio went 1.17 -> 1.43. `eval("1")` grew the default region 49
  bytes an eval (`mere -c --region-sites` + MERE_REGION_STATS, 100 against
  100,000 evals):
  - fsl_ctx "v" (the frozen_string_literal answer) was a str set and put back
    around each eval, and a str value is copied at each set. It holds 0 / 1 /
    2 now, behind fsl_get / fsl_put; a fiber saves it as an int map.
  - ind_ctl's "off" / "no" were set and deleted: 0 / 1 now (flag_on).
  - the eval's caller's local names (lvt_outer, vw_outer) were cleared and
    filled at every eval, a copy of each name each time. A name's value is
    the table's generation now, kept under "" (no local is named that), and a
    clear moves the generation on (lvo_clear / lvo_fill / lvo_has): a name is
    copied the first time any eval's caller has it.
  Flat: 35,372,632 -> 35,466,048 bytes for 100 -> 100,000 `eval("1")` (was
  -> 40,266,128), and the kwargs eval 35.73 -> 35.77 MB.
- **What is left of test_kwarg_eval_memory_leak is Mere's**: the RSS still
  went 67 -> 88 MB (limit 1.2x). The string pages are not it
  (MERE_RUBY_STORE_STATS now prints str_pages and str_pg_pool: 6 live, 7
  pooled); the mapped blocks Darwin keeps for reuse are -- up to 16 MB,
  resident, empty when the run's START is read and full at its end. A build
  with the kept list off reads 66 -> 69 MB. madvise cannot give them back on
  Darwin (MADV_FREE_REUSABLE and MADV_DONTNEED leave ps's RSS as it was;
  only munmap lowers it), so merelang/mere#74 (v0.1.729) adds `mem_trim`, the
  Go `debug.FreeOSMemory` of the runtime, for GC.start to call once it is
  merged. Until then the test is RED here (it was MATCH on round 16's binary
  only because the seeds had already filled the list before START).
- **v0.1.727 on main's CI went over 2 GiB on three files** (run of
  b71a9a91, the first on the pin): prism/snippets_test (3,833 tests),
  net/http/test_http and test_trick read MEMORY_LIMIT, MATCH 30,407 ->
  26,953. snippets_test's peak: 1.5 GB with the cache 8 deep, 1.6 GB at 9,
  2.6 GB at 64. Not the cache's own bytes (64 MB at most): a region reused
  from the cache is not zeroed, the bump allocator leaves bytes it does not
  write under top, and the conservative scan reads them -- the handles a
  previous use left there kept their objects alive. Past depth 8 a region
  had always come from a zeroed mapping. merelang/mere#74 zeroes what a use
  wrote as the region goes into the cache: 1.49 GB, and 405 s against the
  8-deep cache's 524 (Marshal.load(1) 0.14 ms). test_http is at the edge
  either way (2.0 GB locally on round 16's binary too) -- a stage-4 item of
  its own.
- **Checked** on Mere v0.1.727: corpus 598/598 with the hash index on and
  off (after the rebase onto #70's encoding work; 596 before it); the gates, gc_roots_check and meth_writes_check; #77's embedding check
  and embedding stress check (flat). The 247 unittest files plus
  test_compile_prism, test_etc, test_weakkeymap, test_zlib, test_addrinfo,
  test_udp and test_method: MATCH 10197, nothing RED that was not RED after
  round 16 except test_kwarg_eval_memory_leak (above). The stage-4 tests one at
  a time (note 543 §2): passing now -- test_udp x3, gunzip_no_memory_leak,
  test_pow, blocking_backtrace, the yaml store, test_clear_bug_20691; still
  over -- hash replace, alias, io select, syntax invalid_symbol, addrinfo
  marshal, the tracepoint pair, string_empty?, and #78's four. The spec
  records: base DIFF 16, CRASH 0 (library/etc/getgrgid read DIFF in the
  sweep and MATCH alone twice: the load flake of (32); its record is kept).

## 2026-11-11 (34): stage 4, round 18 -- Mere v0.1.729 and the 64-deep cache again, a hash index the pool dropped and never freed, the idle wait's and a bignum addition's scratch in the default region

Round 18 of note 543 (stage 4, memory and time).

- **Mere v0.1.729** (merelang/mere#74, merged as a3deab36): a region that
  goes into the per-thread cache is zeroed where it was used, and `mem_trim`
  hands back what the runtime keeps for reuse (cache entries past 8, and on
  Darwin the kept mapped blocks). mere.toml and MERE_REF move to it, and
  GC.start calls `mem_trim ()` after its collection (both the in-stack and
  the off-stack one) -- what assert_no_memory_leak reads right after GC.start
  no longer counts up to 16 MB of kept blocks.
- **The cache is 64 deep again.** #79 built with `-DMERE_REGION_CACHE_CAP=8`
  for two reasons, both of them v0.1.727's and both gone in v0.1.729: the
  un-zeroed reuse (snippets_test past 2 GiB) and test_kwarg_eval_memory_leak
  at 1.44. Side by side on v0.1.729, under the same load: test_udp's bind /
  connect / send leak checks pass at 64 (4.8 / 4.8 / 2.4 s) and run into
  their child's 10 s at 8; kwarg_eval passes at both (1.9 s, 128 MiB at 64;
  2.1 s, 203 MiB at 8). build.sh builds with the compiler's default and
  refuses an mr.c without `__lang_mem_trim` (one older than v0.1.729).
- **A hash index the pool dropped was never freed.** A hash whose keys are
  not all plain (a Class key -- `{Exception => :immediate}`, the mask of
  every Thread.handle_interrupt) gets an index: a Map with an arena of its
  own. A dead hash's index goes back to a pool at the next collection --
  and past 4096 pooled ones it was dropped. A dropped Map gives nothing back
  (its arena hangs off the default region), so the cap was a leak of every
  index past it: 3.9 KB a call in a handle_interrupt loop, found with
  MallocStackLogging (16,054 live 3.9 KB blocks from map_recycle in
  hidx_start). test_thread's handle_interrupt_with_return_and_trap_handler
  (500,000 calls) went past 1.8 GB in its child, which is why test_thread
  read MEMORY_LIMIT on main's CI. Every index goes back to the pool now, and
  each one taken counts 4 KB toward the next collection (as a queue counts
  512 B), or the pool grew to hold what piled up between two collections.
  The frame pool had the same cap (past 4096 frames, a returning frame kept
  its 4 KB seed for good): gone too. That loop: 59 -> 64 MB for 200,000
  calls (was -> 511 MB), and 1.8 s (was 16 s). tools/loop_rss_check.rb has
  the case "a hash with a Class key": 4.90 before, 1.08 now.
- **The scheduler's idle wait wrote into the default region at every
  wait.** sch_iofd_wait (every thread waiting, some on a descriptor) built
  three maps, a joined text and the split words in the default region, and
  sch_next_deadline / sch_expire / sch_waiters_n their maps: 4.27 GB
  allocated there over net/http/test_http's 85 tests, found with `mere -c
  --region-sites` (m_sched.mere:204 1.25 GB, :217 0.83 GB). Each is in a
  region of its own now: the default region ends at 222 MB, and the file's
  largest RSS is 726 MB (1.2 - 1.8 GB before, with the cache 8 or 64 deep).
- **A bignum addition's buffer was in the default region**: mag_add and
  mag_sub (rev_str beside them already had a region, note 300). 656 MB of
  test_trick's child; `a + b; a - b` on 2,400- and 3,400-digit Integers
  20,000 times: 216 -> 59 MB.
- **What does not fit a leak check's 10 s, and why it is not this round's.**
  test_hash replace (500,000 `h.dup.replace(h)` of 676 pairs), test_alias
  (500,000 define_method / alias / remove_method), test_settracefunc's two
  (1,000,000 TracePoint.new; enable(target:)), test_addrinfo's marshal
  (20,000), test_io's select (threads and IO.select for 60 s) and
  test_optimization's string_empty? child: none of them is held back by a
  leak any more -- each is an interpreter at 10 - 40 times ruby's time per
  call. An empty `Foo.new(:a) {}` is 10 us here and 0.3 us in ruby, `proc
  {}` 3 us against 0.2, a Hash#dup of 676 pairs 125 us against 2.5 (the
  pair list and the digest index are copied whole). Taking the two blocks
  out of TracePoint#initialize changed nothing measurable. A path made
  cheaper does not close a 20x gap; the VM layer (note 511, stage 10) is
  where these are, and the ledger says so. test_syntax's SyntaxError eval
  (1,000,000) does fit now, at 10.0 s locally -- at the edge on CI.
- **Checked** on Mere v0.1.729 (a3deab36): corpus 598/598 with the hash
  index on and off (with LANG set: corpus/492 asks ENV for its encoding,
  which follows the locale and not -Eutf-8 -- under an empty LANG the
  reference answers BINARY, on round 16's binary too); loop_rss_check 8/8;
  psych_scalar / tmpdir_fileutils / unicode_normalize / yaml_store /
  record_hygiene; the embedding check and its stress; encoding_search;
  prism_query_boundary. unittest on round 17's list plus test_thread,
  test_http and test_trick: MATCH 9,958 (round 17: 9,954), newly all MATCH
  in test_exception, test_integer, test_syntax and test_method
  (kwarg_eval); test_array's shared_marking omits itself past 5 s on every
  build here (12 - 16 s on round 17's binary too). Integer, bignum,
  numeric, rational and test_trick: 180/180. Peak RSS (process family):
  snippets_test 411 MB in 307 s (1,490 MB / 405 s on #74's measurement),
  test_trick 392 MB, test_http 1,114 MB, test_thread 850 MB. Stage-4 list
  on the final build: test_udp bind / connect / send 4.0 / 4.0 / 2.2 s,
  gunzip 5.6 s, pow 11.1 s (passes; its own limit), blocking_backtrace,
  yaml store binary, WeakKeyMap clear, syntax invalid_symbol -- MATCH.

## 2026-11-11 (35): stage 4, round 19 -- the captured-frame threshold grows with the heap, and IO's poll answer has a region of its own

Round 19 of note 543 (case_comprehensive inside CI's limits).

- **ruby/enc/test_case_comprehensive collected 14 times a second.** Main's
  CI on round 18 (92d97333) was green with MEMORY_LIMIT at 0 (test_thread,
  test_http and test_trick back: MATCH 30,266 -> 30,472), and this file was
  the one WALL_LIMIT left. A third of its run was the collector (sample:
  gc_collect 1,177 of 3,244), and a log of why each collection was asked for
  (MERE_RUBY_GC_LOG plus the three axes, in a scratch build) said it was the
  captured frames: lv_cap at 2,048, the floor its threshold went back to
  after every collection. The file captures a frame per call while it holds
  a 120 MB Unicode table, so every 2,048 captures (8 MB) marked all of it --
  1,721 collections in its first 120 s. The floor is now the larger of 2,048
  and half the live stores' bytes at 4 KB a frame (gc_store_bytes / 8192):
  the same 2,048 for a small heap, about 15,000 for this one.
  442 -> 307 s locally, 422/422; the peak 702 -> 1,211 MB (2 GiB is the
  limit; round 18's other changes had taken it down from 1.9 GB).
- **io_poll_once's answer map was made in the default region** at every
  IO.select and every idle wait with a descriptor: 115 MB over test_http
  once the idle wait had its own region (round 18). It is in one now: the
  default region ends at 84 MB there (199 MB).
- **Checked** on Mere v0.1.729: corpus 598/598 with the hash index on and
  off (LANG set); loop_rss_check 8/8; the five gates; the embedding check and
  its stress; encoding_search; prism_query_boundary. unittest on round 18's
  list plus test_io: MATCH 9,957 -- against round 18's 9,958 the difference
  is test_array's shared_marking for the subclass too (it omits itself past
  5 s: 12 - 16 s on every build here) and settracefunc's
  thread_end_with_exception, F once under load and MATCH three times alone
  on round 18's binary and on this one. snippets_test 504 MB in 285 s.
- **CI on round 18, the files that moved down by one**: test_integer's
  test_pow and test_object's copied_ivar_memory_leak timed out (60 s on CI;
  `a.clone.set` is 6.4 - 6.9 s per 100,000 on every build from round 17 on,
  so 500,000 is about 33 s locally and at the edge there), and test_method
  has one test EXTRA (the reference failed it). None is this round's.

## 2026-11-12 (36): stage 5, round 20 -- parse.y's tokens from Prism's lexer, a deep Array read, retry and ensure, a Hash copy's default, builtin class-method aliases, nested autoloads and a Struct's lexical scope

Round 20 of note 544 (the plan after stage 4: stage 5 first, then RubyGems).

- **RubyVM::AbstractSyntaxTree.parse(keep_tokens: true) answers #all_tokens.**
  test_ast's test_all_tokens is one test per file under test/ (851 of the
  file's 958 RED). parse.y's tokens and Prism's lexer's are nearly one to one
  -- Prism's names come from parse.y -- and the differences are four rules,
  measured against the reference over test/**/*.rb (869 files: text and
  places agree in all, names in 862): the gaps are tSP (word_sep inside a
  %w list), cut after each newline and each `\` newline; a newline that ends a
  statement is made after the comment lines that follow it (parse.y looks past
  them for a leading `.`); a <<~ body is one token a line until a line with no
  indentation, and an expanding <<- / <<~ body is cut after a line ending in
  `\`; a `do` is keyword_do_block when its block belongs to a call with
  arguments and no parentheses (decided on Prism's tree). The tokens are made
  in C (tools/prism_glue.c, prism_tokens: 1.4 s for all 869 files) and the
  arrays in Mere (the builtin __all_tokens; a Ruby loop was 17 us a token),
  and counted toward the next collection (qv_ctr 3, 128 B a token).
- **An Array is a cons list, and `a[i]` walked to i.** Reading near the end
  of a 340,000-element Array was 0.6 ms a read; unpack's answer read seven at
  a time took 14 s. arr_at moves the array to its Vec form once for a read
  past the first 32, and the reads after it are a slot.
- **retry ran the ensure clause every time.** It now runs once, when the
  begin is left, as ruby does. rubygems' Specification._load sets
  Object::YAML in its rescue, retries and removes it in its ensure: the
  retried load found no YAML.
- **Hash#dup and #clone dropped the default value and the default proc.**
  rubygems' tests restore `specific_extra_args_hash.dup`, a Hash.new with a
  block, and read a missing command from it ("no implicit conversion of nil
  into Array", exec_command's 27). A program's own Hash#initialize_copy still
  leaves the copy without either (test_dup's user_flags).
- **An alias of a builtin class method is that builtin** after the name is
  redefined or undefined in the singleton (bi_skip past the singleton's Ruby
  body and its tombstone), and undef_method takes such an alias. Class#methods
  and #singleton_methods list a class's builtin class methods from ruby's own
  rows (`Time.` -> now ...) and not the prelude's `__` helpers. minitest's
  Object#stub asks `methods` whether a name is the object's own; Time.now was
  not, so it defined a super-calling one and the stub reached nothing (five
  rubygems files stopped there: install_command, tar_writer,
  remote_fetcher_s3, update_suggestion, and owner's TCPServer.new).
- **A reopened Struct class sees the nesting it was written in.**
  `State = Struct.new(...)` and then `class State` inside `module
  Gem::Molinillo` reads DependencyGraph: the cref's name (Struct_N) says
  nothing about the nesting, so each scope of it is asked in turn (the
  resolver's 140 errors).
- **`class A::B::C < A::B::D` loads A::B's autoload first**, so the autoloads
  A::B's file registers are there for D (rdoc's Markup::Formatter: the rdoc
  plugin, test_gem_rdoc).
- **Array#sample takes a Float count** (NUM2LONG), and the ivar listings
  compare a key's prefix without building a substring per key.
- **Left out, measured**: ripper's assert_parse_files hits
  Prism::Translation::Ripper's `arguments&.any?` on an event's own answer.
  Transcribing visit_call_node with that one condition made the files pass,
  but a parse of lib/mkmf.rb (95 KB) then takes 1.46 GB and 190 s -- lib's
  5% sample would hit CI's limits at random. It waits for a faster, smaller
  translation. error_highlight needs the call's node_id (stage 2').
- **Checked** on Mere v0.1.729: corpus 598/598 with the hash index on and off
  (before 640 was added); loop_rss_check 8/8; the five gates; the embedding
  check and its stress; encoding_search; prism_query_boundary. test_ast
  2,664 tests, 12 F / 86 E (958 RED before), 317 s locally, the process's
  peak 1.45 - 1.89 GB with the test order. The rubygems files above pass but
  install_command's 4 and exec_command (a native extension build, stage 8).
- **Moved onto main after #78 and #80** (Mere v0.1.731). Two conflicts:
  collect_cls_methods keeps NKF's own class functions and the `__` filter;
  the builtin-class singleton arm takes bi_skip_pass for every name, which
  is what NKF's arm asked only for its own.
- **An open File writes on after a chmod takes its write bit.** The first
  CI run of the round stopped rubygems/test_gem.rb before its first result
  (112 MATCH before, 0 after): the resolver now got far enough to install a
  gem with `prog_mode: 0510`, and the bin stub is written, chmodded and
  closed. A File here is a path and a buffer, and the flush wrote the path
  again; the path refused (EACCES) and the failure was not a Ruby
  exception at all, so it went past every rescue and ended the runner.
  File#chmod on a handle that writes now opens its descriptor first, and a
  flush the path refuses goes through that descriptor at the write position
  (a refused flush with no descriptor is Errno::EACCES). test_gem 127/129.

## 2026-11-12 (37): stage 6, round 21 -- RubyGems' remainder, a class body's value and the env pool, Comparable's !=, rubygems before -r, GB9c

Round 21 of note 544: the RubyGems files that were left after round 20,
surveyed again file by file against the reference run locally (a test the
reference also fails here -- no rust toolchain, the binary's path, a
different install layout -- is not counted), and the small items the stage 3
tail turned up on the way.

- **A class body's value outlived its env.** #78 moved register_class_blk's
  env into the frame pool (blk_env_get), and the walker's answer was read out
  of that env's arena: `show(c.module_eval("self"))` answered show's own
  receiver, and at the top level the String "show" -- the next call's frame
  had been written over it. The body's value is now copied out (a region
  around the walk) before the env goes back. test_eval's module_eval basics
  had come back RED on main.
- **`!=` of an object whose == is Comparable's** negates that == (it was
  identity): Gem::Version's 1.2.003.0.0 and 1.02.3 are equal, and the
  uninstaller's `s.version != spec.version` kept every executable. **Array#eql?**
  asks each pair #eql? (it asked ==), so "~> 1.3" and "~> 1.3.0" differ; an
  Array of rows that hold objects sorts with their <=> (Requirement#hash).
- **super into Exception#message** from an exception made by `raise Cls,
  msg` (the built-in form): RuntimeRequirementNotMetError's decoration was
  "super: no superclass method" (install_command's 3, update's 1).
- **A standard stream's #pos / #seek / #rewind** are its descriptor's offset:
  capture_subprocess_io reopens $stdout onto a Tempfile and rewinds it (nine
  tests in five files). ESPIPE is named per method; #lineno of an output
  stream is "not opened for reading".
- **defined?(X) inside `class A::B::C`** asks the nesting as written, as
  reading X does: it found rubygems' vendored Gem::SecureRandom, and net-http
  never required the real one (push_command's attestation).
- **A loop modifier's assignment is a local in its condition**
  (`line = out.shift until line == "x"`), as an `if` modifier's already was.
- **`class E < X` inside `class S < Base`** finds X among Base's constants
  (rake's Scope::EmptyScope < EmptyLinkedList made a new top-level class).
- **rubygems is loaded before -r's libraries**, as ruby_opt_init does, and a
  load that raises ends the program reported (operating_system.rb's message,
  test_rubygems); `ruby -r ./activate.rb` with `gem(...)` in it works.
- **OpenSSL::Digest(:SHA512)** takes a Symbol; PKey::RSA / DSA / DH #to_s is
  #export (lib/, regenerated with tools/gen_openssl_lib.rb).
- **GB9c**: a consonant, linkers and extends, and a consonant are one
  grapheme cluster ("क्त"). The Indic_Conjunct_Break sets come from the pinned
  ruby source's name2ctype.h (tools/gen_incb_table.rb; ruby's regexp does not
  name the property). test_grapheme_breaks 2,923/2,923.
- **Left, measured**: the rubygems tests that build a native extension
  (mkmf needs RbConfig's CC and friends: stage 8, and exec_command's runner
  exit is the same build failing); test_download_local_read_only (a failure
  with no Ruby exception under the read-only cache, one test); the AST of
  `_=1` (test_pp, stage 5's tree).
- **Checked** on Mere v0.1.731: corpus 671/671 both ways (641 added after,
  checked alone both ways); loop_rss_check 8/8; nkf, encoding_search and
  class_module checks. Locally: rubygems' test_gem 127/129 (2 env),
  requirement 35/35, kernel 14/14, rubygems 3/3, signer 18/18, package
  59/59, uninstaller 40/41 and installer 119/127 (extensions), and the
  files the changes touch (array, hash, class, module, syntax, io, eval,
  string, comparable, enumerator, rubyoptions, regexp, exception, object,
  file, range, struct, require, autoload, super, delegate, openssl's
  pkey_rsa and digest) at or above round 20's CI counts.

## 2026-11-12 (38): stage 9, round 22 -- Ractor on the scheduler's threads, its isolation, live Array/Hash counts

Round 22 of note 545 (the plan after round 21). Stage 9 was surveyed first:
most of its RED is CRuby's heap shape -- GC.stat_heap, GC::INTERNAL_CONSTANTS,
GC::OPTS, generations, a moving compactor -- which this collector does not
have; GC.start's own comment says why those are not invented, and they stay
out (the ledger's "CRuby heap shape"). What has a real answer here was done.

- **Ractor runs on the scheduler's threads.** Each body is a Thread, a port
  a Thread::Queue its creator reads (a value travels boxed, so nil and
  "closed" are two answers), #value / #join wait on the thread, select looks
  at its ports and ractors and passes. It used to run each body sequentially
  when its value was asked for, so two ractors that talk could not be
  written. bootstraptest's test_ractor: 62 failing of 154 -> 22.
- **What crosses is copied, frozen state and instance variables kept** (an
  Array's and a Hash's too); a shareable object is passed as itself, a Thread
  or a Mutex refused by its allocator. Only the first ractor to ask takes a
  value (its successor); #join takes none. #monitor answers false for an
  ended ractor and tells it at once (:aborted when it raised). Ractor-local
  storage refuses another ractor. The first Ractor.new warns that the API is
  experimental; #inspect names where the ractor was made.
- **A non-main ractor's isolation** (variable.c, proc.c): a global
  (rb_gvar_ractor_local's list aside), a class variable, a class's or
  module's unshareable instance variable, a Ractor's own instance variables
  (by @iv or by name), a non-shareable constant read or written; the block
  may not reach an outer local (a walk of its body, block-locals and nested
  parameters aside). RUBY_VERSION and the other RUBY_* are frozen, an
  Encoding and ENV shareable. The interpreter's own code is exempt, as ruby's
  C is: the prelude, the __*.rb files that stand for a C extension, the
  .bundle stand-ins, and the constants a shipped library defines (cgi/escape's
  tables are C data in ruby). A require or an autoload set off in a non-main
  ractor runs as the main ractor's, as ruby 4.0 hands them to main (rubygems'
  Ruby require read Gem's tables otherwise); Ractor._require exists.
- **A thread belongs to the ractor that made it**: Ractor.current is its
  ractor's, and an `exit` in it ends that ractor (its body's SystemExit), not
  the program. each_object there sees only the shareable objects and
  _id2ref refuses an unshareable one. A TracePoint is its ractor's.
- **count_objects counts the live Arrays and Hashes** (T_ARRAY / T_HASH from
  their stores, without the ones count_objects itself makes), so
  test_allocation now compares real allocations; mere-ruby's call path makes
  two Arrays where CRuby makes none for `anon_splat()`, which is the VM's
  work (stage 10), not this one's.
- **undef_method in a subclass** hides the inherited method from
  public_instance_methods(true) and method_defined? (test/unit's test list
  ran an undefined test).
- **Left, measured**: moving (`send(obj, move: true)` -- the sender's Array /
  String / Hash would have to answer MovedError, and those are values here);
  $stdin / $stdout per ractor; Binding / eval / shareable_proc isolation;
  define_method's and trap's unshareable-Proc refusals. ⚠ Two found on the
  way and left for their own rounds: (1) a block that assigns a name the
  enclosing scope assigns only LATER shares it, where ruby makes it the
  block's own (`pr = proc { x = 1 }; x = 5; pr.call; x` is 1 here, 5 in
  ruby) -- the top level and methods predeclare every local; test_settracefunc's
  ractor_local_method counts 110 for it. (2) Threads with finalizer-holding
  objects collect far too often (each collection scans every coroutine's
  stack): 4 threads x 2000 clones of such an object take 2.3 s against 0.05 s
  without the finalizer; objspace/test_ractor's copy_finalizer, which passed
  while ractors ran one after another, now times out.

## 2026-11-12 (40): round 23 -- a block's own locals, decided where ruby decides them

Round 23 of note 545, found in round 22 (test_settracefunc's
ractor_local_method counted 110 for 100).

- **A name a block assigns before any enclosing scope has it is the
  block's own**, also when the enclosing scope assigns the same name later:
  `pr = proc { x = 1 }; x = 5; pr.call; x` is 5, and a method's `q = proc {
  y = 1 }; y = 5` likewise. A scope here predeclares every name it assigns
  anywhere (the top level's tl_decl, a method's frame), so the block found
  the outer y and wrote it. ruby decides this when it parses the block; so
  does this now: the lexer's local table (lvt) notes a block-frame
  assignment of a name no visible scope has yet (and no eval caller has),
  and, since lex_go builds a block's `{` / `do` token after lexing the rest
  of the source, it knows by then whether an enclosing scope assigns that
  name at all -- only those names are marked (the others are made in the
  block anyway). The marker token rides after the `{` / `do`; a block with
  parameters gets them as `|;x|` block-locals, one without keeps an empty
  parameter list (that is what lets `it` and _1 in) and opens its body with
  a declaration that makes the name the block's at its FIRST assignment
  (lv_set's chr 8 marks): a read before it still reaches outward, as ruby
  reads `prior_name || (prior_name = ...)` as a call first (corpus 527).
  `it` is never marked (test_syntax's test_it). A hash literal's `{` may
  carry the marker too and drops it. Binding#local_variables lists the
  block's own from its start, as ruby's table does.
- ⚠ Marking every such name cost each call of the block two writes:
  test_module's iclass_memory_leak (3M calls of `proc do mod = ...`) went
  4.98 -> 10.09 s, past its 10 s bound; marking only the names an enclosing
  scope also assigns brought it back.
- The blk_own_marks mechanism (blocks with parameters, decided at block
  creation by whether the enclosing env has the name) stays; it cannot see
  a later assignment, which the predeclaration already holds.

## 2026-11-12 (41): stage 9, round 24 -- moving, isolated Procs, a ractor's own streams, and a Queue that was quadratic

Round 24 of note 545: what round 22 measured and left. bootstraptest's
test_ractor, 21 failing of 154 here before the round -> 0 (locally, the
runner with --ruby=mere-ruby).

- **`send(obj, move: true)` takes the object away** (ractor.c's move): the
  receiver gets the copy, and the sender's object -- and every unshareable
  thing it holds -- answers every method with Ractor::MovedError and
  Ractor::MovedObject to `===`. Arrays, Strings and Hashes are values here,
  so a moved one is a key in a set (moved_set, asked only once something
  has moved: moved_on) rather than an object whose class changed; the call
  paths that reach a receiver -- a method call, an operator, a call with a
  block, a send -- refuse it, a builtin of a String, Array or Hash handed one
  is the TypeError ruby's type check gives (the methods that keep or compare
  any object aside), and printing one is the refusal its #inspect is. An
  object's class becomes Ractor::MovedObject. The moved are kept, so no later
  value is made under a moved key.
- **make_shareable in ruby's order**: an object is frozen by its own
  #freeze when it is entered and what it holds is walked after, so a #freeze
  that sets an instance variable has it frozen too; Complex's and
  Rational's parts are walked; a Proc needs a shareable self ("Proc's self
  is not shareable: ...") and a Method a shareable receiver ("can not make
  shareable object for ..."); a Ractor or a Port is not frozen. On the way:
  `Rational(N.new, 0)` of a Numeric with no #to_r divides as itself (ruby
  protects the to_r), and a MatchData's groups no longer show as
  instance variables `@0`.
- **Isolated Procs** (vm.c's rb_proc_isolate / rb_proc_ractor_make_shareable):
  shareable_proc / shareable_lambda make a copy whose self is the `self:`
  given (nil by default, refused when unshareable); make_shareable isolates
  the Proc itself; Ractor.new isolates its block. An isolated Proc's env is
  its own, cut from where it was written: the outer locals it reads are
  copied in -- refused when unshareable, or when the scope assigns the name
  more than once, also after the block (the parse's lvar_reassigned: the
  lexer counts each scope's assignment sites, and a block written straight
  after shareable_proc / shareable_lambda carries the names its scopes
  assign twice on a marker, as round 23's own-locals marker rides) -- and
  an eval inside that names a local of where it was written is ruby's
  SyntaxError "can not access variable ... from isolated Proc"; its #binding
  is refused.
- **A non-main ractor has its own $stdin, $stdout, $stderr** -- IOs of its
  own on the same descriptors; a method define_method made from an
  unshareable block answers only in the ractor that made it ("defined with
  an un-shareable Proc in a different Ractor"; an isolated block's answers
  anywhere); a non-main ractor's trap handler that reads the ractor's locals
  is refused; ObjectSpace._id2ref finds an Array or a Hash by its id.
- ⚠ **Thread::Queue#push rebuilt the whole list**, and the dispatch arm
  folded and inspected the queue on every call: 20,000 unread messages took
  6 s, 100,000 never finished (test_ractor's port flood timed out at 180 s).
  It uses the array's own queued push and counted shift now: 40,000 in 0.8 s.
- **Left, measured** (the same before this round, so not its doing): an
  allocation inside a ractor has no allocation_sourcefile under
  trace_object_allocations (objspace/test_ractor), and GC.start reports no
  `<internal:gc>` line event (test_settracefunc's
  tp_ractor_local_untargeted).

## 2026-11-12 (42): round 25 -- where an object was made, and ObjectSpace.dump's honest fields

Round 25 of note 545 (§5's objspace): objspace/test_objspace 44 failing ->
32 locally, objspace/test_ractor 2 -> 1.

- **trace_object_allocations records**: while tracing (one per _start not
  yet stopped, so starts nest), each Object, String, Array and Hash notes
  its file, line, GC.count and method as it is made -- in alloc_oid,
  arr_new, mkstr / mkstr_join and mkhash, one slot read when nothing traces.
  allocation_class_path / _method_id answer the method's class and name; a
  block's allocations are its own method's (run_block notes the block's home
  while tracing), a top-level def's class is Object, a singleton method's
  class path nil, as ruby's. A Float is not recorded (it has no identity
  here), nor is an allocation charged to the C method that makes it in
  CRuby (`"x".dup` is String#dup's there). `objspace.so` is the stand-in too,
  so objspace/trace loads.
- **ObjectSpace.dump**: an immediate is its own JSON (null, true, 0, a
  Symbol's `{"type":"SYMBOL", "value":...}`, a flonum's `%#g`), a heap
  Float's NaN / Inf / -Inf value, a String's value as a JSON string (control
  characters as `\u00xx`), a class's name, superclass, singleton and
  real_class_name, an object's ivars, the allocation fields when traced, and
  shareable. Left out on purpose: shape_id, slot_size, embedded, age and the
  other flags -- CRuby's heap, not this one's (the ledger's heap shape).
- ⚠ Round 23's own-locals marker was taken by `BEGIN{q=...}` / `END{...}`,
  whose `{` the lexer opens as a block's: their body is the top level's, and
  the marker reached the program as a method call `blocal:q` (test_trick's
  chopsticks, -1 in round 23's CI). The BEGIN / END parse drops it.
- Left: reachable_objects_from over each_object (which walks objects, not
  Arrays); count_symbols' dynamic symbols.
- ⚠ **Round 24's CI stopped at the embedding stress check**
  (embedding_stress_check's churn: the same `scratch = 'x' * 1024` eval
  100,000 times grew the default region by 24 bytes each). The lexer's
  assignment count (lvt_asg) was a map write per assignment on every eval,
  for a question only a shareable_proc block asks: it is kept now only for a
  source that names `shareable_` (as `binding` gates lvd_st), and churn is
  flat again (34,404,640 bytes at 1,000 and at 100,000).
- ⚠ **Two more from round 25's CI.** (1) tools/string_pages_check.py
  compiles mkstr / mkstr_join out of m_state on their own, and the
  allocation-trace call in them was unbound there: the harness supplies the
  switch (off) beside the value tag and handle offset now. (2) test_module's
  complemented_method_entry_memory_leak timed out on Linux (10.04 s of 10):
  round 24's define_method ractor check kept a table beside dm_closenv that
  every anonymous class's methods added a key to and no sweep removed --
  4-5 % slower on that loop, and growing. The defining ractor is a mark on
  the block's env now (set only in a non-main ractor), asked only while a
  ractor runs.

## 2026-11-12 (43): round 26 -- Ruby::Box: a journal of each box's writes, and code that runs in the box it was read in

Round 26 of note 545 (§6, Ruby::Box): ruby/test_box 28 failing (RED; the 30
BOTH are setup_box's pend in the main process, ruby's too) -> 1 locally.
corpus 647.

- **What a box sees**: the booted interpreter (the master) and its own
  writes. The tables stay shared and are read everywhere as they are (several
  hundred readers); a box's writes are kept by JOURNAL (m_state, bx_note):
  the first time a box writes a key the master owns -- a top-level constant
  or one in a class there at boot, a method of such a class, its include or
  prepend, a global -- the master's value is noted under that box, and the
  box writes the table itself. Leaving a box (bx_out) saves what it wrote and
  puts the master's back; entering one (bx_in) does the reverse; a switch
  costs what the two boxes wrote. The doors: store_meth / del_meth, set_inc /
  set_pre, gvar_write, and consts_put / consts_del in the six functions that
  write a program's constants. A class made after boot is its box's alone
  (ruby's non-boxable class) and is written for everyone.
- **Which box runs**: a file read while boxes are on is marked with the box
  reading it (its SFile, "\1<box>\1<name>"); running it enters that box, and
  a call's box comes back with its file (box_put / box_take beside
  call_files_s). "<internal:...>" is never marked: the prelude's method
  bodies are parsed when first called, and they run in their caller's box,
  as a C function does in ruby. So a method, a block and a proc run where
  they were written; `box::Foo.yield_block { Ruby::Box.current }` is main.
- **Boot**: RUBY_BOX=1 marks the main script for main (box_st 0 = 2: the
  script is read before the prelude runs), and after the prelude box_boot
  records the classes there are, gives root and main load lists of their own
  ($LOADED_FEATURES and $LOAD_PATH, journaled copies), and enters main. Root
  and every Box.new load RubyGems for themselves when main did (gem_prelude's
  BUNDLER_SETUP rule), and a shipped library runs once per box (stdlib_ran).
- **The API** (prelude, Ruby::Box < Module): enabled?, current / main / root
  / master, main? / root? / master?, inspect as ruby's, eval in a fresh top
  level of the box (Box.__scope: main as self, the box in the scope, so a
  Binding made there evaluates in the box), require / require_relative /
  load, `box::X` (Box#const_missing), constants.
- A class a box makes under a name another box's class has is a new class:
  an anonymous internal name shown as the constant's (bx_int "m:" -- a class
  of no written superclass has no cls_sup entry to tell it exists).
- Two general fixes on the way: `X = Module.new; class X::Y` defines Y in
  the module (it went to a separate "X::Y"), and `MM.new::X` with MM < Module
  asks MM#const_missing without falling to the top level.
- ⚠ The emitted C hit the 1024 nesting budget twice: the first version's
  forty-odd top-level lets, then a 21-element tuple -- a tuple's elements are
  a level EACH. Six lets (a slot vec, four maps by value type, call_box);
  tools/bracket_depth_check.sh says 1009 now.
- ⚠ The journal holds Vals (a box's own $LOADED_FEATURES array): rooted in
  gc_mark_roots (bx_val), and a parked box's methods keep their metadata.
  test_mark_box_object_referred_only_from_binding (GC.stress) found it.
- Left: test_prelude_gems_and_loaded_features (ruby preloads bundled_gems
  and error_highlight at boot; stage 6 / error_highlight's), -ext-/box (C
  extensions), a fiber resumed mid-body keeps its resumer's box.
