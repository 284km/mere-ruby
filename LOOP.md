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

## 2026-11-12 (39): stage 5, parallel round A -- Ripper on values it cannot read, error_highlight through Prism, a per-object ivar index, and exceptions that keep their own frames

Run beside round 22 (stage 9) on a branch of its own, for note 545's stage 5
remainder (Ripper) and error_highlight.

- **Ripper's files tests (55) were one line.** test/ripper's parse-files
  Parser answers `Object.new` for every event, and the translation decided
  whether a call without parentheses is a command by asking the VALUE its
  argument events returned (`arguments&.any?`, prism's ripper.rb:1101). The C
  core never looks inside a handler's answer. lib/ripper_ext.rb carries
  visit_call_node with that line deciding by the node, as the receiver branch
  already did. Checked first on the reference: every .rb of ruby's lib, ext,
  test and sample through an Object.new Parser over the translation -- that
  line was the only place it broke.
- **Round 20 had made the same fix and taken it back** (mkmf.rb alone was 1.46
  GB and 190 s). Two costs behind it, both gone:
  - **Prism's Loader read the serialized bytes through StringIO, one #getbyte
    per byte** (serialize.rb's FastStringIO is ::StringIO everywhere but
    TruffleRuby), and StringIO#getbyte here is six or seven method calls on
    the state a dup shares, 20 µs each: 3 of mkmf.rb's 5.5 s of Prism.parse.
    The Loader is given the bare reader TruffleRuby's branch writes
    (Prism.serialize in lib/prism_ext.rb): 2.2x on every load.
  - **Object#inspect walked every object's instance variables** to list one
    object's (the second item of round 20's hidden linear scans, left then
    because the table had "about a hundred" writers). It has 380, through
    thirty names for world's fourth map, parameters and the global. Every
    `map_set` on it is `iv_put` now, which files a NEW key's name under its
    object (iv_idx, m_state); a delete leaves the name and the reader asks the
    table; the collector drops a dead owner's names. mkmf.rb through the
    Object.new Parser: 19.5 s -> 9.5 s user, 817 -> 782 MB.
    ⚠ The first pass at finding the writers read a match arm's guard
    (`| X when map_has ivars ...`) and a `||` as bindings and missed 63 of
    them. MERE_RUBY_IVAR_INDEX_CHECK=1 lists every object both ways and says
    on stderr where they differ: the corpus and ~90 of ruby's test files ran
    clean with it after the second pass (the first found Random's `__gid`).
    ⚠ A Map made per listing (to drop repeated names) took the same run to
    1.1 GB: a Mere Map is never given back.
    ⚠ (review) A class's ivars are in the same table under its NAME
    ("cls:AnonClass_..@"), and they were indexed too -- but the collector's
    sweep knows object owners only, so every discarded Class.new kept its
    entry, and a long first name went past the 4 KB bound: 1,200 classes with
    a 64 KB ivar name, 66 -> 209 MB. Only object ids are indexed now (the
    reader asks by object id), and the bound holds for a first name;
    loop_rss_check has the case (2.05x before, 1.04x after). The same entries
    were what the first push's CI tripped on: class_module_check's
    test_complemented_method_entry_memory_leak (300,000 turns of Class.new
    and a refinement, in 10 s) timed out. A key that is no object's is now
    written without asking the table first, and that loop runs as main's
    does (5.8 s and 5.7 s locally).
- **error_highlight goes through Prism in ruby 4.0**: AST.of raises a
  RuntimeError naming prism, and prism_find parses the file and looks for the
  node with node_id_for_backtrace_location's id. Neither existed. A frame
  here has no column and m_parse's nodes are not Prism's, so
  Exception#backtrace_locations writes on each Location the call that frame
  was making (the method of the frame inside it; the innermost one's is a
  NameError's name, or the callee's own definition for an ArgumentError of
  the arguments), and Prism.__node_id_for_location picks that call among the
  line's in the file's Prism tree. The ids are the tree's, the ones ruby's
  Prism compiler numbers: corpus 643 prints the same numbers both ways.
  ⚠ (review) A line and a name do not identify a call: `'a'.upcase;
  nil.upcase` raised from the second and the first one answered, so
  error_highlight would point at a call that succeeded. When more than one
  node answers, the id is -1 (no node, no snippet) -- unknown rather than
  wrong. (An operator write and the constant path it writes are one
  construct: `::X += 1` answers the write.) Two of error_highlight's tests
  expect no snippet for exactly such a line, and pass for it.
- **What error_highlight's tests found on the way** (each is a defect outside
  it too):
  - **An exception held as a (class, message) pair had no frames of its
    own**: #backtrace_locations read the LAST raise's, so after anything else
    raised -- AST.of's RuntimeError, raised and rescued inside spot -- it
    answered another exception's frames, or nil. `rescue => e` now makes the
    pair it binds an object carrying its frames, and `$!` that same object
    (exc_pin_bt; its text through vexc_text, which corpus 449's EUC-JP class
    name needed). A pair kept from `$!` in an ensure and compared with the
    object a later rescue made asks the object's Exception#== (test_exception's
    circular_cause).
    ⚠ (PR CI) The same in an Array: test_settracefunc's test_tracepoint
    compares the event list, which holds the pair a TracePoint saw as the
    self of Exception#initialize, with the object the rescue bound, and
    Array#== compares structurally unless an element answers a #== of its
    own -- and it looked only at the left array for one. An object made from
    a pair is marked (@__from_pair) and equals a pair of its class and
    message, as two pairs did; Array#== looks at both sides.
    ⚠ (review) The first version of that bridge asked ANY object on the right
    of a pair: `[pair] == [obj]` called obj's #== -- an object whose #==
    answers true made it true, where ruby says false and never calls it. The
    bridge goes only to an exception (exc_bridge_peer), and -- second round
    -- its #== is not asked at all: the comparison is the PAIR's
    Exception#== (exc_pair_equal: same class, its #message and #backtrace),
    so an exception on the right that overrides #== (`def twin.==`) still
    equals the pair as in ruby, and its override is not called. Its class is
    read through the singleton the `def` gave it. Third round: the
    same-class branch reads the other's STORED message and backtrace, as
    exc_equal's rb_attr_get does, and the pair's frames from the raise
    record (pair_bt_raw) -- calling #message let an override decide the
    answer and run, or raise, inside ==. Array#include? / #index took the
    structural path for them (it asks the semantic one only for an element
    or argument with an == of its own) and now asks it for an exception too.
    Fourth round: one predicate (exc_cmp_val: a pair, or an exception
    object) for every container entry point that picks between the
    structural and the semantic comparison -- the elements' check
    (elem_has_user_eq, which include? / count / delete / value? / key read),
    the argument's check of count / value? / key, Array#== and Hash#== (the
    latter looking at BOTH hashes' values; it looked at the left one only,
    so `h == g` and `g == h` differed).
    Fifth round: two exception OBJECTS -- a rescued exception and its #dup,
    with no TracePoint and no == of the program's -- were identical-or-not
    inside containers (obj_answers_eq did not count an exception, and
    rb_eq_w0 fell back to identity), and the built-in Exception#== itself
    compared the raw class names (a `def odd.message` singleton made
    `obj == odd` false) and called #message on both sides. It is now ruby's
    exc_equal: identical; else the same class (rb_obj_class, through the
    singleton) compares what both HOLD (exc_same_class_equal: the stored
    message and backtrace, for pairs and objects alike); else the other
    converted by #exception, whose #message / #backtrace are asked, as
    rb_check_funcall does. corpus 643 has the pair/object matrix, all four
    ways round.
    corpus 643 has the three rounds' witnesses, `include?` and a nested
    Array included.
  - **A pair's #detailed_message / #full_message went past the program's
    own** (error_highlight prepends one to TypeError and ArgumentError), and
    super from one did not reach Exception's.
  - **A Location read from "f.rb:3:in 'T::M.baz'" had the path "f.rb:3:in 'T"
    and line 0**: the last colon of the string was the label's. It is cut
    where ":in '" starts.
  - `nil[0] = 1`'s message lacked " for nil"; `+nil`, `-nil`, `+:a` answered
    their operand (NoMethodError now); `A::NotDefined::Foo` is the head's
    NameError ("uninitialized constant A::NotDefined"), and `B::Nope` inside
    `module A` is named A::B::Nope.
- **Ripper's #parse reports as parse.y does** (lib/ripper_ext.rb): a magic
  comment's `-` is `_`; a warning goes to #warn where parse.y's is rb_warn and
  to #warning where it is rb_warning, with parse.y's format and arguments (the
  translation had the two levels the other way round and passed the message
  as the format); an ambiguous binary operator is operator_ambiguous; the
  lexer's errors are #compile_error in parse.y's words; and when the only
  errors are ones parse.y builds the tree through (a write to $&, self or a
  constant in a method, alias of $1, a formal argument, an endless setter,
  a misplaced retry) the tree is built and the write wrapped in assign_error /
  alias_error. A heredoc's end token has the state its body left.
  ⚠ The fast loop for all of this was the reference itself: test/ripper run
  on ruby 4.0.9 with ::Ripper replaced by the translation and
  lib/ripper_ext.rb (ripper's names added to $LOADED_FEATURES so the C
  extension is never loaded), seconds per file; mere-ruby then differs only
  where the interpreter does.
- **Left, measured**: test_ast's tree (107: a parse.y-shaped AST built from
  Prism's -- and test_ranges / test_not_cared parse all 869 test files, which
  today pass by having no children; a real tree in Ruby at today's ~250 µs a
  node would not fit 600 s / 2 GiB, so Prism's load wants building in a Mere
  builtin first, as all_tokens is); a bare name with a builtin value as self
  is NoMethodError, not NameError (prim_self_send); IO#lineno=; `::E += 1`;
  scanner events during #parse (ignored_nl, heredoc_beg), lex_compat's escape
  splits and embexpr_end, `/[\xC0-\xF0]/u` not refused. Seen and not
  touched: `1 + nil` pushes no Integer#+ frame (`1.+(nil)` does); ruby loads
  error_highlight at boot and mere-ruby does not; a `case` declares every
  when-body's locals each time it runs (declare_nils, a tenth of Prism's
  load).
- **Checked** on Mere v0.1.731, rebased on round 22: corpus 674/674 with the
  ivar index check on; loop gates (bracket depth 977 of 1024, dead defs, gc
  roots). Locally, against round 21's CI: ripper's six files 55/55 (lib 119 s
  and test_2 83 s, under 1 GB -- 257 s and 242 s before the index),
  parser_events 165 -> 197, error_highlight 1 -> 107 (274 s), test_ast 2,557
  -> 2,559 (313 s, 864 MB; round 20 recorded 1.1 GB); and with the index
  check on, the files the changes touch (exception, backtrace, keyword,
  method, proc, object, struct, module, marshal, class, eval, syntax,
  iterator, fiber, thread, io, array, hash, string, numeric, range, regexp,
  require, refinement, lambda, variable, const, autoload, super, pp,
  delegate, timeout, json, did_you_mean, prism's ripper_test) at or above
  round 21's counts (test_keyword needs a -test- extension the local
  reference does not have; test_array's shared_marking is the reference's
  known wobble).

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
  call_files_s). "<internal:...>" is never marked -- by name: the prelude is
  parsed after the main script (driver_setup), when files are already being
  marked -- and it runs in its caller's box, as a C function does in ruby. So a method, a block and a proc run where
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

## 2026-11-12 (44): round 27 -- Coverage over the interpreter's own counts, and line events where ruby puts them

Round 27 of note 545 (stage 10's coverage): coverage/test_coverage 46 RED
(the file died on `coverage.so`) -> 12 locally, all ten branch tests and
the two that need ruby's line for a multi-line statement's event. corpus 648.

- **Coverage** ships as Ruby (lib/coverage_ext.rb through
  gen_pathname_lib.rb, `require "coverage"` and "coverage.so") over natives
  on Coverage: setup / start / resume / suspend / result(stop:, clear:) /
  peek_result / state / running? / supported? / line_stub with ruby's
  refusals and the compatible mode's bare Array.
- **Lines**: a file read while coverage is set up (require, load; an eval
  given a file name with eval: true, numbered from the line given; the main
  script when -r started it, its lines noted by parsing it again) is
  covered. Its executable lines are the parser's SLine marks (cov_note) --
  exactly where TracePoint's :line fires, so the two cannot disagree -- and
  each SLine run counts (cov_line: the statement arms, the class-body walker
  and the native definition paths that replay positions). oneshot_lines keeps
  the first-run order; clear leaves a oneshot line run, as ruby's hook is
  gone.
- **Methods**: counted where a method body starts (run_meth_result, and
  call_method for a top-level one), an alias's calls for its original
  (alias_srcname); the result's [owner, name, first line/column, last
  line/column] is the definition read with the shipped Prism -- a def, a
  define_method's block, or the proc handed to it.
- **Line events where ruby puts them** (TracePoint too): a literal statement
  whose value nothing uses -- not last in its list, or last in a branch of
  an unused if / case / while body -- compiles to nothing in ruby and has no
  :line event (void_marks makes its SLine an SLineQ); an endless def's body
  marker is an SLineQ (it sets the line for caller(0), no event, no count);
  TracePoint#lineno of an eval numbered from below 1 is unbiased (it said
  1073741822 for -2).
- General fixes on the way: `define_method(:m, &pr)` reports the proc's
  source_location; Array/Hash#inspect asks a String subclass's own #inspect
  (test_coverage's DummyConstant is `def inspect = self`).
- Left: branch coverage (the structure needs each if / while / case / &.
  target's execution tied to Prism's node; the AST keeps no position), and
  the line of a multi-line statement's event (ruby's is its first
  instruction's: `FOO = [` with a hash on the next line fires on that line).

## 2026-11-12 (45): round 28 -- the stage 3 tail's Ractor edges, ENV as an object, and immediates interpolated as ruby 4.0 writes them

Round 28 of note 545: the stage 3 tail (31 files, 51 RED in round 25's CI)
run locally, its Ractor and object items fixed; ruby/test_ractor 4 -> 0,
test_env 1 -> 0, etc/test_etc 1 -> 0, io/console/test_ractor 1 -> 0, and
test_optimization's objtostring / optimized_rescue. corpus 649.

- **A non-main ractor**: `fork` is Ractor::IsolationError ("can not fork
  from non-main Ractors", rb_fork_ruby); Etc's database calls -- what
  etc.c defines after RB_EXT_RACTOR_SAFE(false) -- are Ractor::UnsafeError;
  ENV's instance variables are refused (ENV is shareable and not frozen),
  through instance_variable_get as through `@x`; each ractor has its own
  default ThreadGroup, made when first asked (dfl_tg_of).
- **make_shareable**: a Method's error names it as it inspects -- through a
  singleton class too (`def m.to_s` on one no longer printed the object's
  bookkeeping) -- "because it refers unshareable objects"; a Hash's or a
  Method's #to_proc is ruby's C-function block, refused "not supported yet"
  before its self is looked at (vm.c's order).
- **ENV is an object of its own** to instance_eval / instance_exec and to
  instance_variable_get/set (they went to a Hash copy of the environment).
- **Immediates**: `"#{x}"` where x's #to_s answers no String is rb_any_to_s
  for nil, true, an Integer and a Symbol too (their address is the object
  id in ruby 4.0), and nil's object_id is 4 (Qnil in 4.0; 8 was 3.x's).
- `ruby ""` reads the program from standard input, $0 "-" (ruby treats an
  empty script name as `-`; assert_in_out_err("", ...) passes one).
- IO#console_mode / #console_mode= and IO::ConsoleMode (echo=, raw, raw!,
  dup) over the termios the io/console port already reads -- a stream that
  is no terminal is its errno.
- RubyVM.keep_script_lines as the option it is.
- ⚠ **Backticks in several threads read one another's output**: a backtick
  off the main thread runs through Process.__bt_async, which named its
  output file from a counter taken in two steps -- two threads met in
  between and shared a file (`echo 4` answered "3\n"). Found as test_etc's
  ractor_parallel failing now and then (ten ractors asking getconf through
  Etc.sysconf), on Linux CI and here. The counter is taken once, and the
  file is the thread's.
- Left in the tail, on purpose: the heap-shape ones (size pools, embedding,
  shapes, memsize, warmup's old/compact), the memory-leak tests that time
  out on this interpreter's speed, callcc, `<internal:gc>`'s line event,
  three that depend on which earlier test loaded tmpdir/tempfile (ruby
  errors too when they run alone), and two performance items found here:
  a compare_by_identity Hash has no index (every lookup walks it), and
  #instance_variables walks every object's ivars -- test_object_id_race_free
  times out on both.

## 2026-11-12 (46): round 29 -- a compare_by_identity hash indexed by identity, and Ractor._require as main's

Round 29 of note 545: two things round 28 and round 27's CI turned up.
corpus 650.

- **compare_by_identity had no index**: the content digest makes two equal
  Strings one key, so marking a hash dropped its index for good and every
  lookup walked the pairs -- 2,000 object keys 0.125 s, 4,000 0.476 s
  (Ractor.make_shareable's `seen`, __deep_copy's, Marshal's). The index now
  keys such a hash by identity (hkey_ident: an object's, a String's, an
  Array's or a Hash's handle; an immediate's value; a Float walks, 0.0 and
  -0.0 being two objects) at every index door (hkey_dig), a container key
  needs no "is it still equal" check there, compare_by_identity and a
  derived hash (hcbi_copy) build the identity index in place of the content
  one. 8,000 keys: 0.024 s. The corpus agrees with the index on and off.
- **Ractor._require** called Kernel#require inside the ractor: with
  RubyGems loaded that is RubyGems' Ruby require, which reads Gem's class
  ivars, and a non-main ractor is refused them (bootstrap test_ractor #112,
  `require 'tempfile'` through a prepended require, red in round 27's CI).
  The whole call now runs as the main ractor's (__as_main_require, the
  do_require trick around the call), as ractor.c hands it to main.
- ⚠ A prelude class method calling a native of its own class by implicit
  self (`__as_main_require(f)`, `__gems`) does not reach the native: it hung
  here. Call it as `Ractor.__x` / `Box.__x`.
- Left: #instance_variables still walks every object's ivars (no per-object
  list to keep in step at ~330 write and ~50 delete sites);
  test_object_id_race_free stays slow for that. Bootstrap test_ractor #153
  (1,000 ractors, 35 s here) and #99 sit at the runner's time limit.

## 2026-11-12 (47): round 30 -- RubyVM::InstructionSequence compiled for real (note 548, stage 10)

Round 30 of note 548: the first stage-10 round. A sequence from source is
now compiled from Prism's tree to ruby 4.0.9's instructions (lib/
iseq_compiler_ext.rb, shipped as `__iseq_compiler` and required when a
sequence is first asked for to_a, disasm, each_child or trace_points). It
ports prism_compile.c, the parts of compile.c's backend it needs (peephole,
specialised instructions, operand unification, the stack depth, the
layout) and iseq.c's to_a and disasm. corpus 651.

- **What it compiles**: literals, locals, ivars, globals, constants, string
  interpolation, arrays (pm_compile_array_node's chunks and splats), hashes,
  ranges, regexps, calls (arguments, one splat, keyword arguments, a block
  argument, a literal block, attribute writes with setn, `&.`, opt_new,
  opt_str_freeze / opt_str_uminus, getblockparamproxy), if / unless / while
  / until / break / next, case (opt_case_dispatch's hash, the `===` chain,
  splat `when`s, a case with no subject), `for`, ||= / &&= on locals and
  ivars, def and singleton defs (every parameter but a destructured one,
  `...`, and a keyword default that is not a literal), class, module and
  `class << x`, return (top level too), yield, the line / call /
  return / class / end / b_call / b_return events.
- **Compile options**: ISeq.compile's fifth argument as make_compile_option
  takes it (false, true, a Hash). Off, peephole_optimization,
  specialized_instruction, operands_unification and inline_const_cache
  each turn off what they do; a tail call and instruction pairs are refused.
- **Refused** with NotImplementedError naming the node: rescue / ensure,
  super, defined?, multiple assignment, return / break / next out of a
  block (they need the catch table), constant paths through a value,
  pattern matching, and the rest. Nothing is emitted that was not derived.
- **Checked against ruby itself**: tools/iseq/compare_with_ruby.rb compiles
  each of tools/iseq/snippets.txt (87, some under `#opt:` compile options)
  with ruby 4.0.9 and with this compiler and compares to_a and disasm byte
  for byte: 87 exact. Found on the way: disasm's header line is the code
  location's, not first_lineno; an `ic:` index counts past the ivar caches;
  two labels on one position are one in to_a; a jump turned into the leave
  it jumped to takes that leave's events; compile.c goes on past a pop it
  kept.
- **What it moved**: prism/newline_test 52 -> 16 failing, ruby/test_iseq
  36 -> 33, ruby/test_syntax 1 -> 0. The six tests the empty stand-in
  passed by coincidence pass again (case, class << self, top-level return,
  for, `**nil`, compile option false).
- Not yet: the VM. The instructions are not executed; ISeq#eval still runs
  the source the way the program runs (note 548 §3). Next: the catch
  table and the nodes refused above, then the VM.

## 2026-11-12 (48): round 31 -- the catch table, rescue / ensure, super, defined?, and compile.c's peephole rules

Round 31 of note 548: the ISeq compiler's second round. corpus 652.

- **The catch table** as compile.c keeps it: entries pushed as ADD_CATCH_ENTRY
  pushes them (start unremovable, end and cont referenced), kept only when
  the sequence may catch something (a throw in it or in a sequence inside
  it, or an entry other than break / next / redo -- update_catch_except_
  flags); to_a and disasm show it, each entry's sequence under it one "| "
  deeper. A block has its redo / next entries and start / end labels, a
  while loop its break / next / redo, a call whose block keeps a table a
  break entry, super always one. An ADJUST makes its label unremovable.
- **Out of blocks**: break throws TAG_BREAK, return TAG_RETURN, next jumps to
  the block's end; from a rescue or ensure sequence, break / next are thrown
  to the block or loop around (VM_THROW_NO_ESCAPE_FLAG for a loop's).
  iseq_optimize's leading nop of a block goes unless a throw or a jump back
  needs it.
- **rescue / else / ensure, `x rescue y`, retry**: the rescue clauses and the
  ensure clause as sequences of their own ($! their one local, the RESCUE
  event), the ensure clause also inline after the body (compiled first,
  as pm_compile_ensure does), iseq_insert_nop_between_end_and_cont. Leaving
  an ensure region by return / break / next is refused (pm_add_ensure_iseq
  inlines the clause there; not yet).
- **super and zsuper** (the method's own parameters read where they are),
  **defined?** (with its "defined guard" rescue sequence, and true as the
  answer in a condition), **->{}**, **multiple assignment** (the target
  state's topn fixed after the writes), a block body with rescue.
- **compile.c's peephole and specialisation, per element as iseq_optimize
  runs them**: opt_ary_freeze / opt_hash_freeze, opt_newarray_send (max,
  min, hash, pack, pack with buffer:, include?), opt_duparray_send,
  newarray / duparray + expandarray, string-literal ranges, the
  concatstrings rules, dup / getlocal / setlocal, getblockparamproxy before
  a branch, the KW_SPLAT_MUT rule, a branch before a jump to the same place
  as a pop, opt_neq's two calldatas, FCALL sends specialised too. String
  interpolation as pm_interpolated_node_compile joins it.
- **Checked against ruby itself**: 181 snippets exact (tools/iseq).
- **What it moved** (against round 30): ruby/test_optimization 15 -> 8
  failing (opt_duparray_send / opt_newarray_send include?, the freeze and
  string-range peepholes), prism/newline_test 16 -> 10, ruby/test_iseq 33
  -> 33. test_settracefunc's single_raise_inside_load and
  tp_ractor_local_untargeted fail alone on main too (FileUtils not yet
  required; the test order decides).
- Not yet: the VM; ensure inlining; pattern matching; interpolated regexps;
  a splat with keywords; class variables.

## 2026-11-12 (49): round 32 -- every call argument shape, the op-assigns, alias / undef / backticks, and the parameters left

Round 32 of note 548. corpus 653.

- **pm_setup_args as a whole**: keyword hashes with any key and ** (KW_SPLAT
  / KW_SPLAT_MUT, pm_compile_hash_elements, which hash literals now share),
  several splats, a splat with keywords (compile.c's splatarray false +
  duphash rule is reached now), *, ** and & passed on, `...` both through
  its locals and in a forwardable method (sendforward, invokesuperforward),
  splatkw, yield and super through the same setup.
- **The op-assigns**: $g / C / A::B / r.x / r[i] with ||=, &&= and op=, &.
  included; constant paths through a value and constants without the
  inline cache (pm_compile_constant_path); alias (methods and globals),
  undef, `backticks` with and without interpolation.
- **Parameters**: destructured ones (the hidden locals, expandarray before the
  body), `...`, keyword defaults that are not literals (checkkeyword).
- Found by comparing about 27,000 methods of ruby's lib/ and test/ against
  ruby: getblockparam / setblockparam only for the method's own block
  parameter; `initialize` is use_block; a def or `class << x` has no
  parent_iseq, so a rescue in it gives the block around no catch table.
- Each_child takes the catch table's sequences first (iseq_iterate_children):
  a line inside a rescue clause was missed.
- **Checked against ruby itself**: 383 snippets exact. prism/newline_test
  passes whole (54 / 54; 52 failing on main), ruby/test_iseq 33 -> 31,
  ruby/test_optimization 8 -> 7.
- Still refused: shareable_constant_value beyond `X = literal`, pattern
  matching, interpolated regexps, class variables, ensure inlining; the VM.

## 2026-11-13 (50): round 33 -- the VM's first form: ISeq#eval runs a top-level sequence's instructions

Round 33 of note 548 (§6). corpus 654.

- **The VM** (main.mere, `and` members of the eval_e chain; entered as
  RubyVM::InstructionSequence.__vm_run with the sequence's to_a): the body
  decoded once (labels to indices), a value stack and a pc, its own
  top-level frame (backtraces as ruby's), locals by name through the
  local table. ISeq#eval runs a :top sequence on it when every instruction
  is one it has: the stack and literal instructions, locals (level 0),
  ivars, globals, constant reads and a top-level constant write, sends
  (FCALL / VCALL, keywords, splats, &.) and every opt_* that is a send,
  the freeze / newarray / duparray forms, interpolation, splat / concat /
  expandarray, jump / branchif / branchunless / branchnil / leave,
  opt_case_dispatch (its key popped and the `===` sends that follow run,
  ruby's own path when === is redefined), opt_new (its plain send).
- **A send is the parser's expression for it** (EBin / EUn / ECall /
  EMethod / SPuts) evaluated with the values in hidden locals: invoke_val_c
  alone skips EMethod's frozen, chilled-string and in-place paths. Each
  send's hidden scope is pooled and given back; the stack's live values are
  rooted. Peak memory does not grow with the loop.
- **Refused, the whole sequence before it starts** (it runs on the evaluator
  as before): blocks, definemethod, defineclass, throw, invokeblock,
  invokesuper, checkmatch, defined, a kept catch table, a local above level
  0, a block argument, Kernel functions that read the caller's frame, a
  TracePoint hook, the frozen-string-literal debug options, and a
  sequence the compiler refuses or fails on. `MERE_ISEQ_VM=strict` raises
  instead of falling back; `#__vm?` says which way it would run.
- **Checked**: tools/iseq/vm_check.sh compares ruby's ISeq#eval with this VM
  (strict) on 61 snippets: 61 / 61. The compiler took a symbol's encoding
  from Prism's forced-encoding flags (parse_string_symbol): a US-ASCII
  source's `:"\xC3\xA9"` raised EncodingError (test_compile_prism's
  test_SymbolNode). ⚠ `:"\xC3\xA9"` in a UTF-8 source is BINARY in ruby
  though Prism's flag says UTF-8: not matched yet, not among the snippets.
- **The cost**: every ISeq#eval now compiles its source with the Ruby-written
  compiler -- 0.5 s and ~220 MB to load it once, then ~15 ms to parse and
  ~30 ms to compile a few lines. test_compile_prism 4 s -> 85 s (within
  the 600 s bound). The VM's loop is about twice the evaluator's time.
  Both are for later rounds (note 548: the target is the evaluator's speed).
- Next: blocks (a small AST forwarder into run_block), def / class, the
  catch table (try_or and flow_sig), line / call events.

## 2026-11-13 (51): the VM is handed over -- round 34 on is the Fable session's

By the user's decision (note 550 §2), the VM goes to a Fable session from
round 34, which carries it on to stage 11 (the JIT). The state it is handed
over in is note 548 §8; in short:

- main `1f007da0` holds rounds 30-33 (the ISeq compiler, 383 snippets
  exact against ruby, tools/iseq/compare_with_ruby.rb; the VM's first form,
  61 / 61, tools/iseq/vm_check.sh, MERE_ISEQ_VM=strict). No branch holds
  unmerged work.
- Next, in this order: blocks (an AST forwarder into run_block), def /
  class (definemethod, defineclass), the catch table (try_or and
  flow_sig), line / call / b_call / c_call events and Coverage, then whole
  files on the VM, then speed, then stage 11.
- The traps as they stand: the compiler's first load 0.5 s / ~220 MB and
  ~45 ms per short source on every ISeq#eval; test_compile_prism 4 s -> 85
  s; the VM's loop about twice the evaluator's; a send must go through the
  parser's expression, not invoke_val_c alone; the bracket depth at 1012 /
  1024 (VM functions are `and` members of the eval_e chain). The
  compiler's known gaps and refusals are listed in note 548 §8.

## 2026-11-13 (52): the rubygems round -- the non-native rubygems failures

The first round after the VM went to the Fable session (note 550): the
rubygems failures that are not native extensions. corpus 655.

- **Sorting the 67 RED of CI** (round 33): the native ones -- extconf /
  mkmf (`mkmf.rb:6689`, an RbConfig key it adds to), make, cargo -- are
  stage 7′ / 8's (the Fable session's). test_gem_commands_exec_command's
  28 are among them: its one native test builds an extension, fails, and
  MockGemUi's TermError is a SystemExit, which ends the runner (CRuby too,
  were that build to fail). Locally, rubygems tests need ruby's lib/ first
  on RUBYLIB as unittest/run.sh gives it, and a binary named mere-ruby (a
  bin wrapper's shebang must say "ruby").
- **`recv.meth arg, &blk` passed the block as an argument**: a `break` in it
  no longer ended the method it was given to (`recv.meth(arg, &blk)` and
  `meth arg, &blk` were right). rubygems' Util.traverse_parents (`Dir.chdir
  here, &block`) walked on past the Gemfile it had found:
  BundlerVersionFinder never read the lockfile (test_gem's
  activate_bin_path_selects_exact_bundler_version_if_present).
- **File.open with an integer mode or a permission** first creates the file
  (for O_CREAT and the perm); in a read-only directory that step failed
  with no Ruby exception, and the open came out as "(ruby exception
  raised)" instead of Errno::EACCES. FileUtils.cp opens that way:
  RemoteFetcher#download's fallback for a read-only cache
  (test_download_local_read_only). `MERE_RUBY_LOST_EXC=1` named the place.
- **Default gems**: rubygems loaded from source (`-I lib`) built
  Gem.default_dir from RbConfig's fictional /usr/lib/ruby, and found no
  default spec. rubylibprefix is now taken from the standard library
  RUBYLIB hands mere-ruby (`<x>/lib/ruby/4.0.0` with its default specs
  beside it) when GEM_HOME is no gem tree; rubylibdir and the shipped
  libraries' directory stay as they were. And that library goes where
  ruby keeps its own, after site and vendor in $LOAD_PATH, not in front:
  in front of rubygems' insertion point it was "-I beats a default gem",
  and `require "json"` never activated the default json spec
  (test_realworld_default_gem).
- Left, with their reasons: test_activate_via_require_respects_loaded_files
  (File.realdirpath of the fictional rubylibdir follows macOS's own
  /usr/lib/ruby symlink into the system Ruby framework);
  test_realworld_upgraded_default_gem (a newer json in GEM_HOME is
  activated -- 999.99.9 -- but `require "json"` loads the shipped json, as
  it is meant to: a real json gem's json.rb goes on to its C extension).
- Locally: test_gem 1 -> 0, test_gem_remote_fetcher 1 -> 0, test_require
  3 -> 2 non-native.

## 2026-11-14 (53): the stage 3 tail -- what is left, file by file, and the stack size

The RED of CI (main `407b07b3`) outside every other stage: 45 in 27 files.
Run with `unittest/try.sh` (run.sh's environment: bootstrap.rb's preloads,
the seed), not by hand -- by hand, test_eval's tmpdir and test_settracefunc's
FileUtils looked like defects. corpus 656.

- **Fixed: RUBY_THREAD_VM_STACK_SIZE and RubyVM::DEFAULT_PARAMS**
  (test_thread's test_vm_machine_stack_size and test_stack_size). The size
  is read as vm.c's get_param reads it (atol, the 16 KB minimum, rounded up
  to 4 KB), before the prelude, and the call depth budget follows it: 15000
  calls for the 1 MB default, in proportion, never under 2000 (the prelude
  and rubygems run in the same budget), never past 19000 (each stack's
  depths are a band of 20000). DEFAULT_PARAMS has the two thread sizes that
  are this interpreter's own: that size, and the machine stack a thread runs
  on -- a thread's root is a coroutine, and mere.toml gives every coroutine
  512 MB. The budget is a slot (call_depth_v) the depth checks read: m_state
  cannot read ENV (env_get is m_eval_leaf's, through a subprocess).
- **Not this stage's**, each with where it belongs:
  - GC internals (stage 9, not fabricated; the user's call): GC::
    INTERNAL_CONSTANTS (test_file_exhaustive, test_string ×2, test_struct
    ×2), objspace's "embedded" / "old" flags (test_object, test_process ×2),
    GC.stat's compact_count / heap_available_slots (test_process ×2), and
    every "compaction is not supported" skip (test_weakmap, test_weakkeymap,
    test_set, test_proc, test_method, test_io_buffer, test_eval).
  - Speed (stage 10 / 11): the assert_no_memory_leak tests at the runner's
    10 s (test_alias, test_hash, test_io, test_settracefunc ×3, test_syntax,
    socket/test_addrinfo).
  - The native stage: `require '-test-/class'` (test_class
    test_redefinition_mismatch), cgi's C extension (test_cgi_escape ×2).
  - Stage 5: RubyVM::AbstractSyntaxTree::Node#empty? (test_pp).
  - Fibers' sizes (test_stack, already in the VM row): a fiber's budget does
    not follow RUBY_FIBER_VM_STACK_SIZE yet, so DEFAULT_PARAMS reports no
    fiber size.
  - callcc re-entry (test_array ×2, test_hash's skips): KNOWN_GAPS.
  - An IO nothing references is not collected, so its finalizer never
    closes the descriptor (test_io autoclose_*_closed_by_finalizer, two
    skips; a plain object is collected): GC lifetimes, stage 9.
  - Object shapes: Warning[:performance]'s "reached 8 shape variations"
    (test_object) describes CRuby's shape tree.
  - Noise (unittest/README "Known noise"): test_settracefunc
    tp_ractor_local_untargeted, test_thread's interrupt test, the ±1 of
    test_object_id / test_module / test_class / test_integer, test_fiber
    test_fatal_in_fiber and test_process test_rlimit_nofile (both fail on
    the reference here too).

## 2026-11-15 (54): Prism's node tree is built by the interpreter, not by Prism's Ruby loader

The first half of stage 5's second part (note 550 §1, note 551). `Prism.parse`
here is libprism's serialized answer read back into Prism::Node objects, and
the reading was Prism's own generated Ruby -- `Serialize::Loader#load_node`,
a `case` of 151 arms with a method call per field. Run by this interpreter it
was 230 µs a node, which is why RubyVM::AbstractSyntaxTree could not be given
a real tree: test_ast parses ruby's 850 test files more than once, and the
loading alone was past the 600 s a file has on CI. corpus 657.

- **The loader is Mere now** (m_prism_load.mere, `Prism.__prism_load_node`):
  one pass over the same bytes at the same position, each node made as `new`
  would have made it -- an object of the node's class with the instance
  variables its `initialize` assigns, in that order -- without a line of Ruby
  run. What a node is made of is not written in it: m_prism_schema.mere is
  generated from Prism's own `config.yml` (tools/gen_prism_schema.rb, the
  file Prism's templates generate node.rb and serialize.rb from), so a new
  Prism regenerates the table. The line offsets and the walk to the end of
  the constant pool, the loader's two other loops that run once per line and
  once per name, are read the same way. `freeze: true` (every Location made
  at once, everything frozen) still runs the generated Ruby.
- **Measured** (this machine, -O2, ruby's `test/**/*.rb`: 850 files, 8.0 MB,
  1,016,782 nodes, one process, each tree dropped after its file):
  `Prism.parse_file` over all of them 234 s -> 9.0 s, 230 µs -> 8.9 µs a
  node, with libprism's own parse inside that; peak RSS 547 MB -> 325 MB.
  mkmf.rb (10,907 nodes) 2.73 s -> 0.11 s. The reference does the 850 files
  in 0.6 s.
- **A node's instance variables are filed once.** The index of an object's
  instance variable names (iv_idx, note 547) grew by one name per write; a
  node has a dozen. `iv_file_new` files a new object's whole entry -- the
  names are known from the table -- and `iv_put_new` writes under it.
  `MERE_RUBY_IVAR_INDEX_CHECK=1` holds it to the table as before.
- **Checked**: every file of test/prism, test/ripper and
  test/error_highlight (76 files, 14,123 tests) gives the same MATCH and RED
  as main's CI run 43548292351, file by file. Every node of the 850 files'
  trees -- 1,016,782 nodes: its type, flags, node id, location and each
  field, a String by its encoding and bytes, a Float by its bits -- is the
  one the reference ruby's Prism makes (`tools/prism_tree_dump.rb` run on
  both, compared with diff: no file differs).
- **Found beside it: `unpack("D")` lost the sign of -0.0.** flt_from64 /
  flt_from32 negated with `0.0 - x`, which is +0.0 for a zero, so Prism's
  FloatNode for `-0.0` held 0.0 (the Ruby loader reads doubles with
  unpack1). Fixed where it was; the new loader does not go through unpack.
- Not done here: the tree RubyVM::AbstractSyntaxTree answers. That is the
  translation from Prism's tree to parse.y's, in progress on its own branch
  (note 551).

## 2026-11-15 (55): the native extension prototype is taken in -- stage 7′ / 8 starts from it

The first unit of the C extension stage (note 550 §3, note 553): the
prototype another session had built and left unpublished is on main's
line now, checked, and in CI. It does not change what the unit tests
measure yet -- `-ext-` and mkmf wait for the C API proper, which is built
on this from the next round.

- **What came in** (prototype/native-target-config, 8 commits on a base 274
  commits behind main): a table that keeps Ruby values alive while C holds
  them; a boundary where an exception or a `throw` raised under a C function
  comes back to C first, so `rb_ensure`'s cleanup runs before it goes on;
  TypedData with dmark called for live owners and dfree at the sweep;
  `rb_define_*` registering into the ordinary method tables and `require`
  opening a `.bundle` and calling its `Init_`; an opt-in RbConfig that lets
  ruby's own mkmf.rb write a Makefile and build; the environment mkmf's 17
  test files need; and headers generated for the target compiler with
  compile-only size checks. All of it is under tools/native_probe/ and
  described in tools/native_probe/NATIVE.md. The value C sees is a 32-bit
  token, not CRuby's VALUE: Ruby's own ext/-test-/float, exception and
  typeddata sources compile unchanged against the probe header, and little
  else does.
- **The merge**: 5 files, 12 places. The collector had changed most (class
  and metadata passes, the live set no longer a map): the TypedData owner
  visit sits in the new drain, the native sweep after the fixpoint asks
  gc_live_has. The rest is both sides kept. The prototype's README sections
  moved beside the probes; its two writes to the ivar table go through
  iv_put; corpus/516_string_format_super.rb is gone (526 is the same
  witness, grown, from PR #50).
- **One contract no longer held**: a ZeroDivisionError raised under
  `rb_ensure` must be the same object in the cleanup's `$!` and in the
  `rescue => e` after it. Since the prototype's base, a rescue makes the
  object out of a class-and-message pair (exc_pin_bt), so the two were a
  pair and an object. The boundary now makes that object when it captures
  the exception.
- **Checks** (all on this machine, O2 build): the prototype's own --
  ensure_check 9 runs, typeddata_check 9, loader_check 7, mkmf_check (ruby's
  nextafter.c built by mkmf and its 400 tests through `require`), 
  configure_headers_check 7 -- each with its negative controls, are a step
  of CI's corpus job now. The corpus matched 687 of 687 (run before the
  duplicate witness was removed; 686 remain). The embedding archive
  links the five bridge sources too (tools/native_probe/native_build_flags.py
  lists them once for build.sh's two other callers).
- **Not done here**: mkmf_suite_check (mkmf's 17 files on both sides) needs
  the reference's static libruby, which this machine's reference
  installation does not have; CI's unit test run measures test/mkmf on both
  sides as before. Bracket depth is 895 of 1024 (878 on main): the probe's
  tables are top-level values, and the next round replaces them.
- **What CI and the review found** (PR #83):
  - Linux's corpus job failed on `corpus/403_bigdecimal.rb`. The prototype
    had changed the file name `require "x.so"` looks for from `x.so.rb` to
    `x.so`; on Linux the reference's own `bigdecimal.so` is on the load
    path, and it was read as Ruby source. The name is main's again, and a
    `.bundle` / `.so` is asked whether it was compiled against this
    interpreter's header before it is a candidate for a feature at all (a
    library built for another ruby is passed over; what provided the
    feature before -- a .rb, the shipped library -- still does).
  - A negative C int could not come back from `NUM2INT`: the answer of a
    request to the interpreter was one number, positive a value's token and
    negative an exception's, so -1 read as an exception and INT_MIN
    aborted. The int travels beside the answer now, range-checked on the
    interpreter's side; the loader contracts gained INT_MIN, -1, 0, INT_MAX
    and an out-of-range value (41 -> 46 shared checks).
  - Asking a file whether it is an extension loaded it. The question added
    for the Linux failure above was a `dlopen` and a `dlclose`, so a library
    that was accepted ran its constructors, its destructors and its
    constructors again before `Init_`, and a library built for another ruby
    had its constructors run here. The file is read for the name every
    extension compiled against the header defines, and the library is opened
    once, when it is loaded; the number behind the name is compared then.
    The loader fixture writes down its constructor, `Init_` and destructor:
    "constructor, Init" after the first require and "constructor, Init,
    Init" after a reload, on both sides (46 -> 48 shared checks). Against
    the previous head the first of those fails with "constructor,
    destructor, constructor, Init".
  - The Wasm build's source tree (tools/nothreads_tree.sh) copies top-level
    .mere files only and could not find the externs under
    tools/native_probe/. Every native extern is declared in
    m_native_api.mere now, and the tree gets m_native_none.mere in its
    place: the same names as functions that answer "no library". `mere -w`
    emits again.
  - embedding_stress_check.py has a link line of its own: the bridge
    sources go there too.
  - The collect-at-every-safepoint runs of loader_check.py and
    mkmf_check.py have only the contracts' library on the load path: with
    the standard library there, a refused require goes on through RubyGems'
    search, which is minutes at that load.

## 2026-11-15 (56): rounds 34-37 -- the VM runs blocks, methods, classes, rescue / ensure, and fires events

Rounds 34 to 37 of note 548 (the record from here on is note 552). corpus 658, 659.

**In one line**: `RubyVM::InstructionSequence#eval` now runs on the VM a
sequence that has blocks, defines methods and classes, calls super, and
rescues, ensures and retries, with a TracePoint or Coverage on as well --
230 snippets identical to ruby 4.0.9 with the VM forced
(tools/iseq/vm_check.sh, was 61); the compiler is 413 / 413 against ruby
(tools/iseq/compare_with_ruby.rb, was 383). What the VM cannot
run it still refuses whole, before the first instruction, and the sequence
runs on the evaluator.

- **A sequence's parts are programs of their own, run in the evaluator's
  frames.** A block's, a method's and a class body's sequence is decoded
  once into a program (vm_code / vm_meta, m_state.mere), and the evaluator
  is handed the SAME statements its parser would have made -- EMethodB /
  ECallB with the block, SDef, SClass / SClassE / SSingletonE, ESuper,
  SVis, SAlias, SUndef -- whose body is one statement, `SVm`, that runs the
  program. So a block's frame and arity, break / next, a Proc made of it,
  a method's key, visibility, method_added, `super`, reopening a class are
  the evaluator's, once; only what the body does is the VM's. Parameters
  are bound by the evaluator from the sequence's own table (vm_params); an
  optional parameter that was not given is bound to a marker (EVmArg) and
  the sequence's own default code runs, entered at the label for how many
  were given.
- **rescue / ensure are the evaluator's begin, given functions.** run_begin
  is now a wrapper over run_begin_f, which takes the body, the rescue
  clauses, the else and the ensure as functions. The VM hands it a catch
  table entry's protected instructions and its rescue / ensure sequence
  (vm_region), so `$!`, retry, an ensure's own escape and what a pending
  exception means are one implementation. A break / next / redo / return
  thrown out of a rescue or ensure sequence travels as a flow signal, so
  the ensures between it and where it lands run (vm_jump, vm_seg).
- **The compiler** (lib/iseq_compiler_ext.rb): `it` and `_1`.. blocks, redo,
  return with several values, and an ensure clause inlined where a return /
  break / next / redo leaves its region (pm_add_ensure_iseq, its region cut
  around the copy; thrown instead under a rescue's body:
  can_add_ensure_iseq). `to_a(u, true)` is the VM's export: ruby's Array
  plus what ruby's leaves out that a run needs (a for loop's parameter,
  `**nil`).
- **Found on the way, in the evaluator**: a `def initialize` run as a
  statement (an eval'd body, under an `if` in a class body) was public --
  ruby keeps initialize, initialize_copy / _clone / _dup and
  respond_to_missing? private wherever the def runs.
- **Programs are given back, by who can still run them** (the review of
  #85). The programs of one loaded Array are a tree. A tree is freed when no
  frame runs a program of it, no Proc was made in such a frame and no
  method's body is one of its programs: a top, method or class body frame
  carries the tree's id (the env's `__vm~p`; a block's env chains to the
  frame it was written in), marking an env that carries one marks the tree,
  the method table is read for bodies that are programs, and what nothing
  named in a collection is freed after its marking (m_state's vm_sweep).
  A body a Method or UnboundMethod object still holds after its name was
  defined again or removed is read too (the evaluator's snapshot table,
  snap_meths, and a box's own methods, bx_meth): `saved =
  Object.instance_method(:m)`, a second `def m`, two GC.start, and
  `saved.bind(o).call` raised "no longer loaded" (the second review of #85).
  Those two tables keep a body for as long as they keep the entry, so its
  tree stays that long.
  ISeq#eval frees its tree at once unless a Proc took the frame or a def of
  it actually ran. Counted with `RubyVM::InstructionSequence.__vm_trees`:
  100 evals of a sequence whose def is never taken hold 0 trees, of one
  that redefines a method 1; trees a dead Proc held go as the collector
  stops reaching the Proc (about 50 linger whether 400 or 6,000 were made).
- **The VM's own names cannot be Ruby's** (the same review): the hidden
  locals and the helper bindings carry a `~` (`__vm~r`, `__vm~0`,
  `__vh~1_3`), which no source spells -- `__vmr = 1; [1].map { __vmr }` read
  the call's receiver -- and Proc#parameters hides only those.
- **Events (round 37).** A sequence is no longer refused while a TracePoint
  or Coverage is on. A line event on an instruction is Coverage's count and
  the TracePoint's :line, a rescue clause's first instruction its :rescue;
  :call / :return, :b_call / :b_return, :class / :end and :c_call /
  :c_return come from the evaluator's frames and sends as before, at the
  lines ruby has them (a def's and a class's `end`, a block's opening line
  and file, a rescue clause's `===`). A sequence loaded while Coverage is
  set up is covered as ruby covers it: its lines are noted from its line
  events. Witness 659: all eleven event kinds in ruby's order.
  ⚠ Branch coverage is still not counted anywhere (test_coverage's 10), and
  a covered sequence's methods are reported only when its path is a file.
- **Still refused** (the sequence runs on the evaluator): `...`, binding /
  eval / local_variables called bare, class variables and pattern matching
  (the compiler), a String literal that is not UTF-8.
- **CRuby's tests, locally against the baseline run 43548292351**:
  ruby/test_iseq 39 -> 42, ruby/test_ractor 16 -> 17, and the same counts
  for test_compile_prism (182), test_optimization (82), test_settracefunc
  (97), coverage/test_coverage (34), test_syntax, test_proc, test_method,
  test_exception, test_eval.
- **Speed, measured, not yet worked on** (local, -O2, the same program on
  the evaluator and on the VM): a method-call mix 1.0 s / 1.8 s, a block
  mix 1.3 s / 2.3 s, a 3M-turn integer loop 1.7 s / 4.5 s. The compiler in
  Ruby takes 2.1 s for pp.rb's 738 lines: before whole files run on the VM
  it has to be native (note 552).
- Next: whole files on the VM (the compiler made native first), then speed.

## 2026-11-16: stage 9 GC remainder, round 1 -- measured profiling and explicit exclusions

Baseline: main c64d0ae4, successful CI run 43807166928. The six target files
have 159 RED: allocation 76, objspace 35, gc 23, gc_compact 22, string_memory 3.
The GC policy follows CRuby's alternate MMTk collector: actual measurements,
NotImplementedError for unavailable operations, and a reasoned ledger for
tests of the default collector. No slot or page constants are invented.

- GC.auto_compact now raises like the other unavailable compaction methods;
  respond_to? remains false. INTERNAL_CONSTANTS and stat_heap are empty,
  and OPTS does not advertise generational collection.
- gc_collect_any records actual collection durations for GC::Profiler and
  the inspected/retained weak references for latest_gc_info. The profiler
  reports measured per-run times and supports clear. No per-slot sizes are
  fabricated. gc_fixpoint, gc_mark_roots and gc_collect are untouched, to
  avoid overlapping PR #87. The allocation counter uses issued Proc handles,
  rather than the shrinking live Proc table.
- each_object snapshots String, Array and Hash stores, using real String
  survivors and post-sweep allocations. count_objects keeps its separate
  Array/Hash accounting, avoiding double counting.
- The upstream EXCLUDES mechanism applies the same reasoned ledger to both
  interpreters. Actual removed methods are audited and counted separately
  in local STATUS.md/EXCLUSIONS.tsv and CI summary.json/files.tsv/exclusions.tsv.
  The GC implementation-name comparison is excluded: the reference keeps
  its own default collector, and Mere truthfully reports mere-ruby.
- Local round 1: objspace MATCH 28 -> 29; gc 29 -> 32; string_memory 0 -> 2;
  55 exclusions, identical per side. Compaction's unsupported-API checks stay
  enabled (five EXTRA, one BOTH). Missing local -test-/stack makes two GC
  finalizer tests BOTH locally; they are RED in CI and belong to PR #87.
- Left: WeakMap's freed-object test retains 66 objects against a bound of
  10, despite real counts; conservative roots are shared with PR #87. One
  string_memory test sees interpreter parameter-name Strings on the first
  call into each_object (VM allocation provenance). Neither is excluded.
- Witness 669 checks actual profiling, latest info, unsupported compaction,
  empty slot information and each_object over real value stores.

### Stage 9 GC remainder, rounds 2 and 3 -- real heap dumps and complete triage

- dump_all snapshots real objects and value stores, emits actual handles,
  class/reference edges and allocation generation filters, and returns the
  requested stream/string/file. dump includes observed object_id in flags,
  File's type and String encoding information. It omits the inherited guessed
  memsize field. Witness 670 checks real membership, references and provenance.
- A snapshot can otherwise retain many expired runtime temporaries. When GC
  is enabled it collects before the public value-store snapshot; GC.disable
  and count_objects allocation comparisons retain their existing behavior.
- All 159 baseline RED are listed in unittest/gc_cases.tsv: 14 honest MATCH,
  55 reasoned exclusions, 90 reasoned handoffs. All 76 allocation tests remain
  enabled and RED locally. VM handoffs cover call-path allocation/provenance,
  actual literal pools, Float identity and Symbol lifetime; native handoffs
  cover -test-/stack, TypedData owners, allocator attribution and stack roots.
- Raw standalone results: objspace MATCH 28 -> 38, GC 29 -> 32, string_memory
  0 -> 2; objspace/ractor stays 3. The 15 raw gains include memsize_of_all,
  which still sums pre-existing guessed sizes and remains a handoff, not an
  accepted honest implementation match. The exclusion count remains 55 on
  both interpreters. Missing local -test-/stack remains BOTH, not a pass.
- The RSS gate caught a real regression: cause recording reused oncall and
  suppressed native arena compaction during explicit off-stack GC. A separate
  explicit cause flag restores the original collection behavior; the
  discarded-class-ivar ratio returns from 2.25x to baseline 1.06x. No resource
  limit was changed. The collector's gc_fixpoint/gc_mark_roots/gc_collect and
  m_state.mere remain untouched.
- Main advanced through PR #88 to 535ad955 during this work. It was merged
  into this branch; only the appended LOOP.md sections conflicted, and both
  were retained. Final verification uses that main plus the GC changes.
- Validation: runner 20, CI collector 47 (five existing optional real-reference
  fixtures skipped locally), exclusion accounting's identical/asymmetric
  fixtures, transcript 17; new witnesses agree with Ruby. Full corpus, final
  source gates, RSS and whole-suite CI are recorded in the PR as they finish.

Final review corrected that raw classification: test_start_full_mark and
test_latest_gc_info_need_major_by return before assertions without USE_RGENGC.
They are default-generational-GC tests, not honest implementation matches;
both are now explicitly excluded on both interpreters. The final inventory
is 12 honest MATCH, 57 reasoned exclusions, 90 handoffs (159 total). Raw MATCH
gain is 13, including the unaccepted inherited memsize_of_all estimate.
The GC file's expected local counts are MATCH 30 and exclusions 19; other
target files are unchanged. Of MMTk's 38 exclusions, 22 now apply here.

## 2026-11-15 (58): Ruby's C API on CRuby's own headers -- `test/-ext-` runs against ruby's unchanged test extensions

Stage 7′ / 8, second unit (note 550 §3, note 553). The prototype taken in at
(55) showed that the boundary could be made to hold; its value was a 32-bit
token behind a header of its own, so almost no real extension compiled
against it. This replaces it with the C API proper: an extension is compiled
against ruby 4.0.9's own headers and loaded by `require`. `capi/README.md`
is the description; this is what was decided and what was measured.

- **The decision: CRuby's headers, with ten macros rerouted.** `capi/include`
  is ruby 4.0.9's `include/`. The ten macros that cast a VALUE to a struct
  pointer (`RBASIC`, `RSTRING`, `RARRAY`, `RDATA`, `RTYPEDDATA`, `ROBJECT`,
  `RFILE`, `RCLASS`, `RMATCH`, `RREGEXP`) call a function instead, and
  everything written on top of them is ruby's text. Immediates are CRuby's
  bit for bit; any other VALUE is `2^56 + 8n`, a number in a table the
  interpreter keeps, and the struct C asks for is a mirror made on demand,
  refreshed when the interpreter has run and written back when C has. The
  alternative -- a header of our own with the same names -- was the
  prototype's, and it is where "ruby's sources compile unchanged" stopped at
  three directories. `capi/tools/headers_check.py` holds the copy to the
  ruby source tree: 194 headers, 10 patched by `capi/tools/headers.patch`
  and nothing else.
- **The prototype's code is gone**, and its contracts stayed: the scripts it
  checked itself with (ensure 58 checks, typeddata 78, loader 46, numeric 13)
  now run on the real headers, on both sides. `tools/native_probe/` keeps
  only the embedding checks, which are another feature.
- **No interpreter failure crosses a C frame.** A request from C comes back
  with an outcome; C jumps to the nearest guard it made itself
  (`rb_protect`, `rb_rescue2`, `rb_ensure`, `rb_catch`, the C method's
  entry). An exception, `throw`, `break` and `return` all travel that way.
- **What C holds is alive**: registered addresses, a conservative scan of
  the C stack while a call is in progress (and of a stopped Fiber's or
  Thread's stack), `dmark` to a fixpoint, the elements of live mirrors.
  `dfree` runs once at the sweep.
- **A call into C stays with the stack it is on.** Fibers and threads switch
  in the middle of `rb_block_call`; each stack has its own chain of C calls
  (`mr_capi_switch`, called from the one place the interpreter switches
  stacks).
- **Whether a file is an extension of ours is asked of the file.** The
  intake asked by `dlopen` and `dlclose`, which gave an accepted library an
  extra constructor / destructor cycle before its `Init_` and ran a foreign
  library's constructors (PR #83's review). The file is read for the name
  every extension compiled against these headers defines; the library is
  opened once, and the number behind the name is compared then.
- **A long division is not one uninterruptible step** (the interpreter, not
  the C API; it is here because `ruby/test_bignum.rb` could not finish
  without it). The file ran nothing at the baseline -- its first line
  requires `-test-/integer` -- and with the extension there, one of its
  tests grows two numbers until two signals arrive during a division.
  Threads take turns at statement boundaries and a trap runs at one, so
  they never arrived, and the operands grew until a single division took
  minutes (the file would have ended at CI's 600 seconds). The long
  division now counts the limbs it has gone over and, every four million,
  takes the look a statement boundary takes: another thread that can run
  gets its turn, a trap that is waiting runs (`long_op_hook` in
  m_numeric.mere, `long_op_tick` in main.mere). The test's scenario is met
  at its sixth round, in 4 seconds.
- **What is refused**: `capi/unsupported.c` lists 66 functions that exist so
  that a library using them loads, and raise NotImplementedError by name
  when called -- CRuby's internal bignum routines (`rb_big_mul_toom3`, ...:
  this Integer has one multiplication, and answering under another's name
  would be a claim), TracePoint / debug inspector / profile frames /
  postponed jobs from C, memory views, the Random interface, encoding
  converters. Nothing in it answers.

**Checks.**

- `tools/capi_check.py`, a step of CI's corpus job (macOS) and of
  build-linux: ruby's `ext/-test-/exception`, `typeddata`, `float`, `iter`
  and the fixtures of `capi/check`, built against the reference's headers
  and against these; five contract scripts print the same on both sides
  (ensure 58, typeddata 78, loader 48 and one of our own, numeric 13, fiber
  16), again under a collection at every safepoint; and with dmark, dfree,
  the ensure cleanup, the stack switch and the load-free ABI question each
  switched off, the contracts that depend on it fail. Run here on macOS and in
  a Linux container, each against ruby 4.0.9: both agree.
- The unit test shards build all of `ext/-test-` with
  `tools/capi_ext_build.py` (72 of 75 directories build; the three that do
  not want CRuby's internal headers) and `unittest/shim/-test-/`, three Ruby
  stand-ins for C extensions, is deleted.
- Gates: dead_defs, dup_defs, gc_roots (`capi_tab` is an entry),
  meth_writes, name_len, ns_names pass. Bracket depth is 892 of 1024 (895
  with the prototype, 878 on main).
- The corpus matches 687 of 687 (O2 build, this machine). There is no new
  corpus program: a corpus program cannot build a library, and what this
  round adds is witnessed by the two-sided contracts above, each with the
  control that makes it fail.

**What CI found** (PR #87):

- `config.h` claimed `dup3` and `pipe2` for macOS: this machine's macOS has
  them and the runner's release does not, and `config_probe.py --check`
  refused the claim on the runner. They are said for Linux alone now.
- With the file asked instead of loaded (above), ruby's own
  `-test-/memory_status` extension loads, which is what `tool/lib`'s
  `assert_no_memory_leak` waits for: its tests (34 files use it) were
  pended as "unsupported platform" on this side and now run.
- The unit test run of 80e41026 (run 43792242051): MATCH 33,175, 710 above
  the baseline (run 43745055106 on main ba088b2f: 32,465), RED 1,239;
  INCOMPLETE files 19 (82 at the baseline); 68 files higher, and five
  LOWER. One of the five is noise (`ruby/test_ractor.rb`, in
  `unittest/README.md` now). The other four were real, each from a test
  reaching code it had not reached before, and each is fixed here with a
  contract in `capi/check/api.rb`:
  - `ruby/test_dir_m17n.rb` 22 -> 20. `Bug::File::Fs.fsname` is ruby's C
    now, and `capi_ext_build.py` built it without extconf.rb's answers: no
    `HAVE_STRUCT_STATFS_F_FSTYPENAME`, so it said nil for every path where
    the reference says "apfs", and two tests that return early on APFS ran
    on. The builder asks the compiler the three probes that file writes out
    (`have_header` over a list, `have_type`, `have_struct_member`) and
    passes the answers as mkmf does. `rb_str_encode_ospath`, which the
    function then calls, is written.
  - `-ext-/file/test_stat.rb` 2 -> 0: `rb_stat_new` was in the ledger. It
    makes a `File::Stat` from the struct C filled.
  - `ruby/test_keyword.rb` 114 -> 113: a block function C passed
    (`rb_block_call`) was not told that it had been yielded keywords, and
    `rb_yield_block` handed them on as a Hash. The request that runs a C
    block carries the flag; `rb_keyword_given_p` answers from it.
  - `ruby/test_regexp.rb` 161 -> 160: `onig_get_parse_depth_limit` /
    `onig_set_parse_depth_limit` were in the ledger, and the regexp parser
    had no such bound (deep nesting ended at the stack). The parser counts
    its nesting -- groups and character classes -- and refuses past the
    limit with Onigmo's message ("parse depth limit over"); the default is
    Onigmo's 4096, and C reads and sets the same number. The file is at
    162 here, one above the baseline.

**What the review found** (PR #87; each has a contract in
`capi/check/api.rb` now -- 63 checks on both sides with those of "What CI
found" -- and the first has the control that makes them fail):

- A primitive called whatever the receiver's class had made of the name:
  `rb_ary_push` on an instance of `class A < Array; def push` ran A's
  `push` and left the Array empty; the same for `rb_str_append`,
  `rb_str_strlen`, `rb_obj_freeze`, `rb_hash_aset`. The primitives of the
  C API now name the class whose operation they are (Array, String, Hash,
  Kernel), and where the receiver's class or singleton overrides the name
  the call goes the way `super` from that override would -- to the next
  definition from the builtin class on, or the builtin itself. Only an
  override pays for it. (A redefinition IN the builtin class itself was
  still what got called; the second review below.)
- The watch on a struct C may have written (a String's bytes through
  `RSTRING_PTR`) ended when ANY C call at that depth ended. A Fiber stopped
  inside a C call lost it to an unrelated call on another stack, and what
  its C wrote after resuming never reached the String. The watch belongs to
  the C frame that took the pointer now.
- `rb_get_kwargs` is class.c's again: with a place for the values, what it
  finds is taken out of the Hash (also when other keywords may stay);
  without one, the Hash is only read.
- `rb_proc_new` made a lambda; it makes a Proc.
- (Found here, from a gem: redcarpet.) A class C defines is the class
  statement itself where its scope and superclass have names. Made
  anonymous and set as the constant, a class under two modules made the
  same way was not found again as a superclass -- `class Custom <
  Redcarpet::Render::Base` then was not a Base -- and ruby's own
  `-test-/memory_status` did not define what `tool/lib` looks for.

**What the second review found** (PR #87, after the CI fixes; five, each
reproduced by the same C on both rubies, each with contracts now):

- `rb_stat_new(NULL)` -- file.c's way of allocating a File::Stat -- read
  through the NULL and the process died. It is an uninitialized File::Stat
  now, whose readers raise TypeError.
- `rb_stat_new` kept whole seconds: the struct's nanoseconds and, on
  macOS, its birth time were dropped. The times are seconds plus a Rational
  now, and the birth time is kept; File::Stat#<=> compares the Times, not
  their seconds. (On Linux ruby keeps a statx and copies neither the device
  numbers, the block size nor a birth time from a struct stat: those read 0
  there and #birthtime is NotImplementedError, on both sides.) That made
  `-ext-/file/test_stat.rb` 0 again: it compares the C-made snapshot with
  `File.stat` of the same file, and this interpreter's own File.stat had
  whole seconds (Mere's `file_stat_field` gives no more). File.stat and
  File#stat now have the nanoseconds too, read by `mr_stat_times`
  (tools/process_glue.c) from one stat call that also gives the seconds,
  so `File.mtime` and the rest are exact as in ruby. With the times exact,
  `File.utime` / `File.lutime` had to be too: utime(2) took whole seconds,
  and lutime ran `touch -h` in a shell. Both are utimensat(2) now
  (`mr_utimens`, the same glue), to the nanosecond and with no shell; the
  old ways stay where a target refuses the call. (On this machine a
  freshly written file's atime is moved a few ms later by something
  outside the process -- ruby sees it as well. `test_lutime` in
  pathname, which reads the atime right after writing, then passes or not
  by how fast the steps between are: ruby's pass, ours sometimes do not.)

**What the CI of c32cc30c found** (run 43841373314: every job green; MATCH
33,183, 718 above the baseline, RED 1,231; 70 files higher, one lower):
`ruby/test_dir.rb` 38 -> 37, `test_symlink`: `Dir.glob("*/")` listed
symlinks to FILES. Not this branch's -- main's build does it too, 29 runs
in 40 here, and the baseline's run happened to pass -- but its cause is the
interpreter's directory test, `dir_there`, which asked `stat("<p>/")`; macOS
answers that with success at random for a link to a file. The same cause
made `File.read("~/.gemrc")` (a link to a file) raise EISDIR in one run of
`gem` in five here. `dir_there` stats the path and reads the type bits now
(a 0000 directory is still a directory, as before): 0 runs in 40 list a
link to a file, and `~/.gemrc` reads 30 times in 30.
- The regexp parse depth was one level too lenient: Onigmo counts the
  pattern itself (its outermost parse_subexp) as the first level, so at
  limit 1 `/(a)/` and `/[a]/` are refused. Counted the same way now, with
  contracts at the limit and one past it.
- Two C calls stopped in two Fibers, holding pointers into the SAME String:
  the mirror's watch recorded only the first call, and when that call
  ended the second one's write was lost (`"Xbc"` where ruby says `"Ybc"`).
  A mirror is watched by every C call in progress that touched it, and
  until the last of them has ended.
- The primitives: `rb_ary_aref` still dispatched (a subclass's `[]`
  answered), and a redefinition in the builtin class itself (`class
  String; def length`) was still what `rb_str_strlen` called. The first is
  routed like the others. For the second, what the prelude defines in
  Array, String, Hash and Kernel is the builtin here: when a program
  redefines or removes one of those names afterwards, the method table's
  setter keeps the prelude's definition aside (`capi_boot_defs`; none where
  the name is native), and the primitive calls that, or the native one.
  A module prepended to the builtin class (`Array.prepend`) is passed over
  the same way an override in a subclass is.

**Measured here** (this machine, the interpreter's side only; CI's shards
are the record and go in below when they have run): of `test/-ext-`'s 94
files, 94 reach their summary (12 did at the baseline, CI run 43548292351 on
main f7b2579a, where 811 of 823 tests were RED); 657 tests pass of 831 run.

`ruby/test_bignum.rb`: 65 of 74 pass (0 at the baseline). The nine left are
the interpreter's numeric semantics (`Integer#to_s` and `#digits` with an
invalid radix, the Float-range warnings of `to_f` and `/`, `fdiv` past
1e300, `Integer#[]` with a range past the top) and two that ask about
CRuby's representation (`Bug::Integer.bignum?(0)` of a bignum-typed zero,
an interrupt during `to_s`, which is not long here).

**What is still RED in `test/-ext-`, by cause** (174 tests):

- CRuby's internal bignum routines by name -- `bignum/test_mul` 19,
  `test_str2big` 3, `test_big2str` 2, `test_bigzero` 2, `test_div` 1,
  `rational` 1: refused (above). Whether to vendor CRuby's bignum.c for them
  is the owner's question in note 553 §4.
- `GC::INTERNAL_CONSTANTS` and what depends on it (`string/test_capacity`,
  `test_set_len`, `test_rb_str_dup`): an item waiting for the owner (note
  549 §4), not touched.
- The VM's own structures from C: `tracepoint`, `debug` (inspector, profile
  frames), `postponed_job`, `thread/test_instrumentation_api`, `iseq_load`,
  `bug_reporter`, `stack`, `test_bug-14834`.
- Symbols that must not come into being (`symbol/test_inadvertent_creation`,
  32 of 49): `rb_check_id` answers truthfully, but the interpreter's own
  method lookup interns the name first.
- Not written yet: memory views, the Random interface, `rb_econv_*`, dummy
  encodings, `rb_stat_new`, `rb_marshal_define_compat`,
  `rb_f_notimplement`'s effect on `respond_to?`, `rb_data_define` with a
  superclass, `st_table` of a Hash.
- The interpreter, not the C API: `String#encode` on a subclass answers a
  String; `IO#wait` on a descriptor closed behind it does not raise EBADF.

**Next**: RbConfig's keys from this build's real environment and mkmf on
these headers (`test/mkmf`, and `capi_ext_build.py` replaced by ruby's own
extconf.rb runs), then RubyGems' native builds and a real gem.

## 2026-11-16 (59): round 38 -- a whole file runs on the ISeq VM, and the corpus matches ruby that way too

**The point.** With `MERE_RUBY_VM=1` the main script and every file it
requires run on the ISeq VM: the file is compiled once and its top sequence
is the file's one statement. A file the compiler or the VM does not take
runs on the evaluator as before, whole. The corpus run this way matches
ruby: 691 programs, 660 with the main script on the VM, 31 on the
evaluator, 0 different (`tools/iseq/vm_corpus.sh`). The default execution
is unchanged -- the evaluator -- and the corpus matches there as before.
The first survey of this round was 410 on the VM, 188 fallen back and 91
different.

- **How a file gets there.** `MERE_RUBY_VM` is `1` (quiet), `report` (a
  note on stderr saying which of the two ran a file and why), `strict` (a
  file that falls back raises) or `why` (the answer for the main script,
  without running it). The driver and `require` / `load` hand the parsed
  statements to vm_file_stmts, which answers the file's position marks and
  one `SVm`. Not taken, by decision: a main script under an option that
  changes how it is read (-n, -p, -a, -l, -x, -s, -K), and a source that is
  not UTF-8 or US-ASCII.
- **What whole files asked of the VM** that `ISeq#eval` snippets had not:
  `binding`, `eval` and `local_variables` called bare (the frame declares
  its locals on entry, as the source does); `...`; a call without a
  receiver is the parser's own call node whatever self is (`refine`,
  `raise`, `attr_reader`, `include`, `define_method` as a class body reads
  them); `__dir__` and `require_relative` from the frame's file; a
  parameter named `_` twice (the parser's `_~N`); a lone `**obj` argument
  (#to_hash, before the block's #to_proc; `**nil` passes nothing and still
  says keywords were given); a def on a value without a singleton class;
  `class << self`; the frame's line under a rescue clause (the instruction
  before where the frame goes on, as ruby leaves its pc); a `break` in a
  Thread's body (LocalJumpError where it is); `alias $new $old`; a
  Continuation re-entered into a VM frame (run again from the statement
  the guarded call is in; refused where values would be on the stack); a
  String literal in any encoding (the compiler's own operand, which
  compare_files.rb holds to ruby's encoding).
- **What the evaluator reads off a body's AST**, a VM body now answers from
  its program: whether the method takes a block (ruby's own `use_block`,
  which the compiler already computed -- the unused-block warning), the
  locals a TracePoint's binding of the frame has before they are assigned,
  the lines a targeted TracePoint hooks, the outer locals that may be
  reassigned (a shareable Proc's refusal; ruby's update_lvar_state, from
  the setlocals), the box a body's file was read in.
- **The compiler** (lib/iseq_compiler_ext.rb, 431 / 431 against ruby):
  interpolated regexps, `$1` / `$&` and their kin (getspecial), a regexp
  match that writes locals, class variables, `#@x` in a string,
  `__ENCODING__`.
- **Found on the way, in the evaluator** (each was wrong without the VM
  too): the builtin operator is a frame of what it refuses -- `1 + nil`,
  `1 < nil`, `1 / 0` have 'Integer#+' on top of their backtrace, as
  `1.+(nil)` always had; a def or an undef under `1.instance_eval` is
  refused when it runs, and a constant or a class there is not refused at
  all (a scan of the block refused all four before anything ran);
  `1r.equal?(1)` was true; "uninitialized constant Nope::Thing" named both;
  undef_method of an inherited builtin on a singleton class, and of a
  refined class's method; a method in a source that says `binding`
  anywhere was never warned about for an unused block.
  ⚠ Found and NOT fixed, both the evaluator's own: in a source that says
  `binding` anywhere, a def-level rescue clause sees its frame at the
  caller's line instead of the def's (the VM has it right; corpus 663 keeps
  those two methods in a file of their own); and Method objects made of a
  top-level method that is then defined again several times all call the
  newest body.
- **The compiler against ruby, a whole file at a time**
  (`tools/iseq/compare_files.rb`, new): every corpus program compiled by
  ruby and by the compiler, #to_a and #disasm compared, a String operand in
  its encoding too. 691 files: 667 the same, 24 refused (the list below
  without the encodings, which are the VM's refusals and the driver's), 0
  different. It
  began at 587 the same. What whole files showed that snippets had not: a
  written `nil` as a range's bound is a static Range; an absent bound's nil
  is the range node's instruction; a constant's inline cache is numbered as
  the instructions are laid out, not as they are compiled (`f(String,
  &Proc.new {})`); #disasm pads by bytes; a rescue modifier's sequence is
  at the modifier's line; an escape forces a String literal's encoding and
  a pattern's to binary (`"\xFF"` and `"\u00e9"` in a US-ASCII source);
  `defined?`'s answer is a US-ASCII String; `__LINE__` among a literal's
  elements; a lone interpolation starts from an empty String in the
  source's encoding.
- **Still on the evaluator**, of the corpus's 31: pattern matching (`case
  / in` 8, `=>` / `in` as an expression 3), a Regexp literal in an encoding
  other than UTF-8 or US-ASCII 5, a source in another encoding 2,
  flip-flops 3, a `for` over a target that is not a local 3, `/o` 2, an
  empty `#{}` 2, END 1, a keyword hash node 1, a shareable_constant_value
  write 1.
- **The review of #88** (three points, all taken):
  - a literal's value is made without a method the program can define. The
    compiler runs while the program does -- a file is compiled when it is
    required -- and called `Regexp.new` and `Range.new`: `def Regexp.new(*)
    = :intercepted` in the main script made every `/abc/` of a required
    file a Symbol. A Regexp literal is now the interpreter's own maker's
    (Regexp.__rx_new, the native behind Regexp.new), a Range the literal
    syntax's.
  - a Regexp literal is frozen (`/abc/.frozen?` was false on the VM).
    compare_files.rb cannot see that -- Regexp#== does not ask -- so
    witness 663 does: a third file required after the two redefinitions.
  - `MERE_RUBY_VM=why` is answered before the BEGIN blocks run, of the
    program as it was parsed ("a BEGIN block"); it ran them first.
  ⚠ What this does not reach: the compiler is Ruby, so a program that
  redefines what the compiler itself calls -- Array#map, String#<< -- still
  changes what it compiles. That ends with the compiler made native.
- **Checked** (local, the commit before this note): vm_check 243 / 243,
  the compiler 431 / 431 snippets and 667 / 667 compiled files, corpus
  691 / 691 on the evaluator and 691 with 0 different on the VM, the gates
  (bracket depth 878). Witness 663 runs one
  script both ways in a child and prints that the two agree.
- **Not done yet, and why the default stays the evaluator**: the compiler
  is Ruby running on mere-ruby, about 3 ms a line; and the VM's loop is
  1.7 - 2.6 times the evaluator's time (note 552). Next: the smaller
  fallbacks, then the compiler made native, then speed.

## 2026-11-16: stage 9, round 4 -- count the actual live String store

While PR #91 waits for CI, an independent probe found that count_objects
omitted T_STRING although each_object(String) now visits the actual store.
The store count is the last sweep's survivor count plus handles issued since
its sweep boundary. Empty strings count, reclaimed slots do not, and TOTAL
includes the same live Strings. No collector function or m_state.mere changed.

Witness 674 checks empty/live/reclaimed Strings, hash reuse, zeroed old keys
and the total's arithmetic. It fails on PR #91's old binary (missing T_STRING)
and agrees with Ruby after this fix. Core test_objectspace remains 37/37;
objspace stays MATCH 38 and string_memory stays MATCH 2. The original 159-case
classification is unchanged; this is an additional real API correction.
### PR #91 review: GC::Profiler keeps the runtime CPU epoch

P2 found that GC_INVOKE_TIME began at Profiler.enable instead of runtime
startup. The existing gc_state initializer now captures the process CPU clock
once, before Ruby execution; enable/disable/clear preserve it. GC_TIME uses
that same process CPU clock, so sleeps and scheduling waits are not charged
as collection CPU. tools/process_glue.c adds mr_gc_process_cpu_time using
CLOCK_PROCESS_CPUTIME_ID with the standard C clock fallback; it is a new
function, separate from the stat/utime functions in the concurrent C API work.
No top-level value or collector-body change is introduced.

Witness 673 spends CPU before enabling, checks clear and re-enable, and checks
that sleep does not advance the CPU timeline as wall time would. Ruby passes;
the old build fails at the delayed-enable assertion; the corrected build
passes. The C clock glue also passes strict compiler warnings.

### PR #91 platform review: the browser CPU clock ABI and Linux witness

The browser host now supplies mr_gc_process_cpu_time as a pointer to a boxed
negative Float, matching the Wasm backend's custom-extern ABI. Returning a raw
negative number would instantiate but trap during collector initialization.
The host import check validates the box; the browser build also executes the
full interpreter and checks that Profiler.enable raises NotImplementedError.
A fresh emitted module starts normally and reports the unavailable CPU clock.

Witness 673 now reads Process.clock_gettime(CLOCK_PROCESS_CPUTIME_ID), using
the same native process clock as the profiler. It no longer depends on the
platform-specific ps output behind the existing Process.times implementation.
The unchanged witness and measurement witness 669 pass on Darwin and Linux.
The native process-clock unit selection preserves the existing conversion
checks; all 19 upstream clock tests pass locally.

dump_all hoists its main-ractor check and reuses the shareability result
already needed by non-main ractors. This removes repeated interpreter calls
without changing its object selection or the subprocess timeout. The ractor
dump witness passes in 6.76 seconds under the unchanged ten-second bound.

### PR #91 CI follow-up: enumeration preserves the current retained set

The OpenSSL lifetime gate exposed an extra collection in the new iterator:
it changed the native retained set after the caller had measured it following
GC.start. each_object now snapshots the current stores without forcing GC.
Witness 669 reproduces the extra collection on the previous build and agrees
with Ruby after the correction. The existing OpenSSL memory gate passes,
including 20/200 owner counts, interrupted allocation and worker lifetimes.
All six affected GC/ObjectSpace files preserve their local counts: MATCH 110,
RED 11, BOTH 5, EXTRA 5, plus 57 separately audited exclusions. Allocation
comparisons remain enabled; no collector body, timeout or memory limit changed.

The latest successful main run is now 43869939788 at 535ad955. Its target
RED counts are unchanged: 76 allocation, 35 objspace including ractor, 23 GC,
22 compaction and 3 string-memory. The 159-case inventory remains applicable.

Dump string escaping now scans bytes into a Mere buffer, copying plain runs
and using the existing JSON byte-escape helper for control characters. It
preserves quotes, backslashes, all controls and DEL without a Ruby call for
every character. Witness 670 round-trips a long ASCII string and those bytes;
the unchanged ractor dump test still passes its ten-second limit. No new
top-level value or JSON engine changes are introduced.

## 2026-11-17: stage 9, round 5 -- enumerate Proc and Binding stores

each_object now snapshots actual Proc and Binding handles from proc_store
and bind_store, applying the existing class filter and preserving identity.
count_objects includes those live store lengths in T_DATA and TOTAL. This
does not invent native TypedData owner counts or allocator byte sizes.
Witness 680 checks held values, unique identities, Enumerator behavior,
returned counts and survival after collection. Witness 674 covers String
counts, including empty and reclaimed values. The 159-case classification
remains 12 accepted matches, 57 reasoned exclusions and 90 handoffs.

The inherited Ruby memsize_of_all loop now visits Proc/Binding too, producing
temporary Strings that enter the next String-only measurement. Its a > b
assertion fails (1081807 versus 1844111 in the isolated reproduction). This
is the already-recorded native allocator handoff; its guessed byte counts
are not adjusted to retain a raw pass. It remains enabled and visible.

The latest main baseline is successful CI 43869939788, main 535ad955. Its
target 159 RED are unchanged from the original inventory. Both hash modes
pass 696/696 corpus comparisons before the final dump escaping optimization;
all nine RSS cases pass, with discarded-class-ivar at 1.07x. The final
ObjectSpace file and dump witnesses are rechecked after that optimization.
No collector body, m_state, VM, AST, C API or gemtest change is introduced.

The pre-publication origin check found witness 675 newly used by the VM
branch. This branch's Proc/Binding witness moved to the first free number,
680, leaving the concurrent branch unchanged.

Final ObjectSpace remeasurement: 46 tests, MATCH 37, RED 9, with 16 audited
exclusions. The ractor dump passes again; the remaining raw loss from #91 is
the unaccepted memsize_of_all estimate described above. Combining that final
file with the unchanged six-file measurement gives 207 tests: MATCH 109,
RED 88, BOTH 5, EXTRA 5, plus 57 separately reported exclusions. Against the
latest main the target raw gain is now 12, all accepted implementation
matches. Both final store witnesses and the extended dump witness pass.

## 2026-11-17: stage 9, round 6 -- inverse identities and integer conversion

While #91 and #94 wait for CI, a separate worktree reproduces two ObjectSpace
gaps: _id2ref rejects to_int arguments and cannot recover retained Proc or
Binding handles. It now converts once, including private and conventional
respond_to_missing? conversions, rejects non-Integer results with TypeError,
and reads the actual Proc/Binding tables for those identity tags. The
collector and the shared conversion helpers remain unchanged.

Witness 681 round-trips held objects and stores, checks conversion calls,
private/dynamic conversion, one-argument respond_to? overrides, invalid
return types, Float conversion and preservation after collection. Ruby
passes; the previous interpreter fails at the first to_int argument.

## 2026-11-17: stage 9, round 7 -- reject swept String identities

_id2ref's String path used the issued-handle boundary alone, so an old ID
could recover a swept slot as an empty String. __str_of_id now checks the
existing gc_str_present predicate. This reads actual survivors and fresh
handles without changing the collector, its roots or its sweep behavior.

Witness 682 releases dynamic Strings, collects and requires rejection of
collected IDs, while retained empty/nonempty Strings and a fresh empty String
still round-trip. The reference rejects collected IDs; the old interpreter
rejects none. No default-collector exclusion or allocation comparison changes.

### PR #91 CI comparison: snapshot iteration without temporary Ruby Arrays

The full 758-file report at 47c833e7 has three lower MATCH counts than main
535ad955, all at the unchanged ten-second bound. Paired local runs of the
actual CI binaries pass the Class and Zlib leak tests on both builds. The
Enumerable reverse_each case reproduces the regression: main 2.58 seconds,
PR 10.10 seconds and Timeout. It must not be dismissed as timing noise.

The ObjectSpace snapshot now filters class candidates internally and avoids
walking unrelated stores for exact builtin value-class filters. each_object
yields from the native snapshot without creating Ruby snapshot Arrays that
would enter later iterations. Actual candidate values are temporarily rooted
in the existing Ruby method frame, with cleanup on normal and exceptional
exits. Snapshot storage and each callback turn have scoped Mere lifetimes.
The existing builtin-frame wrapper gives callbacks a native iterator boundary
so statement watermarks do not retain every earlier callback's temporaries.
No collector/root-table definition, shared block helper or limit is changed.

Witness 683 covers class/module/subclass filtering, held objects across GC,
nested enumeration, exceptions, break/nonlocal return, lambda/orphan break
and Fiber suspension across collection. It agrees with Ruby. The scoped
native-yield candidate passes the original Enumerable case in 7.07 seconds
and the existing RSS harness's 3000-iteration probe at 1.07x. The complete
corpus and the integration with newly merged main are checked separately.

### Latest main integration and public native iteration

Main 96075af9, successful CI 43933582689, supersedes the earlier baseline.
Its native extension integration passes the two finalizer stack-overflow
cases, leaving 157 target RED: 12 accepted implementation matches, 57
reasoned exclusions and 88 named handoffs. The original 159-row inventory
retains those two main fixes without claiming them as stage 9 gains.
WeakMap still retains 50 keys against a bound of 10; moving the statistics
sampler did not improve that count, so that experiment was discarded.

The public each_object native arm accepts the original block directly,
avoiding conversion through an extra Ruby Proc wrapper. It preserves
blockless enumeration, argument validation, user overrides and Proc break
semantics. The unchanged Enumerable test passes in 6.38 seconds. On the
actual latest-main CI binary, the million-finalizer test takes 25.84 seconds;
this candidate takes 26.97 seconds, both within its unchanged sixty seconds.
The complete seven-file comparison is MATCH 198, RED 12, BOTH 6, EXTRA 5,
with 57 exclusions reported separately: objspace 37, ractor 3, Enumerable
89, GC 30, compaction 0, core ObjectSpace 37, string memory 2 MATCH.
The local missing native stack extension remains BOTH. The native iteration
RSS probe is 1.07x; roots/dead/duplicate checks pass and bracket depth is
892/1024. Full CI against the new main is still required before merge.

The integrated candidate passes 695/695 corpus programs with hash indexing
ON and OFF, the original nine RSS cases (class ivar 1.05x), and the complete
OpenSSL owner/lifetime gate. Linux CI then failed the unchanged Float#step
bit comparison: the baseline used Ubuntu 24.04, while ubuntu-latest had
moved to 26.04 with Clang 21. The native build job is pinned to Ubuntu 24.04
to preserve that baseline environment; its 90-minute limit and all test
time/memory bounds remain unchanged. The platform explanation is checked by
the next CI run, rather than changing Float arithmetic during GC work.

The final identity branch also integrates this main and the native iterator
correction. All 699 corpus programs agree in both hash-index modes. Its
seven-file comparison completes with MATCH 198, RED 12, BOTH 6, EXTRA 5 and
57 symmetric exclusions; Enumerable is 89 MATCH and core ObjectSpace 37/37.
All nine RSS cases (class ivar 1.05x), the complete OpenSSL lifetime gate,
root/dead/duplicate-definition checks and bracket depth 892/1024 pass.
Rounds 6 and 7 are PR #98, stacked on #94; none of the three PRs is merged
while the latest-main full CI and per-file comparison are pending.

### PR #98 review: conversion does not require argument reflection

The review found that asking the argument for method(:respond_to?) rejects
a valid to_int object that undefines or overrides Kernel#method. The native
ObjectSpace __id_integer arm now reads existing method metadata and calls
through the existing dispatcher. It preserves private and dynamic conversion,
one-argument respond_to? overrides, refusal, errors and result type checks;
it does not call the argument's method, class, is_a? or __send__ methods.

The BasicObject control exposed another dependency: scanning snapshot
candidates through their object_id failed just because a BasicObject was
present. Ordinary object IDs now resolve from the real obj_cls store, and
the fallback compares existing native identity metadata. Witness 681 adds
the review's missing-method case, reflection traps, BasicObject and held
Class identity. It passes on Ruby and the O2 candidate; the prior binary
fails the new missing-method case. Sixteen conversion controls have identical
reference/candidate output. Witnesses 682/683 and root/dead/duplicate gates
also pass; bracket depth remains 892/1024. The full comparison is rerun.

### PR #98 follow-up: checked method_missing conversion

A further review found that a custom method_missing can supply to_int
without advertising it through respond_to_missing?. The ObjectSpace native
conversion arm now distinguishes an explicit query refusal from the absence
of an advertised method. It tries custom missing-method dispatch, preserves
explicit refusals and promised-method exceptions, and treats an unadvertised
NoMethodError as a declined conversion. A tagged result distinguishes a
successful nil return from a missing method. The caller's exception context
is restored before reporting refusal. Query arity errors match Ruby's
checked-call entry. No shared conversion helper or VM function is changed.

Witness 681 covers Object/BasicObject proxies without an advertisement,
refusal, nil results, query arity and collection inside conversion. It agrees
with Ruby and fails on the prior binary. Existing witnesses 682/683 and 30
comparison outputs (16 prior conversions, 12 new conversions and two exception
context checks) agree too. Roots/dead/duplicate checks and depth 892/1024 pass.
The complete upstream comparison and both corpus modes are rerun.

## 2026-11-16 (65): five real pure Ruby gems run their own upstream test files

Gem-suite rounds 1-3, on main c64d0ae4, independently of #86 (AST), #87
(C API) and #88 (VM). This measures original upstream tests, beyond the
29-gem require-only inventory. The final lock has 62 files and 1,969
reference tests. Counts below are FILE verdicts, not case counts:

| suite | initial MATCH / RED / BOTH | latest MATCH / RED / BOTH | other |
|---|---|---|---|
| minitest 5.25.5 | 3 / 4 / 0 | 3 / 4 / 0 | mock now completes all 94 tests |
| rack 3.2.0 | 29 / 9 / 0 | 30 / 8 / 0 | 1 MEMORY on both builds |
| rack-test 2.2.0 | 7 / 1 / 0 | 7 / 1 / 0 | assertion-count reflection difference |
| public_suffix 6.0.2 | 7 / 0 / 0 | 7 / 0 / 0 | |
| base64 0.2.0 | 1 / 0 / 0 | 1 / 0 / 0 | |

- **Reproducible sources and measurements.** `gemtest/suites.lock.json`
  pins release commits, full source digests, test-file inventory, commands
  and every pure Ruby development dependency's archive and extracted tree.
  Restore checks the runtime dependency closure and rejects C extensions.
  Sources stay in an external cache; measurement retrieves nothing. Each
  side/file gets its own source copy and seed 1. Raw stdout, stderr and exit
  are saved separately. Existing CI supervision bounds the whole process
  family to 600 seconds and 2 GiB, with no option to increase either.
- **Honest file verdicts.** MATCH requires successful exits, non-skipped
  tests, assertions and identical summaries. No summary, zero tests and all
  skips cannot pass. Reference failures remain BOTH, and resource limits
  remain explicit. The final baseline has no BOTH or timeout; its remaining
  memory failure is Rack's multipart file. Initial and latest results are
  saved separately and compared file by file, with no lost MATCH or changed
  reference coverage. `SUITES_GAPS.md` records every remaining difference,
  distinguishing confirmed symptoms from causes still under investigation.
- **Two local semantic fixes.** `pct_strict_value` follows escaped newlines
  backwards before deciding whether `%` starts a literal. Minitest's
  continued format string now parses; its original mock file runs 94 tests
  instead of stopping with SyntaxError (still 2 failures / 13 errors).
  `cls_meth_own` respects a local builtin alias before an inherited Ruby
  class method: Rack::MockResponse's `alias [] new` no longer calls
  Rack::Response.[] with its different argument order. The original mock
  response file becomes MATCH (24 tests / 100 assertions). Witnesses 667
  and 668. These are the only interpreter functions changed; no new global
  let, VM, AST tree, C API or collector change.
- **Selection and reference readiness.** Rack 3.1.12 requires removed
  cgi/cookie, so 3.2.0 was selected before the final baseline. Hoe and logger
  are explicitly pinned so minitest's task file and Rack's logger tests run
  on the reference. These environment repairs are not interpreter gains.
  Kramdown 2.5.1's conversion tests depend on tidy and optional Rouge and
  stringex (reference 19 failures / 11 errors); it is explicitly deferred
  in the lock, not selectively patched or counted as passing.
- **Validation.** Corpus 690/690 before and 692/692 after; test_alias
  17 MATCH / 1 RED and test_syntax 167 MATCH / 1 RED / 2 BOTH, identical
  file counts to both handoff CI 43548292351 and main CI 43807166928.
  Dead/duplicate definitions, GC roots and loop RSS gates pass; generated
  bracket depth stays 895/1024. Six harness negative controls cover zero
  tests, missing summaries/files, reference failures, limits and source
  mutation/shadowing. The separate `Gem suites` workflow uses actions/cache
  and runs on macOS and Linux, without changing existing job durations or
  any per-file limits. Full existing-suite regression checks still gate merge.

## 2026-11-16 (66): gem rounds 4-5 -- gzip callbacks and StringIO reflection

While #90's full CI runs, two independent Ruby-library fixes make two more
original Rack files pass. The same locked 62 files / 1,969 reference tests
now report 50 MATCH / 11 RED / 1 MEMORY (was 48 / 13 / 1 after rounds 1-3),
with no lost MATCH or reference coverage change. Rack alone moves from
30 MATCH / 8 RED / 1 MEMORY to 32 / 6 / 1; the other four gems are unchanged.

- `Zlib::GzipWriter#__write_output` takes the pending bytes out of its
  buffer BEFORE calling the destination. Rack's consumer accepts a chunk
  and then raises FakeDisconnect. The old buffer still held that chunk,
  so ensure's `finish` sent the gzip prefix again and replaced the caller's
  exception with Zlib::DataError. A two-write sink that inflates bytes and
  then raises reproduces it without Rack; now it retains the reference's
  Disconnect and decoded `foo`. Original `spec_deflater.rb` becomes MATCH,
  and CRuby's zlib file stays 96/96 MATCH. Witness 671.
- StringIO's eight backing ivars use the interpreter's existing internal
  namespace. CRuby keeps that state outside Ruby ivars; exposing `@st`,
  `@enc` and the flags made Psych serialize the private State object and
  fail restoring the environment dump. User-added `@st` and `@label` remain
  visible and round-trip; assigning `@st` no longer replaces the stream's
  real buffer state. This is a mechanical backing-name change in
  `lib/stringio_ext.rb`, with its embedded copy regenerated. The original
  `spec_mock_request.rb` becomes MATCH; both CRuby StringIO files give
  103/103 MATCH. Witness 672.
- Corpus 695/695 matches the reference, dead definitions and GC-root gates
  pass, bracket depth stays 895/1024. No main interpreter function, VM,
  AST tree, native API, collector, global let or resource bound is changed.
- `suites.py --verbose` only asks the upstream runner to name each test.
  It identifies the multipart memory file's active case as
  `test_0018_rejects insanely long boundaries`. Both interpreters pass a
  small control allocating 10 MiB and doing one nonblocking pipe write
  (65,536 bytes on each); this does not establish the combined workload's
  cause. The MEMORY verdict and 2 GiB cap remain.
- The previous batch's Gem suites CI 43874223005 passes on Linux and macOS
  with identical reference counts and the recorded 48 / 13 / 1 verdicts;
  an independent review of #90 repeated all 62 files with no regression or
  actionable finding. Full existing-suite CI remains a merge gate.

## 2026-11-17 (67): gem rounds 6-7 -- File overrides and deferred Chain groups

The same 62 locked upstream files now give 51 MATCH / 10 RED / 1 MEMORY,
with zero BOTH or timeout, no lost MATCH and no reference coverage change.
Minitest improves from 3 MATCH / 4 RED to 4 / 3; Rack remains 32 / 6 / 1,
rack-test 7 / 1, public_suffix 7 / 0 and base64 1 / 0.

- `invoke_with_block0` previously handled File.open/new before Ruby method
  dispatch, so a stub worked without a block but opened a real path with
  one. Ruby overrides now receive the block. A restored prelude IO alias
  still uses File's native path handling; the method's native flag and
  actual prelude source metadata identify that case. Witness 676 covers
  keyword/block forwarding and restoring the original alias. The original
  mock file improves from 2 failures / 13 errors to 1 / 8 across 94 tests,
  while remaining RED.
- `core_prelude_b` attaches the existing Enumerable implementation to
  Chain, whose advertised ancestry alone did not provide its private
  helpers. `chunk_while` and `slice_when` construct deferred enumerators
  over the source rather than eagerly gathering it. Witness 677 covers
  deferred predicates, infinite inputs stopped by take, multiple yielded
  values, empty inputs, argument errors and reflected owner/ancestors.
  Minitest's original reporter file becomes MATCH (22 tests / 52 assertions).
  Its test file loses the backtrace-compression errors but retains 8 Marshal
  failures and 1 yield error.
- Corpus 697/697; Enum/Enumerator 159 MATCH / 0 RED / 1 BOTH, with no
  decrease from either required CI baseline. GC roots pass and bracket
  depth remains 895/1024. No new top-level let or resource bound change.
  After #88 merged, the current open branches no longer changed either
  function; their diffs were checked again before publishing this batch.
- #90's completed existing-suite shard 3 has one lower file count:
  test_transcode.rb is 97 rather than 98 MATCH because its ractor encoding
  test reaches its existing 10-second timeout. The isolated test passes
  locally on both the PR binary (5.35 s) and a CI artifact whose relevant
  runtime sources equal main (5.79 s). This does not yet establish a cause;
  rerun CI without changing the limit before accepting the merge gate.

## 2026-11-17 (68): gem rounds 8-9 -- ordered rescue and Hash initialize's block

The original 62 files / 1,969 reference tests now give 52 MATCH / 9 RED /
1 MEMORY, with zero BOTH, TIMEOUT or baseline regressions. Rack improves
from 32 MATCH / 6 RED / 1 MEMORY to 33 / 5 / 1; minitest stays 4 / 3,
rack-test 7 / 1, public_suffix 7 / 0 and base64 1 / 0. The initial 47 / 14 /
1 MEMORY snapshot remains unchanged.

- Rescue checks one candidate before evaluating the next expression or
  validating the next splatted value. An earlier ArgumentError match now
  prevents an unreachable regexp from raising TypeError; a reached invalid
  value still raises. Empty/nil splats remain different from bare rescue.
  `rescue_clause_matches` / `rescue_values_match` reuse the existing lexical
  constant, splat conversion, Module#=== and TracePoint machinery.
  `run_rescues` calls the ordered matcher. The obsolete eager expansion and
  its unused class-name filter are removed. Witness 678.
- `super_missing` retains the actual default Proc passed to Hash#initialize
  from a subclass. The iterator fallback previously lost the block, so
  Rack's symbol-key fallback returned nil. Existing entries remain, lambda
  arity is validated from Proc metadata, and invalid arguments/frozen hashes
  keep their errors. Witness 679 includes to_h, Proc identity and variadic
  as well as strict lambdas. The original Rack utils file passes all
  63 tests / 285 assertions (previously 1 failure / 1 error).
- Corpus 699/699, all six suite-harness controls and the structural gates
  pass. Generated bracket depth stays 895/1024; no top-level let, collector,
  VM instruction or resource bound is added or changed. The open branches'
  corresponding function bodies were compared with main before publication;
  none overlaps. Marshal's separately isolated exception-wrapper difference
  remains recorded because `stdlib_src` is being edited by the GC session.
  Final CRuby Hash gives 297 MATCH / 1 RED / 8 BOTH across 306 tests, equal
  to both baselines; Exception gives 98/98 MATCH. The earlier local exception
  timeout does not recur in this final measurement at the unchanged limit.
- #93's review found that the new grouping callbacks returned true to their
  source. Both now explicitly return nil; witness 677 includes a source that
  stops on truthy yield results. The old O2 runtime truncates both methods to
  [[1]], and the fixed runtime matches the reference's [[1], [2], [3]]. Its
  latest Linux gem CI also gives 51 / 10 / 1 with zero regressions. The P2
  thread is answered in English and resolved; hosted merge checks remain.
- Existing-suite comparisons use latest successful main CI 43869939788 and
  handoff CI 43548292351. #90's final report covers all 758 files. The three
  lower counts from ObjectSpace finalizer, Object copied-ivar and transcode
  ractor timeouts remain, and zlib is 95 rather than 96 MATCH (its case still
  needs confirmation). Bootstrap has 9 missing files after a cancelled shard;
  test_eval is 48 MATCH, equal to main but below handoff's 49. Basic stays
  894/894 MATCH. The whole ordinary workflow is rerun at its existing bounds
  to recover missing coverage and verify the lower counts. Local transcode gives 98/98 on
  both main and #90, and copied-ivar passes on both. Finalizer controls cross
  2 GiB on the PR binary while main controls finish; its cause is unconfirmed.
  No lower count is waived, no limit is increased, and no GC-internal
  exclusion decision is made.

## 2026-11-17 (69): retain implicit super's Proc without replacing yield wrappers

The review's implicit-super witness exposed a lost default Proc identity and
lambda arity in #96. `bind_params` now retains the incoming VProc in the method
frame; `method_body_flow_result` carries its identity through the existing block
metadata path, and `super_missing` recovers it for Hash#initialize. The new
`block_source_proc` recognizes a repeated marker, distinct from the single
marker naming a literal wrapper's enclosing yield context. No new root table,
global pin, top-level let or collector change is needed.

The first candidate confused those two meanings. The original Minitest
assertions file and corpus 226 caught that regression, so it was corrected
before accepting the review response or updating the snapshot. Witness 679 now
covers implicit super/super(), an unrelated nested call, a two-level relay,
literal captures, replacement/nil blocks and yield-containing wrappers. The
extended witness matches the reference both normally and with GC.stress.

- Fresh O2 source 5fbd80c1: all 62 original gem files remain 52 MATCH / 9 RED /
  1 MEMORY, zero BOTH/TIMEOUT/regressions; the initial snapshot is unchanged.
- Corpus 699/699; CRuby Proc 117 MATCH / 1 RED, Super 50/50 and Yield 13/13,
  identical to the paired latest-main controls (96075af9). All six harness
  controls pass; bracket depth is 892/1024 after the incoming main C API merge.
- The separate merge gate remains open. #90's Linux build job now fails the
  Float#step bit comparison. This is not waived as known noise. Latest successful
  main CI is 43933582689; compare it and handoff 43548292351 before any merge.

## 2026-11-17 (70): gem rounds 10-11 -- singleton undef and Module name super

With the unchanged lock and 62 files / 1,969 reference tests, round 10 gives
53 MATCH / 8 RED / 1 MEMORY; round 11 gives 53 MATCH / 7 RED / 2 MEMORY.
There are no BOTH, TIMEOUT, reference changes or lost MATCH. Rack Lint becomes
MATCH (37 tests / 763 assertions). The second memory verdict is a newly reached
request case, not another passing file. The initial snapshot remains unchanged.

- `invoke_val_c2` / `invoke_with_block2` consult a primitive singleton's undef
  before the native path; `respond_to_answer` / `responds_x` ask the same fact.
  `hng_lookup_cls`, `hng_undef_blocked` and `hng_undef_call` keep the actual
  lookup class, method_missing block, query hook and NoMethodError attributes.
  Ordinary class identity stays separate. Witness 681 includes send/public_send
  with and without blocks, redefinition, other instances and saved aliases.
- `super_missing` sends a class/module override's name super directly to the
  existing `mod_name_val`, with native arity. Witness 682 checks named,
  anonymous, late-named and singleton classes, frozen cached names and a
  superclass undef. The shared super lookup and main dispatcher are untouched.
  Minitest spec now executes 76 tests (2 failures / 4 errors), and Rack headers
  51 (37 failures / 2 errors). Both stay RED. Request now reaches TestProxyRequest's
  16 MiB ASCII NUL test and crosses 2 GiB; no VM/GC cause is established.
- Fresh O2 source 861c74d1: corpus 701/701 and both witnesses under GC.stress
  match Ruby. CRuby Method is 97 MATCH / 1 RED and Module 195/195, equal to the
  same-environment latest-main controls. Six harness controls pass; bracket
  depth stays 892/1024. No top-level let, root table or limit change.
- Additional controls reduce RewindableInput to File rewind after chmod(0),
  and the uploaded-file assertion count to reflected File/IO helpers.
  A separate prepended name/undef lookup gap also predates these rounds.
  Their shared-function constraints and remaining symptoms stay in the ledger.
- Linux's ubuntu-latest rollout changed the reference from Ubuntu 24.04 to
  26.04 and exposed fused versus separate Float#step rounding. Strict diagnostic
  output confirms the differing bits. #90 pins only the runtime build and gem
  Linux jobs to the measured Ubuntu 24.04 target; all bounds/assertions remain.
  The newer-target numeric gap stays documented. Updated Linux jobs pass.
  #92's separate Module leak test hit its documented 10-second known noise;
  its raw record is retained for an unchanged-bound job rerun after completion.

## 2026-11-17 (71): retain native definitions through singleton undef

#97's review exposed two distinct native-definition regressions and a saved
alias path missed by the original Hash-only alias witness. A Method captured
before undef must keep its definition, and replacing Module#name must not
make super revive that definition beyond Module. Saved String/Array/Proc
aliases retain their definitions too, including direct, send/public_send and
reflected Method calls with and without blocks.

- `method_unbind_fields` retains the existing native metadata;
  `bi_meth_shadowed` / `bi_meth_call` preserve the native definition through
  the existing one-dispatch bypass. Retained String conversion keeps the
  correct receiver identity, and Hash#to_hash ignores its block.
- `run_block1`, `bind_params`, `method_body_flow_result`, `run_stmts` and
  `eval_run` clear that bypass before Ruby code. The witness includes a
  second receiver's override, coercion defaults and string instance_eval.
  `en_can_buffer` / `gen1_src` keep a returned Enumerator's later source lookup
  ordinary, including NoMethodError after each has been undefined.
- `hng_retained_alias` / `hng_retained_alias_call`, consulted by
  `invoke_val_c2` / `invoke_with_block2`, preserve the native alias's source
  only during redispatch. The block alias path uses the actual singleton.
  `module_name_super_ahead` reads the current method frame and ancestry;
  `super_missing` returns the native name only when Module remains ahead.
- Fresh O2 source a3ad911a: all 62 original files / 1,969 reference tests give
  53 MATCH / 7 RED / 2 MEMORY, zero BOTH/TIMEOUT/regressions. Corpus is 701/701;
  expanded 681/682 also match under GC.stress. CRuby Method is 97 MATCH / 1 RED,
  Module 195/195, TracePoint 97 MATCH / 4 RED / 1 BOTH, Proc 117 MATCH / 1 RED,
  Super 50/50 and Yield 13/13, retaining the paired baseline counts. All six
  harness controls pass; bracket depth remains 892/1024. The initial snapshot,
  collector, shared dispatch bodies and resource limits are unchanged.
- A preliminary corpus invocation stopped at the stale-generated-C gate;
  regenerating and comparing C proved identical contents. A later run mixed
  a changing alias witness/binary and was rejected. Only the final fixed-tree
  701/701 run is accepted. A verbose ShowExceptions time control passes on
  both pre-review and final binaries (81.73s / 82.86s inside the test runner);
  this does not establish a review-induced slowdown.
- An unaccepted Headers class-[] trial exposed bare new without native Hash
  storage and worsened the file to 51 errors. It was reverted, with no trial
  snapshot or public implementation. Its try_self_call/new_obj coordination
  constraint, and additional pre-existing primitive lookup gaps, remain in
  the ledger. Current remote AST/VM/C API/GC function bodies were compared
  before publication; none overlaps the functions changed in this follow-up.
- Existing hosted per-file checks against both CI baselines remain pending;
  no lower count or incomplete coverage is waived and no PR is merged.

## 2026-11-17 (72): gem rounds 12-13 -- singleton missing hooks and command blocks

The unchanged five-suite inventory still gives 53 MATCH / 7 RED / 2 MEMORY,
with zero BOTH/TIMEOUT/regressions across 62 original files / 1,969 reference
tests. Within the RED files, Minitest spec improves from 2 failures / 4 errors /
443 assertions to 2 failures / 0 errors / 451 assertions. Minitest test improves
from 8 failures / 1 error to 8 failures / 0 errors, retaining its one skip.
No entire-file MATCH gain is claimed.

- `invoke_val_c2` / `invoke_with_block2` use the new `hng_missing_hook` to
  reach a primitive singleton's Ruby method_missing for a genuinely missing
  name. Existing Ruby methods, native aliases and the existing native owner
  table win first; response hooks do not decide existence. The existing
  missing-call path retains arguments, keywords, blocks and error attributes.
- `super_missing` now reaches the extracted `missing_native_super` before
  the generic primitive fallback. A hook's super reports the originally
  requested name, receiver and arguments instead of method_missing itself.
  Witness 683 includes Hash/Array/String/Proc, direct/send/public_send calls,
  query claims, existing methods, private refusal, hook super and removal.
- `safe_nav_bare` / `attach_block_method` respect an enclosing command's
  existing nodo flag after parsing their own bare arguments. The outer
  do...end no longer attaches to a nested dotted command. Witness 684 covers
  normal/safe/nil calls, nesting, direct calls, parentheses, braces and the
  exact regex/new/Mutex/yield shape isolated from Minitest. This is a language
  parsing difference; AST/Ripper/Prism tree APIs are untouched.
- Fresh O2 source 61d57736: corpus 703/703. Both added witnesses match normally
  and under GC.stress. Method retains 97 MATCH / 1 RED, Super 50/50, Yield
  13/13; paired latest-successful-main controls for Parse are 102/102 on both
  and Syntax 167 MATCH / 1 RED / 2 BOTH on both. Six harness controls and the
  structural gates pass; bracket depth remains 892/1024.
- The remaining spec-name failures reduce to Array#join ignoring a class's
  Ruby to_s while the direct call works. Its invoke_val_c0 branch, like the
  exception Marshal branch in stdlib_src, is still shared with another
  session. Keep those coordination constraints and original RED files.
- AST #86 has merged to main 392bf810; its ordinary CI is still queued, so
  43933582689 remains the latest successful main baseline alongside handoff
  43548292351. Before publication, the current #99 AST, VM, C API and GC
  branches were compared at all changed function bodies; none overlaps.
  No top-level let, collector, shared dispatcher or resource bound changes.

## 2026-11-17 (73): preserve active refinements before singleton missing hooks

#100's P2 found that hng_missing_hook's real-definition probes omitted lexical
refinements. The existing refinement dispatcher could handle the call, but the
new earlier guard sent it to method_missing. Source 77e39520 also consults the
existing refined_impl_for before declaring the name missing, preserving that
dispatcher's priority without editing it.

Expanded witness 683 covers Hash/Array/String/Proc refinement methods, keyword
arguments, send/public_send and ordinary unhandled names with singleton hooks.
It matches Ruby normally and under GC.stress. A separate block-bearing refined
Hash control fails on the pre-round base too; that existing block-dispatch gap
is recorded, rather than claimed as fixed or removed from an upstream file.

- Fresh O2 full run: 62 files / 1,969 reference tests, 53 MATCH / 7 RED /
  2 MEMORY, zero BOTH/TIMEOUT/regressions. Corpus 703/703. Method retains
  97 MATCH / 1 RED, and paired #97-base/candidate Refinement both give
  121 MATCH / 1 BOTH. Six harness controls pass; bounds are unchanged.
- #90's newly available hosted raw artifacts cover 663/758 existing files.
  ObjectSpace 37, Object 65, transcode 98 and zlib 96 MATCH recover their
  earlier lower counts. TracePoint gives 96 versus handoff's 97; its extra
  recorded error is test_thread_add_trace_func's access-from-outside error,
  while the local paired controls give 97; its cause remains unconfirmed.
  Bootstrap eval is still
  48 versus handoff's 49: case 19 incorrectly allows Integer.instance_eval
  to define a constant. Neither shortfall is waived; remaining shard coverage
  and the two file gates still prevent merging.
- Candidate-only measurements outside the public lock give Matrix 2 MATCH.
  Rake has 20 BOTH because CRuby's core Test::Unit adapter refuses the tag's
  assert_raises alias; Logger's child cannot find its locked library on the
  reference side. These are setup defects, not interpreter verdicts accepted
  into the baseline. The candidates need their actual pinned Test::Unit
  dependencies and inherited locked child load paths before inclusion.

## 2026-11-16 (60): ruby's mkmf builds extensions from mere-ruby's own RbConfig, and published gems -- nokogiri among them -- install with `gem install`

Stage 7′ / 8, third unit (note 553), on the C API of (58). Until now
`require "mkmf"` stopped at a nil RbConfig key, so nothing that builds an
extension the way a gem does could start. Now `mere-ruby extconf.rb && make
&& make install` works with ruby's unchanged mkmf.rb, RubyGems' `gem
install` builds a gem's C extension, and seven published gems -- nokogiri
built from source against the system's libxml2 among them -- behave as on
the reference.

- **RbConfig says the build where there is one.** An interpreter that finds
  `capi/include/ruby.h` beside its executable adds its own build to
  RbConfig: the header directory (`rubyhdrdir`, `rubyarchhdrdir`), the
  executable's directory and name (`topdir`, `bindir`,
  `ruby_install_name`), clang and the flags an extension for it is built
  with, no libruby, and the POSIX tools a Makefile calls -- 97 keys in all
  (36 before; CRuby has 254). Each value is how tools/build.sh builds the
  interpreter or how capi/README.md says an extension is built; none is
  copied from a CRuby installation, and a build without the C API (the Wasm
  playground) gets none. `bindir` and the install name had been `/usr/bin`
  and `ruby`: mkmf writes them into every Makefile as `$(RUBY)`, and
  RubyGems starts `extconf.rb` with them, so with the stand-ins a build ran
  the system's ruby.
- **Left unsaid, on purpose**: `ENABLE_SHARED` ("no" is true, but RubyGems
  names the directory of built extensions after it, and the gems this
  interpreter reads are the reference installation's: every gem with an
  extension was then reported as not built, seven lines on stderr in any
  process whose `require` missed); a libruby name; and the installation
  layout (`prefix`, `libdir`, the site directories stay the stand-ins --
  `make install` is given its directory, as RubyGems gives it).
- **A class C defines is the class statement.** `rb_define_class_under`
  made an anonymous class and set it as the constant. Under two modules
  made the same way the interpreter then lost the link: `class Custom <
  Redcarpet::Render::Base` did not find its superclass again
  (`Custom <= Redcarpet::Render::Base` was nil -- plain Ruby shows it too:
  `Module.new` twice, `const_set` twice, a `Class.new` under them). Where
  the scope and the superclass have names, C's definition now runs `class
  Outer::Name < Super; end` itself (taken to #87 as well, where it went
  first). The anonymous way is kept for the rest,
  and the interpreter's own gap is still there for plain Ruby.
- **`have_func` of a ruby function is answered by whether this interpreter
  has it.** mkmf answers by linking a program that names the function, and
  there was nothing to link a program against -- the C API is in the
  executable -- so the answer was "no" for every ruby function and an
  extension compiled its own substitutes. tools/build.sh now writes an
  import library after the link (capi/tools/import_library.py:
  `capi/lib/libmere-ruby-api`, one empty symbol for each function and
  variable of the C API the executable exports -- about 800 and 100), and
  RbConfig names it as `LIBRUBYARG`, which mkmf puts on the link line of
  its test programs and not on an extension's. The functions of
  capi/unsupported.c are left out of it: for those the answer is "no", so
  an extension takes its other path instead of meeting NotImplementedError
  when it runs.
- **test/mkmf has a build tree to run in.** ruby's mkmf tests are written
  for a ruby build tree (`$extmk`, topdir's Makefile, ruby.h under the
  source tree, config.h under `.ext`). The reference side runs them in its
  own (build_reference.sh); for mere-ruby, unittest/mkmf_context.sh stages
  one of links to capi/include, a Makefile mere-ruby's own mkmf writes, and
  a launcher the test and its children run through. Nothing about the
  compiler or the flags is overridden there.

**Checks.**

- `tools/capi_mkmf_check.py` (CI, macOS and Linux): an extension whose
  extconf.rb asks about headers, functions, macros, a size and a library,
  and ruby's `ext/-test-/float` by its own extconf.rb, built with
  `extconf.rb`, `make`, `make install` on both rubies. What mkmf answered
  is read out of the built library: 14 contracts, the same on both sides
  and under a collection at every safepoint (`rb_ary_new` yes on both,
  `rb_tracepoint_new` yes on the reference and no here). A source that does not compile
  fails at `make` on both; mere-ruby given the libraries the reference's
  mkmf built fails.
- `tools/capi_gem_check.py` (CI, macOS and Linux): fast_blank 1.0.1,
  redcarpet 3.6.1, msgpack 1.8.7, racc 1.8.1, bcrypt 3.1.22, nio4r 2.7.5
  and nokogiri 1.19.7 (from source, `--use-system-libraries`) are installed
  by each ruby with `gem install` from the same .gem files;
  `capi/check/gems.rb` uses them (84 lines of output: blank tests; HTML and
  a Ruby-defined renderer called back from C; packing and unpacking
  Integers, Floats, binary and UTF-8 Strings, a streaming unpacker, a
  malformed input's exception; racc's C runtime; a bcrypt hash of a fixed
  salt; nio4r's selector over a pipe's two ends and its byte buffer;
  nokogiri's CSS and XPath queries, namespaces, node edits and
  serialization, the Builder, syntax errors as objects and as a raised
  exception, a fragment, a SAX handler called back from libxml2) and prints
  the same on both sides. mere-ruby pointed at the reference's gem
  directory fails.
- Local, O2: gates dead_defs, dup_defs, gc_roots pass; bracket depth 933 of
  1024; capi_check as before.

**Measured here** (this machine, the interpreter's side; CI's shards are the
record and go in below when they have run):

- `test/mkmf`: 144 of 148 pass and all 17 files reach their summary (0 and
  none at the baseline). The four left: `have_func("ruby_init")` -- the
  embedding entry point is not part of this C API, and the answer is a
  true "no"; two of
  test_have_library, which take the platform's library prefix from
  `LIBRUBY_A`'s name, and there is no such archive; `test_dir_config`,
  which wants `libdir` written in terms of `exec_prefix`.
- `test/rubygems`: 2773 of 2780 pass (the baseline's MATCH was 2712), no
  file lower than its baseline row. test_gem_ext_ext_conf_builder 3 -> 8 of
  8, test_gem_ext_builder 18 -> 22 of 23, test_gem_installer 120 -> 127 of
  127, test_gem_commands_exec_command 0 -> 28 of 28,
  test_gem_ext_cargo_builder_unit 0 -> 5 of 5.
- `test/-ext-`: 659 of 831, as at (58).

**Found on the way, not this round's to fix** (both are the interpreter's,
on any build):

- A program started with SIGINT ignored (a shell's `&` job) keeps it
  ignored in ruby and does not here: corpus/394 prints one more line in
  that case alone. `run_corpus.sh` in the foreground, as CI runs it, is not
  affected; two local runs started with `&` were.
- The directory test is `stat("<path>/")`, and on this machine's macOS the
  kernel answers that for one symlink to a file (a `~/.gemrc` pointing into
  another directory) with success about four times in ten: `File.read` of
  it is then EISDIR, at random. capi_gem_check.py runs with a home of its
  own.

**Memory views** (`ruby/memory_view.h`) are CRuby's own memory_view.c,
vendored unchanged like st.c and compiled through a wrapper
(capi/memory_view.c; the two internal headers it includes are stand-ins in
capi/standin with the one function and the one macro it uses). They leave
the unsupported ledger, which was 56 functions then (62 with the six
ruby/spec's extensions needed to load, below). `ruby/test_memory_view.rb`
passes 24 of 24 here (0 at the baseline, where the file stopped at its
require). Its last test calls the extension's methods from another Ractor:
a method that is a C function may be called from any Ractor now, where one
made from an ordinary Proc belongs to the Ractor that made it.

nokogiri needed two things beyond what the smaller gems did: RbConfig's
`host` (the configure triplet -- cpu, vendor, os and, on Linux, the C
library the interpreter was compiled against -- and an empty `host_alias`),
and `rb_undef_method` being C's, which says nothing when it undefines
`initialize` and does not mind a name nothing defines.

**What more gems asked for.** Eleven more source gems were built with `gem
install` here -- bcrypt, oj, nio4r, websocket-driver, json, date, stringio,
bigdecimal, puma, unf_ext (C++), strscan -- and for each built library the
C API symbols it asks for and the executable does not export were listed
(`nm -u` against `nm -gU`). Ten of sixteen libraries missed nothing. What
the others missed and is written now (capi/needed.c, capi/mirror.c):
`rb_convert_type` / `rb_check_convert_type`, `rb_memhash`,
`rb_must_asciicompat`, `rb_ivar_foreach`, `rb_copy_generic_ivar`,
`rb_backref_get` / `set`, `rb_reg_new`, `rb_reg_nth_match`,
`rb_marshal_load`, `ruby_scan_digits`, `ruby_strtoul`, and the IO struct:
`RFILE(io)->fptr` is filled from the IO each time it is asked for (the
descriptor, how it was opened, the path), and `rb_io_check_closed`,
`rb_io_check_readable` / `writable`, `rb_io_set_nonblock`,
`rb_io_taint_check` take it. With those, oj, date's and json's extensions
load and answer, and nio4r's selector (libev) behaves as on the reference;
bcrypt and nio4r joined capi_gem_check.py (seven gems, 84 lines), and
each of these functions has contracts in capi/check/api.rb (65 on both
sides then; 94 with those #87's CI added). Writing those against the reference corrected two of them
before they shipped: the refusal of an implicit conversion reads "no
implicit conversion of X into T" in 4.0, and `$~` read from C is the
calling Ruby frame's, which is parked while the C method's frame runs. Still
out: strscan (written against Onigmo's own structs: its substitute for
`rb_reg_onig_match` collides with the header's declaration) and stringio
(`rb_io_extract_modeenc`, Onigmo's `onigenc_get_right_adjust_char_head`);
this interpreter has its own StringScanner and StringIO.

**ruby/spec's C API specs run, on both sides.** `optional/capi` is 46 spec
files, each with a C extension that calls the functions its examples are
about; README.md listed them as not measured because they are built with
mkmf. `tools/capi_spec_check.py` builds each extension for both rubies and
runs each file on both with the spec shim; the count of passing examples per
file is recorded in `capi/check/spec_expect.tsv`, and CI (macOS) holds the
reference to its recorded count and mere-ruby to no less than its own.

- The first run: 756 of the reference's 2,372 examples passed, and 20 files
  did not report at all -- 55 functions were missing among them, and one
  missing function keeps a whole extension from loading. With those written
  (capi/needed.c: `rb_iterate`, the `rb_fiber_*` and `rb_set_*` families,
  `rb_make_exception`, `rb_class_*instance_methods`, `rb_reg_match`,
  `rb_io_open_descriptor`, the descriptor sets of thread.c,
  `rb_thread_fd_select` and `rb_thread_wait_fd` as the interpreter's own
  wait so that other threads run meanwhile, ...) and six more in the ledger
  (an encoding's alias, a TracePoint's state, and at first the global
  variables C keeps):
  **2,242 of 2,584** then, 2,269 with what follows (the reference's count grew as files that had not
  loaded there either, for a helper this tool had left out, came in).
  16 files pass every example the reference passes.
- It found a crash: `rb_get_alloc_func` answered NULL for a class no C
  allocator was defined on, and ruby/spec's allocator calls its
  superclass's. It answers ruby's own allocator now (an instance made the
  builtin way), and NULL only after `rb_undef_alloc_func` -- which is kept
  apart from "no C allocator": `allocate` and `new` raise "allocator
  undefined for C" then.
- Two things the examples then asked for, written: **a global variable C
  keeps** (`rb_define_variable`, the read-only, hooked and virtual kinds:
  the interpreter's read and write of `$name` call the C getter or setter
  the name was defined with; globals_spec 17 -> 33 of 44), and **the bytes
  past a String's length are C's too** -- what C writes there, to reveal
  with `rb_str_set_len`, is no longer cleared by the next fetch, and a
  String ends in the terminator of its own encoding (one NUL, or a UTF-16 /
  UTF-32 code unit) where four NULs were written; `StringValueCStr` puts
  the terminator back (string_spec 280 -> 291 of 314).
- Not reporting yet on this side: io_spec and thread_spec (both reach the
  120-second bound: a wait in C that the interpreter's threads cannot end),
  and digest_spec (no `ruby/digest.h`). The rest of the difference is
  examples, file by file, in the record.

**What the review found** (PR #95; four, each reproduced by the same C on
both rubies, each with contracts in `capi/check/api.rb` now -- 166 on both
sides):

- A global C keeps (`rb_define_variable`), defined under a name Ruby had
  aliased already (`alias $dest $src`), aborted the first read with "[BUG]
  a global variable C keeps has no record": the interpreter keeps the
  variable under the alias's original and called C with that name, while C
  had recorded the alias. The request that defines it answers the name it
  is kept under, and C records that.
- The struct behind an IO said the DESCRIPTOR's directions (F_GETFL): an
  `IO.for_fd(fd, "r")` on a descriptor opened for both read as writable,
  and `rb_io_check_writable` let C write through an IO Ruby holds
  read-only. The directions are the IO's own now -- a File's mode, a
  descriptor IO's two flags, or the standard stream it is; O_APPEND still
  comes from the descriptor, whose property it is.
- `rb_io_open_descriptor` dropped FMODE_EXTERNAL, so the IO owned (and
  would close) a descriptor the caller keeps. It is `autoclose: false` now.
- `rb_set_*` dispatched: a Set whose singleton or subclass overrides
  `add?`, `include?`, `size`, ... changed what C added, found or walked.
  They act on the Set's table with the Hash primitives now, as set.c does
  on its own, and a frozen Set refuses with ruby's FrozenError.

**What CI found** (run 43985130423 on b90f63af, every job green; MATCH
33,403 against main's tree's 33,183, RED 1,011, 29 files higher, one
lower): `test_rbconfig.rb` 6 -> 5, `test_archdirs`. Ruby's MAKEFILE_CONFIG
names every `*arch*dir` in terms of `$(arch)` (or `$(rubyarchprefix)`), and
this branch said `rubyarchhdrdir` as the plain path of capi/include. In
ruby's layout that directory is the arch's own and holds `ruby/config.h`
(mkmf puts it first on the include path and in every Makefile's
dependencies). tools/build.sh now writes `capi/arch/<arch>/ruby/config.h`
after the link, and RbConfig says `$(topdir)/capi/arch/$(arch)` where that
file is there (the plain capi/include where it is not). Also: the Linux jobs
are pinned to ubuntu-24.04, as in #89 -- ubuntu-latest became 26.04, where
unittest/math_glue_check.py fails on every branch.

The CI of d63baee5 (run 44023829896) still had `test_rbconfig.rb` at 5:
the shards run the executable from the build job's artifact, which carried
the executable alone, so capi/arch -- and capi/lib, the import library --
were not beside it there, and RbConfig said what a build without them
says. The artifact carries both now. The same run had
`-ext-/string/test_nofree.rb` and one test of `ruby/test_object.rb` time
out at `assert_no_memory_leak`'s 10 s (7.2 s here, on main's build as on
this one): unittest/README.md's Known noise.

**What the CI of main's merge found** (run 44129914798 on b2ee5cb3):
`optional/capi/regexp_spec` 28 -> 27. `rb_backref_get` answered nil for the
match an example had just made: capi_enter finds the C method's caller one
entry below the C method's own frame on fb_env_at, and since #89 that frame
stands at two depths when the call is in a block a Ruby method yields to --
mspec's `it` -- so "one below" was the C method itself, with an empty `$~`.
Every entry that is that frame (its fid) is passed over now. A call from the
top level read its own frame too: its caller is at -1, the main script's
env, which `at > 0` left out. Three contracts in api.rb (a yielded block,
the top level, rb_backref_set there); regexp_spec is 31. The same run's
build-linux failed in the Module check at
`test_complemented_method_entry_memory_leak` (10.05 s of 10), as main's own
run of e40bb486 does. Not #89: other runs on main's tree took 25.5-27.0 s
for the whole Module check where these two took 39.7-39.9 s, every test
about 1.6 times slower -- a slow runner. The leak tests take 4.6-6.5 s of
their 10 on an ordinary one, though, and they are being made faster (the
limit stays).

**What the third review found** (two, both reproduced with the same C on
both rubies): looking the caller up was the wrong way round. A Fiber's or a
Thread's body matches into a `$~` of its own, not its lexical home's, so C
read the outer match there and `rb_backref_set` wrote into it; and
`public_send`, `class_eval` and `module_eval` leave no entry on fb_env_at,
so the lookup fell back to the C method's own empty frame. Ruby's C
functions have no `$~` at all -- they run under their caller's -- and this
interpreter already had that for the prelude's methods (meth_cfn,
rx_cfunc_frame). A method whose body is a C API Proc (capi_dm_body) now
gets it too, and rb_backref_get / set read and write rx_md as it stands. A
`Regexp#match` that C sends now sets the caller's `$~` as in ruby, which it
did not before. Seven contracts (a Fiber's and a Thread's reads, a write
from each that leaves the outer match alone, public_send, class_eval,
module_eval). regexp_spec is 35 of 35 now (the reference's), the C API's
specs 2,277 of 2,584, the contracts 177.

**Next**: the examples of `optional/capi` that differ, largest files first
(string_spec, encoding_spec, class_spec, struct_spec, globals_spec's `$/`
and `$stdin` as C variables that follow the interpreter's), and io_spec /
thread_spec.

## 2026-11-15 (57): RubyVM::AbstractSyntaxTree answers parse.y's tree

The second half of stage 5's second part (note 550 §1, note 551). test_ast
was 92 RED of 2,664 (main's CI run 43548292351): `parse` answered a SCOPE with
no children. With this it gives the reference's result here -- 2,664 tests,
2,633,172 assertions, no failure, no error, the same 13 skips. corpus 660
(658 and 659 are the VM rounds', #85).

**It did not fit CI's 600 s at first.** CI run 43711089264
stopped the file at 623.9 s (WALL_LIMIT, 2,416 of its tests named), which
reads as 0 MATCH where the baseline has 2,559. From that run's log, for all
850 files: test_all_tokens about 360 s, the two walks over real trees
(test_ranges, test_not_cared) about 280 s that were 4 s, the rest 26 s --
about 670 s on a runner that was a tenth faster than the baseline's. The
estimate made here from instruction counts (1.345 times the baseline's, so
557 s) was wrong: on the runner the token test took the same time as before
although it executes 0.85 of the instructions. With the two fast paths
below (the walks 17% cheaper, measured under test/unit: 141.7e9 -> 117.2e9
instructions for 200 files) CI run 43736889826 finished the file in 500.3 s
on a runner as fast as the baseline's: 2,651 MATCH, 0 RED, 13 BOTH, where
the baseline has 2,559 and 92. The collector's floor (below) takes the walks
down further; with it, run 43793344878 finished the file in 553.4 s -- 2,651
MATCH, 0 RED -- on a runner whose other files ran at 0.92 of the
baseline's time. The same code's instructions here did not change between
the two (the token test 159.4e9 / 160.3e9, the walks 101.1e9 / 100.5e9), so
the spread between 500 s and 553 s is the runners'. That leaves 47 s of the
600 on the slower one, which is thin. What is left, and where it is, is the
last item.

- **The tree is made from Prism's, in Mere.** libprism's serialized bytes are
  decoded into flat integer tables (m_prism_dec.mere), translated to
  parse.y's nodes (m_ast.mere, m_ast_out.mere) and made into Node objects
  (m_ast_obj.mere) with no line of Ruby run: 9.8 µs a node for
  `parse_file`, libprism's own parse included. The translation is parse.y's
  grammar actions replayed -- block_append, list_append, arg_append,
  new_args, reduce_nodes, literal_concat and the rest under their own names
  with a `p_` in front, moving locations as they do -- and `#children` is
  ast.c's node_children. The readers of Prism's fields and the dispatch on a
  node's type are generated from Prism's `config.yml`
  (tools/gen_prism_schema.rb nodes -> m_prism_nodes.mere; only the names the
  sources use are written, the rest being definitions dead_defs refuses).
- **Checked against the reference's parse.y, node by node.**
  `tools/ast_on_cruby.rb text` writes the reference's tree a node a line
  (values by their bytes, with `--locations` the other locations too) and
  `tools/ast_dump` -- the translation alone, compiled without the
  interpreter in about a second -- writes this one's; `tools/ast_text_diff.rb`
  compares. All 850 files test_ast reads agree (1,002,706 lines, locations
  included); 956 of Prism's 976 fixtures do (5 of the rest are where the
  reference's own `#children` raises, `::A ||= 1`). Which programs are
  refused agrees for the 201 tried (break / next / redo / retry / yield /
  return in every place test_ast puts them, and the like).
- **A program that does not parse (`error_tolerant: true`).** parse.y and
  Prism recover differently, and what test_ast pins is translated back: a
  construct whose `end` never came ends at the last token; something after a
  whole statement at the top level (`1q`) ends the program there; a missing
  condition's ERROR is the token the parser was looking at; an `end` that
  closes a class or module by its indent (parse.y's enforce_keyword_end:
  `foo.` / `end`) closes it, the statements Prism nested under it going back
  out one construct at a time; a literal that is no regexp holds nil. Not
  translated: where parse.y makes the whole statement an ERROR -- the same
  junk after a statement inside a def, an expression cut off at the end of
  its line (`a = 1 +`), an unclosed bracket before an `end` -- and the
  indent rule anywhere but directly in a class or module body.
- **This interpreter's own parser is no longer the judge of whether the
  program parses.** `parse` reads the program with it first, for what parse.y
  says besides the tree -- its warnings (corpus 502 pins them) and a
  SyntaxError in its wording (corpus 467) -- and that parser refused programs
  that are fine (a pattern with a range and a guard), which was a
  SyntaxError out of `parse`. Its error now stands only when the tree's
  parser refuses the program too. Prism's errors refuse what parse.y refuses;
  the two it does not report -- a `retry` in an `END { }` inside a rescue, a
  literal that is no regexp -- are found by the translation, and an error
  only Prism reports is its text in parse.y's layout (the text, the line, a
  `^~~` under the place).
- **Two things that made the tests' own loops slow, found by timing their
  pieces inside and outside test/unit.**
  - `#inspect` of an Array or Hash asked pp's cycle table
    (`Thread.current[:__recursive_key__]`) with four method calls, for every
    container, once pp.rb had run at all -- and test/unit loads it. An array
    holding one array: 2.9 µs before pp.rb, 14.4 µs after; now the table is
    read where Thread#[] keeps it (3.4 µs). test_all_tokens builds two such
    strings a token, 2.37 million tokens: 296.8 s -> 242.0 s.
  - An attribute reader called with nothing reads the instance variable
    where it is, with no frame (2.6 µs -> 1.7 µs). ruby's is a C function
    too. A TracePoint, set_trace_func, Coverage's method table, a Ractor or
    a block given take the full path.
- **Two fast paths for the walks' own code** (after the CI run above), each
  where ruby has a C function or nothing to look at:
  - *An attribute read is answered at the dispatcher's door.* `obj.name`
    with no argument went the whole way a call goes -- the tests by name,
    the ancestor walk, the visibility walk -- before run_meth_result's arm
    read the slot: 12,900 instructions. The first time, for a class directly
    under Object, the whole way is gone and what it ended at is kept under
    the lookup generation and the count of private / protected marks
    (attr_ic in m_state.mere); after that it is 3,300. Both doors, with a
    receiver (invoke_val_c) and without (try_self_call).
    `MERE_RUBY_ATTR_IC_CHECK=1` asks the dispatcher every time as well and
    stops on a different answer.
  - *A method that only stores its arguments runs with no frame*
    (`def initialize(a, b); @a = a; @b = b; end`): `Point.new(1, 2)` 62,800
    -> 38,100 instructions.
  The walk benchmark (200 files, both walks and the parse): 167.7e9 ->
  135.5e9 instructions. corpus 661 holds what can change an answer after
  the short way was learnt -- it caught the cache learning a `super` from a
  prepended module's method as the call itself: learning stops as soon as
  any method or block body starts to run. The corpus is 690 of 690 with
  the check on.
- **The collector waits for 32,000 new entries, not 4,000, while no class
  is being made** (the owner's decision, 2026-11-16; note 551 §8). A
  collection has a cost that does not depend on what is live, and a program
  with little live that makes small objects paid it every 1,300 objects:
  30% of `Point.new(1, 2)` in a loop, a quarter of test_ast's walks. With
  the floor at 32,000 the walks execute another 14% fewer instructions
  (117.2e9 -> 101.1e9 for 200 files under test/unit) and the file's peak
  memory footprint is no higher (3.93 GB before any of this, 3.62 GB now).
  Raising it found what the low floor had been hiding, and each is dealt
  with here:
  - *Dead classes are not small, so a loop that makes classes keeps the old
    floor.* test_module's complemented_method_entry leak test -- two classes
    and a refinement a turn -- already sits on its limit (1.94 to 2.01 times
    its starting RSS here, limit 2.0) and went to 2.43; `a.clone.set`, `a`
    having a method of its own, ran four times the instructions, since a
    clone copies its singleton's methods out of the whole method table. The
    count of classes ever given a superclass (cls_made) is kept at each
    collection, and once it has moved the entry threshold is the one with
    the old floor (gc_knob 13, 14). Those loops collect exactly as they did
    (11 collections in 21,000 turns of the leak test, before and after).
  - *Copies and `instance_variables` walked the table of every object's
    variables.* `obj.dup`, a Struct's, an exception's, `"abc".dup`,
    `[1].dup`, `{}.dup`, `-str`, `obj.instance_variables`: each looked
    through every instance variable alive for the ones of its receiver,
    which made them two to five times slower once more garbage waited. An
    object's are now found by its own list of names (ivar_names_of's
    index, and a Struct's members by its class); a String's, an Array's and
    a Hash's are looked for only once one of them has ever been given a
    variable (hiv_made). Against the build before the floor moved, with
    objects being made beside them: `obj.dup` 0.37 of the instructions,
    `"abc".dup` 0.68, `instance_variables` 0.55, `-str` 0.73. corpus 662.
  - Thirty-six kinds of allocation loop (objects, fibers, threads, classes,
    modules, structs, singletons, finalizers, procs, enumerators,
    exceptions, strings, ...) and twenty operations beside an allocation
    were measured before and after: none executes more than 1.05 times the
    instructions it did. A small program's peak RSS is 20 to 40 MB higher
    (75 -> 100 MB for a loop of `Struct.new(1, 2)`): that is what now waits
    for a collection. tools/loop_rss_check.sh holds all nine of its bounds,
    and the memory-leak tests of test_object, test_module and test_class
    pass as before.
- **Where the rest of the time is** (note 551 §5), none of it touched here:
  - what one collection costs: three fifths of it is the runtime gathering
    and sorting the suspended stack's words (`__lang_coro_pins`,
    `__lang_coro_scan_ints`) -- deep under test/unit, deeper in a recursive
    walk. 20% of an assertion loop is still collection;
  - interning a block's body compares the whole tree each time a block
    becomes a Proc: 6.7% of test_all_tokens (assert_equal's message is
    thirty lines);
  - the fixed cost of a call into a builtin (12,000 instructions for
    `array.last`) and of a method call (25,000).
- **Also**: a Symbol literal keeps the encoding it was written into
  (`:"r\u{e9}sum\u{e9}"` in a US-ASCII file is UTF-8 -- test_struct.rb and
  test_data.rb could not be read); `AbstractSyntaxTree.of` answers nil for an
  attribute method; tools/ast_dump lost its development stubs. Kernel#pp of
  a Node before pp.rb is loaded still prints `#inspect` (ruby loads pp.rb on
  the first `pp`).
- Gates: dead_defs, dup_defs, gc_roots pass; bracket depth 923 of 1024 (was
  892 on main: the translation and the caches keep top-level tables).

## 2026-11-21 (76): what Rails' own dependencies build, on the C API

Rails 8.1 installs on main now (issue #116: #95 and #120), and the next
stages -- boot, the application's tests, Puma serving HTTP -- run the C
extensions of its dependencies. Thirteen of its 68 locked gems have one.
`tools/capi_gem_check.py` builds five more of them at railstest/'s versions,
on both rubies, and uses them the same way: erb (its escape, which
ERB::Util.html_escape is), rbs (a C parser building Ruby AST objects),
websocket-driver (the frame mask), puma (the HTTP request parser) and sqlite3
on the system's SQLite (BLOBs, a Ruby function SQL calls, transactions,
errors). Each prints whether the extension it loaded is the gem home's.
json, date, bigdecimal, io-console and prism build too, but mere-ruby
loads its own library of the same name before an activated gem's extension
(issue #127, PR #128): what they would compare is not the C API.

**What it found** (each reproduced against ruby first):

- `class <<self` with no space was a here document whose terminator is
  "self": the rest of the file was its body, and `require "rbs"` a
  SyntaxError. parse.y opens none after the keyword `class` (EXPR_CLASS);
  after_class_kw says so (and `obj.class <<X`, a method named class, keeps
  its argument). corpus/761.
- A backslash that ends a line continues it, and a `?` that starts the next
  line was taken for a character literal at a statement's start ("unexpected
  '?'"): prev_nonspace now looks past `\` + newline. rbs's
  value_object_generator.rb writes `x.nil? \` and then `? a : b`.
  corpus/762.
- `module_function` copied a define_method body WITHOUT its closure: the copy
  of `define_method(:x) { v }` read `v` as a method call. A C method is such
  a body, holding the function it calls, so erb's
  `include ERB::Escape; module_function :html_escape` -- how every Rails
  template escapes -- raised NoMethodError for `__capi_m`. modfunc_promote
  copies as alias does (copy_meth_src). corpus/763.
- CLASS_OF of an instance of a builtin's subclass was the builtin: a String
  of `class Blob < String` is a primitive tagged with its class, and
  capi_describe answered class_name. sqlite3 binds a SQLite3::Blob as a BLOB
  by its class, so it stored text and read it back in UTF-8. It answers
  dispatch_cls_of now. Four contracts (`class_of` in the fixture).

**Found, not fixed here**: `module_function :m` of an INHERITED m leaves no
private `m` in the module itself (`private_instance_methods(false)` is `[]`
where ruby lists it).

## 2026-11-17 (73): test_ast's margin -- what every assertion runs, and a block's number

test_ast fits CI's 600 s since LOOP (57), with 47 s to spare on the slower of
two runners (553.4 s in run 43793344878). This round takes what every
assertion and every Proc pays. corpus 680.

- **A store-only method and a memo reader run with no frame where
  test/unit has them.** Every assertion calls `self._assertions += 1`, and
  both halves went the whole way of a method call. `_assertions=` is the
  store-only shape LOOP (57) gives no frame, but core_assertions.rb says
  `binding` (in a method no test calls), and in a file that does the parser
  puts a mark in front of every body naming the locals it assigns (lvd_head)
  -- a statement the store-only check did not know, so the setter was off
  the short way under test/unit and on it everywhere else. The mark is read
  past now. `_assertions` is `@_assertions ||= 0`: a reader whose body is
  `@x ||= <literal>` is answered with no frame. An `assert_equal(1, 1)`
  524,500 -> 483,300 instructions.
- **`@x ||= v` / `@x &&= v` used as a value no longer writes back what the
  short circuit decided.** The statement form (SIVarAssign) never wrote; the
  expression form -- `def n = @n ||= 0`, `(@n ||= 0)` -- did, and a frozen
  object raised FrozenError for a memo it already had. Found by the
  witness of the memo reader.
- **A block made into a Proc again is found by its number** (blk_intern).
  Interning a body compared it with the bodies already kept under its key,
  and comparing two trees that ARE the same goes to the end of both: 6% of
  test_ast's token test, assert_equal's thirty-line message block each
  time. The parser now numbers each block it reads and puts the number in
  the mark that already carries the line of its `{` or `do`:
  `SLine -(line + number * 2^24)`, read with blk_line_of / blk_id_of (five
  readers took the line as `0 - n`; the VM's vm_body_pos is one of them).
  A body seen under its number and key is the one interned the first time.
  The key stays beside the number because the interpreter rewrites block
  bodies at run time keeping the mark in front.
  `MERE_RUBY_BLK_ID_CHECK=1` compares anyway; it found that a body with a
  Float literal is never equal to itself here -- Mere's generated eq_float
  answers 0 -- so before the numbers every Proc of such a block added its
  body again and compared against every copy kept: 8,000 Procs of one block
  35.6e9 instructions, 1.1e9 now.
- **The attribute reader cache asks about the class only before an entry
  is made.** What it asks -- a singleton, a superclass other than Object, a
  builtin name -- is fixed when the class is made, or changes through
  set_sup / set_meth, which move the token an entry is kept under. Asking
  it at every hit was 6% of the walks.
- **Measured** (instructions, under test/unit, this machine): the token
  test over 150 files 158.9e9 -> 141.8e9 (-11%); the walks over 200 files
  100.5e9 -> 97.6e9 (-3%).
- **Why it is in #86.** On CI run 43873004686 (the translation, the fast
  paths and the collector's floor, on main with the VM's round 38) test_ast
  ran 625.6 s and was stopped at the wall: the shard's runner ran the other
  files at 1.15 times the baseline's time, and 625.6 / 1.15 is 546 s -- the
  same file as before, with too little room for a slow runner. With this
  round the same file is about 7% less work.
- Checked: corpus 694 of 694, and with MERE_RUBY_BLK_ID_CHECK,
  MERE_RUBY_ATTR_IC_CHECK and MERE_RUBY_IVAR_INDEX_CHECK on; test_ast's
  individual tests 114 as the reference; the gates.

### Integrate the AST main and keep corpus numbers unique

Main 392bf810 integrates #86. Its main CI 44030304378 is still pending;
successful PR CI 43985122856 tested source 0031da3a, whose tree is identical
to this main, and retains the same 157 target RED. This supplements the last
successful main baseline 96075af9 rather than claiming a completed main run.
The AST and VM changes are imported unchanged; there are no independent
edits to m_state or the AST/Prism implementation. Corpus namespace auditing
found overlapping publication numbers. This branch moves its native
ObjectSpace snapshot witness from 683 to 685, retaining the upstream cases.

The follow-up store witness moves from its original publication number 680
to 686. The upstream AST/Proc witness at 680 is retained unchanged. Earlier
progress entries use their publication numbers; this records the mapping.

The identity witnesses similarly move from 681/682 to 687/688 after the
remote namespace audit. The earlier conversion-review entries retain their
publication numbers. Only this session's witnesses are renamed; main's and
the concurrent branches' cases are retained. This integrated branch has
703 corpus programs, including the four cases newly imported from main.
## 2026-11-16 (61): round 39 -- what test_iseq and test_optimization still asked

**The point.** `ruby/test_iseq.rb` goes from 42 of 70 to 62 of 68 (the two
tests of `ISeq.load` are not defined in ruby, where the method is private,
and no longer are here), `ruby/test_optimization.rb` from 82 to 85 of 89.
None of it is the VM's loop: it is `RubyVM::InstructionSequence`'s own
surface, the compiler, and four things the evaluator had wrong.

- **`ISeq.of` answers a sequence.** For a Method, a Proc or a backtrace's
  Location it answered an object that knew a name and a line and nothing
  else. It is now the sequence the file's own compilation has: the file is
  compiled once (per path), and the method's sequence that starts on that
  line -- a block's, the innermost; a frame's by its label and line -- is
  what #to_a, #disasm, #label, #base_label and #first_lineno read. The same
  code answers the same object; a sequence answers itself; a file that does
  not compile leaves the name and the line, as before.
- **What compile refuses.** After the evaluator's own parse, Prism is asked:
  "Invalid break" and its kin, and a stray `end` the evaluator's parser let
  by, are a SyntaxError as Prism frames one (the line, two around it, the
  extent under it); a `yield` outside any method is prism_compile.c's
  one-line "Invalid yield". A source String in another encoding is read in
  it, and its disassembly answers in it. `ISeq.allocate` has no allocator;
  `debug_level: ""` and `load_from_binary(0)` are TypeErrors; a File is read
  by its path, open or closed.
- **`ruby --dump=insns`** prints the main script's sequences (the program
  is not run; what runs in its place prints the disassembly).
- **The compiler**: an empty `#{}` is a nil no node stands for; a keyword
  hash as a value (`return **h`); a pattern's literal pieces in the
  encoding its n / u / e / s names. compare_files: 671 the same, 21
  refused, 0 different.
- **In the evaluator** (each wrong without the VM):
  - a shareable Proc whose block ASSIGNS an outer local is ruby's
    ArgumentError naming every such local, before anything else is asked;
    a local whose name is not ASCII was not seen as one; a bare `super` in
    the block reads the method's parameters (the anonymous `*` shown as
    `*`). A VM block answers the same from its program (vm_outer_writes).
  - the operand after `and` / `or` takes its own one-line pattern match:
    `true or 1 in 1` was `(true or 1) in 1`, and a SyntaxError as a
    statement.
  - a `===` the program gave TrueClass, FalseClass or NilClass is the one
    `when true` calls.
  - `-x`, `~x`, `+x` and `!x` are calls a TracePoint sees (:c_call of
    String#-@; one that raises still returns), not a String literal's
    `-"s"`; a builtin `!=` is a call of `==` inside it. `unless` and
    `until` were written with the same node as `!x`, so a class's own `!`
    was called for them, which ruby never does: they are an operator of
    their own now (neg_op), the condition's truth turned over with no call.
  - a negative Integer's own address is the 64 bits it is
    (`#<Integer:0xffffffffffffffff>`).
- **Still RED, and why**:
  - test_iseq 6: two loops of a million `ISeq.new(nil)` / `load_from_binary`
    inside 10 s (28 and 39 s here: the evaluator's speed, the speed stage's);
    two that read a builtin's own sequence (`[].method(:pack)`); a Ractor
    that redefines Kernel#Float; `case / in` in the compiler.
  - test_optimization 4: tail calls that must not grow the stack (2), a
    million `"".empty?` in time, the memory a frozen IO buffer gives back.
  - test_coverage: round 40, below.
- Witness 664. The counts are with round 40's, below.

## 2026-11-16 (62): round 40 -- branch coverage, counted by the VM

**The point.** `coverage/test_coverage.rb` goes from 34 to 45 of 46.
Branch coverage was counted nowhere; it is now what ruby's is, construct
by construct and count by count, for a file the VM takes.

- **A file read while Coverage is set up runs on the ISeq VM**, when the VM
  takes it (vm_file_stmts; otherwise the evaluator runs it as before and
  the file has no branches). With branches asked for, the compiler is given
  `coverage_branches`.
- **The compiler puts the branches where ruby's does** (compile.c's
  decl_branch_base and add_trace_branch_coverage, at prism_compile.c's
  sites): `if` / `unless` / the ternary (then, else), `while` / `until`
  (body), `&.` (then, else), `case` / `when` with and without a subject
  (each when, the else written or not). Each branch is a `nop` of its own
  with the coverage event, at the branch's last line. ruby compiles the
  same into a sequence made while Coverage counts branches, so this too is
  compared with ruby itself: `tools/iseq/compare_coverage.rb` (new) -- the
  disassembly, and the structure as Coverage.peek_result shows it -- 19 /
  19 snippets.
- **The VM counts** at that nop (the VM's export gives it the branch's
  counter), and `Coverage.result` answers `{[type, id, line, column, line,
  column] => {[type, id, ...] => count}}` with ruby's numbering: a
  construct, then its branches. `result(clear: true)` zeroes the counts and
  keeps the structure.
- **Lines.** A covered file's lines are the compiled code's line events
  when the VM runs it, and the lines the evaluator's parser had noted for
  it are dropped: `some =\n  'value'` counts on the value's line, a
  literal Array's first element's. That is test_line_coverage_for_multiple_
  lines and test_oneshot_line_coverage.
  ⚠ A file of more than 2,000 lines under Coverage for its lines alone
  stays on the evaluator: the compiler is Ruby, about 3 ms a line, and
  test_big_code's 10,003 lines took past its limit. Branches use the VM
  whatever the length. The bound goes when the compiler is native.
- **Still RED**: test_branch_coverage_for_pattern_matching -- `case / in`
  is not compiled yet.
- **Checked** (local, the commit before this note): vm_check 243 / 243,
  the compiler 433 / 433 snippets, 671 / 671 compiled files and 19 / 19
  under branch coverage, the gates. The corpus in both executions was
  run with the next round's build: (63). Witness 665.

## 2026-11-16 (63): round 41 -- pattern matching, compiled and run on the VM

**The point.** `case / in`, `expr => pattern` and `expr in pattern` were
the largest thing the compiler refused: 11 corpus programs fell back to the
evaluator for it, and two tests waited on it. The compiler now takes them
as ruby's does and the VM runs the result.

- **The compiler** is prism_compile.c's pm_compile_pattern, ported: array,
  find and hash patterns (the constant they may be under, #deconstruct with
  its cache, #deconstruct_keys with the keys it is asked for), captures,
  alternatives, pins, guards, values by `===`; the stack as the scratch
  space, with the slots a single pattern keeps for its error (the string,
  whether it is a key error, that error's matchee and key); the error
  handler that raises NoMatchingPatternError / NoMatchingPatternKeyError.
  Against ruby: 22 / 22 snippets under branch coverage (`in` clauses are
  branches), and every corpus file that has a pattern.
- **Whole files, again** (compare_files: it was 672 the same and 21
  refused of 693): a Range nobody reads is what
  its bounds do, with no newrange; `nil&.m(args)` is the receiver's nil and
  none of the rest; #to_a says an instruction's events once an
  instruction-info entry (a second `leave` after the first repeats none).
- **The VM**: checktype (what a #deconstruct answered), the two calls a
  failed pattern makes on the VM's own object (core#sprintf, core#raise --
  the frame's format and raise), pushtoarraykwsplat (`return 1, **h`).
- **Found on the way**:
  - `raise Cls, obj` with a message that is no String says the object's own
    #to_s -- "3", "sym", an object's -- where it said the class's name
    (the evaluator's; a multi-clause `case / in` raises exactly that).
  - #deconstruct / #deconstruct_keys of the wrong type: ruby 4.0's
    "deconstruct must return Array", without the class before it.
  - a NameError raised by a send on the VM lists the locals its frame's
    program declares, assigned yet or not, as the evaluator's assignment
    does (`g = no_such` in a block has g): the VM keeps which program is
    running (vm_cur).
  - `defined?(name)` of a private method a refinement in use gives, in an
    instance_eval'd block: asked as the bare name the parser reads it as.
- **Flip-flops** too (pm_compile_flip_flop): `a..b` as a condition and as
  a value, an Integer bound as `$. ==` it. The state is a special variable
  of the method's frame in ruby (getspecial / setspecial of a number from
  2); the VM keeps it as the evaluator keeps one, a thread's, under the
  program and that number.
- **`once`** (`/#{x}/o`, `END { }`): the instruction over a sequence of
  type `plain` that builds the Regexp, or over a block that hands the
  block of the statements to core#set_postexe. The VM keeps the value
  under the program and the instruction's number; a thread that arrives
  while another is running the sequence waits for that one and takes its
  value (ruby's vm_once_dispatch; corpus 536 has the two threads). The
  plain sequence runs in the frame it is in, as a rescue's does; an END's
  block is the evaluator's at-exit statement's body.
- **A `for` over a target that is no local** (pm_compile_for_node_index):
  an instance variable, a global, a constant, a call or an index target
  takes the one element of the block's parameters; several targets or a
  splat take the parameters, or the one parameter when Array.try_convert
  answers for it. The four calls ruby writes for that are on the value
  with FCALL set; the VM reads FCALL as a call without a receiver, so the
  compiler's export for the VM marks them.
  - ruby 4.0 itself: `for o.x, y in [[1, 2]]` raises NoMethodError (x= on
    the 2) -- no state is handed down for the receivers, and the topn
    reaches a value. The sequence is compiled as ruby's, so the VM does
    the same; the evaluator assigns o.x the whole pair.
  - the parser does not take a group among several `for` targets when the
    group has a splat (`for a, (b, *c), d in`): a syntax error in either
    execution.
- **A Proc made in a class body of an eval'd sequence lost its program.**
  `ISeq.compile("class C; P = proc { 42 }; end").eval` and then `C::P.call`
  said "a body of an ISeq sequence that is no longer loaded": the eval gave
  its tree back when it ended unless a Proc had taken the eval's own frame
  or a method was defined, and a class body's frame is another. A tree
  with a class body is now the collector's to give back, as one with a
  method is (vm_sweep finds the frame a Proc holds). In main since round
  34; found when END went to the VM -- test_compile_prism evaluates `END {
  }` inside a class body 10 times, each ran at exit, the process ended 1
  and all 182 of the file's tests counted RED.
  And the evaluator's END did not mark its frame as taken either: a frame
  an END block was written in could be recycled before the block ran.
- **Still refused by the compiler**, of the corpus: a
  shareable_constant_value write that is not a literal, 1 program.
- **Checked** (local, the commit before this note): vm_check 245 / 245,
  the compiler 453 / 453 snippets, 693 / 693 compiled files (694 files, 1
  refused), 22 / 22 under branch coverage, the gates. The corpus: 694 /
  694 on the evaluator; under MERE_RUBY_VM=1, 694 programs -- 684 on the
  VM, 10 fallen back (6 a Regexp literal in another encoding, 3 a source
  in an encoding the VM does not take, 1 the compiler's refusal above), 0
  different. It was 660 / 31 / 0 of 691 at round 38. Witness 666.

## 2026-11-16 (64): the ISeq compiler in Mere, and the VM's first speed work

**The point.** The compiler that turns a file into the VM's sequences was
Ruby (lib/iseq_compiler_ext.rb) run by this interpreter, about 3 ms a line:
the VM could not be the default execution with it. It is now Mere as well
(ic/), reading libprism's serialized tree directly, and the VM's files are
compiled with it. Requiring optparse.rb (2,463 lines) on the VM: 6.70 s ->
0.15 s, start-up included.

- **ic/**: `m_ic_tree.mere` reads the serialized tree into flat stores (a
  node a number, a field two words; the reader table is generated from
  prism/config.yml by tools/gen_ic_schema.rb); `m_ic_core.mere` the
  instruction lists (doubly linked with sentinels, compile.c's
  LINK_ANCHOR), labels and sequences; `m_ic_finish.mere` compile.c's
  iseq_optimize, the events, the stack depth, the layout;
  `m_ic_export.mere` to_a; `m_ic_nodes.mere` prism_compile.c's
  instructions node by node, in the Ruby compiler's order. main.mere's
  `ic_vm_native` packs Prism's options, serializes, compiles and turns the
  answer into values (literals frozen, as the Ruby compiler freezes them).
  What the native compiler refuses, and a file while Coverage runs (it does
  not compile branch coverage), goes to the Ruby compiler as before;
  MERE_RUBY_IC=ruby forces that.
- **Held to the Ruby compiler** by tools/iseq/native/check.sh (expect.rb
  writes the Ruby compiler's answer and the serialized tree, dump.mere the
  native one's, compared as text): the corpus' 694 files, the 698 snippets
  of tools/iseq, and 613 files of ruby's lib/ and test/ruby/ -- 2,001 of
  2,006 the same, 2 refused (a hash pattern key that inspects quoted), none
  different. The tree reader is held to Prism's own tree node by node
  (tools/iseq/native/tree_check.sh: 694 / 694).
- **The Ruby compiler held to ruby on ruby's own files** for the first time
  (compare_files.rb over lib/ and test/ruby/): 50 of 613 differed, in forms
  the corpus does not have. compile.c takes a label nothing names any more
  out of the list at once (unref_destination, replace_destination), and
  its branch-before-jump rule looks at the element just before the jump;
  the inversion and the branch-to-pop rule keep a label counted that this
  compiler let go of; an unreachable chunk's labels go too. A String
  literal under `frozen_string_literal: false` is putstring; __FILE__ is
  pushed as a literal is; a multi-line `/o` pattern's leave is on its last
  line; a source declared binary that has UTF-8 bytes compiles in binary
  (Prism's Ruby side answers UTF-8 there); `[1, "a#{"b"}"]` is static; the
  disassembly pads the local table in bytes and does not quote a non-ASCII
  local. Now 1,305 of 1,307 the same as ruby, 2 refused, none different.
- **Speed** (local -O2, evaluator / VM; the VM was 1.7-2.6 times slower):
  - two Integers and a plain operator are answered in vm_step, under the
    evaluator's own conditions (no Integer operator redefined, no
    TracePoint);
  - a statement's instructions run in one region (one an instruction
    before), and a frame's first eight statements in the frame's own --
    a short block body makes one region a call;
  - a program statement is not wrapped in a statement region of its own;
  - vm_exec takes its stack and registers from a pool, given back however
    the frame is left.
  3M-iteration `while`: 1.74 / 1.21 s (was 1.79 / 4.34). 10M block calls
  (`times`): 8.17 / 9.34 s (7.89 / 11.30). Method mix (fib(24), ivar
  updates, rescues): 0.86 / 1.24 s (0.93 / 1.79). Still slower: a method
  call (it goes through the evaluator's call with the arguments as
  expressions), and Array#each over 2M elements, where the VM starts one
  collection the evaluator does not.
- **Checked** (local): vm_check 245 / 245; the corpus 694 / 694 on the
  evaluator; under MERE_RUBY_VM=1, 684 on the VM, 10 fallen back, 0
  different (with the native compiler and with the speed changes); the
  gates; test_compile_prism 182, test_coverage 46, newline_test 54,
  test_pattern_matching 30, test_iseq 63 / 68, test_optimization 84 / 89
  (the RED as before).


## 2026-11-16 (68): what the VM did otherwise than the evaluator in whole test files

**The point.** Forty of ruby's test files run once on the evaluator and once
under MERE_RUBY_VM=1 (local, same build): the VM answered 115 fewer tests.
The ones fixed here, with corpus 675 as the witness (a child runs it as it
is and under MERE_RUBY_VM=strict, and both print ruby's lines):

- **test_thread** hung: a loop on the VM never let another thread or a
  trapped signal run. A jump back and a statement's start now do what a
  statement boundary does in the evaluator (vm_poll). test_thread 99 / 100
  on the VM, as on the evaluator.
- **test_module**: `c.instance_eval { include m }` included m into c's
  singleton -- the class body walker ran the statement for the singleton
  the body defines into. It is Module#include on c. The evaluator did the
  same for `include m` written without parentheses. `private [:a, :b]` (one
  Array of names) at the top level was "private method 'private' called for
  main"; define_method as a class body's statement answered nil, not the
  name.
- **test_proc**: `proc { it }.parameters` named the slot `_1`; the VM's
  block sequence now says its parameter is `it` (vm_it_seqs), and
  Proc#parameters answers `[[:opt]]` for it.
- **test_variable**: `1.instance_eval { @a = 1 }` wrote the ivar; the VM's
  setinstancevariable goes through assign_one, which refused only a frozen
  object's. An immediate's is refused too, as SIVarAssign refuses it.
- **test_refinement**: a constant or class variable written in a refine
  body said nothing on the VM (Bug #10103's warning).
- **test_syntax**: the Ruby compiler's "argument of top-level return is
  ignored" was printed under -W0.
- On the evaluator too: a bare `private_methods` / `protected_methods` at
  the top level was a NameError.
- CI: the embedding check copies main.mere and rewrites its imports to the
  repository's paths; the `ic/` ones were not rewritten, so it failed on
  #89 (a8c2fe5a).

Still different on the VM: test_module's two memory-leak tests (3M
`Class.new do ... end`, past the 10 s bound: the VM runs that block about
2.7 times slower than the evaluator), and test_sprintf's test_rational
fails after a certain set of earlier tests and passes alone or with any
smaller set (an exception value is lost when a collection falls in a
particular place; not found yet).

Checked (local): corpus 694 / 694 on the evaluator and under MERE_RUBY_VM=1
(675 among them); vm_check 245 / 245;
the gates; the embedding check; test_module 195 (2 timeouts on the VM),
test_proc 118, test_variable 32, test_refinement 122, test_syntax 170 the
same on both.

## 2026-11-17 (69): the evaluator's shape shortcut on the VM, and the VM's own frame costs

**The point.** test_module's test_iclass_memory_leak runs `Class.new do
include mod end` three million times in 10 s. The evaluator does it by a
shortcut that reads the block's statements (core_metadata_plan); without
it the evaluator takes 4.9 us a turn too. A block run on the VM is one SVm
statement, so the VM never took it and needed 6.3 us.

- **The shortcut on the VM.** The loader recognises the same shape in a
  block sequence's instructions (`opt_getconstant_path Module`, `opt_new`,
  `setlocal`, `opt_getconstant_path Class`, `send new` with a block whose
  sequence is `putself; getlocal_WC_1; include`) and keeps the statements
  the evaluator would have had, with their lines (vm_metadata_shape,
  vm_plan_body); core_metadata_vm hands them to the shortcut. 1.5M turns:
  3.3 s on both; test_iclass_memory_leak 5.8 s on the VM. The other leak
  test (refine, using, def; 300k turns) has several shapes and is the VM's
  method call cost, not a shortcut: 43 us a turn on the VM, 24 on the
  evaluator.
- **No stack copy per send.** vm_root wrote what lay below a send's inputs
  into an Array in the frame's env before every send that had something
  there, so that a value held by the stack alone survives a collection.
  The collector reads the pool's stacks in use instead (gc_mark_roots, up
  to each stack's depth); vm_root and __vm~stk are gone. `h[i] = i.to_s`
  300k: 1.10 -> 0.83 s (evaluator 0.73).
- **A body of one value needs no VM frame.** A block's or a method's
  sequence of two instructions -- putnil / putself / putobject /
  getinstancevariable, then leave -- is answered by vm_enter without
  vm_exec when no TracePoint and no Coverage is on (vm_trivial). `def m0;
  end` called in a while: 1,184 -> 1,056 ns a turn (evaluator 1,124);
  `n.times { 1 }` 633 -> 474 ns (487).
- Measured, not changed: a VM method call costs the evaluator's call plus
  the VM's frame (vm_exec's pool, region and try) and a copy per push
  (vm_push into a Vec outside the statement's region); calling a method
  the VM defined runs about 2.5 times as many collections as the
  evaluator (`k.new` 2M: 2,487 against 999), each turn allocating about
  1.2 KB more.

Checked (local): corpus 695 / 695 on the evaluator; under MERE_RUBY_VM=1
685 on the VM, 10 fallen back, 0 different (tools/iseq/vm_corpus.sh);
vm_check 245 / 245; gates; test_gc, test_fiber, test_thread, test_weakmap,
test_array, test_hash on the VM the same before and after the root change.
(Running run_corpus.sh under `( ... ) &` makes corpus/394 FAIL: the
reference ruby keeps the SIGINT ignore a background job inherits.)

## 2026-11-17 (70): test_optimization's two timeouts, and a respond_to? that split its lists

- **test_string_empty?** hung in its separated child: the IO prelude's
  write loops ran `until data.empty?`, and the child had redefined
  String#empty? to answer nil -- the exit's flush wrote nothing forever.
  ruby's IO calls no Ruby method; the write loops ask the byte count now.
- **test_clear_unreachable_keyword_args** (`GC.stress = true`, 30
  ISeq.compile) passed 60 s: ISeq.compile checked the source with Prism's
  Ruby side (__prism_check builds the node tree in Ruby, the most of
  compile). It asks libprism first (`pm_parse_success_p`, the
  RubyVM::InstructionSequence.__prism_ok door) and builds the tree only
  when there is an error to report. ISeq.compile 0.3 s -> 1.4 ms; under
  GC.stress three of them 6.1 -> 0.44 s. test_optimization 84 -> 86 / 89,
  the file 98 -> 37 s (left: the two tailcall tests, and the frozen IO
  buffer's memsize).
- **respond_to? on a builtin's name** split the builtin name lists into
  words for every question (listed_builtin_root, nine tenths of
  `nil.respond_to?(:read)`): 7.6 -> 2.6 us. The lists are asked as text
  now. (test_iseq's two leak tests still take 23 us and 38 us a turn --
  `ISeq.new(nil)` through `...`, kwargs, a raise and an interpolation, and
  load_from_binary -- against the 8 us they need.)

Checked (local): corpus 695 / 695 on the evaluator; under MERE_RUBY_VM=1
685 on the VM, 10 fallen back, 0 different; vm_check 245 / 245; gates;
test_io, test_object, test_method, test_module as before; test_iseq 63 /
68 and test_compile_prism 182 / 182 as before.

## 2026-11-17 (71): tail calls -- compiled as compile.c marks them, made by the caller on the VM

**The point.** test_optimization's two tail call tests compile with
`tailcall_optimization: true` and call a method a million levels deep
(test_tailcall_not_to_grow_stack) or twice as deep as the stack allows
without it (test_tailcall_condition_block). The compiler refused the
option, so the sequence ran on the evaluator and the stack ran out.

- **The compiler** marks a `send` / `invokesuper` with no block that the
  sequence leaves right after -- through nops, and through the jumps an
  `if` makes -- VM_CALL_TAILCALL, in iseq_peephole_optimize's place among
  the rules; not in a top, eval, main, rescue or ensure sequence, and not
  between a rescue region's labels (a block's whole body is one, as
  prism_compile.c marks it). Five snippets with the option join
  tools/iseq/snippets.txt: 460 / 460 the same as ruby, to_a and disasm.
- **The VM** makes a TAILCALL send of positional values from a method
  frame whose caller is a VM send that takes it: the frame is left (how 7)
  with the call waiting (vm_tail), and the caller's send makes it, one
  frame at a time at its own depth (vm_tail_call). The callee is told by
  depth and name, and only that frame's vm_enter takes it, so the mark
  never reaches a builtin's call or a block. A million-deep self call:
  3.4 s.
- test_optimization 86 -> 88 / 89 (left: the frozen IO buffer's
  memsize). Corpus 676 is the witness: deep self and mutual recursion,
  another receiver, a private callee, a rescue region and a block that
  are not tail calls, the label a tail-called method sees.

Checked (local): corpus 696 / 696 on the evaluator; under MERE_RUBY_VM=1
686 on the VM, 10 fallen back, 0 different; vm_check 245 / 245;
compare_with_ruby 460 / 460, coverage 22 / 22; gates; test_iseq 63 / 68
as before.

**Review fixes for #89** (on top of (71)):

- tools/nothreads_tree.sh copies `ic/` as well: the Wasm and RISC-V
  preparation could not resolve `ic/m_ic_nodes.mere` (the embedding check's
  copy was fixed earlier).
- ic_to_val builds the compiler's literals without calling the program: an
  Encoding operand is the interpreter's own object (enc_objs), a frozen
  Hash or Regexp is frozen by the primitive -- a program that redefined
  Encoding.find before requiring a file got its own answer for that file's
  `__ENCODING__` on the VM.
- The visibility statement the VM makes of `private` and its kin answers
  what the method answers (the names; self for the constant and class
  method forms), is not taken when the receiver defines the method itself,
  and takes one Array of names only at the top level -- in a class the
  Array goes to Module#private. The name is asked before an argument Array
  is walked, so an unrelated call with a long Array is not.
- respond_to?'s word lists do not match a name with a space in it
  (`:"class clone"` matched two neighbouring entries).
- A tail call is made by the caller only into a Ruby method of the
  receiver's class and with no refinement defined: binding, eval,
  local_variables at a method's end and a refinement the method's module
  uses read the frame the call is written in.
- And from (72), already on stage10-r42: vm_scoped's answer copied out
  before its scope goes back, the waiting tail call held as one Array.

- (after CI) Each call vm_tail_call makes runs in a region of its own:
  a million of them kept their allocations in the caller's statement, 2.1
  GB for test_tailcall_not_to_grow_stack, past CI's 2 GiB for the file;
  1.07 GB now.

Corpus 675 and 676 carry the witnesses (return values and an overridden
`private`, a required file's `__ENCODING__` under a redefined
Encoding.find, multiword names, binding / eval / local_variables / a
refinement with the optimization on and off).

## 2026-11-17 (74): Prism's fixtures -- where parse.y's lexer, not its grammar, decides the tree

PR #86 (main `392bf810`) left 20 of Prism's 976 fixtures whose tree is not
parse.y's. 5 of them CRuby cannot answer itself (`#children` raises
NoMethodError on `::A ||= 1` and the like). The other 15 now agree: 971 of
976, measured with tools/ast_on_cruby.rb against tools/ast_dump. The 850
files test_ast reads still all agree. Each is a place where parse.y's lexer
cuts or places a token differently from Prism:

- **A percent literal closed by a line end** (`%\nfoo\n`, `%r\nfoo\n`) ends
  on that line, in the column past the newline -- and so does every node
  ending with it. The offset is the next line's start, where every other
  node that ends there ends; tr notes these literals and ao_nl_end places
  them.
- **A program's end** reads past a `\` continuation and past the heredoc
  bodies a line opened; after a comment, a program that ends after those
  bodies ends at the comment, and a last line of blanks with no newline is
  the term's place (hd_skip, nl_after_comment, skip_terms).
- **A regexp's text splits at a `#@` / `#$` that names no variable**
  (`/a#@~b/`): parse.y's tokadd_string stops there to look for a variable
  name, finds none, and the text from `#` is the next token -- a DREGX,
  and in a condition a MATCH2. Prism keeps one RegularExpressionNode.
- **Text a heredoc body interrupts is one token** (`<<-A.gsub(/b\` / body /
  `b/)`, a `%w` / `%i` word): a REGX, and a word placed from the line it
  ends on. Prism splits it into parts, and places such a `%i` word where
  its first line is.
- **A `<<~` heredoc with an unindented line** reads as a plain heredoc
  (heredoc_dedent has nothing to remove); when the indentation falls to
  none at a later line, the lines before it stay tokens of their own,
  because literal_concat does not join while heredoc_indent is above 0. A
  `<<~` DSTR whose pieces all joined its head is a STR.
- **`Foo::Bar { }`** (ruby bug #18878): the call takes the block's place.
- **A command's `do` block inside bracketed arguments** (`foo(bar baz do
  end)`, `[bar baz do end]`, `foo[...]`, a splat, a keyword value) is a
  SyntaxError, as in parse.y -- checked against 16 forms.
- **An empty file's tree is at line 0** with no script lines
  (`parse_file`); an empty String's stays at line 1.
- A regexp in a condition: an interpolated one warns only under -w, in
  Prism as in parse.y (it always warned); under AST.parse, one parse.y
  splits warns so too.

Review of #99 (two P2s, both fixed): a `<<~` heredoc with interpolation
whose indentation falls to none later also keeps its pieces before that
line apart and placed as `<<~` pieces (`  #{1}` / `b`: the text after the
interpolation is 2:6-2:7, not the opener's end) -- tr_contents runs
literal_concat with `squiggly` until that line; and a regexp split at `#@`
takes its pieces' text as tokadd_string leaves it: an escaped delimiter is
the delimiter unless simple_re_meta, a `\` and its line end go, a `\`
before a non-ASCII byte goes, `\cX` / `\C-X` / `\M-X` are written `\xHH`.
Checked against 11 heredoc forms and 20 regexp forms. The follow-up review
(one P2 left): a control or meta escape's operand is a whole escape again,
as in read_escape -- `\c\n` is `\x0A`, `\M-\n` is `\x8A`, `\c\x41` is
`\x01`, an unknown `\q` is `q`; a bare `?` is DEL only right after `\c` /
`\C-`. rx_read_escape does this over Prism's bytes. Checked against 20 more
forms on ruby 4.0.9, among them a condition and ones ruby refuses. The
third (one P2): looking for a split, a control or meta escape is read whole
-- `\c#@~` is `\x03` and `@~`, no split -- in regx_splits and in
rx_text_splits, which classifies the condition's warning. Checked against 12
forms. Not done, and so on main too: AST.parse lets a regexp through that is
not valid in its encoding (`/a\M-b/`, `/a\xff/` in UTF-8), where ruby
raises SyntaxError.

Not done: `/(?<y>a)#@~/ =~ x`, where parse.y's DREGX assigns no `y` (the
scope's table comes from Prism's locals).

Speed: tr reads a node's first byte once. 300 files of test_ast's walk,
205.05e9 -> 205.34e9 instructions (+0.14%). Bracket depth 923 -> 924 (one
table, ao_lx, holds both kinds of note). Witness corpus/684.

- Checked: corpus 696 of 696, and with MERE_RUBY_BLK_ID_CHECK,
  MERE_RUBY_ATTR_IC_CHECK and MERE_RUBY_IVAR_INDEX_CHECK on; test_ast's
  individual tests 114 as the reference; the gates; loop memory.

## 2026-11-17 (72): what still differed on the VM in 40 whole test files -- freed memory, a loop with no safepoint, collections that marked too much

**The point.** The 40 files of (68) run again on both, same build: the VM
3,805 MATCH against the evaluator's 3,810 (it was 3,695). The five left,
and what they were:

- **test_sprintf's test_rational** (failed after one set of earlier tests
  and not another): `vm_scoped` gave its scope env back to the pool --
  which compacts the env's arena -- while the value the call answered
  could still point into it. Found with tools/asan_build.sh (brought up to
  the current Mere runtime, and linking the glue and libprism as
  tools/build.sh does), which also caught vm_tail_call reading the waiting
  call's name from a map it had cleared. The answer is made in a region
  of its own and copied out before the scope goes back; the waiting tail
  call is one Array with its name as a String handle. The VM corpus under
  ASan: no report but corpus/524's deliberately deep recursion, where ASan
  trips over its own stack.
- **A loop written on one line** has no statement start inside it, so the
  VM never reached a safepoint: `while i < 3_000_000; s += i; i += 1;
  end` ran no collection and grew to 1.4 GB (the evaluator: 85 MB, 30
  collections). One jump back in 64 now ends the turn: the stack's Vec is
  wound back when it is empty, a collection may run, and vm_loop starts
  the next turn in a region of its own. 102 MB, 1.24 s (evaluator 1.48).
- **test_fiber's test_many_fibers_with_threads** (60 s on the VM, 3 s on
  the evaluator): the stack's Vec was recycled at every statement, and a
  Vec's recycle asks every suspended coroutine whether it points into the
  arena -- with 100 threads parked and a fiber switched each turn, that
  was nearly all the run. Wound back only when its arena passes 64 KB
  (asked one statement in 64): 8.3 s.
- **test_thread's test_thread_join_during_finalizers** (`GC.stress =
  true`, past 60 s on the VM, 27.5 s on the evaluator): every collection
  marked the to_a Array of every loaded program -- each instruction's
  Array and call data -- and a frame's first statement was a second
  safepoint right after the block run that entered it. The collector
  marks each program's operands instead (vm_keep keeps the tree's id
  only), and a frame's first statement is no safepoint of its own: 50 s.
- test_integer's test_pow and test_exception's test_blocking_backtrace
  pass on the VM now as on the evaluator (bound-edge timings). Left:
  test_module's complemented-method-entry leak test (the evaluator's
  shape shortcuts, LOOP (69)).

The other 102 files of test/ruby, on both with the same build: the VM
5,727 MATCH against the evaluator's 5,735. One is test_ractor's
move_nested_hash_during_gc_with_yjit, at its bound on main too
(unittest/README). The other seven were test_random_formatter: on the VM
`self.bytes(n)` is the receiverless call `bytes(n)` (both are FCALL in
the sequence), and a bare call of a builtin the class answers --
Random#bytes, which no name list has -- was a NoMethodError on the
evaluator too. The self-call with arguments asks whether the object
answers the name before giving up, as the one without arguments did.

Checked (local): corpus 696 / 696 on the evaluator; under MERE_RUBY_VM=1
686 on the VM, 10 fallen back, 0 different; vm_check 245 / 245; gates;
test_sprintf 33 / 33 on the VM, also under ASan; test_random_formatter
26 / 26 on both.

## 2026-11-17 (80): ruby's test files outside test/ruby on both executions

**The point.** The 594 files of CI's measurement outside test/ruby
(rubygems, -ext-, prism, psych, openssl, mkmf, optparse, fiber, ...) run
on both, same build: the VM 21,905 MATCH against the evaluator's 21,906.
With test/ruby's 142 ((68), (72)) that is every file CI measures. What the
VM did otherwise:

- **test_delegate**'s Ractor test: delegate.rb's Delegator is a class under
  BasicObject, and `kernel = ::Kernel.dup` was "uninitialized constant
  Delegator::Kernel" on the VM -- a call on Kernel is rebuilt as the
  evaluator's EMethod, and the receiver was written `Kernel`, which such a
  class cannot see. It is written `::Kernel`.
- **test_coverage's test_big_code** (a 10,000-line file under Coverage,
  past its bound on the VM): a file under Coverage was compiled by the Ruby
  compiler, 25 s for that file. Only branch Coverage needs it; line
  Coverage is counted by the VM from the line events either compiler puts
  in, so the native compiler takes the file: 0.2 s.
- ripper/test_scanner_events differed by one in the VM's favour (a gvar
  test that is RED on the evaluator in this run): not a VM difference.

Corpus 690 is the witness (::Kernel calls inside a BasicObject subclass,
DelegateClass, and line Coverage of a required file, each run as it is and
under MERE_RUBY_VM=strict).

Checked (local): corpus 696 / 696 on the evaluator; under MERE_RUBY_VM=1
686 on the VM, 10 fallen back, 0 different (before 690 was added; 690
alone the same as ruby both ways, and different on the previous build);
vm_check 245 / 245; gates; test_coverage 46 / 46 and test_delegate 37 / 37
on both.

## 2026-11-17 (81): the VM's own work per call -- what a method call and a block on a receiver paid that the evaluator does not

**The point.** Profiled side by side (fib, a block reading a local of its
frame, a method call in a loop), the call machinery the two share --
call_method, binding, the body's bookkeeping -- costs the same on both;
what the VM adds is its own layers around it. Five of them were work no
call needed:

- **a tail call readied on every send.** vm_tail_call wrote the callee's
  name into a map (a copy of the string) before each call. Until a send
  marked VM_CALL_TAILCALL is loaded (vm_cd notes it; ruby marks none unless
  tailcall_optimization is on) no frame can leave for one, and the call is
  made with nothing readied; once one is, the name is written only when it
  changes.
- **the receiver bound as a hidden local** by vm_call_in before the
  receiverless door (`fib(n - 1)`), which passes values: it is bound after.
- **a block on a receiver made in a scope of the frame.** `a.each { |x| s
  += x }` went through vm_scoped, and the scope was the block's env: every
  name the block read or wrote of the frame, and its `$~` home, was looked
  up through one env more. Such a call (positional values, a literal block,
  not `new`, no TracePoint) is now EMethodB's arm past its written receiver
  and arguments, in the frame itself (vm_blk_send).
- **a region of the frame's own for a method's or a block's body**, which
  already runs in the region its call made (MCALL, BLK). What the frame
  leaves is still copied out of the stack's arena before the slot goes back
  -- a :return hook's frame takes the slot next and may wind the arena --
  by a region around that value alone (VMR). Rescue, ensure, top and class
  bodies keep theirs.
- **the tree's id written into every method frame's env** (`__vm~p`). A
  method whose program has no block in it makes nothing that can run the
  tree after the frame is left; while the frame runs, its pool slot names
  the program (regs' slot 13), and the collector now marks the tree from
  there. The `__vm~re` lookup of a re-entered Continuation is asked only
  once one is in use (cont_on).

Corpus 691 is the witness: blocks on receivers (the frame's locals, `$~`,
break / next, a block-local name, the Symbol shape, a private method,
Struct.new), a Proc from a removed method, a :return hook that runs Ruby
while a method's value is on its way, and a method from a file of its own
removed while its frame waits in a Fiber, then a collection -- which stopped
the VM run where the Fiber went on, built without the pool slot's mark.

Measured (local, the least of 7 runs each, interleaved, this machine under
other load): fib(24) on the VM 0.208 s -> 0.195 s (the evaluator 0.172);
`(1..200_000).to_a.each { |x| s += x }` 0.176 -> 0.165 (0.141); 200,000
calls of a two-argument method in a while loop 0.568 -> 0.548 (0.562). The
VM is still 1.13x the evaluator on fib and 1.17x on the block: what is left
is its per-instruction stack (every value pushed is copied into the stack's
arena) and the frame's own entry (the pool slot, try_or, vm_step's
statement start), against the evaluator's walk of the same expression.

Checked (local): corpus 698 / 698 on the evaluator; under MERE_RUBY_VM=1
688 on the VM, 10 fallen back, 0 different; vm_check 245 / 245; gates.
Under MERE_RUBY_VM=1, previous build against this one: test_proc,
test_iterator, test_optimization, test_settracefunc, test_method,
test_regexp, test_enumerator, test_fiber, test_hash the same counts;
test_array MATCH 473 on both (one test that fails on the reference too
moves between RED and BOTH from run to run, on either build).

## 2026-11-18: stage 9, complete CI comparison and remaining bounds

Main CI 44030304378 completed at 392bf810: 33,277 MATCH, 1,137 RED,
134 BOTH, 21 EXTRA, 49 incomplete files. Its GC intake remains 157 RED:
12 honest implementation matches, 57 audited exclusions and 88 named
handoffs. The original 159-row inventory separately identifies main's two
finalizer fixes. Main later advanced through #89 and #101 to 3eb24fef;
those changes are imported unchanged into this branch and its follow-ups.

All three main-392 PR workflows completed green, but the per-file gate is
not met. #91 (44043415539) has ObjectSpace memory stops and Enumerable
89 -> 88 MATCH; #94 (44043433986) has Enumerable and several timing
differences; #98 (44043456672) also has a core ObjectSpace memory stop.
Duplicate summary artifacts in #91's rerun include a partial seven-shard
report; the final eight-shard artifact is the comparison source.

Native ObjectSpace snapshots now use scoped vectors instead of indexed
maps, reuse their pin keys, and skip class metadata for exact builtin value
filters. The ordinary-object scan, actual candidates, temporary frame roots,
GC/Fiber behavior and callback helper are preserved. These small changes
do not fix the unchanged ten-second Enumerable subprocess: about 6,800
Arrays in its runner environment mean millions of real callbacks. A
100-turn diagnostic takes 0.73 CPU seconds with an empty callback and 1.89
with the original body. No arrays are hidden or additional GC forced.
The VM callback-throughput handoff and this merge blocker remain explicit.

On the #89 integration, seven of eight bounded files complete: 225 MATCH,
15 RED, 6 BOTH, 5 EXTRA, with 57 identical exclusions reported separately.
Core ObjectSpace reaches 2,123,504 KiB during its million-finalizer child.
Paired isolated runs of the actual main e40 CI binary and this candidate
both pass, with peaks of 1,900,768 and 2,009,040 KiB. Those isolated passes
do not clear the whole-file memory stop. The nine RSS cases and OpenSSL
lifetimes pass on this integration; no resource bounds are changed.

The main-392 candidate previously passed all 703 corpus programs in both
hash-index modes. The #101 integration passes all 710 corpus programs in
both hash-index modes, nine RSS cases and the OpenSSL lifetime gate.
Root/dead/duplicate checks pass; bracket depth is 932/1024. The seven
completed bounded files retain 225 MATCH, 15 RED, 6 BOTH, 5 EXTRA and 57
symmetric exclusions. Core ObjectSpace still reaches the unchanged bound
at 2,102,256 KiB.
Both _id2ref review findings are fixed and resolved on #98. All three PRs
remain unmerged until current CI and the per-file comparison satisfy the
stated gate. The next independent work outside stage 9 is VM callback cost,
conservative frame lifetime and native allocator attribution, with concrete
test names retained in gc_cases.tsv and KNOWN_GAPS.md.

### Follow-up review: receiver-side undef in checked ID conversion

The next #98 review found that owner metadata alone could see an inherited
to_int, respond_to_missing? or method_missing past a child's undef marker.
ObjectSpace.__id_integer now checks undef_blocked from the receiver's full
lookup start (super_base) before using owner metadata. The same check guards
the real-method probe and custom respond_to? arity; shared lookup/dispatch
helpers are unchanged. Corpus 687 covers inherited conversion/hook/query
undefs, a definition restored below an undef, and class singleton lookup.

Ruby passes the expanded witness; the previous candidate fails its inherited
undef assertion. The fixed O2 candidate passes witnesses 685–688, all 30
earlier conversion/exception-context outputs, and the upstream id2ref group
(25 tests, 54 assertions, no failures, errors or skips). Root/dead/duplicate
checks pass and bracket depth remains 932/1024. The independent Enumerable
P2 and whole-file finalizer memory bound remain open; no new exclusion or
resource-limit change is made.

The final review-fix build also passes 710/710 corpus programs in both
hash-index modes, all nine RSS cases and the OpenSSL lifetime gate.

## 2026-11-18: gem source provenance is checked before accepting MATCH

The initial gem harness exposed a provenance gap during the next candidates'
audit: Mere selected its bundled Base64 before the locked release library on
-I. That result passed the upstream tests but did not establish the upstream
library's execution. Preserve both the initial and pre-audit snapshots.

do_require0 / resolve_feature now use load_path_pick_shipped and honor the
physical prefix before the actual stdlib entry. The private Marshal loader
keeps its previous internal behavior after a user clears $LOAD_PATH. Corpus
685 covers real library replacements, converted entries, relative imports
and the real Marshal API; no public __marshal feature is invented.

The bootstrap appends reference fallbacks after each interpreter's stdlib,
then records physical locked-gem files after the upstream autorunner. Healthy
summaries alone and exit! cannot pass. All seven harness controls succeed.
The core runner keeps the same fallback order, including RubyGems' source.

Fresh normal O2 source 799c55d7, including main 3eb24fef: all 62 original
files retain 48 MATCH / 13 RED / 0 BOTH / 1 MEMORY. Both sides audit the
locked library on every normally completed file (reference 62, Mere 61).
Only command descriptions change in the lock; all source/dependency digests,
inventory and bounds stay fixed. The explicit protocol transition compares
against the preserved snapshot with zero regressions, and the CLI still
rejects a different lock digest.

Require retains 51 MATCH / 1 BOTH, Autoload 27 / 1, GemVersion 32, Integer
38, TracePoint 97 and PP 36 MATCH in the integrated build. Full corpus and
the hosted per-file comparisons remain independent merge gates. No collector,
C API, ISeq or Prism implementation is changed by this correction.

The integrated corpus completes at 705/705 MATCH. Generated C needs bracket
depth 932 (the inherited search seed was 923); record 932 for the check's
two-compile search. The existing build limit remains 1024. Before publishing,
retain the already published main-merge history as well; its runtime sources
are identical to the fully measured 799c55d7 build.

The same audit on rounds 4-5, normal O2 source f2f57fa7 including main
3eb24fef, retains 50 MATCH / 11 RED / 0 BOTH / 1 MEMORY. The branch's own
pre-audit result is preserved; all 62 reference and 61 non-resource Mere
files audit the locked gem lib. The ordinary per-file comparison reports
zero regressions. Gzip/MockRequest retain their two additional MATCH files.

Normal audited O2 source d403f444 on rounds 6-7 retains 51 MATCH / 10 RED /
1 MEMORY, zero regressions and 709/709 corpus matches. Preserve that branch's
own old snapshot and audit transition (reference 62, Mere 61 library audits).
The later hosted-driver and standalone-loader fixes still need their combined
validation; this result does not claim that unmeasured combination.
Hosted validation found old reference-first paths in Unicode/NKF and other
drivers, plus a fake interpreter unable to answer the new path query. Share
the clean runtime query in tools/runtime_load_path.sh, put reference fallbacks
after it, and make the fake harness answer and assert that ordering. Harness
20, Unicode, original NKF, Psych scalar/wire/store/lifetimes and YAML Store
controls pass without changing bounds or skip rules.

Also preserve the original standalone bundled-library fallback after a user
clears $LOAD_PATH. Physical replacements still win; the existing standalone
tmpdir check and the real Marshal API pass. Fresh O2 source 53e0077f keeps
the strict audited 48 MATCH / 13 RED / 1 MEMORY, zero regressions and
705/705 corpus matches. The separate bootstrap constant-assignment correction
is now applied for a combined build; its original bootstrap eval control is
49/49 MATCH, with isolated corpus 705/705 and unchanged core Eval/Module/Const
counts. No combined-head or hosted result is inferred from those controls.

Final combined rounds 6-7, normal O2 source 7a79b8db: 51 MATCH /
11 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY, zero strict-baseline regressions.
Final combined rounds 4-5, normal O2 source 9730ae28: 50 MATCH /
12 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY, zero strict-baseline regressions.
Final combined first gem-suite PR, normal O2 source 4ff6b54f: 48 MATCH /
14 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY, zero strict-baseline regressions.
All 62 files on both sides finish the locked-library source audit. Multipart
finishes below the RSS cap with one custom-params-hash error (test_0034),
85 tests / 238 assertions versus the reference's 239. Its prior MEMORY/RED
variation is not a new MATCH or an inferred VM/GC cause.
File override, Chain, provenance and constant witnesses 676/677/685/693 match the reference. The earlier full corpus was 709/709 before the final shared corrections. The final hosted corpus and every existing-file comparison remain merge gates.
The earlier full corpus was 707/707 before the final shared corrections. The final hosted corpus and every existing-file comparison remain merge gates.
Integrated corpus: 706/706. The provenance-checked bootstrap harness gives eval 49/49 MATCH, both COMPLETE. Hosted gem jobs pass on Linux and macOS. The Linux runtime job reaches the documented complemented-method-entry leak timeout. Its artifacts are preserved; GitHub rejects reruns while the enclosing workflow is active, so that retry remains pending.

Audited rounds 8-9, O2 source 72effb05 on main 3eb24fef: two consecutive
normal full runs give 53 MATCH / 9 RED / 0 BOTH / 0 TIMEOUT / 0 MEMORY.
All 62 files on each side audit the locked library. Ordinary comparison
against this branch's preserved pre-audit 52 MATCH / 9 RED / 1 MEMORY gives
zero regressions, with identical source/dependency pins and reference tallies.
Multipart gives 85 tests / 239 assertions in both runs, with peaks about
1.69 and 1.36 GiB. Its earlier MEMORY/RED variation remains recorded; neither
its cause nor attribution to a specific change is established by these runs.
The latest snapshot uses the second full run. Cross-platform hosted checks
must retain this new MATCH under the same bounds before merge.
## 2026-11-18 (82): build-linux's Module check at its 10 s, and Module#clone walking every constant

Main e40bb486's CI run failed the Module check:
TestModule#test_complemented_method_entry_memory_leak took 10.04 s of the
10 s its child process has. PR #89 was not the cause. In class-module-Linux's
module.log, the runs with #89 in them took 25.5-27.0 s for the file: #89's
own run, and PR #101's and PR #91's after merging main. Main's run took
39.7 s and PR #95's 39.9 s. Those two were slower at every test, not only
the leak ones: test_prepend_gc was 1.50 s against 0.79-0.95. Locally, a
build of 392bf810 and one of b148d041 take the same time on the three leak
programs at their real sizes: 4.65 / 4.79 s (iclass), 5.85 / 5.62
(complemented), 6.52 / 5.86 (clone). That is 5-6.5 s on a usual runner,
and a slow one crosses 10. The bound stays. The way out is to make the
three programs faster.

Ruby 4.0.9 on the same Mac takes 1.7 s (complemented), 2.7 s (iclass) and
0.35 s (clone). Here they took 5.6, 4.7 and 4.6 s. The clone test had one
place where the time went: Module#clone collected the copy's constants,
autoloads, class variables and class ivars by walking each whole table for
keys under the original's prefix. That is every constant in the
interpreter, once per clone. `const_owners` now lists the owner of each
key ever written to `consts` or `autoloads` (each write goes through
const_tbl_put / autoload_tbl_put), and a class with no row there has
nothing to copy. The class sweep drops a dead owner's row. The clone test
went from 4.6 s to 3.2 s.

The other two have no single place. A collection costs 2.25 ms with
nothing to free. Most of that is the interrupted stack walked twice: once
for the pin set when a scratch Vec is recycled, once for integer roots.
The rest grows with the dead classes:
- the class sweep's walk of about 60 tables;
- the native candidates, every class-naming key, 122,577 in one collection
  of the refine program;
- the edges of each refinement method's packed scope.
Making a class costs a few microseconds spread over a dozen tables. In the
complemented program, collections are 27% and the rest is spread with no
function above 6%. Halving it means fewer rows per class: work of its own,
not this round's.

## 2026-11-18 (75): AbstractSyntaxTree where Prism and parse.y part ways -- captures parse.y does not assign, and two kinds of error_tolerant recovery

**The point.** Two of the gaps note 551 left in stage 5, against ruby 4.0.9:
- **Named captures in a regexp parse.y splits.** For `/(?<y>a)#@~/ =~ x`,
  parse.y splits the text at the `#@`, so the regexp is a DREGX, and
  reg_named_capture_assign does not run. MATCH2 has no assignments, `y` is
  not in the table, and a later `y` is a VCALL until something else assigns
  it. Prism does not split the regexp and assigns `y`.
- **Two kinds of error_tolerant recovery:**
  - in a body, what cannot follow a statement (`1q`, `a = 1 2`);
  - an `end` after `.` that closes by its indent (`bar.` / `end`) in
    constructs other than a class or module.

**Captures.** tr_match_write sees the DREGX and records each name as a
"ghost" of its scope (as_gh). Scopes now carry a serial (as_sc keeps kind +
2 x serial). A program with a ghost is translated a second time; nothing
else pays for it. The second pass records where each variable is really
assigned: a write, a target (multiple assignment, for, rescue =>, pattern
captures), an operator write, a parameter (nm_push), or a capture of an
unsplit regexp. Then:
- a read of a ghost name with no real assignment before it, in that scope
  or one inside it, is a VCALL;
- a ghost name that nothing assigns is left out of the table;
- a ghost name first assigned later moves to where that assignment puts it
  in the table;
- in a block, an assignment to an outer scope's ghost that nothing has
  assigned yet makes a new variable of the block (kind 4), as parse.y does.

`y = y` assigns before its value is read, as assignable does. Checked
against 33 forms.

**Garbage after a statement.** parse.y pops back to the start of the
body's `stmts`, makes everything from there to the last token it throws
away one ERROR (`stmt: error`), and reads on after the next term. That holds
in the body of a def, class, module, `class <<`, begin, while, until and
lambda, and of an if or unless without else (rv_mark, as_px 11).
tr_stmt_list replaces those statements:
- the ERROR runs from the body's start through the statements written
  without a term between them;
- where the body has a leading term (class, module), the ERROR starts there
  and takes the place of that BEGIN;
- a second error in the same body starts from the body's start again.

Other places recover differently, and those were left alone:
- a do or brace block makes the whole outer statement an ERROR, and the
  program ends;
- an if with an else takes the then-branch too;
- under when there is no tree at all (NIL);
- a modifier after the garbage (`1q if y`) wraps the ERROR.

Checked against 26 forms.

**An `end` closed by its indent.** The class and module code is now two
helpers, de_open and de_close. def, do blocks, if and unless without else,
while and until use them as well:
- the statements before `bar.` stay;
- an ERROR runs from `bar` through that `end`;
- the construct ends there;
- the statements after it go up a level.

de_open saves as_px 7 and 8, and de_close puts them back, so a sibling does
not lose a value that is still pending. A do block's indent is the one of
the line it opens on. Checked against 11 forms.

Speed: 300 files of test_ast's walk, 203.95e9 -> 204.13e9 instructions
(+0.09%). Bracket depth 934 -> 935 (as_gh). Witness corpus/700.

- Checked: fixtures 971 of 976; the 850 files 850 of 850; corpus 705 of
  705; test_ast's individual tests 114 as the reference; the gates.


### AST review repairs: real bindings and recovery body starts (2026-11-21)

Ghost capture assignments now keep later writes in the nearest real or
relocated block binding, including writes in nested blocks. Destructured
parameters and explicit block locals register real bindings before the
body is translated. For-loop local targets register before the collection
without changing AST node construction order. Recovery ERROR locations
start at the original statement-list syntax, including a removed begin
and leading empty statements.

Corpus 700 adds 13 review cases. All 13 match the reference's standalone
AST including locations, and the normal O2 runtime matches the whole corpus
700 output in all four hash/MRO configurations. All 869 current Ruby test
files match, including 1,002,971 textual AST lines. Prism fixtures retain
971/976: only the same five reference children walks raise NoMethodError.
The new two Prism readers were regenerated from the pinned config. Root,
depth, dead-definition and duplicate-definition gates pass. Full hosted
corpus and per-file comparison remain required for merging.

Functions changed: gh_put, gh_targets, gh_parameter, gh_block_locals,
tr_stmt_list, tr_compstmt, tr_block_scope, tr_mlhs, tr_lambda, tr_for;
generated readers pm_block_parameters_locals and pm_block_local_variable_name.

## Gem-suite OS baselines and the multipart resource gate

Hosted Linux before and after the source audit (runs 43989409595 and
44248949546) has the same 52 MATCH / 9 RED / 1 MEMORY and no per-file loss.
Its multipart MEMORY was incorrectly compared with macOS's new MATCH.
Keep the complete actual Linux snapshots and explicit protocol-transition
proof, select the matching OS in CI, and reject a wrong-OS baseline in the
CLI. Preserve the original cross-platform error in the Linux record. Eight
harness controls pass; source pins, inventory and 600-second/2-GiB bounds
are unchanged. macOS keeps all 53 MATCH files.

The rounds 10-11 candidate really loses multipart on macOS against its
parent, on main 12ca1df2; a focused parent run still matches. Equal total
MATCH counts cannot waive that file loss. Keep the parent gate and route
resource investigation to VM/performance without assuming a GC cause.
The separate rounds 8-9 Linux runtime failure is the documented
complemented-method-entry leak test timing out at 10.05 seconds. Its full
log is archived; retry that job when GitHub allows it.


Audited rounds 10-11 on main 12ca1df2, O2 source 20cc0eac: 53 MATCH /
7 RED / 0 BOTH / 0 TIMEOUT / 2 MEMORY, all 62 reference files audited.
The parent's macOS multipart MATCH becomes MEMORY in both the full run
and a focused repeat. Keep this inherited observation byte-for-byte in
gemtest/suites_candidate_r5_inherited.json; it is not an adopted baseline.
Preserve the parent's macOS
and Linux gates, and leave merge blocked pending the resource investigation.

Audited rounds 12-13 on main 12ca1df2, O2 source e32d84fd: 53 MATCH /
7 RED / 0 BOTH / 0 TIMEOUT / 2 MEMORY. All 62 reference files and 60 Mere
files finish their source audits; two Mere processes reach the RSS cap.
Keep the nonempty multipart MATCH-to-MEMORY regression in the unadopted
suites_candidate.json. The parent's macOS 53-MATCH baseline remains the
merge gate. The source/dependency inventory and resource bounds are unchanged.


## Gem rounds 16-18: real Test::Unit children and two more pinned suites

Matrix 0.4.3 and Logger 1.6.0 use their original test-unit 3.7.8 /
test-unit-ruby-core 1.0.16 / power_assert 3.1.0 framework and release libs.
The new separate lock adds seven files / 169 reference tests; the original
62-file lock and OS baselines remain unchanged. Offline source-audited O2
measurement at 35cfe0d4 gives Matrix 2 MATCH, Logger 4 MATCH / 1 RED, all
reference files healthy. Preserve its initial macOS snapshot independently.
The first hosted Linux observation is pending; the additional workflow
collects initial records before strict per-OS baselines are adopted.

The child framework exposed primitive super skipping Hash's native [] in
favor of Object's included Ruby []. super_next_plain now stops at the
actual primitive native entry, after earlier Ruby definitions/undefs. The
common copy_meth_src records both copied names in the existing meth_aliased
state, suppressing their first replacement warning while later ordinary
redefinitions still warn. Relocate the existing state only; the top-level
let count does not grow. Witnesses 701/702. Both functions are unchanged on
the current AST/VM/C API/GC remote branches. No collector or VM edit.

The final corpus gives 719/719. Ten measurement controls include actual child
interpreter/library routing and all seven Test::Unit summary fields. The
original five suites remain 53 MATCH / 7 RED / 2 MEMORY, with no per-file
loss against the paired parent's actual observation. Keep the nonempty
multipart regression against the stronger stored macOS baseline in
suites_candidate.json; do not adopt that candidate as a new baseline.
The parent's own hosted macOS run 44259245152 also reaches 2 GiB in
multipart (52 MATCH / 9 RED / 1 MEMORY). Its 53-MATCH local baseline is
retained. All these PRs remain subject to that resource gate.

Logger's remaining rotated-File identical? case needs its retained fstat
result. A /dev/fd path trial failed and was reverted; its shared native
dispatch branch stays untouched. A paired pre-existing undef under a
prepended Hash wrapper likewise remains recorded, not claimed as fixed.

Focused original core files retain both baselines: Super 50 MATCH, Module
195 MATCH, Method 97 MATCH / 1 RED, Hash 297 MATCH / 1 RED / 8 BOTH. Hash's
remaining replace-memory-leak case reaches its existing 10-second child
bound; Method's compaction case is the existing skip. Both new witnesses
also match with GC.stress under the same family bounds. The emitted C needs
933/1024, verified with the 933 positive / 932 negative syntax checks. Only
the search seed changes; m_state/main top-level let counts remain 1167/136.

Initial hosted additional Linux run 44269323039 (source 5e73b774) gives
6 MATCH / 1 RED, with all seven reference files healthy and both sides
audited. Preserve its initial observation and enforce the measured Linux
baseline; macOS retains its separate initial six MATCH files. The additional
workflow now requires the matching OS snapshot on every PR/main/dispatch
measurement. The original multipart gate remains unsatisfied and unchanged.

Review corrections for the additional suites: preserve the previous
native-aware super lookup outside the four primitive value kinds, and stop
their ordered walk at each actual native owner. Expanded 701 covers Exception,
Integer and Float before a later Object undef. Shared-definition warning flags
now live in the existing owned meth_src row, with the endless accessor
unchanged. copy_meth_src marks only actual native alias/Method-copy operations;
keyword alias marks its copy explicitly. Clone/import copies do not acquire
sharing, and a new Proc definition clears the replaced definition's flag.
There are no new warning-map entries or collector implementation edits.

Expanded 701/702 match normally and with GC.stress, including clones, singleton
clones, refinement imports and reflective definition calls. O2 source 0521f018
retains the strict additional 6 MATCH / 1 RED and all seven source audits,
719/719 corpus, Super 50, Module 195, Method 97 MATCH / 1 RED and Hash
297 MATCH / 1 RED / 8 BOTH. Bracket depth remains 933/1024; top-level lets
remain 1167/136. The actual Method-copy lifetime control's post-GC peak ratios
are 2.159 on the saved pre-review binary (negative control), 1.740 on the
paired base and 1.708 after correction, with reference around 1.08. Each
prefix is checked against core_assertions' default 2x bound under the same
600-second/2-GiB family caps. The raw series retains the base's existing
allocator growth; this fixes the additional warning-state retention.

The completed original-batch review rerun at 0521f018 retains 53 MATCH /
7 RED / 2 MEMORY and every paired-parent file outcome. Its candidate record
still contains the multipart regression against the stronger stored macOS
baseline, so it is not adopted. The review fixes do not waive that gate.

## Gem rounds 19-21: all original Rake files with complete child dependencies

Rake 13.2.1's release commit d84f6ef7 contributes 46 files / 597 reference
tests / 1,459 assertions. Pin the real Test::Unit framework and Minitest used
by its generated test children. Preparatory 40 MATCH / 6 RED and 45 MATCH /
1 RED observations are not baselines: missing child stdlib paths and then
Minitest could let an unrelated LoadError satisfy a negative assertion.
Preserve these observations with their reasons, restore four exact pure
packages into a separate cache, and propagate actual selected-runtime paths
before the pinned source fallback. The real child-routing control checks
that fallback too. Source/test inventories and all limits stay fixed.

time_cmp_other now uses Time's actual comparison protocol for ordered
comparisons, including sign conversion and nil failure (703). The local
colon_opens_sym backscan and lex_go's quoted-symbol guard recognize a dotted
call's adjacent Symbol argument, with ternary/keyword negative controls
(704). No AST-tree API changes. super_base now starts a main receiver's
super lookup in its actual singleton and extended-module chain (705).
Rake's original FileUtils.touch already has a real Ruby implementation;
the failed functional children were losing that chain, not missing native
FileUtils support. No shared native dispatcher edit is needed.

O2 source e44fe0bd gives 46 MATCH twice, first verbose then a normal-output
strict repeat, all reference files healthy and all 92 source audits complete.
The same binary gives additional Matrix/Logger 6 MATCH / 1 RED, and original
five suites 53 MATCH / 7 RED / 2 MEMORY. The original candidate still records
the multipart loss against the stronger stored macOS baseline; paired actual
parent outcomes do not regress, but that does not waive the stored gate.
Eight gems now cover 115 files and 2,735 reference tests across three locks.

Corpus 722/722; 703-705 also match with GC.stress. Original controls retain
Parse 102, Syntax 167 MATCH / 1 RED / 2 BOTH, Time 87 MATCH / 1 BOTH,
Super 50 and Method 97 MATCH / 1 RED. In the loaded combined run, Module's
iclass and complemented-method leak cases hit their existing 10-second
bound (193 MATCH / 2 RED). An isolated unchanged-limit rerun finishes all
195 tests / 1,240 assertions successfully. Retain both observations rather
than changing their bound. Bracket depth stays 933/1024.

The independent Rake workflow first records actual Linux/macOS observations;
Linux's own initial record was pending at publication. It extends no existing job. No VM,
collector, Prism-tree, or C API implementation changes are part of this work.

Initial hosted Linux run 44288206768 completes all 46 files as MATCH, with
597 tests / 1,459 assertions and 92 physical-source audits. Its actual merge
source c7f36362 has the same tree as head 712befff. Preserve that observation
independently and enforce it as Linux's baseline. macOS keeps its complete
normal-output 46-MATCH baseline. Every Rake PR/main/dispatch measurement now
selects its own OS's strict snapshot; caps and the original suites' stronger
multipart gate are unchanged. The reviewed parent #107's hosted macOS
original suite also passes that unchanged gate (54 MATCH / 7 RED / 1 MEMORY,
multipart 2,037,376 KiB). Keep the failed local candidate as well; the resource
variation's cause remains unconfirmed.

The first hosted Rake run completes macOS as 46 MATCH too, with all source
audits and zero per-file regression against the preceding complete local
baseline. Preserve the original local initial snapshot; the latest macOS
record now carries this actual hosted observation. Both OS strict jobs still
need a repeat on the final workflow. No runtime source changed during this
baseline adoption.

## Gem round 22: publish copied method metadata once at unchanged lifetime bounds

The first strict rounds 19-21 Linux check really fails the unchanged
Method-copy lifetime control: post-GC peak/start 2.086 in run 44292334299,
under the 600-second/2-GiB outer caps. Preserve its actual RSS series in
method_copy_lifetime_latest.json. Do not relabel this as a timeout or silently
retry a failure whose cause has not been established.

copy_meth_src now publishes the copied source location and sharing flag in
one existing method-source row update, retaining the destination end position
and endless bit. An already-shared source is not rewritten per destination.
No collector, VM or shared native dispatcher edit, and no new top-level let.
A borrowed-operation-name trial did not improve the paired observation
(1.780 versus 1.712 on macOS) and was rejected. An intermediate no-op flag
check alone also left Linux near the bound (1.975).

The following earlier before/after observations were initially described as
paired, but compilation separated them; use the consecutive replay below
for a same-window comparison. With the same unmodified control: macOS peak RSS
179,568 to 157,856 KiB, post-GC ratios 1.712 to 1.695; offline Linux/aarch64
199,568 to 173,416 KiB, ratios 1.980 to 1.908. The Linux container is not the
hosted x86-64 runner; final hosted proof remains pending. Every collected
prefix still uses the default 2x bound; no warm-up, workload or limit changes.
Normal and GC.stress warning outputs in 702 match the reference. Corpus
719/719 and bracket depth 933/1024. Module's complemented-method test first
fails its known 2x RSS check at 2.0078; the complete isolated rerun retains
195 tests / 1,240 assertions with no failures at unchanged bounds. Keep both
observations. The additional suites retain strict 6 MATCH / 1 RED.

The original batch retains 53 MATCH / 7 RED / 2 MEMORY and every paired
actual parent outcome. Its candidate still records multipart's loss against
the stronger stored macOS baseline and is not adopted. The latest strict
rounds 19-21 macOS run also loses that file; the preceding successful hosted
observation does not erase the failed run or identify the resource cause.


## Gem rounds 23-24: real class-bracket lookup and native bare construction

Rack Headers exposed two separate Ruby semantic gaps. A container subclass's
Ruby singleton [] lost to its inherited native constructor; after restoring
that entry, bare new allocated an ordinary object without Hash storage.
invoke_val_c2 now selects the real singleton entry after undef/alias checks,
respecting visibility and refinements. try_self_call1 routes bare new through
the existing native constructor, keeping the real Hash/Array storage. The
with-arguments twin belongs to the VM session and is unchanged. An initial
uncommitted edit hit that identical twin; it was restored before the final
build and commit. No other session's branch was edited.

super_missing now reaches Hash/Array's native class [] only when it remains
after the actual method origin, before any tombstone or Ruby definition.
container_bracket_super_ahead reads the existing frame's method origin/index
and singleton chain. Coercion callbacks on a subclass carry no native bypass;
a prepended core override consumes only its existing one-call bypass. No new
top-level let, VM/GC implementation or shared invoke_val_c0 changes.

The unchanged original headers file improves from 37 failures / 2 errors to
6 failures / 0 errors (51 tests, 268 versus 302 assertions). It stays RED.
Both new witnesses 706/707 fail the paired parent and match normally and with
GC.stress; inheritance, prepend, native aliases, native super, tombstones,
visibility, coercions, blocks and refinements are exercised. A separate
inherited-native undef_method availability gap is confirmed on both parent
and candidate and remains a coordination item in the shared dispatcher.

Normal O2 source 170fb4b8 runs all three unchanged locks: original 54 MATCH /
7 RED / 1 MEMORY, Matrix/Logger 6 MATCH / 1 RED, Rake 46 MATCH. All 115
reference files are healthy. Multipart completes 85 tests / 239 assertions at
2,006,464 KiB; no resource-cause attribution follows from this success. Keep
the previous 53-MATCH baseline and failed candidate independently. Ordinary
comparison has no lost MATCH; strengthen macOS to the actual 54-MATCH record,
including Lint. The Linux baseline and both initial records are unchanged.

Corpus 724/724; bracket depth 933/1024. Original core MATCH counts retain
Class 61, Hash 297, Array 473, Super 50 and Method 97 against handoff and
successful main. Class's reference lacks -test-/class (one BOTH); Array's
reference shared-marking case is healthier while Mere keeps its pre-existing
compaction skip. Hash's replace-memory-leak child reaches the unchanged
10-second bound. Exact counts and nonpassing cases are recorded in
suites_runtime_r24.json; no exclusions are added. Full hosted CI remains a
separate merge requirement. The preceding metadata correction now passes
its actual hosted Linux lifetime control at 1.909x in run 44313194961; retain
that series alongside its earlier 2.086x failure and local controls.


## Gem round 25: preserve native bracket aliases and the first actual entry

Review found two real regressions in 596076bb: the early bracket guard
consumed a native alias bypass before the final core override check, and
Ruby lookup could pass Hash/Array's native owner to an included module.
708/709 reproduce both on the saved pre-review O2 binary. Their final
versions and 706/707 match normally and with GC.stress after correction.

invoke_val_c2 now only peeks at a core bypass that its final native check
must consume. A subclass/native-only constructor consumes its bypass at the
direct native entry, before coercion callbacks. container_bracket_ruby_first
walks actual singleton entries and stops at the native Hash/Array owner.
The class-bracket case of super_next_plain uses that native boundary too,
so a prepended override's super does not jump to an included method behind
it. Earlier Ruby entries and tombstones retain priority. No shared dispatcher,
VM or collector edits; top-level let counts remain main 136 / state 1167.

Normal O2 source 1d0cbe6b retains original 54 MATCH / 7 RED / 1 MEMORY,
additional 6 MATCH / 1 RED and Rake 46 MATCH. All three strict comparisons
are empty, with every reference file healthy. Keep the 54-MATCH macOS gate;
its preceding complete observation is preserved in suites_before_review_r25.json.
Corpus 726/726; bracket depth 933/1024. Core MATCH counts remain Class 61,
Hash 297, Array 473, Super 50, Method 97. The Array reference has two shared-
marking skips in this run. Exact counts and unchanged lifetime-control series
are in suites_runtime_r25.json (post-GC ratio 1.807).

Correct the earlier timing separation explicitly: after both saved metadata
binaries exist, consecutive macOS runs give peak 185,104 -> 131,664 KiB and
post-GC ratios 1.708 -> 1.352. Consecutive offline Linux/aarch64 runs give
205,108 -> 171,444 KiB, ratios 2.207 (negative control fails) -> 1.929 (passes).
Keep all earlier observations, labelled as separated by builds, alongside
these same-window pairs. The same workload and 2x/600-second/2-GiB bounds
remain unchanged. Hosted x86-64 success at 1.909 is distinct evidence; the
local Linux pair is not a hosted rerun. No resource-variation cause is inferred
from multipart's further successful observation.


## 2026-11-19: gem rounds 26-28 keep Hash super on its native read entries

Rack Headers' unchanged tests isolated fetch arity, fetch_values' missing-key
exception and dig's intermediate TypeError to super_missing's world-free
leaf. Add native Hash read entries there: hash_super_lookup uses the existing
table/key protocol, and hash_super_fetch keeps arity, key/receiver fields and
the actual block. fetch_values invokes that native entry for each key, rather
than calling the receiver's Ruby fetch override, and stops on block control
flow. dig reads the first native table entry without calling the receiver's
[] override, asks its default on a miss, then uses existing dig_next for
nested user dispatch. The shared invoke_val_c0 remains unchanged.

Witnesses 710/711 fail the saved parent binary and match normally and with
GC.stress after correction. They include nil/present/missing keys, defaults,
warnings, block mutation, break/return, compare-by-identity, custom key
equality, prepend and nested dig/keywords. The normal O2 runtime is 72adb4d3.
The original headers file changes from 6 failures / 268 assertions to
3 failures / 282 assertions, still 51 tests and no errors (reference: 302
assertions). It remains RED. Constructor default+block, clone behavior and
default-proc key normalization remain visible; no upstream edits or omissions.

All 115 original files across the three unchanged locks retain their strict
MATCH gates: original 54 MATCH / 7 RED / 1 MEMORY, Matrix/Logger 6 MATCH /
1 RED, Rake 46 MATCH. All reference files are healthy, with 2735 tests.
Preceding snapshots are saved separately before adopting these observations.
Multipart is MATCH at 1,748,736 KiB, but Request still reaches the 2-GiB cap;
this does not establish the cause of the earlier resource variation.

The actual parent hosted Linux run 44338965455 gives 53 MATCH / 7 RED /
2 MEMORY. Its merge source 548582c7 and head 89dbac2e have the same tree.
The ordinary same-OS comparison loses no previous MATCH; strengthen Linux
to include Lint, preserving the preceding 52-MATCH snapshot and its earlier
cross-platform gate history in suites_linux_before_r28.json. Both MEMORY
outcomes remain visible, and RED to MEMORY is not an improvement. macOS
retains its stronger independent 54-MATCH gate. No bounds or initial records
change; full hosted CI and all existing-file comparisons remain merge gates.

A separate custom-key fetch control still bypasses the Ruby wrapper, and
binding its real Ruby UnboundMethod to that Hash subclass still raises
TypeError. Both behaviors match the saved parent and differ from Ruby;
the shared dispatcher/binding paths are coordination items, not claims of
this correction. The retained standalone control is distinct from the
native fetch_values key lookup exercised by 710. Ten harness controls pass,
bracket depth remains 933/1024, and top-level let counts stay main 136 /
state 1167. No collector, VM, AST tree, C API or API-inventory edits.

Full corpus: 728/728 with the hash index ON and OFF, under the existing
aggregate wrapper. Original core MATCH counts retain Class 61, Hash 297,
Array 473, Super 50 and Method 97, with no preceding passing case lost.
Array's two shared-marking reference cases are healthy in this observation;
the candidate keeps its existing skips, so the exact result is 473 MATCH /
4 RED rather than hiding that reference variation. Hash retains the known
replace-memory-leak 10-second timeout; Method retains its compaction skip.
suites_runtime_r28.json stores every nonpassing case and actual execution.
The unchanged Method-copy lifetime control passes at post-GC peak/start
1.686, with real RSS samples retained. No speedup or resource-cause claim
follows from these observations.


## Gem suites, rounds 29–31: preserve native reflection and sender protocols

The actual parent #115 Linux Method-copy lifetime failure remains a merge
blocker: 2.056x in hosted run 44414103412, with the original 2x assertion and
600-second / 2-GiB outer bounds. Consecutive saved-binary Linux/aarch64
comparisons reproduce both pass and fail for each identical binary (parent
1.894/2.035x, candidate 2.053/1.889x). This is evidence of variation, not an
established resource cause or a substitute for the hosted x86_64 gate.
A metadata-row lookup prototype also fails at 2.119x and is rejected; its
source and extra control are restored. All failed and successful series
remain in method_copy_lifetime_latest.json. No collector edits or bound,
warm-up, workload or native-copy metadata changes are adopted in this round.

The parent's original macOS run 44414103487 also regresses multipart from
MATCH to MEMORY. suites_hosted_r115_macos_failure.json preserves that actual
53-MATCH failure; it does not replace the stronger 54-MATCH macOS baseline.
No retry is presented as a repair or a successful same-head observation.

Minitest Mock exposes a separate Ruby semantics gap: a saved native
respond_to? alias must answer using its own protocol even when respond_to?
is overridden. send, __send__ and public_send must honor actual Ruby
overrides, while their native aliases, retained native Methods and native
super keep the captured implementation. native_sender_call consumes the
one-call bypass at the actual native entry before coercion callbacks,
preserves blocks, keywords and refinements, and keeps public visibility
errors' real name/receiver/args. sender_super_ahead checks the remaining
actual ancestor chain rather than reviving a nonexistent native definition.
Class aliases keep their block and native owners precede later Ruby mixins.

Only user_defines_send, blt_alias_call, invoke_val_c2, invoke_with_block2,
invoke_with_block0, super_next_plain and super_missing change, plus the two
new and-helpers above. An adjacent named_class_of_al comment is updated.
The shared invoke_val_c0, VM, AST tree, C API and GC functions are untouched.
All other active session branches have disjoint changed functions at the
pre-publication check. Top-level let counts remain main 136 / state 1167;
the generated C still needs bracket depth 933, below the existing 1024.

Witnesses 712/713 fail the saved parent binary and match normally and with
GC.stress on O2 source c0b06cc7. The unchanged upstream Minitest Mock file
runs all 94 tests: 8 errors become 2, assertions rise 136 to 144, and its
1 failure / 10 skips remain. Reference assertions are 147, so the file stays
RED. Dynamic missing-method super and bare private Kernel stub calls remain
separate gaps; the shared dispatcher/VM-default functions are not edited.

All 115 files across the unchanged three locks retain their strict gates:
original 54 MATCH / 7 RED / 1 MEMORY, additional 6 MATCH / 1 RED, Rake 46 MATCH;
all reference files are healthy (2735 tests). The preceding complete
observations are saved independently before updating the latest snapshots.
Corpus matches 730/730 with both hash modes under its unchanged wrapper.
These local results do not replace the pending complete hosted merge gates.

Core Class/Hash/Array/Super/Method retain all preceding passing cases, with
MATCH counts 61/297/473/50/97. Array is actually 473 MATCH / 3 RED / 1 BOTH
in this observation; reference shared-marking variation is not hidden.
The unchanged local lifetime control passes at 1.769x. That observation does
not resolve the parent hosted Linux failure. suites_runtime_r31.json stores
the exact core executions/nonpassing cases, corpus bounds and lifetime series.


## Gem suites, rounds 32–34: add Abbrev and Singleton; reject the super trial

Pin Abbrev 0.1.2 (release commit b362e8e3) and Singleton 0.3.0 (256c9117)
in suites_small_stdlib.lock.json. Their complete original Test::Unit files
need only the same three pinned pure Ruby development packages; both source
gems have no native extension or runtime dependency. Sources stay outside
the repository. On macOS and network-disabled Linux/aarch64, both files are
MATCH: Abbrev 2 tests / 6 assertions, Singleton 13 / 17, no errors or skips.
Each side records its own real source audit and exact summary. Initial,
macOS and actual Linux snapshots remain separate; no macOS result is relabeled
as Linux. Linux's build provenance records the fixed checkout, parent-emitted
C and isolated container. A separate two-OS workflow restores the lock through
actions/cache and measures offline under the unchanged 600-second / 2-GiB
bounds. Existing gem workflows and their lifetime checks are unchanged.

A missing-super prototype temporarily reduces Mock from 2 errors to 1, but
additional nested missing-call controls expose a regression: a later missing
call must replace the earlier super reason. Both an inner native refusal and
a successfully handled missing call change it on Ruby and the saved parent;
the prototype incorrectly retains super/private status. Withdraw all runtime
changes and its two temporary witnesses. suites_rejected_r33.json records
the rejected source b501dde1, actual 732/732 corpus and original core counts,
and the additional controls that those tests missed. All three trial batches
are retained separately and are not accepted runtime baselines. The actual
class-hook routing and coordinated missing-reason work remain Ruby semantics
in shared dispatch paths, including occupied invoke_val_c0, not VM/GC causes.
New corpus 714 protects the nested-call behavior; all 730 preceding corpus
files and every runtime source remain byte-identical to parent #118.

Final O2 semantics source is the unchanged c0b06cc7 runtime (binary 8057a658).
The full 117-file observation at checkout f5deacd3 has healthy references
with 2750 tests: 107 MATCH / 8 RED / 0 BOTH / 2 MEMORY. The new files add two
MATCH; original 53 MATCH / 7 RED / 2 MEMORY, additional 6 / 1 and Rake 46
are recorded with their real verdicts. Multipart again loses MATCH to MEMORY.
Keep its nonempty regression in suites_candidate.json and preserve the
stronger original 54-MATCH baseline in suites_latest.json. No bounds, APIs,
source-audit rules, upstream tests, pre-existing corpus or assertions change.
Mock remains at its parent's 1 failure / 2 errors / 144 assertions.

The final full corpus is 731/731 with both hash modes, 586.137 seconds and
1,112,912 KiB under its unchanged aggregate wrapper. Ten harness controls,
source guards and the YAML syntax check pass; bracket depth is 933/1024 and
top-level let counts remain main 136 / state 1167. An initial stale generated-C
guard is resolved by restoring the C for the byte-identical parent, without
weakening it. suites_runtime_r34.json separates this final observation from
the rejected trial and points to the unchanged runtime's original core proof.

Parent #118's actual hosted Linux lifetime failure is 2.270x, not a timeout
or 2-GiB event. Its complete failed RSS series is retained; reference is
healthy and additional measurement was not reached. A reduced File subclass
constructor gap also agrees on parent and rejected prototype, remaining a
shared construction/allocator coordination item. No resource cause or fix
is claimed. Full hosted CI, all existing-file comparisons and P1/P2 resolution
remain merge gates; the new jobs do not waive any failed existing job.


## Gem suites, rounds 35–37: pin delegation and URI original tests

Add Forwardable 1.4.0 (0257b590), Delegate 0.7.0 (a5f35f35) and URI 1.1.2
(e69a74a2), each pinned to its release commit and complete tree in
suites_delegation_uri.lock.json. All twelve original test files are MATCH
on macOS and network-disabled Linux/aarch64: 158 tests / 3229 assertions,
without failures, errors or skips. Source gemspecs have neither extensions
nor runtime dependencies. Reuse the existing three pinned Test::Unit packages;
source audits verify each actual library. A separate two-OS workflow and
lock-based cache retain the same 600-second / 2-GiB bounds. Existing job
settings, locks, runtime sources and corpus are unchanged.

Preserve the complete earlier preflight lock and 9 MATCH / 1 RED / 2 BOTH
observation. Forwardable 1.3.3 expects obsolete message quoting, while URI
1.0.3 calls Ractor#take, absent on reference Ruby 4.0.9. Newer release tests
handle these API changes; no upstream test is edited or omitted. Delegate
0.4.0 has a separate Mere-only keyword-forwarding error through a
ruby2_keywords Proc used by define_method. Delegate 0.7.0 generates explicit
`...` forwarding methods and its full original file passes. This is support
for that release, not an interpreter repair of the old Proc path. The old
RED and both reference failures remain visible, outside accepted baselines.

The inventory now contains 13 gems / 129 files. This round measures the new
twelve separately from the preceding 117-file observation; it does not
present their mixed-date totals as a new complete sweep. The unchanged
parent runtime c0b06cc7 (Mac O2 binary 8057a658) passes all 731 corpus files
with both hash modes under the existing aggregate wrapper. The final record
stores its exact execution. Ten harness controls, YAML syntax, source guards
and bracket 933/1024 pass; top-level lets remain main 136 / state 1167.
No VM, AST, C API, collector, shared dispatcher or API-inventory edits.

Parent #119's real small-suite CI run 44451114499 succeeds on both OSes,
with both files MATCH. Merge source 1c526613 and head 108e8b0e have the
same tree 8792dba0. Adopt the actual hosted per-OS observations after ordinary
strict comparisons, preserving both earlier local snapshots. Its additional
Linux run 44451114073 passes the unchanged lifetime check at 1.996285x.
Its binary SHA256 is exactly the same fbbd0199 as #118's 2.269969x failure,
and the check digest matches. These are separate hosted runs, not a same-window
comparison or a resource fix; retain every RSS series and all strict gates.

The same parent's build-linux job 135315000164 fails only the known-noise
Module complemented-entry memory-leak case (195 tests; 1 failure; ratio
2.371912; outer execution 28.730 seconds, no resource-limit event). A rerun
of that individual job was requested under unchanged bounds. GitHub returns HTTP 403
because the containing workflow is still running, so the rerun is not accepted.
Keep the failure and retry pending; do not report it as green or waive it.
Complete hosted CI, all existing-file comparisons and P1/P2 resolution still
control merging. The previous stronger 54-MATCH original macOS baseline
and failed multipart observations remain unchanged.


### Hash subclass options reach Ruby missing hooks (2026-11-19)

Rails' ActiveSupport OrderedOptions is a Hash subclass with a Ruby
method_missing for configuration setters/getters. The primitive hook guard
accepted singleton lookup classes only, so a real subclass hook was skipped.
Extend that guard to actual Hash ancestry, preserving its existing real
method, native alias, refinement and recursion checks. Only main.mere's
hng_missing_hook changes; no new global values, state, gemtest, VM/ISeq,
AST, C API or collector implementation edits.

On the gem-suites-r14 parent (01d5e498), normal O2 with its pinned Mere
2e3cc433: all 732 corpus files match with hash indexing ON and OFF. Corpus
719 covers inherited hooks, setter/getter storage, arguments/keywords/blocks,
native methods/aliases and callbacks, refinement precedence, a Ruby method
removed by undef and missing-error metadata. Original Hash is 297 MATCH /
1 RED / 8 BOTH, Method 97 MATCH / 1 RED, Super 50 MATCH: 454 cases,
444 MATCH / 2 RED / 8 BOTH. No parent file loses MATCH. All nine RSS and ten
suite-harness controls pass; generated C depth remains 933/1024 with the
parent's compiler. No original test, exclusion or resource limit changes.

An unchanged ActiveSupport OrderedOptions probe reuses each runtime's own
saved gems and matches: reference 0.609 s / 24,208 KiB; candidate 1.344 s /
166,208 KiB, both exit 0 without a resource event. It is a diagnostic, not
a fresh Rails installation or application pass. Keep the earlier complete
gem observations and unresolved native-undef/private-alias diagnostics;
this change does not claim their repair. A fresh combined original Rails
workload and full hosted CI remain required before merge.


## Compatible native features before shipped implementations

An activated gem's existing native extension can precede the shipped stdlib
without being selected: the ordered search handled real Ruby files, then
chose the shipped source before asking the native resolver. This mixed the
actual JSON 3.1 facade with an older shipped generator during Rails loading
(#127). Select a compatible native feature in the same load-path prefix when
no physical Ruby file wins. Preserve explicit .rb searches, the native ABI
probe and the shipped fallback after that prefix. resolve_feature_path and
actual require report/use the same native file and its loaded identity.

Only main.mere's resolve_feature, load_path_pick_shipped and do_require0
change, with new mutually recursive shipped_native_path. No additional
top-level Mere values, C API implementation/header, collector, VM/ISeq, AST,
gemtest, API inventory, original test or resource-limit changes.

Corpus 722 (originally 721) independently compiles the same tiny C fixture for each runtime
using that runtime's headers. It covers a real Ruby file before the native
choice, explicit .rb lookup, native feature resolution/loading, its actual
constant, canonical feature identity and one-time execution. The parent
fails at the missing native constant; normal O2 head matches Ruby 4.0.9 with
indexing ON/OFF. Original require/autoload/Marshal retain the exact paired
parent result: 311 cases, 308 MATCH / 0 RED / 3 BOTH. All nine RSS checks
pass; bracket depth remains 933/1024 with the parent's pinned compiler.

The full corpus is 733/733 in both modes. The unchanged C API contract
groups agree normally and under collection stress (loader: reference 48,
Mere 49); all six fault controls fail as required. The ordinary unchanged
JSON 3.1 probe now matches on validation-only composition 61d01f6d.

A new cold original-CLI replay on that composition installs all 68 gems
(232.699 s / 954,624 KiB), then passes the JSON boundary and stops in the
next ActiveModel Module#included native-super call (#129), migration exit 1
in 4.097 s / 318,224 KiB. Reference passes all six stages; candidate boot,
tests and HTTP remain NOT_RUN, without a resource event. The separate
native_candidate.json in #117 preserves the exact run. No JSON attributes,
Rails/gem sources or original inputs/limits are patched. This own branch
is stacked on the Hash candidate; production integration must wait for the
parent series and required hosted gates.

The native feature witness was renumbered from 721 to 722 after the
concurrent parent published its distinct IO witness 721. Its Ruby/C source
is byte-identical; no observation or historical source record is rewritten.

## 2026-11-19: nonblocking writes use bytes, and the multipart pipe stops copying

Rack 3.2.0's original long-boundary test retries a 10-MiB String while a
reader drains its pipe. IO#__fd_write_nonblock converted that String using
the stream's encoding and called String#b for every attempt. CRuby 4.0.9's
io_write_nonblock writes the supplied bytes directly. Besides allocating an
unnecessary String on every retry, calling #b exposed a user override that
CRuby never calls. The configured converter could also change the bytes.

Use IO.__wstr(s, nil) and pass the resulting String directly to IO.__fdwrite.
This changes only the embedded Ruby IO method in core_prelude_k. Ordinary
write conversion, descriptors, polling, errno handling, the VM, collector,
native allocator and C API are unchanged. Witness 721 covers stream encoding,
invalid/frozen input, an overridden #b, embedded NUL, ordinary write conversion
and the non-String #to_s protocol.

Fresh paired O2 measurements use compiler 2e3cc433, the same locked Rack source
and its complete original 85 tests / 239 assertions. The old parent matches at
1,686,656 KiB peak family RSS; the unmodified current runtime is stopped at
2,333,216 KiB. The corrected runtime completes at 392,672 KiB (15.304 seconds),
and again at 487,648 KiB in the complete macOS sweep. These are measured family
RSS values, not a timing comparison with the killed run. Linux/aarch64 also
completes the original file below the unchanged cap. Both sides audit the
physical locked library. Per-side/file bounds remain 600 seconds / 2 GiB.

All 129 original files across the five existing locks were measured on macOS
at the same source cb09d147 and O2 executable: 120 MATCH / 8 RED / 1 MEMORY,
with no strict per-file regressions. Request remains MEMORY. All 732 corpus
files match with the hash index on/off, 678.868 seconds and peak family RSS
1,086,160 KiB under the existing 900-second / 2-GiB aggregate bound. The
upstream test_io write_nonblock selection gives 6 tests / 5 assertions on
each side; it does not replace the complete upstream file's CI gate. Existing
IO deadlines, inherited pipes and stalled TCP/TLS/HTTP controls pass.

Keep the failed Linux environment probes separate. Root cannot test unreadable
directories faithfully, and its fixed-name temporary files then caused EACCES
when the next run used an ordinary user. The final run uses an ordinary user
and a fresh TMPDIR without changing tests or bounds. Request can be killed by
the container's aggregate cgroup limit before the per-family RSS sample reaches
its cap; preserve the actual signal, OOM observations and RED classification
rather than treating that representation change as a functional improvement.

The Method-copy workload and 2x bound are unchanged. New macOS and local Linux
observations do not clear the earlier hosted x86-64 failures. An independent
diagnostic adds only public ObjectSpace Class counts: the reference stays at
281 and Mere ranges from 283 to 297. This is evidence for further investigation,
not a collector or lifetime repair. No GC internals were changed.

## 2026-11-19: preserve failed measurements while repairing Linux CI setup

The hosted Ubuntu image's APT mirror returned HTTP 503 for the clang
metapackage before any tests ran; libssl-dev and pkg-config were already
installed. Linux setup now first compiles, links and executes a real
C/OpenSSL probe. A working installation needs no package download. A failed
probe still runs the original apt-get commands, and must pass the probe
afterwards. Three controls use real clang/OpenSSL in an offline Linux
container: working dependencies avoid the installer, installer failure is
propagated, and a successful installer cannot hide unusable headers. A
separate small Linux job runs these controls without extending test jobs.

The new hosted control job also passes all three tests on Ubuntu image
20261111.370.1 in 3.375 seconds. Preserve that image version separately from
the earlier APT failures on 20261111.127.1; it does not waive their observations
or imply that the remaining hosted test jobs have completed.

Tool summaries previously ran through upstream cancellation because their
job and collect step used always(). They then failed on zero artifacts.
The summary now requires a non-canceled workflow and a successful or failed
shard job. Actual failed shards still reach the unchanged strict collector;
empty shards remain an error. All eight collector controls pass, including
the real reference child diagnostic. Source locks, baselines, test commands,
600-second/2-GiB file bounds and every existing job timeout are unchanged.

The latest hosted Method-copy control still fails at 2.224702x, reference
1.086532x, without a resource-limit event. The receiver-elision hypothesis
in copy_meth_src was built and measured, then withdrawn. Its paired unchanged
workload reduced cumulative STMT-region allocation by 33,600,288 bytes, but
default-region allocation fell by only 88 bytes and retained RSS did not
improve. This is a rejected hypothesis, not a lifetime fix. The final runtime
source is byte-identical to the parent. Existing diagnostic logs show method
and class entries being reclaimed; they do not isolate retained native memory.
Leave VM/GC/allocator internals to their sessions and retain the failed 2x
gate. Full samples, hashes and CI-only branch updates are recorded in
gemtest/suites_ci_lifetime_r43.json. No new gem sweep is claimed here; the
previous 129-file 120-MATCH/8-RED/1-MEMORY observation remains unchanged.

## 2026-11-19: distinguish current method metadata from retired native arenas

Investigate retained storage rather than the rejected receiver-elision
candidate's transient allocation. Independent first-batch and full-program
diagnostics show default-region allocation growing by only 340,352 bytes,
while current method storage can grow from 4,240,408 to 33,602,136 bytes.
Logical method counts stay near their post-GC baseline. Add eleven actual
metadata byte counters to the existing optional store_stats output; it only
reads stores and changes no roots or collection policy. Diagnostic output
does not establish a repair: the unchanged ordinary paired control is
1.079818x on the reference and 1.804522x on this macOS observation, but a
separate full-program logged diagnostic reaches 2.163428x. Preserve both.

The pinned compiler's map_bytes counts a map's current private arena, not
older generations on the native retired list. The named kept-region counter
does not count those retired generations either. A separate read-only native
exit observer finds 8 retired arenas / 17,227,776 capacity bytes after the
first batch, 16 / 153,240,752 after 19 total batches, and 16 / 95,605,176 after
21. These independent process observations establish retained old arenas;
capacity is not RSS, and exit time is not necessarily the largest RSS sample.
Which pins are live versus conservative stale words remains unproven.

tools/method_copy_retention.py records seven independent prefixes with the
existing 600-second/2-GiB bounds, source/executable/log hashes, real store
bytes and GC/RSS timelines. Only its last case is the unchanged original
program. It is explicitly diagnostic and never replaces the original 2x
assertion, warmup, workload or baseline. The native observer is excluded from
the ordinary build and marked DIAGNOSTIC O2 observer; the ordinary gate
correctly refuses it. All seven real executions complete, their raw logs
reparse with the final parser, ordinary stdout/exit are preserved, and actual
bracket depth is 933/1024 on the pinned compiler. No top-level Mere binding,
GC/VM/AST/C API implementation or allocator policy changed.

The next repair belongs to the GC/native allocator lifetime session: identify
the actual pinners and retirement epochs, and inspect method-store compaction
that updates its floor even if the native operation declined under a pin.
That is an inspection target, not a confirmed fix. Freeing an arena while a
real borrowed pointer survives would be unsafe. Preserve the assigned boundary
against GC internals. Full observations are in
gemtest/method_copy_retention_r46.json; the earlier hosted 2.224702x assertion
and every existing-file merge gate remain open. No new gem sweep is claimed.


## Native ownership at the original RSS samples (2026-11-20)

The unchanged Method-copy control now also reproduces its actual failure on
native Linux/aarch64: 2.040674x and 2.040880x, with a healthy 1.1039x reference,
ordinary O2 and no resource-limit event. Preserve both failures, the earlier
passing observation, and the earlier hosted failures. These are not retries
selected for a green result. The validation attempts changed the diagnostic
collector; the ordinary runtime and program were identical throughout.

A separate emitted-C copy reads native ownership before the existing RSS
reads/spawns. It records physical slots, pin floors, current map storage,
retired generations and saved pinner states without changing collection or
pinning. At the largest native RSS sample in the completed diagnostic, retired
capacity is 170,070,232 bytes while the current method table has 1,275 live
rows and 4,260,408 capacity bytes. All saved pinners identify the running root
coroutine. Capacity is not RSS, and this does not prove the pins unnecessary.

Two initial collection attempts correctly failed because native output
contaminated the verbose parent case identifier. Setting the exclusion before
exec, suppressing unused exit observations, and separating native lines fixed
the collector. The final run preserves all three original clone case names,
the exact child except its two upstream nonce tokens, and all 21 Method-copy
samples. The ordinary gate rejects the diagnostic mode; the combined command
still fails when its ordinary Method-copy assertion fails.

The separate native x86-64 job locks the failing runtime and both existing CI
compiler pins. Existing jobs, source locks, baselines, 600-second/2-GiB limits,
upstream ten-second child and 2x assertions remain unchanged. This adds
observability, not a memory repair. See tools/rss_native_probe.md and
gemtest/native_rss_retention_r59.json for the protocol and measured evidence.

## 2026-11-20: retain the method floor when native compaction is deferred

The native map compactor can return without moving a pinned arena. The
method-store wrapper nevertheless published that enlarged arena as its new
floor, delaying later attempts under the existing growth rule. Change only
m_state.compact_method_store: publish a measurable floor on initialization
or an observed capacity reduction. Preserve the dirty flag, return value,
unmeasurable-arena behavior, numeric thresholds and native pin rules. This
specific collector bookkeeping change was authorized after the investigation;
no compiler, pinning, marking or collection implementation changes are included.

Fixed-order ordinary O2 parent/candidate/candidate/parent measurements use
the same compiler 2e3cc433 and byte-identical original Method-copy program.
Native Linux/aarch64 ratios are 1.900780 / 1.580659 / 1.456400 / 2.426395;
the last parent observation fails the unchanged 2x gate. Mac ratios are
1.689337 / 1.385431 / 1.386783 / 1.685873. Candidate initial RSS is comparable
to the parent, not enlarged to lower the ratio. Complete Module and Refinement
controls lose no passing cases on either OS. The Mac parent Module run fails
the known complemented-entry RSS case; the candidate passes all 195 tests /
1240 assertions. Preserve that failure alongside the passing selected cases.

A separate native diagnostic wraps the original compaction entry exactly once
and counts requested attempts, real arena moves and floor increases without
a move. The parent has 9 requests / 4 moves / 4 noninitial invalid floor
increases; the candidate has 57 requests / 7 moves / 0 such increases.
Maximum retired capacity drops from 169,203,224 to 93,161,712 bytes in this
diagnostic. Capacity is not RSS, and the ordinary ratios remain separate.
The underlying native compactor, pin checks and thresholds are unchanged.

The new x86-64 workflow locks repaired source 90c83c6e and both existing
compiler pins. Prior hosted failures, including Method-copy at 2.221519x,
are not waived. Historical clone RSS failures were not reproduced in this
pair and are not established as repaired. File/side 600 seconds / 2 GiB,
upstream child ten seconds and original assertions remain unchanged.
Twelve evidence acceptance checks pass; bracket depth remains 933/1024 and
top-level lets remain main 136 / state 1167. See
gemtest/method_store_floor_r60.json for all ordinary pairs and diagnostic
provenance. The broader corpus and five-gem verification are in progress;
no baseline snapshot is replaced.

## 2026-11-20: separate clone's cached temporary arenas from live metadata

Backport the verified method floor repair to the earlier PR 119 branch,
without changing any further runtime function. Its original native Linux
Method-copy gate now passes at 1.618172x; the earlier 2.051319x failure remains
recorded. Fresh local verification passes all 732 corpus programs in both hash
modes (599.508 seconds, 1,099,200 KiB peak family RSS) and the original five-gem
batch at 54 MATCH / 7 RED / 1 MEMORY, with no per-file regression. This does
not establish a repair of clone's separate historical RSS failures.

Read-only Linux/glibc diagnostics add allocator accounting, mapping RSS,
coroutine stacks and active temporary-region inventories to the existing
private observer. All ordinary generated C and allocator/pin/GC policies remain
unchanged; the existing default diagnostic emitter is byte-identical too.
A first attempt printed too much into the captured pipe and lost records;
keep its rejection. Print only the existing mandatory maps plus large extra
independent maps, while running the unchanged complete original workload.
Missing allocator, active-region or block-capacity records fail acceptance.

Two fixed local core-compiler batches each run four ordinary clone controls
and two separate diagnostic controls. Ordinary ratios vary from 1.440821 to
1.993544 and all pass; none reproduces the failed hosted assertion. A complete
rich trace nevertheless identifies a separate physical-memory factor. The
21 temporary scopes used for the final report hold 83,886,080 capacity bytes
versus 22,020,096 initially, although allocation since acquisition is only
32,560 versus 31,096 bytes. Several MCALL scopes reuse 16-MiB cached blocks
without allocating any bytes in the call. Their resident pages and retained
native generations are distinct from a growing live-module table. Capacity
alone is not RSS; raw mappings and allocator totals remain separate evidence.

A new, separate native x86-64 job locks the actual failing PR 139 merge source
ae6bd8cc and compiler 01f5ad73. It builds ordinary and diagnostic binaries
before measurement, then retains the full Module control, one reference,
four ordinary clone controls and two diagnostics in fixed order. A failed
ordinary assertion remains a failure. File/side 600 seconds / 2 GiB, the
upstream ten-second child, original child hashes and assertions are unchanged.
The other session's branch is only read; no edits or pushes are made there.
No compiler or native cache implementation repair has been applied.

Seven captured-data heap acceptance checks and the existing twelve native
checks pass. The new fragment compiles and executes on native Linux; the
existing observer remains separate from every ordinary gate. See
tools/clone_rss_heap.md, tools/fixtures/clone_heap_sample.json and
gemtest/clone_heap_r62.json. The local evidence does not replace the pending
hosted observation or waive historical clone failures.

## 2026-11-20: apply the verified method floor repair to the earlier small-suite branch

PR 119 still fails its original Method-copy assertion at 2.051319x on native
Linux. Backport the already verified PR 136 repair of compact_method_store
only: a deferred native compaction must not publish its enlarged arena as
its next floor. Dirty clearing, the return contract, numeric thresholds,
unmeasurable-arena behavior and native pin rules remain unchanged.

Same-compiler ordinary O2 parent/candidate/candidate/parent observations give
1.899619 / 1.592149 / 1.530450 / 1.817941 on native Linux/aarch64 and
1.790451 / 1.482855 / 1.214509 / 1.875326 on macOS/arm64. Both local parent
observations pass too; preserve the earlier hosted failure rather than calling
these a fresh reproduction. All original programs and 2x assertions remain.
Complete Module (195 tests / 1240 assertions) and Refinement comparisons lose
no passing cases on either OS. Selected clone and complemented-entry controls
also pass; this is not an established repair of historical clone failures.

The only ordinary runtime function changed by this backport is
m_state.compact_method_store. Actual bracket depth is 933/1024; top-level
bindings remain main 136 / state 1167. See
gemtest/method_store_floor_pr119_r62.json for every ordinary paired sample
and raw-log hashes. The full corpus and five-gem verification are in progress
at this checkpoint. Baselines, locks, compiler pins, workload and resource
bounds are unchanged. Fresh hosted CI and per-file comparisons still control
merging.

## 2026-11-20: a live refinement snapshot need not duplicate its first target

PR #92's repeated original Module check failed its RSS assertion at
77,643,776 -> 157,310,976 bytes, 2.026060x. Keep that failed measurement.
A refinement scope with one live refinery and its sole matching fixed
target stored both entries, although installing the live refinery restores
that same target and implementation. Store its live marker once in this
exact case. Mixed tables retain their complete snapshots, and later targets
still expand when the live scope is installed. This changes ref_snapshot
only; no collector, native pinning, allocator, cache size or workload changes.

Separate ordinary O2 builds use the same CI compiler 01f5ad73. On local
Linux/aarch64, the unchanged selected upstream case fails before at
2.168020x and passes after at 1.722404x. Initial RSS is comparable,
80,203,776 / 80,076,800 bytes; final RSS is 173,883,392 / 137,924,608.
Outer times are 6.133 / 6.098 seconds. Both complete original Module files
pass all 195 tests / 1,240 assertions. The corresponding macOS observation
gives 1.219891x before / 0.809315x after; its complete files also pass.
These local observations do not substitute for fresh hosted x86-64 CI.

All 122 original Refinement tests retain the reference's per-case result:
370 assertions with no skips on Linux, 367 assertions and the same one skip
on macOS. All eighteen logs reparse, identities match, and the six captured
selected-case child inputs differ only in the original two nonce tokens.
Witness 728 checks live targets added after capture, a fixed using scope,
reopening, enumeration and collection in four hash/MRO configurations.
Actual bracket depth is 155/1024 and no top-level binding is added.
The source locks, stronger suite baselines, 600-second / 2-GiB file bounds,
original 1,000 / 300,000 iterations, ten-second child timeout and strict
ratio below 2.0 are unchanged. Measurements and hashes are preserved in
gemtest/module_rss_pr92_r55.json.

## 2026-11-18: stage 9 follow-up, collectible snapshots and native dump facts

Main 12ca1df2 (#102) is imported unchanged. The complete main CI for
3eb24fef (44196635193) measures 33,313 MATCH, 1,101 RED, 132 BOTH, 21 EXTRA,
49 incomplete/zero-test files and the same 157 target RED. The 12/57/88
inventory is unchanged. The older #94 CI now has all eight shards: 33,322
MATCH, 1,034 RED, 131 BOTH, 23 EXTRA, 49 incomplete files and 57 exclusions.
Its Ractor dump failure is a real Module wrapper error, not timing noise.

ObjectSpace's public snapshot kept every candidate rooted through callbacks,
unlike MMTk's each_object, which rechecks actual presence. It now roots only
the current value in the existing frame and skips candidates collected by
an earlier callback. A control creates 1,001 instances and collects inside
the first callback: the old build keeps all 1,001, Ruby keeps three, and the
new conservative collector keeps about 120. Held values and callback counts
remain correct. No additional collection, root definition or threshold is
introduced. Corpus 685 adds this differential regression.

Exact builtin filters avoid dispatch-class/ancestry lookup for a value whose
store already proves its base type. Other filters read the full hng_store
singleton tag. dispatch_cls_of deliberately strips singleton tags, so using
it had omitted extended Array/Hash values from module and subclass filters.
The expanded 685 reproduces this omission on the old build and covers named
subclasses and singleton-tagged ancestry as well as the existing GC/Fiber
and block-control cases.

ObjectSpace.__dump_one also called singleton_class? on Module-subclass
wrappers and superclass on uninitialized Classes. Native __dump_class_info
reads the actual superclass table and singleton representation. Corpus 670
now covers both forms, with no guessed fields. The upstream Ractor dump
and singleton dump pass: two tests, nine assertions, no skips; the Ractor
case takes 7.33 seconds under its unchanged bound.

The ten-second Enumerable test still times out. A diagnostic of its exact
child program, with the runner's loaded libraries and without adding code
to that program, takes 17.67 seconds on the current-value-root candidate.
That diagnostic is not an upstream pass. Sampling shows shared block frames,
local lookup, hashing and primitive dispatch on the path; those helpers are
unchanged. Full validation of the final combined candidate follows before
publication. No ISeq/AST/m_state/collector-body or gemtest edits are added.

The first combined full validation caught a class-presence regression:
an implicit superclass row had been mistaken for a collected class.
Class candidates now capture their collectible identity owner before the
callbacks and consult that registry after collection. Named classes remain
valid without explicit superclass rows. Existing corpus 226, expanded 685
and test_each_object_singleton_class pass. Dump metadata follows the native
implicit superclass rules too, including Object/BasicObject and Enumerator's
builtin subclasses; expanded 670 compares their actual address edges.

The intermediate bounded run completed all eight files, with core
ObjectSpace at 1,886,512 KiB, below the unchanged 2-GiB bound. It still had
the class-presence assertion above, so it is not the final pass. ObjectSpace
itself completed at 533,136 KiB with 38 MATCH and eight RED; memsize_of_all's
raw pass still uses inherited estimates and is not an honest implementation
gain. Allocation-path tests now reach their actual frozen-literal provenance
failures instead of the Module reflection error and remain named handoffs.

Final validation on the combined #102 candidate completes all eight files:
288 tests, 263 MATCH, 14 RED, six BOTH and five EXTRA, with 57 identical
exclusions separately audited (16 + 19 + 22). Core ObjectSpace is 37/37 at
1,876,592 KiB and objspace is 38 MATCH/eight RED at 571,136 KiB. No file in
this bounded local subset reaches the 2-GiB limit. Nine RSS cases and the
OpenSSL interruption/stress/native-owner/thread lifetime gates pass; source
checks pass and bracket depth is 933/1024. The remaining Enumerable test
still reaches its ten-second limit and is not excluded.

Local corpus commands in earlier progress entries omitted --both; their
ordinary-mode results were incorrectly described as local checks of both
hash modes. Those local mode claims are corrected here. CI's explicit
--both jobs are separate evidence. The final candidate has now completed
the explicit command `sh run_corpus.sh --both`: 711/711 programs agree with
Ruby with indexing ON and OFF. Corpus 670 compares direct class edges;
Object's inserted Kernel ICLASS is not a portable superclass-address test.

A VM handoff can reproduce the callback cost without ObjectSpace at all:
keep 6,800 empty Arrays, and repeat 1,000 times an Array#each block containing
`array.clear if array.length == 1000`. The actual main 3eb24fef CI interpreter
takes 14.22 wall seconds (12.88 user + 0.21 system CPU seconds). This is
independent shared-call workload evidence, not a replacement for the failing
upstream test. Shared block/frame/lookup/dispatch functions remain untouched.

The final remote namespace audit found a concurrent gem witness at 685.
This session's snapshot witness moves from 685 to the verified free 710;
earlier entries retain their publication numbers. Its contents are unchanged
and its renamed path is checked against Ruby with indexing ON and OFF.


The primitive singleton-undef correction reviewed in #109 is also applied
to this stacked ID branch. Only ObjectSpace.__id_integer changes: it reads
the actual hng_store tag for availability and native error class names,
re-reading after callbacks. Corpus 687 retains six String/Array/Hash controls
for preexisting and query-created undefs. Shared lookup/VM helpers are
unchanged. The independent extraction and this port are the same fix, not
two additional matches in the original intake.


## 2026-11-18: stage 9, ship checked ID lookup independently

The GC/ObjectSpace stack has an open Enumerable timeout finding. Its checked
ID lookup can be reviewed independently against main 12ca1df2: this change
ports ObjectSpace.__id_integer, live __val_of_id/__str_of_id lookup and the
_id2ref prelude only. A small __id_value arm reads native identity for the
fallback search, avoiding a dependency on the stack's heap dump metadata.
Corpora 687/688 are copied unchanged from the reviewed stack, including all
four conversion review controls. No additional corpus number is consumed.

The base __objects/each_object and count_objects implementations are kept.
There are no new exclusions, top-level values, collector-body changes or
independent edits to shared VM/dispatch helpers, m_state, Prism, C API or
gemtest. The full 157-test intake remains 12 honest implementation matches,
57 reasoned exclusions and 88 named handoffs in the parent inventory. This
port does not count the same fixes a second time.

O2 verification of the independent port retains core ObjectSpace 37 MATCH,
Enumerable 89 MATCH and Object 65 MATCH under the unchanged CI supervisor.
The 10-second Enumerable subprocess remains enabled. All nine RSS cases pass;
actual bracket depth is 933/1024, so the stale 923 search seed is corrected
to that measured value. No top-level definition is added.


The second independent round ports ObjectSpace.__store_counts and the
count_objects prelude from #94. Actual String survivors/new handles and
Proc/Binding store lengths contribute to T_STRING, T_DATA and TOTAL. Corpus
674 retains 1,000 ordinary Strings, 1,000 empty Strings and 200 Procs plus
200 Bindings, checking real count deltas, totals and held identities. The
base enumeration implementation is unchanged; no exclusion or limit changes.


The third independent round addresses the primitive singleton-undef review.
ObjectSpace.__id_integer now reads a primitive's full hng_store lookup tag
for availability and native error class names, re-reading after callbacks.
The shared super_base/dispatch helpers are unchanged. Corpus 687 adds named
String/Array/Hash subclasses with preexisting singleton undefs and undefs
created by respond_to? callbacks. All six controls require the reference's
TypeError and concrete subclass name. The previous build raises NoMethodError
or accepts conversion instead.


## 2026-11-18: stage 9, ship GC measurements independently

Extract the GC-specific part of #91 against main 12ca1df2, preserving the
base ObjectSpace enumeration and VM/AST/C API code. gc_collect_any wraps
actual collections with CPU profiling and weak-map observations; its
ObjectSpace observation cleanup is left with #91. No collector marking or
sweeping function is independently changed. Startup CPU epoch and portable
CPU-clock/browser bindings retain the three addressed review corrections.

GC APIs expose real observations and unsupported compaction consistently.
The upstream exclusion mechanism and symmetric audit/reporting cover only
19 GC and 22 compaction cases in this branch; ObjectSpace's 16 exclusions
stay with #91. Corpus 711 tests GC measurements/capabilities; existing 673
checks delayed enablement, clear/re-enable and CPU-versus-sleep accounting.
No new top-level value or resource-limit changes.

Fresh Wasm emission also exposed an existing missing mr_utimens/mr_stat_times host imports.
The HTML host now returns its guest wrapper's declared -2/empty-string unavailable
sentinels, preserving startup without claiming timestamp support. The native
File/C API implementation is unchanged.

Merging main on 2026-11-22 (after #91, #99, #103, #144 and #149): #91 carried
this same GC work, so the code, glue, exclusion files, corpus 673/711 and this
record are already on main byte for byte. Main's wording of the ledger (41 GC
and compaction plus 16 ObjectSpace, 57 in all) and its run.sh are kept; #112
adds only this note.


## 2026-11-18: consolidate the deferred GC/ObjectSpace stack

Integrate the count/ID stack and the independently validated #109/#112
changes into this remaining branch. Keep the full ObjectSpace snapshot and
its collectible-owner checks, all ID protocol controls, real store counts,
the ObjectSpace observation cleanup at collection, and both browser host
fixes. The integrated ledger remains 57 (41 GC plus 16 ObjectSpace). The
independent main-targeted PRs stay open; this is branch integration, not a
main merge. The Enumerable P2 is still open and is not claimed as fixed.

The integrated O2 candidate passes explicit corpus --both 712/712, all nine
RSS cases and bracket depth 933/1024. All eight bounded files complete:
263 MATCH, 14 RED, 6 BOTH, 5 EXTRA, plus 57 symmetric exclusions. Core
ObjectSpace is 37/37 at 1,830,016 KiB; Enumerable remains 88 rather than
main's 89. Issue #113 records the shared callback handoff: even the native
1,000-turn diagnostic takes 13.710 CPU seconds without the Ruby wrapper.
That diagnostic is not a passing upstream test or a changed time limit.
The earlier stacked count/ID work is consolidated here, while #109/#112
remain independent main-targeted deliveries. No main merge is implied.


## Stage 9 merge audit after the complete CI run (2026-11-19)

PR #91's prior complete CI 44316999605 attempt 2 is green, but comparison
with complete main CI 44239745755 attempt 3 covers all 758 files and finds
three lower MATCH rows: Enumerable 89 to 88, Optimization 88 to 87, zlib
96 to 95. None is an exclusion; the 57 actual symmetric exclusions remain
separately reported. A green measurement job does not waive these rows.

Merge current main 3b05689f, keeping its compiler 01f5ad73 and bracket seed
155. The only conflict was that seed; the actual 1024 limit and verification
remain unchanged. Fresh independent O2 builds of main and the integrated
GC source f6ed1792 reproduce the original cases sequentially after builds:

- Enumerable: reference 0.22 s, main 1.73 s, both PASS/three assertions;
  GC candidate reaches the original ten-second Timeout, two assertions.
  The outer measurement is 12.357 s / 239,840 KiB without a resource event.
  Issue #113 and its P2 remain open; do not hide real Arrays or change bounds.
- Optimization: the unused named block parameter produces a real extra Proc
  (T_DATA delta 1 versus reference 0). No-call/unused/used controls give
  reference 0/0/1, main 0/0/0, candidate 0/1/1. Main's used control reveals
  its incomplete counter. The true counts stay; issue #130 hands actual
  lazy block-parameter materialization to the VM/evaluator work. The same
  count path is relevant to #109. This test stays enabled, without a new
  exclusion or fabricated zero. unittest/block_parameter_probe.rb preserves
  the three controls in fresh processes.
- The original zlib gunzip memory-leak case passes on all three current
  builds: reference 1.125 s, main 6.515 s, candidate 6.551 s outer execution.
  This selected result does not replace the required complete file/CI row.

The original three files were also rerun under their normal supervisor;
their exact current totals are recorded below. The two genuine blockers
above are outside the original 159-row intake: that inventory remains
two main fixes, 12 honest implementation matches, 57 exclusions and 88
named handoffs. No collector, VM/ISeq, m_state, AST, C API, test or limit is
changed by this audit beyond importing the already merged compiler update.
The PR is not mergeable until these blockers and current hosted gates pass.

```text
ruby/test_enum.rb                                  90 tests  MATCH   88  RED    1  BOTH   1  EXTRA   0
ruby/test_optimization.rb                          89 tests  MATCH   87  RED    2  BOTH   0  EXTRA   0
zlib/test_zlib.rb                                  96 tests  MATCH   96  RED    0  BOTH   0  EXTRA   0
total: 275 tests, MATCH 271, RED 3, BOTH 1, EXTRA 0
```


## 2026-11-19: restore the strict GC merge-gate cases

The unchanged Optimization allocation case now passes with four assertions.
An empty method whose sole formal is its named block parameter, with no
defaults or observer/scheduler, avoids creating an unread Proc. Positional
formals retain the full binder: destructuring can execute to_ary and enable
TracePoint during binding, exposing the block through call/return Bindings. TracePoint, set_trace_func, defaults, threads/fibers, signals and
finalizers retain the full binder. Local-declaration markers are metadata,
not reads of the block. Real none/unused/used T_DATA deltas remain 0/0/1;
the used Proc is still present in ObjectSpace.

The unchanged Enumerable case now completes in 7.919 seconds with all three
assertions under its original ten-second child bound. Native Array length,
size and empty? reads avoid general dispatch only after proving the actual
plain Array entry, its visibility and absence of observers, overrides,
aliases, undef, prepends and refinements. A block with one ordinary positional
formal and one value binds that same value directly, after consuming the
source-Proc state; the surrounding frame, GC roots and flow handling stay.
No objects are filtered out of enumeration and no collection is forced.

The complete Enumerable file improves from 88 MATCH / 1 RED / 1 BOTH to
89 MATCH / 0 RED / 1 BOTH across 90 cases, without losing any previously
passing case. The original Module contract completes all 195 tests / 1,240
assertions with zero failures/errors/skips (22.935 seconds / 359,296 KiB
outer peak, unchanged 600-second / 2-GiB bounds). This local pass does not
erase the earlier Linux clone RSS failure; the new hosted job must pass it.

Corpus 725/726/727 cover actual Proc counts and binding observation, native
Array read dispatch, and one-value block identity/arity/defaults/closures/
bindings/keywords/flow. All three match Ruby with the hash index enabled or
disabled and with MRO caching disabled. Existing native Array singleton-undef
and private-call gaps produce identical failures on the preceding binary;
their separate diagnostics are retained, no new exclusion is added, and the
corresponding existing tests remain enabled. The native-undef gem work owns
that independent behavior; it is not claimed fixed by this read path.

Touched runtime functions: call_method, run_meth_result and bind_block_params,
plus emethod_args; new and-helpers bind_params_body, empty_block_binding_body
and native_array_query. The concurrently changed bind_params implementation
is left alone. No m_state, VM/ISeq, AST/Prism, C API, API inventory, collector
mark/sweep body or resource limit changes. The original 159-row intake and
its 12 honest matches, 57 symmetric exclusions and 88 handoffs (plus two main
fixes) retain their denominator. These extra merge-gate repairs are separate.

The paired comparison covers 12 complete files / 1,390 cases on checkpoint
b54452d8: MATCH 1,297 to 1,299, RED 90 to 88, BOTH 3 unchanged, no previously
passing case lost in any file. This includes Array, Proc, Iterator, Method,
Super, Refinement, Eval, Settracefunc and all 76 allocation comparisons;
those allocation cases remain enabled and retain their 76 existing REDs.

The final observer guard narrows the optimization to a sole named block
formal. Its O2 binary passes the actual original allocation test (four
assertions) and enumeration test (7.768 seconds, three assertions), the
to_ary-activated observer control, all 715 corpus programs in both hash-index
modes, all nine RSS controls and bracket depth 155/1024. The complete Module
contract is repeated on this final runtime: 195 tests / 1,240 assertions,
zero failures/errors/skips, outer 23.441 seconds / 365,632 KiB. The
12-file checkpoint observations are not relabeled as a final-runtime rerun.
The updated hosted CI, Linux Module memory gate and all-file comparison
against complete main remain required before merge. No bound is changed.

## 2026-11-19: compare the original Module RSS failure with current main

PR #90's Linux Module job completes 195 tests / 1,240 assertions with one
complemented-entry RSS failure: 77,672,448 to 186,966,016 bytes, 2.407109x.
Current main 3b05689f also fails that test in hosted CI, but by its unchanged
ten-second timeout (10.05 seconds), not a measured RSS assertion. Both use
compiler 01f5ad73 and the same pinned test. Preserve the distinct failure
modes; neither establishes the other's cause. The PR CI merge's runtime
sources equal head 949e4638. A failed job rerun is still rejected while its
containing workflow is unfinished.

Build main and the PR head independently with the actual CI compiler, then
measure sequentially under one common environment. On macOS both full files,
and the reference, give 195 tests / 1,240 assertions with no failure/error/skip
and identical case dictionaries. A parent-only observer of the original
selected case gives RSS ratios 1.668504x main / 1.668009x PR. The separate
comparison-tool validation gives 1.669211x / 1.672658x. All original 1,000
preparation and 300,000 workload iterations and the ten-second child bound
remain. Captured child programs agree except their original PID/time/hex
tokens. Raw inputs and logs are retained; canonicalization changes only
comparison hashes, and rejects malformed tokens or changed workload text.

No PR-specific worsening is demonstrated locally; Linux-specific behavior
is still unresolved. Add a separate Ubuntu job that builds both locked
sources before measuring the complete reference/main/PR files, then the
observed original selected case. Missing results, skips, failures, unequal
inputs or a ratio not strictly below 2.0 fail the comparison. Every file
retains 600 seconds / 2 GiB. The original Module gate and existing job
durations are unchanged. Details and reproduction are in
tools/module_rss_compare.md; the new Linux result is pending.

All twelve actual local executions complete, with the original complete-file
and selected-case coverage. The first tool-level result failed only because
the input-hash nonce parser omitted hexadecimal digits; preserve that result
and revalidate all saved raw inputs with the final parser. The corrected
parser does not change a runtime observation. YAML syntax passes; actual
bracket depth is 155/1024 with the pinned compiler. No interpreter or
GC/VM/AST/C API implementation, allocator policy, source lock or baseline
changed. No gem sweep or memory repair is claimed. Keep the hosted failures,
source/binary/log hashes and both controlled pairs in
gemtest/module_rss_pr90_r50.json. The separate Method-copy investigation is
not evidence for this test's cause.

## 2026-11-20: reject replaced case identities in the Module comparison

Review P2 correctly found that equal aggregate counts could hide a missing
original case and an extra replacement. Persist every parsed case dictionary
and compare main/PR with the reference separately for each mode. Record
missing/extra identities and differing verdicts; any difference rejects the
measurement even with unchanged COMPLETE state and summary counts.

Three CLI replay controls use captured successful reference transcripts,
real parsing and acceptance, with only source/build preflight and execution
as fixtures. The unchanged replay passes; replacing a case identity at equal
counts fails in both complete-file and selected-case modes. Both negative
controls reproduce the old CLI's erroneous acceptance. These are harness
controls, not new interpreter/resource measurements. Run them in the separate
comparison job before building. Also start the parent observer on a new line:
its old marker joined the unfinished progress line and polluted the parsed
selected-case name. Real reference/PR selected tests each retain one test /
three assertions and the exact original identity. Their child input matches
the original captured program except its upstream nonce.

The earlier Linux pair has completed. Independently reparse all six raw logs
and compare actual dictionaries before using its old collector's success.
All complete files give 195 tests / 1,240 assertions, no failures/errors/skips,
and identical case dictionaries. Observed selected RSS is 1.492139x main,
1.575806x PR, 1.227229x reference. Preserve the old marker-suffixed selected
labels in the historical record rather than rewriting the original logs.
This passing pair does not explain or waive earlier hosted failures.

Audit all 33 open PRs. The other owned branches have no unresolved review
threads, but failed resource assertions remain: Method-copy on #110/#119/
#131/#136 at 2.024243x / 2.213793x / 2.125194x / 2.084157x, and Module clone
RSS on #114/#118 at 2.105955x / 2.234604x. Do not assume clone RSS is noise.
The documented complemented-entry timeouts on #110/#136 were requested for
job rerun; GitHub rejects each with HTTP 403 while the workflow is unfinished.
Keep those retries pending. Other sessions' branches and PRs are untouched.
Full audit, actual Linux logs' hashes, preserved failures and replay evidence
are in gemtest/module_rss_review_r53.json. Workloads, limits, old snapshots,
source locks and interpreter/GC/VM/AST/C API implementations are unchanged.


## PR 90 merge gate: preserve the Pathname core before physical extensions

The preceding head's full hosted run was green but lost two Bundler binstub
cases: the physical Ruby 4.0 pathname.rb extends a core class, while the lazy
core entry pointed back to that same wrapper. Preserve the actual core body
separately as pathname_builtin; the existing autoload and Kernel.Pathname
factory load it, and the ordinary shipped pathname entry adds the extension
body afterwards. Physical pathname.rb files retain their precedence and can
extend the initialized class. The source bodies themselves are unchanged.

Normal O2 runtime1e94ce39, pinned compiler01f5ad73, restores the original
Bundler file from13 to15 MATCH. Full Pathname/Pathname Ractor/Require/Autoload
comparisons against completed main3b05689f retain every PASS: five files,
383 cases, both381 MATCH/2 BOTH/0 RED/0 EXTRA. Corpus746/747 cover the physical
wrapper and factory-first core/library phases. All28 focused hash/MRO-mode
comparisons and710/710 corpus programs with hash indexing ON/OFF pass. The
corpus uses462.840s and1,104,448KiB under the unchanged900s/2GiB bound. Nine
RSS cases, GC roots, dead/duplicate definitions and depth155/1024 pass.

The original offline five-gem62-file run retains48 MATCH/14 RED, no BOTH or
resource-limit event, zero baseline regressions, and62 physical-library audits
on each side. Core harness20 and load-path controls6 pass. The unchanged
30K-method bootstrap completes under the original60s child bound on main's
actual CI binary(34.657s), the prior PR CI binary(33.547s) and candidate
(33.721s), with a healthy reference. Retain the prior hosted Timeout; this is
not a VM speed change or a timeout waiver. New hosted CI, per-file comparison
and addressed P1/P2 findings are still required before merge. No test, helper,
limit, exclusion, collector, VM/ISeq, AST/Prism or C API change is used here.



### Rails command registration honors Ruby subclasses definitions (2026-11-19)

Rails::Command defines subclasses as a Ruby registry on its module. The
native Class#subclasses arm answered first, returning a fresh native array
instead of that registry. Ordinary module/class singleton definitions now
run with their real visibility and argument protocol. A module without a
Ruby definition no longer claims Class's native-only entry.

Saved native aliases, Methods/UnboundMethods and native super use the same
real direct-superclass relation with a zero-argument check. Ruby lookup and
Method#owner stop at Class's actual native entry before later definitions;
replacing Class#subclasses itself does not resurrect a hidden native super.
The fallback checks the actual current Ruby frame's remaining ancestor
chain and introduces no new global Mere values or Ruby API/inventory rows.
No collector, VM/ISeq, AST or C API implementation is changed. Shared
functions are listed in the PR; their other sessions' regions are retained.

On main 3b05689f with its pinned Mere 01f5ad73, normal O2: original Class
62 MATCH, Module 195, Method 97, Super 50 and Refinement 121 (527 cases:
525 MATCH / 1 RED / 1 BOTH). No focused file is below successful main
12ca1df2; Module's additional observation is not attributed to this patch.
Reference and mere-ruby each build their own unchanged -test-/class source.
The existing Method compaction skip remains visible. Corpus 706/706 matches
with indexing ON/OFF, including 717/718/720's native/override/alias/visibility/
super/owner-boundary controls. All nine RSS controls pass. Actual generated
C bracket depth is 155/1024 with main's newer compiler; that depth change
from older measurements is not a result of this dispatch correction.

A separate saved-gem diagnostic registers and finds the actual unchanged
Rails RakeCommand identically on both runtimes: reference 0.661 s / 26,736
KiB, candidate 1.575 s / 177,776 KiB, both exit 0 without a resource event.
It does not repeat dependency installation or establish a Rails app pass.
A fresh original-CLI paired run on validation-only source 5d1a0c95 with
unmerged #95 and bounded SHA-2 #120 installs all 68 gems (231.607 s /
946,832 KiB), then migration fails at the real ActiveSupport OrderedOptions
setter (3.238 s / 305,664 KiB). Reference passes all six stages. The three
following candidate stages remain NOT_RUN; no resource limit event occurs.
Hash subclass missing hooks (#123) remain a separate coordination item.
Generic stale alias origins after redefinition (#124) also reproduce on
unchanged main; no generic alias metadata repair is claimed here.

Review follow-up: share the remaining native-boundary query between actual
super, defined?(super), Method#super_method and UnboundMethod#super_method.
The zero-argument native Method also survives a later undef of its source.
Corpus 720 covers guarded super, native owner/binding, a preceding undef
and a Ruby replacement of Class itself. The same five original files retain
525 MATCH / 1 RED / 1 BOTH after this correction. No test is removed.

Hosted Linux run 44474019351 fails TestModule#test_module_clone_memory_leak
at RSS ratio 2.181378x (71,835,648 to 156,700,672 bytes). This is not an
established known-noise result; keep the failure, the 2x gate and the full
series. A single-job rerun request was rejected by GitHub (cannot be rerun).
The next source head must pass the unchanged gate before merge.


### Rails notification delegation: real private Module entries (issue #129)

ActiveModel extends its module with an `included` override that calls `super`.
The missing native ancestor entry previously sent that call to the module's
unrelated instance `method_missing`, failing on `respond_to_without_attributes?`.
Resolve the seven Module notification methods at their actual Module boundary.
Their native body accepts one argument, ignores the block and returns nil,
matching `rb_obj_dummy1` in Ruby's object.c. Ruby replacements and intervening
undef entries keep precedence; a native entry does not reappear below its owner.

The same remaining-chain query now serves dispatch, `defined?(super)` and
bound/unbound `super_method`. Native aliases and saved Method objects retain
their entry. The prelude marks these existing methods private; arity, parameters
and `respond_to?` reflect the actual native definition and Ruby visibility.
No API inventory, VM, collector, C API or resource limit changes are required.

Corpus 723 covers the ActiveModel-shaped failure, all seven entries, private
calls, arity, bound/unbound super, saved methods, alias/undef and owner replacement.
The original Class/Method/Module/Refinement/Super files retain 525 MATCH, 1 RED
and 1 BOTH across 527 cases, including 195/195 Module matches. Nine RSS checks
pass and generated C needs 155/1024 bracket levels. The complete corpus now matches
Ruby for 707/707 programs with the hash index ON and OFF. The separate fresh-home Rails
composition passes this boundary and reaches the next syntax blocker; it does
not establish that Rails boots or its application tests pass.


Saved native dispatch is covered by corpus 723. A separate pre-existing generic
limitation remains: after replacing an owner's entry with Ruby code, a saved
native Method/UnboundMethod can report the new definition's arity/parameters.
This also reproduces with Array#length on the parent and is distinct from the
stale alias-origin reproduction in issue #124. It is recorded separately and
does not establish another Rails boot blocker.


The fresh-home Rails replay with the independent runtime candidates now passes
this notification failure. Validation-only source b9056808 installs all 68
locked dependency gems in 210.753 seconds / 862,800 KiB. Migration proceeds
to unchanged ActionController source and exits 1 on an absolute-root dotted
extend argument (issue #134; 3.999 seconds / 318,752 KiB, no resource event).
Reference passes all six stages; mere boot/tests/HTTP remain NOT_RUN. The
record is retained separately in intake #117 as module_candidate.json, with
the same locks and 600-second / 2-GiB bounds. This is not an application pass.
The independent saved-native metadata limitation is issue #133, distinct
from issue #124's alias-origin reproduction.


### Notification Method review corrections

The two review reproductions exposed native-entry provenance and
visibility-only super boundaries. A native Method selected below a Module
prepend now records the proven native entry directly instead of asking
has_meth on its owner again; bound/unbound super methods and bindings retain
that entry and UnboundMethod records its selected owner explicitly. The
Method-specific query resumes above the actual body represented by a
visibility-only entry, while retaining an intervening visibility entry as
an observable Method owner. Native dispatch/defined-super traversal keeps
its existing semantics.

Corpus 724 covers published native methods, a wrapper before the visibility
owner, bound/unbound super below a Module prepend, and retained native calls
after undef. The reference outputs match with normal caches, hash indexing
disabled and MRO caching disabled. The five original core files again retain
525 MATCH, 1 RED and 1 BOTH across 527 cases, per-file unchanged.

The separate generic metadata gap #133 also reproduces when capturing a
native Method before prepending a wrapper: parameters and source_location
can follow that wrapper. This occurs on unchanged main as well. Native
invocation and selected owner are fixed here; captured-method metadata after
lookup mutations is not claimed fixed. The recorded b9056808 Rails replay
uses the preceding notification implementation c4477641 and remains tied to
that exact source; it is not relabeled as this reviewed implementation.


Final review candidate validation: all **708/708 corpus programs** match Ruby
with the hash index ON/OFF, including both notification witnesses. The five
original core files again retain 525 MATCH / 527 cases with no per-file drop;
all nine RSS checks pass and generated C needs 155/1024 bracket levels. Both
review reproductions also match with MRO caching disabled, including when
both the hash index and MRO cache are disabled together. The review correction
changes only the Method/UnboundMethod super arms of invoke_val_c0 and the two
new and-helpers module_notification_method_after/module_notification_method_mark.
Full hosted CI and its per-file comparison remain required before merge.

## 2026-11-19: SHA-2 checksums in real gem installation

The locked Rails intake (#117) gets beyond mkmf on the unmerged C API
candidate, then reaches the unchanged 600-second install bound before
Nokogiri is extracted. Its 4,387,328-byte archive exposes the interpreted
SHA-2 loop. The existing OpenSSL provider computes the same hash quickly.

Digest::SHA256/384/512 now use that internal provider when RubyGems or
another caller has already loaded it. Digest itself loads no extra library;
without the provider the original portable algorithm remains. Named
singleton methods and private portable aliases preserve Ractor use. The
provider's binary Array/Hash packing uses explicit empty separators so $,
cannot enter the request. Public OpenSSL::Digest overrides are not callbacks
for these standard Digest operations. No public API, API inventory, native
ABI, collector, VM/ISeq or dispatcher function changes, or new top-level
Mere values. lib/openssl_backend.rb and its generated embedding agree.

The original Digest files retain 80/80, 24/24 and 6/6 MATCH; OpenSSL Digest
retains 14/14 against successful main 12ca1df2. The full corpus is 704/704
with both hash modes. Witness 715 covers binary and block boundaries,
files, incremental/cloned/reset state, SHA2 selection, OFS, Ractors and
independence from public provider overrides; it was renamed byte-for-byte
from provisional 714 after an origin collision and rechecked in both modes.
All nine RSS cases and 15 existing provider lifetime/interruption checks
pass. Bracket depth remains 933/1024. A freshly emitted/assembled/optimized
Wasm module computes the twelve portable vector/clone results as the
reference, with the provider unavailable. That smoke uses the actual host
from the separate GC host-fix candidate (#112) for its already-declared
file-time imports; this change adds no imports or browser host code.

The final archive checksum plus RubyGems metadata probe matches reference
(hash, Nokogiri version and 182 files), completing in 3.492 s / 381,984 KiB.
A fresh own combination with #95 installs all 68 Rails dependencies in
284.529 s / 874,928 KiB under the original 600 s / 2 GiB bounds. This is an
unmerged candidate, not a main Rails pass: migration next stops when the
command registry's Ruby subclasses method loses to Class's native entry.
The standalone registry reproduction is separate from this library fix.


### Rails SHA-2 provider input bounds (review follow-up, 2026-11-19)

The first provider connection sent the complete SHA-2 input in one native
request. Review #120 found that inputs at the provider's 64-MiB wire bound
raise instead of hashing. Reproduced on the preceding O2 binary with a
67,108,867-byte binary input, without a memory or wall-limit event.

SHA256, SHA384 and SHA512 now update the same real native context with
1-MiB byte slices before finalization. The provider's own wire bound and
all test/resource limits are unchanged. Empty inputs and the existing
portable algorithms retain their behavior. No new top-level Mere value,
public API, dispatcher, collector, C API or provider ABI change.

The same input now matches Ruby 4.0.9 for all nine combinations of the
three algorithms and direct/incremental/file entry points, each in a
separate supervised process under 600 seconds / 2 GiB. Mere completes each
in 1.266–2.055 seconds; the largest observed family peak is 1,119,600 KiB.
The reusable actual-input probe is unittest/digest_provider_large.rb;
arguments are algorithm bits (256/384/512) and entry point
(direct/incremental/file). Compare its complete output with the reference.
Witness 716 covers binary bytes crossing the bounded update boundary.

Original Digest/OpenSSL Digest retain all 124 MATCH. The full corpus is
705/705 with indexing ON and OFF. All nine RSS cases, fifteen existing
provider lifetime/interruption/worker controls and the actual bracket
check (933/1024) pass again. The real Nokogiri checksum/metadata probe
still matches both hash and 182 files (4.715 seconds / 352,544 KiB).

The earlier 68-gem installation observation remains tied to experimental
composition 153e64f5 before this review fix. No new full Rails workload
pass is inferred. #121 still owns the independent command registry
boundary, and migration/boot/tests/HTTP require their original CLI replay.

## 2026-11-19: Rails application intake, rounds 1–2

Round 1 fixes Rails 8.1.4.1, sqlite3 2.10.2, Puma 8.1.2, Minitest 6.1.0
and Bundler 4.0.20 in `railstest/`: all 69 Ruby-platform source archives
have hashes and a frozen Bundler lock. Reference Ruby 4.0.9 runs a real
small app: migration, boot, six tests / 31 assertions, and a local Puma
HTTP request. SQLite uses its documented system-library build option;
the first reference library was SQLite 3.46.1. No Ruby version requirement
is bypassed, upstream gem source changed, or native extension shared.

Round 2 adds repeatable measurement in fresh gem homes, separate stdout,
stderr and resource records, and six explicit stages. Reference standard
libraries are a fallback after activated gems. The boot source audit checks
every locked gem's version and installed path. Missing dependent stages are
NOT_RUN; missing/skipped tests, lower assertion counts and limit events
cannot pass. Five harness controls run in an independent lightweight CI
workflow; they do not imply that Rails executes successfully on mere-ruby.

Main 12ca1df2 stops installing bigdecimal before its C extension builds:
RbConfig has no rubyhdrdir, and loading mkmf raises nil-plus NoMethodError.
A two-require probe reproduces it without Rails; issue #116 hands the
actual build metadata/mkmf boundary to the existing #95 work. No runtime
function, API inventory, collector, VM, AST, C API or gemtest file changes
here. There is no claimed Rails framework-suite pass or application MATCH
on mere-ruby. The fixed 600-second / 2-GiB bounds remain. The next action
is the same locked workload after native installation becomes available,
then original Rails component tests.


### Rails intake round 3: isolate reference discovery (PR #117 review P2)

The first metadata subprocess queried the reference before the child-stage
environment was cleaned. Inherited RUBYOPT could load a foreign file or
Bundler with an unrelated Gemfile and abort before any measurement record.
`clean_environment` now supplies the same isolation to discovery and stages,
without depending on a standard-library directory that discovery has not
read yet. No runtime function or dependency lock changes.

The new command-entry control launches the actual measurement with
-rforeign and with -rbundler/setup plus an incompatible external Gemfile.
Both fail at discovery on the preceding version; both now reach the intended
invalid-archive fixture and retain REFERENCE_UNAVAILABLE/exit 2 rather than
an unrecorded startup error/exit 1. All six harness controls pass. The small
harness workflow selects Ruby 4.0.9 to execute that real subprocess control.
The original main Rails measurement remains a historical snapshot.


### Rails intake round 3 candidate result: mkmf passes, archive processing reaches 600 s

A fresh own build of unmerged #95 head 54184e4e passes the standalone mkmf
probe and builds bigdecimal, json, prism and racc during the same locked
install. All six reference stages pass. Mere then hits WALL_LIMIT at
600.910 s, exit -9, family peak 750,928 KiB; migration/boot/tests/HTTP stay
NOT_RUN. `railstest/capi_candidate.json` keeps this separate from main.
No time or memory bound is increased and no resource failure becomes PASS.

The next archive, Nokogiri 1.19.7, has not been extracted yet. A checksum
probe identifies the Ruby SHA-2 implementation as a bottleneck; the actual
OpenSSL provider returns the same hash quickly. The package probe now
requires RubyGems explicitly as well as rubygems/package, so its metadata
read has the real runtime loaded. Any native-provider acceleration is a
separate library change; this PR still changes no runtime function.


### Rails intake: all frozen dependencies install on the provider composition

Provider composition 153e64f5 (unmerged #95 and #120's library code)
installs all 68 gems in a fresh own home at 284.529 s / 874,928 KiB, with no
limit event. Reference installation is 169.866 s / 1,724,144 KiB, and its
six stages pass. The same 600 s / 2 GiB bounds and 69 archive checksums
remain. This is a distinct candidate result, not a main compatibility pass.

The next actual migration exits 1 in 2.070 s / 198,064 KiB before the DB
is migrated. Rails::Command's Ruby subclasses registry stays empty while
its class names and namespace are correct. The five-line module registry
probe reproduces the native Class#subclasses precedence error on main too;
method owner reflection already reports the real Ruby definition. Issue
#121 hands this invoke_val_c0 coordination item to the shared dispatch
work. No framework code is patched and no registry is externally filled.
The three remaining app stages stay NOT_RUN in provider_candidate.json.


### Rails direct-load diagnostic and Hash subclass missing hooks (2026-11-19)

While the original CLI is blocked at #121, fresh copies of the same app
fixture were loaded directly using each interpreter's own saved installed
gems. This diagnostic is explicitly separate from the cold paired stages:
reference runs script/boot.rb successfully (including all source audits)
in 3.918 s / 103,296 KiB; the unmerged provider composition 153e64f5 exits 1
in 5.261 s / 256,368 KiB at ActiveSupport's railties_load_path= assignment.
Neither process has a resource event; bounds remain 600 s / 2 GiB.

A healthy-reference OrderedOptions-only probe confirms that construction
and the reported method_missing owner are correct, then shows mere-ruby
bypassing the dynamic setter. A gem-free Hash subclass with its own Ruby
method_missing reproduces this on unmodified main and an existing gem
candidate. The primitive missing-hook path belongs to that session; #123
records the handoff. No shared dispatcher or Rails source is patched.
The distinct load_diagnostics.json and two small probes preserve this
observation without replacing original CLI FAIL/NOT_RUN stage records.


### Original Rails CLI passes command registration and reaches Hash hooks

Cold paired source 5d1a0c95 combines unmerged C API, bounded SHA-2 and #125.
The unchanged reference passes every original stage. Mere installs all 68
gems in 231.607 s / 946,832 KiB, then the real migration CLI reaches Rake
and application loading. Its next exit-1 failure is the independently
reduced Hash missing-hook assignment (#123), 3.238 s / 305,664 KiB. There
is no resource event. The original bounds and inputs remain; three later
stages stay NOT_RUN. class_candidate.json is separate from main, C API-only,
provider-only and independent-load records. This is no Rails app PASS.


## Native-build children and the declared reference fallback

The validation-only Class/Hash/gem composition a9c8a2ff has a separate cold
record in load_path_candidate.json. Reference passes all six stages, but
Mere dependency installation stops at bigdecimal (33.243 s / 620,816 KiB,
exit 5, no resource event): RubyGems' unchanged native builder passes its
reference source directory through -I, so monitor.rb asks for monitor.so.
The four application stages remain NOT_RUN. This failed run is preserved;
the Hash hook is not reached in it.

The intake bootstrap now moves only its explicitly declared reference
fallback behind the interpreter's own libraries, including when inherited
through a child's -I. RUBYOPT defers automatic RubyGems startup until the
bootstrap restores that order, then requires unchanged RubyGems on both
interpreters. Otherwise RubyGems can load monitor before any -r bootstrap.
The reference's own stdlib order and all other explicit source directories
remain unchanged. No require implementation, RubyGems/Rails/gem source,
RbConfig value or API inventory changes. This
is the intake counterpart of #90's mspec/corpus fallback-ordering repair;
it does not change that PR or globally suppress physical library overrides.

A real child-CLI control first fails on a foreign monitor wrapper, then
loads the runtime's monitor after the bootstrap. Another explicit source
still wins over the fallback, and reference-own path order is identical.
The original archives/app/limits and historical JSON files are unchanged.
The workload must be replayed cold with this bootstrap before claiming
any later stage passes.


## Hash candidate reaches the locked JSON generator

hash_candidate.json is the fresh original-CLI replay on validation-only
source 0b76e819, with C API #95, bounded SHA-2 #120, reviewed Class #125,
Hash #126 and the intake child-startup correction. The runtime binary is
unchanged from a9c8a2ff; only the measured startup inputs changed. Its full
735-file corpus matches with indexing ON and OFF. The same frozen archives,
fresh gem homes/native builds and 600-second / 2-GiB bounds remain.

Reference passes all six stages, including six tests / 31 assertions and
real Puma HTTP. Mere installs all 68 dependencies in 201.059 seconds /
948,608 KiB, then the original migration CLI passes the Hash configuration
and fails on JSON::Ext::Generator::State.default_sort_keys_proc= (2.273 s /
268,896 KiB, exit 1, no resource event). Boot/tests/HTTP remain NOT_RUN.
The earlier main, C API, provider, Class and load-path records are unchanged.

The actual JSON 3.1.0 Ruby facade loads, but shipped parser/generator source
is selected despite the activated gem's independently built native files
earlier on the load path. probes/json_generator.rb is a gem-only ordinary
require reproduction. Issue #127 tracks native feature selection; no JSON
attribute, source patch or forced older gem conceals it. Explicitly loading
the own native libraries after the failed facade is a separate diagnostic
whose sorting/parsing output matches; it is not used by the original run.
Full Rails component suites remain unmeasured, and no Rails app pass is claimed.


## Native-selection candidate reaches Module's included super

native_candidate.json preserves the next fresh original-CLI paired run on
validation-only source 61d01f6d, including native selection #128. Each runtime
again installs from the same lock into an empty home and builds its own
extensions. All six reference stages pass, including six tests / 31 assertions
and real Puma HTTP. Mere installs all 68 dependencies in 232.699 seconds /
954,624 KiB and passes the previous registry, Hash and JSON boundaries.

Migration then exits 1 in 4.097 seconds / 318,224 KiB at ActiveModel's
respond_to_without_attributes? on its AttributeMethods module. Boot/tests/
HTTP remain NOT_RUN; there is no resource event. The original app, lock and
600-second / 2-GiB bounds are unchanged, and earlier records are retained.

An independent TracePoint diagnostic identifies the original missing call
as included. probes/module_native_hook.rb reduces it without gems: a Ruby
included override's super misses Module's native default and calls an
unrelated instance method_missing on the module itself. Reference returns
the real nil result. The same failure occurs on the Hash parent, so it is
not claimed as introduced by the native-file correction. Issue #129 hands
this ordinary native-super/notification boundary to the generic dispatch
work. No Rails alias or notification return is fabricated to conceal it.

The preceding JSON probe now matches using normal require, with no native
preload workaround. Original require/autoload/Marshal counts and all 733
native-branch corpus files match their stated comparisons; existing C API
contracts hold normally/under stress and all six fault controls fail. These
do not establish a Rails application or framework-suite pass.


## Module notification candidate reaches ActionController syntax

module_candidate.json preserves the fresh paired replay on validation-only
source b9056808, including notification correction #132 and the synchronized
native-selection parent. Both sides use the original 69 locked source
archives, initially empty homes and independently built native extensions.
All six reference stages pass, including six tests / 31 assertions and real
Puma HTTP. Mere installs all 68 dependencies in 210.753 seconds / 862,800 KiB.

The original migration CLI passes the preceding Module included failure and
then exits 1 in 3.999 seconds / 318,752 KiB at unchanged ActionController
source: extend ::AbstractController::Railties::RoutesHelpers.with(app.routes).
The parser reports expected end of statement. Boot/tests/HTTP remain NOT_RUN;
there is no resource event. Earlier records, app sources, lock and 600-second /
2-GiB bounds are unchanged; all 18 new stdout/stderr hashes were verified.

probes/absolute_extend.rb reduces the absolute-root factory argument without
gems and checks lexical anchoring. Even the single original extend statement
fails syntax checking on unchanged main and this composition, while Ruby
accepts it. The bare absolute constant, adjacent keyword command and property
assignment controls parse on both. Issue #134 records parse_stmt_id's special
extend branch consuming only the scoped constant and leaving the dotted
call unparsed. No Rails source patch or changed grammar input conceals it.

The independent #132 notification branch completes 707/707 corpus programs
with indexing ON/OFF and preserves all five core files (525 MATCH / 527 cases).
The synchronized #128 branch separately completes 734/734 programs. Neither
is a full-corpus claim for this combined b9056808 composition. A separate
pre-existing saved native Method metadata gap is tracked in issue #133; its
Array#length control fails on the parent and is not an actual Rails blocker.
Rails application and framework-suite success remain unestablished.
## 2026-11-18 (83): the VM's own steps -- an Integer operator on locals in one step, and a frame's body without two turns of marks

**The point.** After (81) the VM was 1.13x the evaluator on fib and 1.16x on
a block that adds to a local. Profiled side by side, the call machinery the
two share cost the same; the VM's own instructions -- vm_step, the stack's
pushes and their copies into its arena, vm_run_stmt, vm_loop, vm_exec -- were
about 300 samples where the evaluator's walk of the same expressions was
about 130. Four things cut it:

- **three instructions in one step.** A getlocal, then a getlocal or an
  Integer putobject, then a plain Integer operator (`n < 2`, `n - 1`, `s + x`)
  is marked when the program is loaded (vm_fuse_mark, in the getlocal's ib,
  which a getlocal does not use) when nothing jumps to the second or the
  third and no event is on them. vm_step answers the three at once when both
  values are Integers, no TracePoint wants the call and no Integer operator
  is redefined -- the conditions of its own Integer path -- and otherwise
  runs the getlocal as itself. A branchif / branchunless after them is taken
  in the same step without pushing the answer (`n < 2 ?`, `while i < n`), and
  so is a setlocal, with or without a dup before it (`s += x`).
- **the operand read without a closure.** The first version read the two
  operands through a closure made at every step: a tenth of the step.
  vm_fz_rd is a function of its own.
- **a frame's body of marks.** A method's, a class body's and a block's body
  on the VM is three statements -- its line, its file, the program -- and
  run_stmts_result gave each a turn (the statement's bookkeeping, another
  thread's turn, a signal). Those three in that shape are now one turn
  (vm_body_run), with fb_wm_stmt and the polls the program's statement had.
- **vm_exec's closures.** Five closures were made for each frame (the run,
  the copy-out, the giving back, the try's two); the run and the giving back
  are functions now (vm_exec_run, vm_pool_give), the copy-out written in.

Corpus 693 is the witness: fib, past a Fixnum into a Bignum, a Float, a
String and nil where an Integer would be, while / until / a ternary on a
comparison, a block's `+=` of a local one and two frames out as a value and
as a statement, an optional parameter read before its default ran, a
TracePoint's c_call on `+`, a refinement of Integer#-, and Integer#+
redefined part-way through -- the same on ruby 4.0.9, the evaluator and the
VM.

Measured (local, the least of 7 runs each, interleaved): fib(24) on the VM
0.189 s -> 0.174 s (the evaluator 0.165, 1.05x); `(1..200_000).to_a.each { |x|
s += x }` 0.169 -> 0.156 (0.148, 1.05x); 200,000 calls of a two-argument
method in a while loop 0.532 -> 0.493 (0.566, 0.87x). Over 2,000,000 elements
three times the block is 1.025x (6.62 s against 6.46). What is left on fib
and the block is the frame's entry (the pool slot, the 16 registers cleared,
try_or) and the per-instruction stack, which a call still pays once each.

Checked (local): corpus 704 / 704 on the evaluator; under MERE_RUBY_VM=1 694
on the VM, 10 fallen back, 0 different; vm_check 245 / 245; gates; the Module
check COMPLETE. Under MERE_RUBY_VM=1, the previous build against this one:
test_optimization, test_proc, test_iterator, test_method, test_integer,
test_fixnum, test_range, test_array, test_hash and test_enumerator the same
counts. The bracket depth needed went 923 -> 933 (BRACKET_SEED; 91 to spare
under 1024).

Then two more, each within the noise alone and kept for what they remove:
vm_send's statement, Symbol-name and Symbol-test closures are functions of
their own (vm_stmt_v, vm_syms, vm_all_syms), and the waiting for a tail call
-- and the closure it is handed -- only once a send marked for one is loaded;
and a frame's first statement no longer marks its allocations' start nor
polls again, which the frame's entry did (vm_body_run, or the statement
around a `once`). Where the VM is still behind is a call of a VM method from
a VM method: 20 levels of recursion 50,000 times took 1.27 s on the VM and
1.18 s on the evaluator, while a call from a loop is faster on the VM (a
one-line method 1,000,000 times: 1.20 s against 1.35) and a loop of its own
is 0.43x (3,000,000 turns: 0.68 s against 1.57). Each such call passes a
dozen layers between call_method and vm_step that the evaluator's call does
not; taking them away is a call path of the VM's own, not a step.

## 2026-11-18 (84): ruby's benchmarks on both executions, and what the VM built for every operator it did not know

**The point.** Three small programs were not the measure. Ruby's own
benchmark/app_* and so_* (27 that finish in 120 s; 4 do on neither) took the
VM 1.184x the evaluator's time in all; after this round 0.940x. Every
program's output is the same on both.

What the VM paid that the evaluator did not, found by profiling the slowest:

- **an operator on anything but two Integers.** `zr * zr`, `s << t` and
  `x + 2.0` were made into the evaluator's EBin over hidden locals bound in a
  scope from the pool, then evaluated: a scope taken and given back, a try,
  two writes, three nodes, a walk. Two Floats -- or a Float and an Integer
  under + - * / -- are answered as arith_bin and Float's comparisons answer
  them (flt_fast_op), and two Strings under `<<` as EBin's `<<` arm appends
  (vm_str_append: the chilled warning, the FrozenError, the encodings
  negotiated). Not while a hook is set, a refinement is in effect, or the
  operator is undefined, aliased or the class's own.
  - The first version asked whether ANY method was undefined anywhere and
    stepped aside if so -- and one is, from start-up: it never ran. EBin
    asks by the operator's name (undef_names), and so does this now.
  - A comparison of a Float with an Integer is not here: ruby makes it
    exactly (flt_cmp_exact_needed), and the general path does.
- **a call on a receiver** (`o.m(1)`, `Toggle.new 1`) went through the same
  scope to reach emethod_args, which takes the values as they are. A call
  that vm_call_in would hand there goes there directly.
- **an ivar read** made an EIVar for eval_e to read; it is read as that arm
  reads it while no hook is set (vm_ivar_get). **A local of a frame further
  out** was looked up in the frame's own env twice before the chain.

Measured, the least of 3 runs each (local, other sessions building):
so_partial_sums 1.59x -> 0.56x, so_nbody 1.24x -> 0.60x, so_mandelbrot
1.82x -> 0.68x, so_random 1.41x -> 0.78x, so_concatenate 1.38x -> 1.03x,
so_spectralnorm 1.42x -> 0.93x; a Float loop of a million turns 4.0 s ->
0.74 s (the evaluator 2.62). Still behind: app_raise 1.72x and so_exception
1.18x (an exception), so_object 1.49x (`new` and `super`), so_nsieve_bits
1.25x, app_mandelbrot 1.16x (Complex), so_pidigits 1.10x (Bignums).

**The VM as the default (a measuring branch, CI run 44252180092)** stopped
before the test shards on two things, both fixed here:

- an embedded program (tools/native_probe/embedding_stress_check.py)
  allocated 16 bytes more in the default region with every evaluation --
  36.1 MB to 37.7 MB over 100,000 -- where the evaluator stays flat. Found by
  counting the default region's allocations by caller in the embedding's
  emitted C (a table keyed by two return addresses, dumped at exit; 1,000
  against 10,000 evaluations): one site, mere_map_str_str_set from
  run_src_mode. Each run wrote MERE_RUBY_VM into cli_opt again, and a map's
  write copies the value into its arena. It is written when it changes. (The
  lib-instance build has no --region-sites: heap containers there go to the
  current region, codegen_c's lib_mode.)
- corpus 388 differed on Linux: `require(x)` as a call converted the path
  for the OS and handed the statement a UTF-8 literal of it, so the
  statement's own conversion recorded UTF-8 as the path's encoding. macOS
  converts the name and keeps a record of the original (os_conv_orig), which
  hid it; Linux takes the bytes as they are. The VM always calls `require`,
  and the evaluator did the same inside a method (`def via(x) =
  require(x)`). A String is handed to the statement as itself. Reproduced and
  checked in docker (ruby 4.0.9, clang, the same mr.c built with
  `tools/build.sh --cc-only`). `require_relative(x)` from a method with a
  non-UTF-8 name still differs, on the evaluator as well: its path is built
  as UTF-8 text by __builtin_relpath. Not this round's.

Corpus 694 (Floats with NaN, Infinity, -0.0 and Integers; a refinement and a
redefinition of the operator; ivars and a class variable; calls on a
receiver with method_missing, private and protected; `$~` in the frame; `<<`
on a frozen String, encodings that cannot meet, a subclass's own `<<`) and
695 (require as a call, three encodings, #to_path asked once, TypeError):
the same on ruby 4.0.9, the evaluator and the VM, 695 on Linux too.

Checked (local): corpus 706 / 706; under MERE_RUBY_VM=1 696 on the VM, 10
fallen back, 0 different; vm_check 245 / 245; gates; the Module check
COMPLETE; the embedding stress check passes under the VM (36,080,600 bytes at
1,000, 10,000 and 100,000). Bracket depth 934 (BRACKET_SEED). The corpus's
fallbacks are unchanged: 6 a Regexp in another encoding -- allowing those
moves 3 programs to the VM and makes 462 wrong, a `/#{...}/` the compilers
fold into a Regexp fixed to UTF-8 in a US-ASCII source -- 3 sources in other
encodings and 1 the compiler's refusal.

## 2026-11-19 (85): an exception no clause can see, a constructor of stores, and super with values

**The point.** After (84) the slowest of ruby's benchmarks on the VM were
app_raise (1.72x the evaluator), so_object (1.49x) and so_exception (1.18x).
Each was a shortcut the evaluator takes and the VM did not.

- **A rescue that only matches.** run_rescues makes the exception an object
  with its own frames (exc_pin_bt) only when the clause binds it to a name;
  the VM made one -- an object id and three ivars -- for every exception any
  clause took. A rescue sequence made of nothing but its local read,
  constants and literals pushed, checkmatch, branches, nil, a pop, a leave
  or a throw (vm_rescue_only_matches) cannot keep or show the exception, and
  leaves it the pair, `$!` included, as the evaluator does.
- **`$!` after a retry** (both executions, found writing the witness): a
  retry ran the construct again by calling run_begin_f again, which took
  the exception in `$!` as "what $! was before" and restored that once the
  construct was done. `begin; raise if t < 2; rescue; retry; end; p $!` was
  the exception; ruby's nil. The construct is run again from the $! it
  started with.
- **A method of stores.** The evaluator runs a method whose body is only
  `@x = param` statements without a frame (triv_store_body); a VM method's
  body is its program, which that never matched. A program of `getlocal p,
  (dup,) setinstancevariable @x` for each parameter and a leave is run the
  same way (vm_triv_store_ok / _run), under the same conditions (a plain
  object, no block, no TracePoint, Coverage or Ractor, the arguments plain).
- **super with values.** `super(a, b)` was an ESuper over hidden locals in a
  scope, evaluated. ESuper's arm is now two halves: the arguments, and what
  is done with them (super_vals) -- the method after the definer along the
  receiver's ancestors, a singleton's extended modules, Class#new, a hook's
  no-op, "no superclass method". The VM calls the second with its values
  when there is no block written or passed, no splat or keywords, and no
  hook (vm_super_direct, with the arm's refusals).

Corpus 696 (a rescue that only matches, a bound one and `$!`, a bare raise,
retry, `$!` in an ensure, a class's own ===), 697 (stores of one and three
parameters, arity errors, `_`, a class variable, a literal, a frozen
receiver, keywords and a splat) and 698 (super with values, a bare super
after a parameter changed, a module's, `def self.new`, a hook, nothing
above, another object's instance_eval, define_method's bare super, a
singleton's extended module): the same on ruby 4.0.9, the evaluator and the
VM.

Measured, ruby's app_* / so_* (27; least of 3 runs, local): the whole 0.940x
-> 0.927x the evaluator; app_raise 1.72x -> 1.06x, so_exception 1.18x ->
1.07x, so_object 1.49x -> 1.10x. Still behind: so_nsieve_bits 1.25x,
app_mandelbrot 1.15x (Complex), so_object 1.10x, so_pidigits 1.09x
(Bignums), so_lists 1.07x.

Checked (local): corpus 709 / 709; under MERE_RUBY_VM=1 699 on the VM, 10
fallen back, 0 different; vm_check 245 / 245; gates; the Module check
COMPLETE; under both executions, the previous build against this one:
test_exception, test_rubyoptions, test_flip, test_super, test_method,
test_object, test_class the same counts.

## 2026-11-19 (86): test_complemented_method_entry_memory_leak -- what a collection costs, and why the floor stays

**The point.** The test has timed out at 10.03-10.04 s on slow runners
(main's CI, PR #95's, the VM-default measuring branch's). Measured here, on
its own program (the test's block, 100,000 turns after 1,000):

- It is linear: 50,000 / 100,000 / 200,000 turns take 0.97 / 1.82 / 3.52 s,
  about 18 µs a turn (ruby 5.7). Nothing grows per collection.
- Of the time, collecting is 36%; the rest is making the classes and the
  refinement, spread over the native declaration paths with no function
  above a few percent. A collection is about 9 ms: the class tables' sweep
  is near half (68 tables walked, each key's owner read from its text; a
  turn leaves 21 rows -- methods 3 x 4 tables, modules 2, supers 2, the
  refinement's 3, privates, mro_external), the stack's native candidates
  about a third, the fixpoint the rest.
- The native candidates were 42,000 a collection, most of them the same
  `Class#name` key from meths_g, meth_src, meth_cref and meth_cvcls; they
  are taken once now (30,000). The time did not move outside the noise.
- The class-time floor (knob 14, 4,000 entries) is load-bearing for this
  very test: at 8,000 its RSS ratio was 2.18 and at 16,000 2.50, against
  the bound of 2.0, and the time did not fall (1.74-1.98 s against 1.75-1.82
  for 100,000 turns). It stays.

What is left would be structure: rows a class keeps a record of, so the
sweep need not read every key's text, or fewer rows a refinement. Until
then the test stays in Known noise (rerun the job).

## 2026-11-19 (87): the VM as the default, measured over the whole suite

**The point.** The measuring branch vm-default-r44 (#104's stage10-r44 with
the VM as the default execution, MERE_RUBY_VM=0 the evaluator; not for
merging) ran the whole CI: run 44295654770. Every job but build-linux
passed, and the CRuby tests' MATCH is 33,312 against main's 33,313 over the
same 758 files. Four files are a test lower, three a test higher:

- ruby/test_keyword.rb's test_kwrest_overwritten: a bare super after `**h`
  was reassigned is "wrong argument type Array (expected Hash)" -- fixed in
  this branch (core#hash_merge_ptr's Check_Type, corpus 699).
- ruby/test_ractor.rb: test_move_nested_hash_during_gc_with_yjit's
  timeout, Known noise.
- ruby/test_iseq.rb's test_parent_iseq_mark and ruby/test_thread.rb's
  test_thread_join_during_finalizers: timeouts, and the VM is slower at
  both. Locally, with the compiler #108 pinned (01f5ad73): 9.65 s on the
  evaluator and 13.12 s on the VM (bound 20 s), and 23.2 s and 44.9 s (bound
  60 s); with the compiler before it, 9.76 / 13.16 and 30.2 / 57.7. The
  second's program alone, outside the test, is faster on the VM (23.6 s
  against 29.4 s, 5,627 collections against 8,768): what the test adds runs
  under GC.stress with 20 popen3 wait threads parked, and the child spends
  nearly all its time collecting -- three quarters of that in gc_mark_roots,
  where the suspended stacks are read (coro_scan_ints, and the pin gather
  the recycles at its start ask for). Why the VM's parked stacks cost twice
  the evaluator's is the next question: the C frames a Ruby call stacks are
  of the same size on both (vm_step 960 bytes, eval_e 2,080).
- build-linux: the Module check's test_complemented_method_entry_memory_leak
  at 10.03 s, Known noise (LOOP (86)).

So the VM as the default passes what the evaluator passes, in the whole
suite, but for those two timeouts under GC.stress with threads parked.

### Preserve exceptions exposed by a custom rescue matcher

PR #144 review: checkmatch can invoke Ruby === even when the rescue body
binds no variable. Pin such an exception before exposing it, update the
handler's hidden exception local and $!, and propagate the same object when
all clauses reject it. Builtin-only matching retains the allocation-free
path. run_rescues needs the same protection in evaluator mode. TracePoint
observers conservatively receive a pinned exception too. Functions changed:
vm_checkmatch, vm_region, run_rescues; no new top-level state or collector edit.
Corpus 696 covers retained backtraces across a subsequent raise, $! identity,
multiple matcher clauses, splat matchers and outer propagation. Corpus
696-699 matches in all four cache modes on both evaluator and strict VM
(32 comparisons). Full integrated validation is still pending.

The final parent-integrated AST runtime b4bbb8d9 also passes all 708 corpus
programs in both hash modes (468.071 seconds, 1,174,736 KiB, unchanged
900-second/2-GiB bounds), the nine RSS workloads and root/depth/dead gates.
Corpus 700 still matches in four independent cache configurations after
this integration. No exclusion, budget or expected output was changed.


### AST parameter default source order (2026-11-21)

A follow-up control found that registering explicit block locals before
parameter defaults changed a ghost-capture name from VCALL to DVAR in
`foo { |z=y; y| y }` and its keyword-default form. Registration now happens
after translating parameters and before translating the body, in both
blocks and lambdas. Corpus 700 adds the two regressions and a destructured
post-parameter control. Standalone O2 comparisons pass all three; all 869
Ruby test ASTs and the same 971/976 Prism fixtures remain unchanged.
The earlier complete 708-program validation applies before this follow-up;
its updated public-API witness and hosted full suite are validated separately.
Functions changed in this follow-up: tr_block_scope and tr_lambda.

### AST parameter defaults before block-local declarations

Register explicit block-local declarations after parameter default expressions
and before the body in tr_block_scope and tr_lambda. Three additional corpus
700 sources cover optional and keyword defaults and a destructured parameter.
All three location comparisons pass; the full current source sweep remains
869/869 Ruby files and 971/976 Prism fixtures with the same five reference
NoMethodError cases. All 13 original review reproductions and the full public
corpus 700 in four hash/MRO modes pass on the rebuilt O2 runtime. The earlier
708-program corpus result predates this follow-up; hosted full checks remain
required for the final revision.

### AST for-target registration is idempotent at its source position

The early for-target registration is replayed during AST construction. gh_add
now deduplicates kind-2 and kind-4 records with the same scope serial, name
and source offset. Reads still use their original strict-before ordering,
and targets remain registered before the collection is translated.
Corpus 700 adds four block/lambda/destructuring and collection-read cases.
All four fail before the repair and match Ruby 4.0.9, including locations,
after it. All 869 Ruby test files and 971/976 Prism fixtures remain unchanged
(the same five reference children errors); all 13 earlier review reproductions
and the rebuilt public corpus 700 API in four cache modes pass. Roots and
bracket depth 155 pass. The earlier full-corpus observation predates this
follow-up; full hosted checks and every-file comparison still gate merge.

### Stage 9 consolidation after main's VM update (2026-11-20)

Merge main d9826ac9 into the existing consolidation branch. Only concurrent
LOOP.md appendices conflict; retain both. The runtime/driver merge is automatic,
with no manual VM, collector or state edits. Normal O2 with the pinned Mere
01f5ad73 passes **718/718 corpus files**, hash index ON and OFF, the 12 observer
witness/cache combinations, all nine original RSS checks, dead definitions and
C nesting **155/1024**. No resource bound or original test was changed.

The paired 10-file checkpoint against this main discovers **559 cases**:
main446 MATCH/102 RED/7 BOTH/4 EXTRA, candidate459/89/6/5. No original PASS
identity or file MATCH is lost. Module remains195 MATCH with all1,240 assertions;
Enum89 and ObjectSpace37 are unchanged; GC29->30, string-memory0->2 and
objspace28->38. All76 allocation comparisons remain enabled and RED for the
existing VM handoff. The same57 excluded identities apply to both sides
(GC19, compact22, objspace16); the per-file exclusion sidecars retain each
reason. These local observations do not replace full hosted CI or its
per-file comparison against a completed main run. Previous hosted RSS failures
remain historical evidence, not waived gates for this new head.


### Pathname follow-up: retain an internal core identity and ordinary user files

A same-named user file exposed a further load-order gap in the split-core
entry. Anchor the existing autoload under the runtime's initialized internal
stdlib directory as <internal:pathname_builtin>; the factory reads the root
constant to trigger it. Ordinary pathname.rb and pathname_builtin.rb files
retain physical load-path selection. Corpus748 checks both the actual core
operations and the canonical physical loaded feature. It introduces no
synthetic metadata, hidden library result or new top-level Mere value.

Final O2 runtimeee50b4d8 includes maind9826ac9 and passes714/714 corpus in both
hash modes,32 focused hash/MRO comparisons, RSS9, roots, dead/duplicate defs
and depth155/1024. Corpus462.885s/1169328KiB stays inside900s/2GiB. Original
five-file383-case comparison retains381 MATCH/2 BOTH with no lost PASS or
file decrease. Original five-gem62-file run retains48 MATCH/14 RED, no
resource-limit event or baseline regression, and62 physical audits per side.
The final original30K-method bootstrap passes in34.535s/1190464KiB with the
same60s child/600s file/2GiB bounds; source-generation parity, six load-path
and twenty core-harness controls also pass.

The intermediate head27e78973's hosted Linux Module test instead records
clone RSS72159232 to151474176 bytes(2.0991655787x):195 tests,1240 assertions,
one failure, no outer-limit event. Preserve this distinct failure; it is not
waived as complemented-entry noise or replaced by a local pass. The final
head's complete hosted result and every-file comparison remain merge gates.


## 2026-11-21: use the released cache-clearing compiler for original Module comparisons

The locked PR 90 source fails the original clone RSS assertion under compiler
01f5ad73 even though its separately selected complemented-entry case passes.
The collector correctly records the failed full-file case. Keep that hosted
failure and its exact case dictionary; do not change acceptance or the input.

Use released compiler 43f2994b for core CI and both locked comparison sources
3b05689f / 949e4638. Ruby source, all 195 tests and 1240 assertions, observed
child input, its ten-second timeout and every 600-second / 2-GiB family bound
remain fixed. Reversing only inactive cached-payload clearing in each emitted
C restores its old-compiler C byte for byte. No Ruby runtime function changes.

On local Linux/aarch64, all six original comparison conditions pass: full
Module on reference/main/PR90 and their selected original complemented-entry
cases. Selected ratios are 1.232550 / 1.278365 / 1.288751 and the canonical
child inputs match the previous hosted observation. On macOS, the current
application passes Module 195/1240, Refinement 122/367 with the shared skip,
and the original Method-copy control at 1.830389x. Preserve the distinct
source and architecture provenance. Full corpus/gem controls and hosted
released-compiler CI remain separate; older Method-copy failures are not waived.
See gemtest/module_rss_released_compiler_r72.json and tools/module_rss_compare.md.

### Review repair: native notification super owners (2026-11-21)

Module's own private notification visibility marks describe real native
bodies, rather than visibility-only forwarding entries. The corrected
`module_notification_method_after` keeps that body before looking for its
super in Object. Corpus 724 now covers bound and unbound Methods for all
seven notifications, including an earlier prepended wrapper.

Before importing the newly merged C API, all 708 corpus programs matched
with the hash index on and off (594.362 seconds, 1,048,560 KiB, unchanged
900-second / 2-GiB bounds). The nine RSS workloads, root, depth (155) and
dead-definition gates passed. After integrating main `e540007c`, the O2
build and all 12 focused comparisons (corpus 720/723/724 in four cache
configurations) passed again. The complete hosted reports and per-file
comparison are still required for this integrated source before merge.

## 2026-11-20: rooted mixin arguments, scoped namespace autoload and the autoload loader

Unchanged Rails loading reached three independent evaluator boundaries:
`extend ::Factory.with(routes)` stopped at the rooted constant; Marcel's
singleton `extend` was preempted by Kernel's native entry; and
`class Base::Child` guessed its namespace before resolving Base's autoload.
Parse the complete rooted expression, let real singleton definitions win,
and resolve the actual namespace value before registering its child. Keep
raw self/local namespace references so lexical constants cannot replace them.

Bundler then exposed autoload invoking an object's unrelated `require`
method. The normal loader now runs with main as receiver, as does the
already supported custom main loader. It retains the original scope data.
The small witnesses are corpus 729-732; each matches Ruby in normal mode,
with the hash index disabled, with the MRO cache disabled, and with both
disabled (16 comparisons). No new top-level Mere values were added.

Normal O2 on main d9826ac9 plus these repairs: **710/710 corpus files**
match with the hash index both ON and OFF; all nine original loop RSS checks,
dead-definition checks and generated-C depth **155/1024** pass. The pinned
Ruby 4.0.9 files compare as follows, using the same bootstrap and exclusions
on both sides, 600 seconds per interpreter, 2 GiB per family and the original
10-second child limits:

| original file | main MATCH | candidate MATCH | RED | BOTH |
|---|---:|---:|---:|---:|
| ruby/test_module.rb | 195 | 195 | 0 | 0 |
| ruby/test_syntax.rb | 168 | 168 | 0 | 2 |
| ruby/test_parse.rb | 102 | 102 | 0 | 0 |
| test_forwardable.rb | 27 | 27 | 0 | 0 |
| ruby/test_method.rb | 97 | 97 | 1 | 0 |
| ruby/test_super.rb | 50 | 50 | 0 | 0 |
| ruby/test_autoload.rb | 27 | 27 | 0 | 1 |
| ruby/test_require.rb | 51 | 51 | 0 | 1 |

That is **722 discovered / 717 MATCH / 1 RED / 4 BOTH**, on both builds,
with no original passing case lost. Module retains all **1,240 assertions**.
An earlier attempt lowered every `include m` to a general method call and
made the original iclass child exceed 10 seconds. Keep the direct include
path for ordinary names and use expression parsing for the computed ternary
that actually needs it. The bound and the original test stay unchanged.
Earlier paired Syntax runs on the previous main had the same invalid-symbol
memory-test timeout on both builds; retain those observations separately.

An own validation-only composition reaches the next actual Rails failure:
ActiveModel's Module subclass cannot define a method from a block. Migration
fails, so boot, application tests and HTTP remain NOT_RUN. Reused own gem
homes make this a warm diagnostic, not a new installation or Rails pass.
The original selected ActiveSupport files are 513 MATCH / 8 RED out of 521;
no framework-wide pass is claimed. The pre-existing module_eval lexical
negative case remains RED and is kept as unittest/scoped_class_lexical_probe.rb.


## 2026-11-20: Module subclass method factories and native super before missing hooks

ActiveModel's AcceptsMultiparameterTime is a Module subclass whose initialize
includes methods, defines a closure and marks its method private. The real
module backing already existed, but its delegation predicate omitted
`define_method` and named visibility. Admit those native operations while
retaining Ruby overrides, the original receiver's freeze check and nil from
an argument-free private call even on a frozen module. The SVis statement
with names reaches that same real receiver, preserving overrides.

ActiveSupport::Concern then reached super from append_features on a module
that also defines an INSTANCE method_missing. super_missing tried that
instance hook before the real native mixin entry. Try native ancestors first;
missing dispatch on a class/module belongs to its singleton chain. Native
append_features/prepend_features/extend_object reuse ordinary native dispatch
for their actual return, validation, freeze checks and ancestry bookkeeping.
No new top-level values or collector/state/VM/AST/C API changes.

On main d9826ac9 plus the preceding rooted-loading repair, normal O2:
**712/712 corpus files** match with the hash index ON and OFF; corpus 733/734
also matches with normal/hash-off/MRO-off/both-off settings (eight pairs).
All nine existing loop RSS checks, dead definitions and generated-C depth
**155/1024** pass. Complete original Module195, Class61, Refinement121,
Super50, Method97, Parse102, Forwardable27, Autoload27 and Require51 MATCH
are identical to main. Module retains all 1,240 assertions and zero skips.
The 10-file first pair discovers 906 cases: main899 MATCH/1 RED/6 BOTH,
candidate898/2/6, with only README's known invalid-symbol Syntax memory test
lost. Repeating the WHOLE unchanged Syntax file gives main167/candidate168
MATCH (two BOTH each); retain both raw pairs, without a new exclusion or a
larger limit. Every focused file has a candidate run retaining main's MATCH.
The original 600-second/2-GiB and 10-second leak-child bounds remain intact.

The own Rails validation composition passes the previous two boundaries,
then migration fails in Pathname#initialize called by Application#encrypted
for credentials. Reference's four application stages pass; candidate
migration takes 8.877 seconds/1,011,920 KiB with no resource event, while
boot/tests/HTTP remain NOT_RUN. This reused-own-gem diagnostic is not a cold
installation or Rails pass. Hash default reads and other selected original
ActiveSupport failures remain separate work. The constructor's captured
Hash default-block behavior is already a separate unmerged prerequisite;
these Module changes do not claim to supply it.
### Rooted loading review: choose a scoped namespace lexically (2026-11-20)

Review found a real regression when both A::B and Scope::A::B exist:
`class A::B::Child` inside Scope selected the outer namespace. Resolve an
unrooted prefix's first segment in its lexical scope, then walk the remaining
segments from that actual module. Preserve explicit :: roots and existing
self/local bindings. Corpus738 covers class/module/conditional definitions,
root anchors, aliases and lexical autoloads; it and729-732 match in all four
hash/MRO settings (20 comparisons).

Normal O2 bcb3bca9: **711/711 corpus**, hash index ON/OFF; all nine existing
RSS checks, dead definitions and C depth155/1024 pass. The original nine-file
pair discovers784 cases on both builds: **777 MATCH/2 RED/5 BOTH** on each,
with no original PASS identity lost. Class61, Module195, Syntax167, Parse102,
Forwardable27, Method97, Super50, Autoload27 and Require51 MATCH are equal.
The known invalid-symbol Syntax memory failure occurs on both main and this
candidate; earlier168-MATCH observations are retained, not overwritten.
No original test, exclusion or limit changed. Hosted checks must still finish
on the review correction before merge.

### Module review: real native ancestors and original notification receivers (2026-11-20)

Restrict Regexp-subclass fallback to actual Regexp methods, and empty
notification fallback to receivers that inherit that native hook. Unknown
super calls continue to the original receiver's missing handler, including
arguments and blocks. Corpus739 covers both reported regressions, genuine
native controls and an undef before the native hook.

A Module subclass's anonymous module stores its methods; the original object
receives method_added. Read the existing backing-to-object ancestry mapping,
select a Ruby body, native alias, undef or Module's actual empty entry in
ancestor order, and notify once after visibility is established. The Proc
and Method argument forms now also notify after installation. The native
empty callback emits c_call/c_return on the real receiver when observed.
Corpus740 covers inherited/singleton/global callbacks, block/Proc/Method
forms, private initialize, exceptions without rollback, frozen refusal,
actual TracePoint receiver/owner, saved native callbacks and undef. The
first unconditional invocation missed the ordinary native callback on an
unmodified Module subclass; the original733 witness caught it and stopped
the attempted sweep. Preserve that failed record separately.

Final normal O2 ec6d6a5a: **715/715 corpus**, hash index ON/OFF, all36 witness
comparisons in four hash/MRO modes, all nine existing RSS checks, dead
definitions and depth155/1024 pass. Twelve original files discover1170 cases:
main1155 MATCH/7 RED/7 BOTH/1 EXTRA, candidate1157/5/7/1, with no original
passing identity or per-file MATCH lost. Module195/1240 assertions and
Regexp161 MATCH are retained. Settracefunc96->97 and Syntax167->168 are
observations, not claimed causal improvements; all raw pairs remain.
No original test, exclusion or resource limit changes.

A separate existing metadata failure stays explicit in
unittest/native_alias_method_predicate_probe.rb: method_defined? misses a
real native alias on both main and candidate. Notification witnesses obtain
the installed method directly; this change does not claim that predicate
repair or a full Rails pass. Hosted CI remains required on the corrected head.


## 2026-11-20: Real Hash defaults, yielded entries and lexical mixin arguments

ActiveSupport::OrderedOptions normalizes keys in Ruby Hash#[]; the missing-key
shortcut ran before that override. Honor the real override, and share native
Hash reads through super and saved aliases with the actual Hash#default.
Hash subclass count/entries now consume the real Ruby each, including arguments,
multiple yields and block/break, while ordinary Hash and Ruby overrides retain
their existing paths. Count uses the existing Enumerator counting body on the
actual Hash receiver; no proxy collection or invented size is used.

Runtime include/prepend evaluates lexical constants, ivars/classvars, local
variables and bare getters before validating the actual Module. Each scoped
segment follows its real ancestor/autoload/const_missing result and privacy;
explicit roots and custom include/prepend overrides are preserved. The first
full corpus caught a missing intermediate const_missing regression in525.
Fix it rather than removing the case. Keep the direct include-local hot path.

Normal O2 eea2a983 on main d9826ac9 plus the reviewed loading/Module stack:
**718/718 corpus**, hash index ON/OFF;525/735/736/737 in four hash/MRO modes
match in all16 comparisons. Nine existing RSS gates, dead definitions and C
bracket depth155/1024 pass. The complete original twelve-file paired set finds
1,302 cases: main1,284 MATCH/3 RED/15 BOTH, candidate1,285/2/15, zero EXTRA.
No original PASS or per-file MATCH is lost. Hash297, Enum89, Module195,
Class61, Refinement121, Super50, Method97, Parse102, Forwardable27,
Autoload27 and Require51 MATCH are maintained. Syntax167/168 is the known
invalid-symbol memory observation, not claimed as a causal improvement.
The final set was measured as eight files plus four additional files on the
same unchanged binary. Original600-second/2-GiB and10-second child bounds,
bootstrap, test files and exclusions remain unchanged.

An own integration reaches real Rails migration and stops at Range#=== through
ActiveSupport's prepended super, rejecting precision6 in0..6. Reference passes
all four warm application stages; candidate boot/tests/HTTP remain NOT_RUN.
This is reused-own-gem diagnostic evidence, not cold installation or a Rails
pass. The separately measured four original ActiveSupport files still have
537/541 MATCH at the earlier Hash-default boundary; these new Enumerable
changes require a new original-framework measurement before claiming more.


## 2026-11-20: Native Range case equality through super and saved aliases

ActiveSupport prepends CompareWithRange#=== and calls super for scalar values.
The native fallback reached Object#=== instead of Range#===, so precision6 was
rejected by0..6 during actual Rails migration. Enter the real Range comparison
from super and native aliases. Compare begin <=> value and value <=> end once
in that order, matching range.c r_cover_p: nil means not covered; comparator
exceptions propagate. Preserve exclusive/beginless/endless boundaries and the
bounds of real Range subclass instances. No invented precision exception.

Normal O2 at25415a32, on the reviewed loading/Module/Hash stack: **719/719
corpus** match with the hash index ON and OFF. Corpus741 matches in all four
hash/MRO settings, including native alias arity, scalar/string/object bounds,
comparison side effects and exceptions. Nine existing RSS gates, dead definitions
and generated C depth155/1024 pass. The original Range/Super/Method/Module
pair discovers410 cases: both main d9826ac9 and candidate409 MATCH/1 RED,
zero BOTH/EXTRA, no original PASS lost. Range67, Super50, Method97 and Module195
MATCH are equal under the original600-second/2-GiB and10-second child limits.

The own integration fd5a68a5 passes unchanged migration in6.812 seconds with
804,208 KiB peak family RSS and no limit event. The next boot check refuses
Bundler's full_gem_path because it points outside that interpreter's actual
installed gem home; candidate application tests and HTTP remain NOT_RUN.
Reference passes all four warm stages. This reused-own-gem run does not claim
cold installation or application success. Remeasuring the same four original
ActiveSupport files on both interpreters gives **539 MATCH/2 RED out of541**,
zero BOTH/EXTRA/skips: OrderedOptions31/31, Concern17/17, Inflector471/473,
class attribute20/20. Both remaining identities are Inflector titleize cases
(String gsub! native super and Unicode negative lookbehind); the framework-wide
suite has not been run.

### Scoped namespace review: every remaining segment is a real scope lookup

Resolving the first constant lexically was necessary but did not make
const_walk_go a full scope lookup. Object::Branch uses a top-level Branch
key; ancestor constants and intermediate const_missing results were also lost.
Add scoped_namespace_tail to follow the actual receiver through each scope
operator, with Object's top-level keys, ancestors, autoload, privacy and the
real const_missing callback. Preserve the first-segment lexical correction.
Corpus742 covers class/module definitions, nested and conditional definitions,
Object roots, inherited namespaces, intermediate hooks, autoload and refusals.

Normal O2 runtime48f8e37f: **712/712 corpus**, index ON/OFF;729-732/738/742
match all24 hash/MRO mode comparisons. All nine existing RSS gates, dead
definitions and C depth155/1024 pass. Complete original Class/Module/Syntax/
Parse/Forwardable/Method/Super/Autoload/Require discover784 cases: main d9826ac9
and candidate both777 MATCH/2 RED/5 BOTH, zero EXTRA or lost original PASS.
Module retains195 tests and1,240 assertions. The existing invalid-symbol Syntax
memory failure is present on both; original test files, bootstrap, exclusions
and600-second/2-GiB/10-second child limits are unchanged. This correction
requires new hosted checks; the previous head's known complemented-method
10.03-second child Timeout is retained rather than waived for merge.


### Module stack after the scoped-namespace follow-up (2026-11-20)

Rebuild the Module repairs with the parent's full scoped-constant correction.
Normal O2 runtime f6975772 passes **716/716 corpus**, hash index ON/OFF,
all40 witness comparisons across four hash/MRO modes, all nine existing RSS
gates, dead definitions and C depth155/1024. Twelve complete original files
find1,170 cases: both main d9826ac9 and candidate **1,156 MATCH/6 RED/7 BOTH/
1 EXTRA**, with no original PASS or per-file MATCH lost. Module195 with1,240
assertions, SetTraceFunc97, Regexp161, Class61, Refinement121, Super50,
Method97, Syntax167, Parse102, Forwardable27, Autoload27 and Require51 are
retained. The known Syntax-memory failure remains on both sides. All original
limits, tests, bootstrap and exclusions are unchanged. Parent documentation
was merged after measurement; it changes no runtime source. Hosted checks
must complete on the updated head before merge.

Final current-main validation of the retained matcher repair: all720 corpus
programs match in both hash modes (490.781 seconds, 1,194,640 KiB under the
unchanged900-second/2-GiB bound). The final integrated runtime retains all32
focused comparisons across evaluator/strict VM and four hash/MRO modes.
Nine RSS workloads, GC roots, bracket depth155 and dead definitions pass.
The handler and $! keep the same pinned exception across rejecting matchers
and outer propagation. No builtin-only VM matcher pins an exception.

### Preserve exception frames before resolving a rescue constant

A getconstant can run autoload or const_missing before checkmatch. Such
handlers now leave vm_rescue_only_matches' optimization and pin the original
exception before the lookup; lookup-free builtin operands, including bare
rescue, keep their fast path. run_rescues likewise pins before expanding
explicit class expressions. This deliberately avoids guessing whether a
constant lookup can execute Ruby. No top-level state or collector change.
Corpus 696 adds an autoload that raises/rescues internally and a const_missing
variant, checking the original frame and identity with $!. The original
head fails the new evaluator reproduction in all four cache modes. The repair
matches corpus 696-699 in all 32 evaluator/strict-VM/cache combinations; the
original Exception and Backtrace files pass all 129 cases. The previous
720-program sweep predates this follow-up; a fresh complete sweep is running.


### PR review: resolve constant path heads through actual lexical scopes

Use lex_const_key_nested for the EConst qualified-path shortcut and both
const_walk_head lookups. An absent namespace prefix is not a lexical scope.
If that first hit is rejected, the helper continues through the actual
nesting instead of discarding a later real outer scope. It preserves the
existing singleton-owner mapping. Changed functions: eval_e,
const_walk_head and lex_const_key_nested; the parent's vm_define correction
is unchanged. Corpus760 adds qualified reopening, method reads, scoped class
definition and the case with both an absent prefix and a real outer scope.
Both reported and additional comparisons failed before these corrections.

Final normal O2/compiler01f5ad73 validation: **721/721 corpus**, hash index
ON/OFF, **481.274s / 1,188,480KiB** peak family RSS. All36 default/evaluator/
strict-VM and hash/MRO comparisons of731/738/760, all nine RSS gates, roots,
dead definitions and C depth155/1024 pass. Complete original Exception/
Backtrace/Module/Autoload/Require discover404 cases: **402 MATCH / 0 RED /
2 BOTH**, with both reference skips explicit and all per-file MATCH retained.
The old invalid-symbol Syntax leak failure is not affected or reclassified.
An initial original-file selection started before the replacement build
finished and is explicitly ineligible; the accepted fresh run checks the O2
build's freshness and unchanged binary hash. No collector/state, C API,
VM/ISeq, AST/Prism, gemtest implementation, original tests, exclusions or
limits were changed for this repair. New hosted CI and latest-main per-file
acceptance remain required before merging.

### Stage 9: preserve native launchers and finish current-main integration

Integrate main a206da11 after the native-extension runner change. The manual
runner resolution retains the current mr_run child launcher and Perl entry,
and UNITTEST_EXCLUSIONS still writes the separate per-file exclusion sidecar.
Only appended documentation requires manual resolution in the final merge;
no collector, state, VM or C API function is manually changed.

Final O2 validation: 728/728 corpus programs match in both hash modes,
514.759 seconds / 1,113,136 KiB under the unchanged 900-second / 2-GiB bound.
All 88 focused comparisons on the default runtime, nine RSS workloads,
roots, depth155 and dead definitions pass. An additional forced evaluator
comparison differs on the existing unused-block and two lexical-namespace
witnesses; it is retained separately and is not reported as passing.

On the preceding native-main integration, the actual pinned CI reference
runtime, source and test extensions give GC 32 MATCH / 1 RED / 2 BOTH over
35 cases with the same19 exclusions on both sides. The original two mkmf
cases give1 MATCH / 1 RED: ruby_init remains an unsupported link symbol.
The first local reference setup lacked its Makefile and test stack extension;
that incomplete setup is not accepted as a passing comparison. The complete
context is measured separately. Existing57 exclusions remain explicit and
unchanged (GC19, compact22, objspace16), and all76 allocation cases remain
enabled for the VM handoff. Hosted every-file comparison still gates merge.

Final current-main integration checkpoint: all 730 corpus programs match in
both hash modes after the Digest/CI changes. All 56 focused comparisons,
including the two new Digest witnesses, pass; nine RSS workloads, roots,
depth 155 and dead definitions also pass. GC runtime functions, the 159-row
classification ledger, 57 symmetric exclusions and all original bounds are
unchanged. Current hosted checks and every-file nonregression still gate merge.

### Native extension child processes retain declared stdlib fallbacks

The runtime-first native runners fixed parent mkmf loading, but RubyGems'
unchanged extension builder repeats its physical stdlib directory in a
child -I argument. That restores the reference monitor.rb ahead of the
shipped implementation and raises LoadError for monitor.so before extconf.

The three native runners declare their actual reference directory through
MERE_RUBY_STDLIB_FALLBACK. load_path_pick_shipped treats a declared fallback
entry as the shipped position for genuinely native-backed shipped features.
This survives the child's -I without guessing reference installations,
changing ordinary user-directory precedence, or replacing pure Ruby source.
No runtime behavior changes when no fallback is declared. Functions touched:
load_path_pick_shipped and run in capi_mkmf_check.py, capi_gem_check.py and
capi_spec_check.py. No new top-level value or collector/C API body edit.
Corpus525 retains a small native-wrapper reproduction.

Released compiler43f2994b/O2: all724 corpus programs match in both hash modes
(470.007 seconds / 1,067,584 KiB under unchanged900-second/2-GiB bounds).
All16 focused comparisons, nine RSS workloads, roots, depth155 and dead
definitions pass. Actual mkmf builds pass all14 contracts on reference,
candidate and collection stress, and both negative controls fail correctly.
All seven published native gems install by the unchanged gem install path;
all84 use-output lines match and wrong-runtime libraries are rejected.
The unchanged C API spec gate accepts reference2584/candidate2277 against
its existing record. Existing digest-header, thread timeout and other
unsupported spec results are retained, not counted as passing cases.
The earlier runner-only attempt's six native-gem child failures remain
separate raw evidence. Current hosted every-file validation still gates merge.

### Reference directories remain fallbacks for wrapped native libraries

The declared-reference marker must describe directory ordering, not a list
of native feature names: the Psych/YAML Ruby wrappers also require their
own runtime's native core. load_path_pick_shipped now defers declared
reference entries, preserves other active user paths, selects the shipped
source at its own position, and searches deferred paths for unshipped files.
No directory absent from LOAD_PATH is added by the marker. Behavior without
a declaration is unchanged. Corpus 525 exercises real YAML parsing in a
child with the fallback repeated through -I, using a genuine native-wrapper
prerequisite on the reference. All 11 ordinary/child library controls pass;
Psych and YAML failed the preceding child control. A real user source still
wins over a declared fallback in the separate priority control.

Current main 2e2ab568 is integrated with Digest, the cached compiler action,
XML dependency checks and released compiler 43f2994b retained. Normal O2:
726/726 corpus programs match in both hash modes (530.253 seconds,
1,058,272 KiB), all 24 focused comparisons, nine RSS workloads, roots,
depth 155 and dead definitions pass. The unchanged mkmf gate agrees on all
14 contracts for reference/candidate/stress and rejects both negative
controls. All seven native gems install and their 84 output lines agree;
wrong-runtime libraries remain rejected. The C API spec gate retains its
existing record, reference 2584/candidate 2277, including existing unsupported
and timeout cases. Reference-cache and embedding-build controls pass, and
workflow YAML parses. Hosted full checks and every-file nonregression remain
required for the new head. No original assertion, exclusion or bound changes.


### Hash review: calculate a native read's search hash once (2026-11-20)

The new native read helper discarded hash_touch's result, then recalculated
#hash for each candidate through hash_lookup_w. Keep the real search hash in
the call and reuse it with stored codes; share the post-bucket identity/eql?
comparison without changing insertion's existing hash evaluation order.
Identity reads skip the protocol. Ruby [] overrides run before probing keys;
the native custom-key [] entry uses the same lookup, so super and saved aliases
both calculate the actual hash once. Reentrant hash/eql? calls use local data.

The first amendment passed the reported alias but its added super control
found an earlier [] dispatcher bypass. Retain the16/20 failed witness run and
stop its incomplete original-file comparison; fix that door too, then start
a new O2 measurement. Runtime4d95d7b7 passes **719/719 corpus** ON/OFF,
all20 comparisons for525/735-737/742 in four hash/MRO modes, nine existing RSS
gates, dead definitions and depth155/1024. Complete original twelve-file
comparison:1,302 cases, both main d9826ac9 and candidate **1,284 MATCH/3 RED/
15 BOTH**, zero EXTRA, no original PASS or file MATCH lost. Original600-second/
2-GiB/10-second child limits, bootstrap, exclusions and tests are unchanged.


### Range review: resume native lookup from the actual ancestor position

A receiver-only native fallback incorrectly reentered containment when Range
itself replaced ===: that super belongs above Range and reaches equality.
Include the real native Range entry while resolving super's remaining ancestor
chain. Ruby definitions and undef before it keep their precedence; a native
Range entry stops before a lower Ruby override. Both ordinary and refined
super retain their actual lookup positions. Only Ruby targets consume the
pending frame index; native comparator callbacks do not inherit that index.

Normal O2 runtime0824a721 passes **720/720 corpus** ON/OFF, all12 comparisons
for735/741/742 across four hash/MRO modes, nine existing RSS gates, dead
definitions and C depth155/1024. The original Range/Super/Method/Module pair
remains409 MATCH/1 RED out of410. Add the whole original Refinement file on
the same unchanged binary:121 MATCH/1 BOTH out of122 on both sides. Combined
five-file result:532 cases, both main d9826ac9 and candidate530 MATCH/1 RED/
1 BOTH, zero EXTRA or lost original PASS. Original600-second/2-GiB/10-second
child limits, files, bootstrap and exclusions remain unchanged. Subsequent
parent merges change documentation only; full hosted checks are still required.

Two exploratory controls expose separate preceding-parent gaps: native Kernel
Method binding loses its owner on a Range receiver, and primitive === bypasses
an undef. Keep unittest/range_kernel_method_owner_probe.rb and
unittest/range_case_equality_undef_probe.rb as explicit failing diagnostics;
these are not claimed repairs, exclusions or passing corpus cases. The older
direct primitive/object comparison diagnostic also remains unresolved.


### Class case equality: invoke Ruby hooks and retain native super positions

A class's Ruby singleton === was used by the explicit operator but skipped by
case/when. This prevented ActiveSupport's Time.=== from accepting TimeWithZone.
Resolve the actual singleton ancestor chain, stop at the real native Module
entry, and call a preceding Ruby body with its actual ancestor index. Super
continues through the real Module/Kernel entries, including after Module's own
Ruby replacement. Splat candidates also use case equality instead of ==.
Native entries consume pending call state before invoking Ruby comparisons.
The obsolete equality-only leaf helper is removed; no top-level value is added.

Normal O2 runtime8812a585 passes **721/721 corpus** with the hash index ON/OFF,
all16 comparisons for735/741-743 in four hash/MRO modes, nine existing RSS
gates, dead/duplicate definitions, GC roots and depth155/1024. The original
Case/Class/Module/Super/Method/Refinement/Settracefunc/PatternMatching comparison
has665 cases: both main d9826ac9 and candidate657 MATCH/5 RED/3 BOTH, zero
EXTRA or lost original PASS, and no per-file MATCH decrease. The original
600-second/2-GiB/10-second child bounds, files, bootstrap and exclusions remain.

The separate combined Rails diagnostic explicitly activates the real installed
Bundler on both sides and retains every locked-package source check. Migration
and boot pass. The original six app tests improve from five errors to three:
all TimeWithZone cast errors are gone, while one unhandled retry and two unknown
<=> errors remain. This warm diagnostic does not establish the direct-start
Bundler path, a cold install, HTTP success or whole-Rails compatibility.

### Review repair: mixed Hash keys and Object autoloads (2026-11-21)

Native Hash reads now use the internal hash for builtin search and stored
keys even when a mixed table contains Ruby-hashed keys. Ruby hash callbacks
still run once for keys whose protocol requires them. Object-qualified
mixin paths normalize the constant/autoload key before firing the loader.
Functions changed: hash_read_native and mixin_argument_value. Corpus 735
and 736 cover String/Symbol hash overrides, missing custom keys, and block,
class-body include and runtime prepend through Object's pending autoload.

With Mere 01f5ad73 and O2, all 719 corpus programs match in both hash-index
modes (516.823 seconds, 1,192,432 KiB under the unchanged 900-second/2-GiB
bounds); RSS, root, depth (155) and dead-definition gates pass. The three
focused corpus programs match in all four hash/MRO cache configurations.
The original test_hash.rb remains 297 MATCH, 1 RED, 8 BOTH out of 306,
without any previously passing named case lost against the retained before
and previous candidate results. The remaining RED is test_replace_memory_leak;
it was already RED. Full hosted per-file comparison is required before merge.


### Review repair: removed native Range entries (2026-11-21)

Native Range and Kernel comparators have entries in the existing
builtin-alias store. Ruby replacements displace them; deleting a replacement
does not restore the native entry. Ordinary/refined super follow the actual
remaining entries while saved native aliases retain containment.

Pinned Mere 01f5ad73/O2 passes all 720 corpus programs in both hash modes
(510.717 seconds, 1,285,680 KiB under unchanged 900-second/2-GiB limits),
all nine RSS workloads and root/depth155/dead-definition gates. Corpus741
matches in four hash/MRO configurations. Original test_range/test_method/
test_super total 215 cases: 214 MATCH and one existing Method RED, with no
previously passing named case lost against retained candidate results.
Full hosted per-file comparison still gates merge. Functions changed by
the review: run_super_target, range_super_lookup and super_next_refined;
existing builtin_alias/blt_alias_names initializers retain the native entries.

## Replay the original Rails native-build issue on integrated main

Issue #116 was left open while the own build metadata (#95) and bounded SHA-2
provider (#120) were unmerged. Both are now in main 2e2ab568. A fresh normal O2
build with main's pinned compiler 01f5ad73 and the unchanged committed Rails
runner installs Bundler and all 68 dependencies from the same 69 archives.
Separate initially empty gem homes and independently built extensions remain;
the same documented system SQLite 3.46.1 option is used on both interpreters.

The dependency stage exits 0 in 253.379 seconds / 914,976 KiB, within the existing
600-second/2-GiB family bounds. The original small mkmf probe matches and the
actual bigdecimal Makefile/build uses this runtime's own headers. All 77 captured
runtime/runner/lock input hashes stay fixed, all stored stdout/stderr hashes
verify, and seven harness controls pass. The initial sandbox-denied ps check
is separate setup evidence; the same harness passes with normal permissions.

Reference passes all six stages, including six tests / 31 assertions and actual
Puma HTTP. Mere's original migration then stops at the separately tracked #121
registry error, perform on nil, exit 1 in 2.062 seconds / 199,616 KiB. Boot/tests/
HTTP are NOT_RUN and the whole record remains RED. Keep all earlier source-
specific records, add railstest/main_native_install.json, and correct the stale
README statement about current main. This meets #116's first-extension-build
acceptance condition without claiming Rails application/framework success.
Runtime functions changed: none; no lock, test, exclusion or bound changes.


### Merge main while retaining the actual GC observations and exclusions

Integrate main05c3bda3 and its released compiler408b03d9 after PR145,
including the documentation-only Rails-install receipt from PR146.
Preserve the already-published07d88806 unused-block correction unchanged;
no VM function is manually edited. The sole implementation-related merge
change is CI's MERE_REF. No GC API value, collector/state function, ledger,
original test, accepted snapshot or resource bound is changed.

New ordinary O2/compiler408b03d9 validation: **730/730 corpus**, hash
index ON/OFF, **586.824s / 1,045,968KiB** peak family RSS.
All56 focused comparisons, nine RSS gates, roots, dead definitions and C
depth155/1024 pass. Five complete original files retain **166 enabled cases:
71 MATCH / 87 RED / 3 BOTH / 5 EXTRA**, plus **57 separately recorded
exclusions**. Both sides exclude the exact same identities/reasons: GC19,
compact22, objspace16. All76 allocation comparisons stay enabled and RED.
GC retains32 MATCH/1 existing RED/2 BOTH; ObjSpace37 MATCH/9 RED and string
memory2 MATCH/1 RED. The compact API controls retain the reference's skips.
The initial GC run lacked Mere's native stack fixture and is not accepted
as the corrected context; rebuilding the unchanged fixture against Mere's
own headers restores the two finalizer matches. The reference is the pinned
CI Ruby4.0.9 with its matching original extensions. The159-row intake remains
14 MATCH/57 EXCLUDED/88 HANDOFF. New hosted checks and the every-file gate
remain required; no exclusion is credited as a passing test.

### Merge main after the released Map-slot compiler adoption

Integrate main05c3bda3 after PR145 and the documentation-only PR146. Resolve only the MERE_REF conflict by
retaining released compiler408b03d9, which clears removed native Map backing
references. Keep the existing native child launchers, declared-reference
fallback ordering and user-source priority. No runtime function, library,
original test, exclusion, accepted snapshot or resource bound is changed.

New ordinary O2/compiler408b03d9 validation: **726/726 corpus**, hash
index ON/OFF, **546.48s / 1,057,696KiB** peak family RSS.
All24 focused hash/MRO comparisons, 11 ordinary/child library controls,
all nine RSS gates, roots, dead definitions and C depth155/1024 pass.
The original upstream mkmf checks retain all14 reference/candidate/stress
contracts and both negative controls. All eight locked packages, including
seven gems with C extensions, freshly install separately under both runtimes;
all84 use-output lines match and reference-built libraries are rejected.
Earlier compiler43 measurements stay associated with their original source.
Fresh hosted checks and latest-main per-file acceptance remain required.

The upstream gem workflow also selects compiler408b03d9, matching core CI
and the new local O2 measurements. Its original locks, tests, accepted
snapshots and bounds are unchanged; new hosted gem results remain required.


### Integrate the merged native-loading repair into stage9

Merge main9b7f16a7 after PR90. Preserve actual GC observations, all57
reasoned exclusions and the original native child launchers. The only
manual code resolution is HarnessCheck.setUp: its fake interpreter writes
both the exclusion sidecar and the actual RUBYLIB capture. The documentation
resolution retains both branches' records. Runtime changes from PR90 merge
automatically; gc_fixpoint/gc_mark_roots/gc_collect and m_state.mere remain
unchanged from this branch. No new GC API value or top-level state is added.
The original percent-literal witness667 keeps its meaningful closing spaces.

Normal O2/compiler408b03d9: **738/738 corpus**, hash index ON/OFF,
**549.227s / 1,168,512KiB** peak family RSS. All72
focused GC/loading comparisons, 11 ordinary/child library controls,
20 harness checks, nine RSS gates, roots, dead definitions and C depth155/1024
pass. Actual mkmf builds retain14 reference/candidate/stress contracts and
both negative controls; eight locked packages including seven native gems
install separately under both runtimes and produce the same84 output lines.
Foreign libraries are rejected. Five complete original files retain166
enabled cases:71 MATCH/87 RED/3 BOTH/5 EXTRA, plus57 separately reported
exclusions with identical identities and reasons on both sides. Allocation76
stays enabled. The159-row intake remains14 MATCH/57 EXCLUDED/88 HANDOFF.
Original tests, locks, accepted snapshots and all bounds are unchanged.
Fresh hosted checks and the latest-main per-file comparison remain required.

## 2026-11-22: stop cancelled workflows from starting new suite summaries

Cancelled runs 44921266629 and 44922636658 still started their Unit,
Bootstrap and Tool summary jobs. The jobs had no completed shard group to
collect, so cancellation produced additional failing summary checks. Main's
Tool summary already checks cancellation and the shard result; apply the same
boundary to Unit and Bootstrap.

Both jobs require a successful plan and an active workflow with a successful
or failed shard group. Their collect steps also check cancellation, covering
a workflow cancelled after the job starts. Genuine shard failures still run
the existing collectors; missing and partial results still fail, and the
existing artifact uploads continue to retain diagnostics. Test inventories,
resource bounds, runners, measurement code and runtime implementation are
unchanged. See the [GitHub status-check documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#status-check-functions).

Validation: actionlint 1.7.12 accepts the workflow. Four existing collection
controls pass: missing shards retain all planned rows and fail; unattempted
files in partial artifacts remain visible; weighted plans still reject a
missing shard; and a monitor failure preserves reference cases while failing
collection. This does not mark previously cancelled or failed runs successful.

Latest-main integration retains the merged stage9 documentation verbatim.
The only conflict was the append position in this log; runtime and collector
changes come unchanged from main. The same four collector controls and
actionlint pass again on the integrated base.


## 2026-11-22: keep TracePoint events on their suspended callback

The PR96 integration at 6fc219e6 loses the original
`TestSetTraceFunc#test_thread_add_trace_func` with `access from outside` in two
complete runs, while paired main a9ca552d passes that case. A short program
that explicitly yields inside a shared TracePoint reproduces overwritten
event metadata on both binaries, so the underlying bug predates this PR;
only the original case's triggering schedule differs. The initial failures
and all existing suite failures remain recorded.

TracePoint's Ruby prelude now keeps each active event in its own Fiber's
entry on the TracePoint object, rather than shared event/inside ivars. An
ensure restores the enclosing event for allow_reentry or removes the entry
when the callback ends, including exceptions. No Mere global map, pin, GC
rule, compiler/dependency pin, upstream test or resource bound is changed.

Witness 749 checks shared callbacks across Thread.pass, outside access while
another thread's callback is suspended, allow_reentry restoration, explicit
Fiber.yield/resume and exception cleanup. A fresh ordinary O2 build matches
Ruby 4.0.9 exactly. Complete original TracePoint and other regression results
are recorded separately on the PR with their actual source revision.

## 2026-11-22 (77): a regexp's escapes must be whole characters of its encoding -- Regexp.new, AST.parse, and the parser's refusal

**The point.** `Regexp.new('a\xff')` compiled, and `RubyVM::AbstractSyntaxTree.parse('/a\xff/')` returned a tree. In ruby 4.0.9 the first is a RegexpError and the second a SyntaxError: "invalid multibyte escape: /a\xff/". Note 551 recorded the AST case as a gap.

**Regexp.new.** `__rx_new` now checks each run of escaped bytes, unless the pattern has NOENCODING. A run is made of `\xHH`, a three-digit octal, and `\M-` (alone or around a control escape). The run must make whole characters of the source's encoding: UTF-8, EUC-JP, Shift_JIS or Windows-31J. A plain character, a raw byte or any other escape ends the run. The reason comes from the parser's own rx_mb_why, through rx_esc_runs_why in m_parse.mere. A control escape with no `\M-` in it is no byte of a character to Regexp.new: `'a\c\xff'` compiles, as in ruby. Once a run has begun, an escaped byte below 0x80 joins it too: Shift_JIS and Windows-31J have trail bytes from 0x40, so `'\x81\x40'` is one whole character (review of #150).

**AST.parse.** It compiles a plain literal (REGX) with Regexp.new, so it now refuses one as parse.y does, in Regexp.new's words. A split or interpolated literal (DREGX) is not compiled, and parse.y does not refuse it either. This interpreter's own parser runs first and refuses such a literal in its own form. AST.parse now leaves that refusal to the tree's error.

**The parser's refusal**, for eval and load:
- it names the pattern as the lexer left it (`\M-b` written `\xE2`), or with interpolation the fragment the run is in (`/\x81#{ }/` says `/\x81/`), where it named only the run's bytes;
- it names the line the literal is on, unframed, as ruby does: rx_cur "why" with syn_why_ln "l". Eval used the eval's own line for an unframed reason, and a literal on line 2 said line 1.

Not done (on main too): `Regexp.new('\xc3\M-)')`, whose `\M-)` the pattern parser takes as an unmatched `)`.

- Checked: the same results before and after on test_regexp, test_m17n, test_m17n_comb, test_syntax, test_ast, test_iseq, test_parse, enc/test_utf16, enc/test_euc_jp and enc/test_shift_jis. Witness corpus/750.

## 2026-11-22: restore the earlier Method arena floor repair to PR 107

PR 107 still fails the unchanged hosted macOS Method-copy assertion at
2.151589x in run 44896678187. Its public source `263c2dd6` omitted the previously
authorized `compact_method_store` correction carried by the later stack.
Restore that exact change: native compaction can decline while an arena is
pinned, and unchanged capacity must not become the enlarged next floor.
Only initialization or actual capacity reduction publishes a measurable floor.
Dirty clearing, the return value, unmeasurable behavior, numeric thresholds
and native pin/collector policy are preserved. No new top-level binding.

Build the exact public parent and candidate `1e977ae4` with released compiler
`408b03d9`, ordinary native macOS O2. Predetermined parent/candidate/candidate/parent
ratios are 1.682880 / 1.380188 / 1.382723 / 1.679791. All 21 original post-collection
prefixes, the complete program bytes and the 2x assertion are unchanged; healthy
references accompany every trial. These local parents pass as well. Preserve
the original failed hosted series instead of claiming a local reproduction.

Complete Module 195/1240 and Refinement 122/367 retain identical reference cases
(the same refinement skip). Method retains 98 tests / 554 assertions and its
existing skip versus reference 558 assertions. No passing parent case is lost.
Both original gem groups complete offline: primary 54 MATCH / 7 RED / 1 MEMORY
and additional 6 MATCH / 1 MEMORY, with zero accepted per-file MATCH losses.
Logger's known RED is MEMORY in this sweep. A separate parent run reaches RED,
followed by a predetermined parent/candidate/candidate/parent whole-file comparison
that exceeds the original cap in all four runs. Keep all five observations;
no Logger RSS or File-identity repair is claimed. Rack Request remains MEMORY.

All 738 corpus programs match in both hash-index modes (466.667 seconds, peak
family RSS 1,039,664 KiB within 900 seconds / 2 GiB). New witness 769 retains copied
Ruby method bodies, aliases and lexical constants across collections. All nine
existing loop RSS checks and dead/duplicate definitions, GC roots, method
writes and record hygiene pass; generated-C depth remains 155/1024.

The receipt `gemtest/method_floor_pr107_r101.json` retains every paired RSS prefix,
the original hosted failure, source/compiler/binary/C identities, complete core
case dictionaries, all 69 gem rows and raw-log hashes. Baselines, locks, tests
and 600-second / 2-GiB file limits are unchanged. This is macOS evidence; fresh
hosted CI and latest-main per-file acceptance still gate merging.

### Retry method-store compaction after a native pin defers it

The additional-suite Method-copy guard failed at 2.093697x under the released
compiler. Bring the already-tested compact_method_store correction from the
later gem-suite stage forward: an unchanged, pinned arena no longer advances
the measured baseline that determines the next real compaction attempt.
The change is confined to that existing function; collector/pin policy,
assertions, source locks and resource bounds are preserved.

Measured source6a39ade7 with compiler43f2994b: Linux Method-copy passes two
predetermined trials at1.519007x /1.589846x, and all seven additional-suite
files retain6 MATCH /1 RED. On macOS the control passes at1.819241x; the
original Method file retains98 cases and its existing compaction skip.
The seven gem files retain6 MATCH /1 MEMORY on macOS, with byte-identical
per-file classifications to a freshly built unmodified7c0fe03d baseline.
The existing logger logdevice failure is not hidden or reclassified as a
success. gemtest/method_floor_backport_r81.json retains the hosted failure,
all Method samples and the two platform results. Baselines are unchanged.

## Native selection after the current Hash parent synchronization

Integrate the current Hash parent without dropping compatible native feature
selection. The load_path_pick_shipped conflict also carries forward PR90's
published true reference-directory fallback policy: ordinary user files and
compatible native files stay ahead of shipped source, and only explicitly
declared reference directories are deferred. An unshipped feature can still
come from its real reference directory. Corpus525 now covers YAML/Psych
native prerequisites in a real child as well as monitor; corpus722 remains
the independently built native-selection fixture.

The published mkmf launcher correction from PR90 is retained too: its child
keeps the declared reference fallback and the caller's explicit helper paths.
The added context/child controls use an actual path containing an apostrophe.
No runtime function other than the existing load_path_pick_shipped is manually
changed in this integration; all other runtime changes come from the reviewed
parent. No top-level value, original test, exclusion, baseline or bound changes.
Fresh O2, complete corpus and original-file checks follow this synchronization;
the older734-program receipt remains tied to its original source.

The synchronized normal O2 source b9c06a08, released compiler43f2994b,
now completes751/751 corpus programs in both hash modes (487.638 seconds,
1,187,808 KiB under the unchanged900-second/2-GiB aggregate bound).
All8 focused native/fallback comparisons, nine RSS cases, roots, depth155
and dead-definition checks pass. Original require/autoload/Marshal remain
311 cases /308 MATCH /0 RED /3 BOTH, the same as the parent receipt.
The original mkmf14 contracts pass on both runtimes and under GC stress;
the real upstream context/child controls pass, and broken-source/foreign
runtime controls fail correctly. Source/binary/check hashes stayed fixed.
The earlier partial focused invocation named absent Digest witnesses;
its successful525/722 rows are retained but only the corrected8-row run
is accepted as a complete focused receipt. No case is silently omitted.
Hosted current-head CI, per-file comparison and review gates remain required.

### Attribute page presence separately from native region capacity

Read-only page-table observations distinguish capacity from pages actually
present in each inventoried native region. The separate diagnostic build
still runs the original input and is rejected by the ordinary RSS gate.
Missing ranges, overlaps, impossible counts or denied access fail evidence
collection. Partial payload edges are explicitly omitted; presence and
exclusive-mapping flags are not process RSS or proof of object liveness.

Locked runtime90c83c6e and released compiler43f2994b on Linux/aarch64 pass
the ordinary Module195/1240, selected clone and Method-copy1.866672891x
(reference1.104115371x). In the separate Method-copy diagnostic, inactive
cache payloads have8KiB of present pages at both samples0 and20. Retired
payloads increase from11,420 to89,212KiB; default and current method payloads
stay close to35,704/35,880 and3,956/4,032KiB. All30 final retired arenas have
present root pinners. The observed established-floor increases without a
move remain zero. This identifies retained old native arenas as the main
growth in this observation; it does not establish that their pins are stale
or safe to release. Collector and native ownership changes remain outside
this diagnostic patch.

The repaired-source native x86-64 comparison in run44867923161 also passes:
candidate Method-copy1.730880370x /1.797650005x and all original core controls.
Its compiler94da60b5 has the same tree as released43f2994b. The older-source
ae6bd8cc Method-copy2.135504918x and ordinary clone2.014963587x failures are
retained and are not repaired by relabeling the historical job.

tools/rss_page_probe.md documents the reader and the independent native Linux
job. bench/rss_page_ownership_r84.json retains ordinary verdicts, all Method
prefixes, page totals, pin observations and the failed historical controls.
The captured fixture and14 reader/evidence controls include real anonymous
mapping and access-denied checks. All35 existing native/heap/comparison
controls still pass. No runtime Mere function, GC/pin policy, original test,
existing workflow input, exclusion or resource bound changes.

### Independently validate cleared Map slots with the same pinned workload

Mere86 repairs a concrete retention source: delete/clear left logically
removed keys and values in backing arrays inspected by conservative scans.
Independently build compiler44bc7bc0 and emit runtime90c83c6e. Reversing only
32 clear and32 delete fragments makes its generated C byte-identical to
parent43f2994b. The published merge408b03d9 has exactly the same source tree.
No compiler implementation or pin rule is edited here.

Fixed parent/candidate/candidate/parent ordinary Method-copy ratios are
1.697336335 /1.920427000 /1.574114244 /1.718854905x: all pass, but one
candidate is higher than either parent. The candidate's additional ordinary
run is1.590390082x; complete Module195/1240 and the original selected clone
also pass. Retain every sample rather than claim uniform improvement.

Separate Method-copy diagnostics reduce final retired payload presence from
89,212 to65,296KiB and observed process RSS from160,440 to136,632KiB. Cache
presence remains8KiB. All Method/Super/Class/Refinement parent and candidate
case dictionaries are identical, with no passing case lost among332 cases.
The reference kwarg-memory and warning failures and the existing unsupported
Method compaction skip remain visible. This is not an all-pass reference run.

bench/rss_map_slots_r85.json retains the emission proof, all paired prefixes,
ordinary controls, page data and all additional original case dictionaries.
The new page-ownership matrix compares parent43 with published fix408 on the
same locked runtime; existing historical jobs and ordinary CI pins remain
unchanged. These observations support the removed-slot repair, not a claim
that every historical RSS failure or workload variation is fixed.

The first hosted page-reader checks fail before measurement: Ubuntu GCC's
fortified pread wrapper cannot prove the partial-read buffer offset is bounded.
Keep warning-as-error and Fortify. Read each chunk at the start of the fixed
buffer and advance the page offset by the number of complete returned entries;
short aligned reads retain every page, while invalid reads remain errors.
All15 reader/evidence controls pass locally with explicit Fortify3, including
the new short-read control. Previous measurement receipts retain their original
observer hashes; this does not relabel them as measurements of the revised
reader. Existing ordinary binaries, tests, limits and compiler pins are unchanged.

### Replay the actual PR115 iclass timeout without changing its workload

Sourcec22ad346 is the exact failed test merge and has the same tree as
head767c7690. Its hosted Module file has195 tests /1234 assertions and two
ten-second child timeouts, iclass and complemented-entry, with no outer memory
event. Freeze that source and compare43f2994b with408b03d9 at normal O2.
Generated C differs only at the32 Map clear and32 delete fragments.

The local Linux/aarch64 fixed reference/parent/repair/repair/parent sequence
is2.917 /5.929 /5.945 /6.198 /6.094 seconds, with original child hashes equal.
User plus system CPU is close to elapsed time. Both complete Module files
pass195/1240; Method-copy is1.543573492x /1.535259846x. This does not reproduce
the native x86-64 timeout and does not establish an iclass speed improvement.

The independent iclass-resource-replay job measures the same source, original
input and fixed order on native Linux/x86-64. CPU observations use wait4 for
the Ruby parent and waited descendants; all original stdout/stderr, inputs,
case identities, exits and resource prefixes are retained. The ten-second
child and600-second /2-GiB family bounds remain unchanged, including the
wrapper in the latter. There is no added GC, sleep, allocation policy or
retry-until-pass loop.11 acceptance controls reject altered input, enlarged
bounds, missing trials and waived failures. Both compilers' original timings
remain visible; the new job is not a claim of repair. The end-to-end runner
validation is recorded separately from the first experiment.

## Gem suites: adopt released Map-slot clearing without weakening gates (2026-11-21)

The released compiler `408b03d9` clears key/value backing slots after logical
Map deletion or clearing. This independently implemented fix removes stale
references without changing live/borrowed values, pins, retirement or collection
policy. Adopt it consistently in ordinary CI and all five upstream suite
workflows. Existing historical compiler/source comparisons retain their inputs.
No Mere implementation, library, build script, source lock or accepted snapshot
changes in this adoption.

Ordinary O2 source `0bae011f` has the same runtime as the preceding integration
`03a8ca31`. A metadata-only follow-up `8df2e278` is the actual recorded source
for the macOS gem run; its binary is unchanged. Both macOS and native
Linux/aarch64 retain the following original file results, identical to the
previous compiler43 measurements. Each file/side retains 600 seconds / 2 GiB.

| Gem | MATCH | RED | BOTH | MEMORY |
|---|---:|---:|---:|---:|
| minitest |4|3|0|0|
| public_suffix |7|0|0|0|
| rack |35|3|0|1|
| rack-test |7|1|0|0|
| base64 |1|0|0|0|
| matrix |2|0|0|0|
| logger |4|1|0|0|
| abbrev |1|0|0|0|
| singleton |1|0|0|0|
| forwardable |1|0|0|0|
| delegate |1|0|0|0|
| uri |10|0|0|0|
| rake |46|0|0|0|
| Total |120|8|0|1|

All 129 file classifications match the preceding integration; no accepted MATCH
is lost. Tests run offline with verified external source/dependency caches.
The original complete Rack Request file remains MEMORY.

macOS matches all 751 corpus programs in both hash-index modes in 475.314 seconds,
peak family RSS 1,085,344 KiB, under the existing 900-second / 2-GiB bound.
Refinement has the same 122 cases / 367 assertions and existing skip as the
reference. Method-copy passes 1.366086957x, reference 1.077448747x, retaining
all 21 prefixes. The first complete Module attempt retains a real complemented
RSS failure at 2.026762957x (77,135,872 to 156,336,128 bytes). Its one documented
noise recheck passes 195 tests / 1,240 assertions. Preserve both observations.

Native Linux Module passes 195 / 1,240 and Method-copy 1.612270451x. Native API 178,
fiber 16 and mkmf 14 contracts agree across reference, candidate and collection
stress; negative controls are rejected. These are validation results for the
combined leaf runtime, rather than measurements of every intermediate head.
Current-head hosted CI and latest-main per-file merge acceptance remain required.

The exact historical iclass replay also succeeds on native x86-64, before
8.509 / 8.179 seconds and repair 8.294 / 8.287 seconds. This does not establish
a repair of the historical timeout. Require both Method-copy pairs and healthy
reference controls in each pair; 18 evidence controls include the new P2
mutation, missing before evidence and the intentionally allowed failing before
interpreter. `bench/iclass_resource_r88.json` retains the native capture, while
`bench/compiler_map_slots_r89.json` retains every gem file, all Method prefixes,
actual source/binary identities and failed attempts.

The additional Linux corpus run reaches all 751 programs with the original
CI keep-going option, taking 394.222 seconds / 1,074,744 KiB.
It retains 750 matching programs and the existing `corpus/55_require_and_stdlib.rb`
difference when this private image has `HOME=/`: reference `~/x` expansion
normalizes the separator, whereas both compiler 43 and 408 builds produce the
same differing output. The full run remains failed; this is not counted as
all-green corpus evidence or silently excluded.

Before that run, the image's extra installed JSON 3.1.0 and Prism 1.9.0 shadowed
Ruby 4.0.9 defaults 2.18.0 / 1.8.2. A private isolated specification directory
retains the default versions and native bundled dependencies. Original
JSON /BigDecimal /Prism witnesses match reference /before /repair before the
complete run. The earlier setup failures and exact exclusion inventory remain
in the receipt. This changes neither the public test runner nor CI bounds.

## Gem suites: remove duplicate regexp-subject storage and untouched String copies (2026-11-22)

`rx_publish_at` saved its subject twice: once in a rooted private String
snapshot and again as raw bytes in a default-arena map. The released
compiler's generated `Map.set` calls `__mcopy_str` even when replacing an
existing value. Alternating large and small subjects therefore copied each
large subject again into the default region. Read the existing snapshot's
bytes instead, keep the encoding metadata, and mark that private snapshot
immutable. Named captures read the same snapshot. The caller's original
String is not reused as the snapshot.

Unmatched regexp splits and full-span byteslices also copied the entire
unchanged input. Share the immutable bytes beneath fresh Ruby handles.
Positive-limit literal splits stop searching at the requested limit rather
than splitting the whole tail and joining it again. Encoding, object
independence, frozen receivers, capture behavior and mutation remain covered
by corpus 764-766. The scanner matrix retains its existing implementation.

The ordinary O2 application source is `3be599c2`, compiler `408b03d9`.
`bench/request_subject_copy.rb` fixes a mutable 2-MiB input and 128 alternating
large/small matches, checking the capture checksum without manual collection,
warmup or delay. Compare against `ffdfa33c`, which already has the split and
byteslice changes. The fixed reference/before/candidate/candidate/before
peaks are **22,896 / 489,488 / 169,040 / 256,016 / 532,768 KiB**. All outputs
are `[2097152, 768, false]` and every process finishes within 600 seconds / 2 GiB.
These are focused observations, with the variability retained.

The original isolated Rack multipart tempfile-limit case retains its one
test / 130 assertions while moving from **1,413,056 to 1,146,704 KiB**.
The original isolated 128-MiB NUL case passes its one test / five assertions
at 1,745,472 / 1,744,736 KiB; no meaningful reduction is claimed for it.
The complete original Request file still fails every process in the fixed
before/candidate/candidate/before comparison: **2,147,360 / 2,120,784 /
2,154,704 / 2,283,536 KiB**, all MEMORY. References retain 404 tests / 1,754
assertions and two skips. Its stopping position varies even with the existing
seed 1; ownership of the remaining retained pages is unproven.

The five offline gem groups retain **13 gems / 129 files: 120 MATCH / 8 RED /
0 BOTH / 1 MEMORY**, identical file verdicts to the preceding compiler-408
integration and zero lost accepted MATCH. Sources, locks and accepted
snapshots are unchanged. All **754 corpus programs** match Ruby 4.0.9 with
the hash index ON and OFF in **499.256 seconds / 1,048,320 KiB**, within the
unchanged 900-second / 2-GiB aggregate bound.

The four complete core files retain identical before/after named cases and
summaries: Regexp 162 / 62,510, StringScanner 149 / 1,042 with its existing
two errors, Module 195 / 1,240, and Refinement 122 / 367 with its existing
skip. The Regexp reference itself fails `test_s_timeout_memory_leak` at
4.721222x; retain that failure. Both application sides pass its cases.
The original Method-copy gate passes **1.369198679x**, reference 1.081050228x,
with all 21 prefixes. All nine original loop RSS checks pass their 1.6x bound;
dead/duplicate definitions, GC roots and bracket depth **155/1024** pass.

`bench/request_subject_copies_r97.json` preserves actual source/binary/C
identities, every gem row, core case identities, Method prefixes, complete
failed Request comparisons and raw-log hashes. Broader frozen-caller-input
reuse and scanner anchor rewriting were tried and withdrawn; their observations
are not attributed to the final runtime. The private ledger retains those
unpublished attempts and uncertain lifetime observations.

Final local Linux execution was unavailable because Docker's content store
returned input/output errors. Do not relabel earlier Linux results as this
source; require current-head hosted Linux CI. No collector, native pin,
threshold, test workload, API exclusion, top-level value, VM, AST or C API
implementation changed. Existing hosted Method-copy failures on other stacked
heads also remain merge gates; this local result does not waive them.

## StringScanner: keep skip entries independent and avoid unused search Strings (2026-11-22)

`skip` called Ruby's `scan`, and `skip_until` called Ruby's `scan_until`.
A subclass overriding those public methods therefore changed the skip
results and prevented the pointer from advancing. CRuby's skip entries run
their own scan. Use the existing internal matching worker directly instead:
the corpus subclass now returns 1 with position 1 and then 3 with position 4,
without calling either override. The preceding runtime returned 8 and left
position 0 after each call.

The shared search worker also built a String spanning everything from the
pointer through the match even when `exist?`, `skip_until` or `search_full`
only needed its byte count. Keep the same MatchData and scanner state but
return `end - start` directly in those cases. String-valued searches retain
their existing slice. Changed Ruby methods are `StringScanner#skip`,
`#__search`, `#skip_until`, `#exist?` and `#search_full`; regenerate their
existing `pathname_lib_src` body. Interpreter/GC/VM/C API implementation,
compiler pins, source locks, accepted snapshots and top-level values do not
change.

Ordinary O2 source `0f5aae57`, compiler `408b03d9`, is compared with parent
`9bd00c1a`. The fixed 8-MiB / 24-search workload in
`bench/scanner_search_lengths.rb` retains the checksum
`[8388608, 201326592, 0, "z"]` without manual collection, warmup or delay.
The reference/before/candidate/candidate/before child peaks recorded by
wait4 are **35,312 / 255,760 / 122,976 / 122,960 / 255,680 KiB**. The existing
600-second / 2-GiB process-family supervisor covers the wrapper and child;
its sampled family peaks are retained separately. The first sampled-only
reference observation missed its short child's actual peak and reported
32 KiB. Keep that incomplete observation, and use the kernel peaks from the
same repeated fixed sequence for the resource comparison.

The complete original Rack Request file remains MEMORY in every fixed
before/candidate/candidate/before run: **2,399,232 / 2,224,864 / 2,127,920 /
2,245,024 KiB**. References retain 404 tests / 1,754 assertions and two skips.
Selected multipart observations are 1,147,792 / 1,152,416 KiB, retaining one
test / 130 assertions. The selected 128-MiB NUL case is 1,869,552 / 1,606,400
KiB, retaining one test / five assertions. These do not establish a repair
of the whole file or a causal improvement of that NUL path.

All named cases and summaries in the original Regexp, StringScanner, Module
and Refinement files are identical before/after. StringScanner retains its
existing two errors; the Regexp reference retains its own memory assertion
failure. Module passes 195 / 1,240, Refinement retains 122 / 367 with its
existing skip, and Method-copy passes **1.372842949x** with all 21 prefixes
(reference 1.080407701x). The nine original loop RSS checks, dead/duplicate
definitions, GC roots, record hygiene and bracket depth **155/1024** pass.

A separate byte-position shortcut was withdrawn: it trusted a String's
overridden `length` and made `charpos` wrong. Corpus 767 retains byte/character
positions across mutations and encodings, including that override; corpus
768 covers integer/String search results, match state, unscan and native skip
dispatch. No position shortcut or its measured gains are part of this source.
The paired preceding runtime also exposes a native UnboundMethod binding
redispatch gap; keep it in the semantics coordination ledger rather than
editing the shared dispatchers here.

The final five-group offline sweep retains **13 gems / 129 files: 120 MATCH /
7 RED / 0 BOTH / 2 MEMORY**, with zero lost accepted or preceding MATCH.
Logger's formerly RED LogDevice file now reaches MEMORY; keep that changed
verdict. Its separate fixed parent/candidate/candidate/parent recheck is also
all MEMORY: **2,182,912 / 2,344,288 / 2,366,736 / 2,267,744 KiB**, with healthy
27-test / 124-assertion references. No baseline is replaced. Read-only copies
of the monitor's existing PID/RSS table show the root itself holding the large
RSS at the guard, rather than establishing an aggregate-of-children cause.
One parent diagnostic completes at 1,772,160 KiB with its known assertion
failure; the candidate diagnostic remains MEMORY at 2,613,664 KiB. Keep all
observations and the uncertainty about the retained allocation's owner.

All **756 corpus programs** match Ruby 4.0.9 with the hash index ON and OFF in
**598.656 seconds / 1,193,568 KiB**, within the unchanged 900-second / 2-GiB
aggregate bound. `bench/scanner_search_copies_r100.json` keeps every original
gem row, core case, Method prefix, kernel/family measurement, failed complete
Request and Logger comparison, diagnostic and raw-log hash. Local Docker
content-store reads still fail with input/output errors, so current-head
hosted Linux validation remains required. Keep the candidate draft until
hosted checks, latest-main per-file comparison, parent integration and review
pass. The existing hosted Method-copy failures remain separate merge gates.

## Native comparator review repairs: final validation

PR #142 retains original native comparator owners through aliases and native
Method installation. Module and class wrappers invoke saved native entries;
Kernel#=== rebound as Module#=== retains equality semantics for super.
Existing initializers record physical native entries without adding top-level
state. Functions: invoke_val_c0, native_case_entry, native_case_alias_owner,
run_super_target, set_builtin_alias. Corpus 743 covers the review regressions.

O2: 721/721 corpus programs match in both hash modes, 480.426 seconds and
1,284,944 KiB under unchanged 900-second/2-GiB bounds. Sixteen focused cache
comparisons and nine RSS cases pass, as do roots, depth 155 and dead definitions.
Original Module/Method/Super: 342 MATCH and one existing RED over 343 cases;
no previously passing case is lost. Parent #141 documentation is integrated.
The additional already-rebound comparator alias diagnostic remains explicit
in unittest/module_kernel_comparator_alias_probe.rb and KNOWN_GAPS.md; it
fails identically on prior main, parent #141 and candidate. The ineffective
broader alias-copy change was reverted. Hosted checks and per-file comparison
remain required before merge.

### Preserve an already-selected native comparator under Module prepends

run_super_target now reads native provenance through the new exact-entry
native_case_alias_entry_owner helper. Ordinary alias dispatch continues to
resolve ancestors through native_case_alias_owner; selected super targets
must not restart at an earlier prepend. Corpus 743 adds a Module-level
forwarding comparator and both matching/nonmatching cases.
All 16 focused comparisons and the complete Module/Method/Super files retain
342 MATCH and one existing RED over 343 cases. A fresh full sweep is running.
The additional saved-native-Method diagnostic fails on the preceding main
integration and #141 parent as well as the candidate and remains explicit
in unittest/module_saved_comparator_method_probe.rb and KNOWN_GAPS.md.


### Captured native comparator Methods keep their body after prepends

A captured native comparator can reach bi_meth_call after a Ruby prepend
shadows its name. Its recorded Module, Kernel or Range owner now selects the
existing native_case_equal body directly. The selected-super repair from
11d87d93 is preserved. This follow-up edits bi_meth_call and adds corpus 749;
it adds no global state or placeholder native implementation.

The final ordinary O2 source is 8e060d3f, using the exact CI compiler
01f5ad73. Corpus 741, 743 and 749 match Ruby 4.0.9 in all four hash/MRO cache
combinations (12 comparisons). The retained saved-comparator probe now prints
true/false on both runtimes. Original Module passes 195/1240 and Super50/109;
Method98/554 keeps the same single compaction skip, with its complete 98-case
verdict dictionary identical to the retained baseline. The three files retain
342 MATCH and one existing RED over343 cases. Original Method-copy passes at
1.679902x, reference1.084765x. All original assertions and resource bounds stay
in force. All 722 corpus programs match in both hash modes: 520.933 seconds and
1,290,080 KiB peak family RSS, within the original 900-second / 2-GiB bound.
This was measured at 8e060d3f before the documentation-only follow-up.

## 2026-11-22 (78): what an explicit GC.start gives back -- test_module's complemented-method-entry leak test on macOS

**The point.** `TestModule#test_complemented_method_entry_memory_leak` fails on main's macOS unittest shard every run: RSS 2.22-2.30 times its start, against ruby's limit of 2.0. The shard keeps the run green, so it went unnoticed. It is no leak. Retained memory after the final GC.start is 55-62 MB whether the loop runs 60,000 or 600,000 times. A loop that makes and drops classes grows two things that an explicit GC.start did not hand back:
- **The method store (meths_g).** Its arena swings between 8.4 MB and 33.6 MB under that churn, while it holds about 1,270 live rows. compact_method_store copies it only once it doubles.
- **Mere's region cache.** mem_trim emptied it only down to eight regions, and those eight held grown blocks: the collector's own scratch (GCC 7.3 MB, GFX 6.3 MB, CSD/CSC 4 MB), 28 MB in all. Only the cache cap that mem_trim enforced was below what they held.

**What changed.**
- `compact_method_store force` copies the store whenever it grew at all since the last copy, when the collection is an explicit GC.start (gc_state "explicit"). The automatic collector keeps its doubling rule.
- Mere 90d05895 (merelang/mere#87): a trim after real work releases every cached region. Real work means at least 4,096 region acquisitions since the last trim. A trim right after another, as in a loop of GC.starts, keeps them as before. MERE_REF moves to it.

The same Mere commit also fixes eq_<tag> for values holding a float: a tuple, record or variant with a float never equalled even itself in the C backend.

**Measured** (locally, under the test's own harness; it fails on CI's macOS, which kept the loop's peak after GC.start):
- the leak test's ratio, 1.51 -> 1.32;
- 2,000 GC.starts with 20,000 live Strings, the same instructions as before (55.8e9);
- test_module 195/195.

Neither the collection floor nor the class-time floor is touched. LOOP (86) showed that raising them only makes the ratio worse.

## 2026-11-21: reduce clone cache residency without losing the Method-copy gate

PR #109's Linux job 136752758452 fails the original Module clone leak check:
71,696,384 to 144,699,392 resident bytes, **2.018224406x**, under compiler
01f5ad73. The failed test-merge source 1533737c has the same tree as head
5813b8d6. Both compilers are compared on that exact source, ordinary O2,
with the original upstream input and ten-second child timeout.

Published compiler 43f2994b clears discarded cached-region pages with Linux
MADV_DONTNEED rather than writing zeros into every page. Restoring its clear
helper and call makes the generated C byte-identical to 01f5ad73. Neither
the native cache's default of 64 regions nor live or pinned storage changes.
On Linux/aarch64, the predeclared parent/candidate/candidate/parent clone
order gives **1.818147056 / 1.150605110 / 1.348688635 / 1.671946690x**.
The old compiler also passes locally; this is evidence of reduced residency,
not a reproduction of the x86-64 hosted failure on the same runner.

The compiler-only candidate fails the independent Method-copy gate at
**2.118446692x**, so that change alone is insufficient. Backport the existing
compact_method_store correction from #114: if native compaction is deferred
and the arena has not shrunk, preserve the previous measured baseline.
The thresholds, dirty flag, initial baseline and unmeasurable fallback are
unchanged. The combined source 6d8d563d passes two Linux clone trials at
**1.264892127 / 1.301888908x** and two Method-copy trials at
**1.705846868 / 1.704296585x**. Module **195/1240** and Refinement
**122/370** match every reference case. macOS Method-copy is **1.385781495x**
and Refinement **122/367, one reference-matching skip** is unchanged.

Keep the failures: the compiler-only macOS Module runs fail complemented-entry
at **2.051378446x** and **2.037586135x**. The first combined macOS Module run
also fails that case at **2.018579686x** and times out in the original iclass
child. The retained serialized comparison follows the corpus runs; no
assertion, test or timeout is removed. In that comparison, the compiler-only
baseline still fails complemented-entry at **2.030891254x**; the combined
candidate passes **195/1240**, loses no passing cases, and the iclass timeout
does not recur in either run. Both sources also pass **721/721 corpus** in
both hash-index modes: 529.512 seconds / 1,104,752 KiB for compiler-only,
524.786 seconds / 1,187,728 KiB for the combined candidate.
The separate instrumented Linux clone
observes deferred compaction with zero increases to an established baseline
without movement.
Its success is diagnostic evidence and cannot replace an ordinary gate.

[The measurement receipt](bench/module_clone_cache_r82.json) preserves the
hosted failure, all compiler controls, original case dictionaries, all 21
Method-copy samples per trial, corpus results and the serialized macOS
comparison. The identical retained Method-copy program can be rerun with
`python3 tools/method_copy_memory_check.py --reference /path/to/ruby --output /path/to/results`.
All per-file checks retain 600 seconds / 2 GiB; the complete corpus keeps its
900-second / 2-GiB aggregate guard. Current hosted checks and comparison with
the latest completed main remain required before merge. This follow-up
changes only m_state.compact_method_store in the runtime; collector bodies,
native pin policy, ISeq, AST/Prism and C API implementations are unchanged.

### Class-subclasses integration with current main

Integrate main a206da11 into PR #125, preserving both subclasses and extend
branches of defined_super_str. Documentation retains both independent
appendices; no other runtime conflict requires manual resolution. The O2
runtime matches corpus717/718/720/729/730 in all four hash/MRO modes (20
comparisons), and roots/depth155 pass. Current hosted full checks remain
required. The prior Linux clone RSS failure remains recorded; this merge
and the focused comparisons do not establish its repair or waive its gate.

### Native notification repair after the updated class-dispatch parent

Integrate the repaired #125 parent without manually changing a runtime
function. The normal O2 runtime matches all 721 corpus programs in both hash
modes; all 28 focused comparisons include the new Module-subclass notification
and native-super cases. The original Module/Method/Super files retain
342 MATCH and one existing RED across 343 cases (Module 195/195). Nine RSS
workloads, roots, depth 155 and dead definitions pass. The earlier 708-program
result remains tied to its preceding integration; current hosted checks and
every-file comparison still gate this head.


## Deliver Class registry and Module notification repairs directly to main

PR #132 previously targeted the closed, unmerged Class branch. Deliver both
reviewed repairs together against main, preserving the Ruby subclasses registry
and real Class native entry alongside the Module notification owner protocol.
Integrate main 2e2ab568 without manually resolving any runtime conflict; both
independent documentation records are retained. The generic alias-origin and
saved native metadata issues #124/#133 remain outside this repair.

Normal O2 runtime 732c99ab, compiler 01f5ad73: all 723 corpus programs match with
hash indexing ON/OFF (538.321 seconds / 1,113,104 KiB under unchanged 900-second /
2-GiB bounds). All 36 focused hash/MRO comparisons, nine RSS cases, roots,
depth 155 and dead definitions pass. Original Class/Module/Method/Super/Refinement
cover 527 cases / 525 MATCH / 1 existing RED / 1 BOTH, with no file below completed
main d9826ac9. Class uses its unchanged native fixture built separately against
each runtime's own headers and passes all 62 cases. The earlier missing-fixture
context remains diagnostic; the final Class comparison has a healthy reference.
All 49 captured Mere-source/binary hashes stay fixed.

The actual unchanged Rails RakeCommand registers and is found on both runtimes
in a separate saved-own-gems diagnostic (reference 0.692 seconds, candidate 1.490).
The original migration CLI on a fresh unchanged app then reaches the next Hash
configuration setter issue #123, exit 1 in 2.538 seconds / 306,800 KiB; reference
migration passes. This diagnostic reuses each runtime's independently built
gems and is not a cold installation or an accepted six-stage application pass.
The previous main Rails measurement and all NOT_RUN states remain unchanged.
No source lock, original test, exclusion, API inventory or bound changes.
Current-head hosted CI, full file comparisons and review still gate merge.


## 2026-11-22: preserve Class visibility owners and their selected Method bodies

PR 132's remaining review reproduction makes an inherited subclasses entry
private. Its bound and unbound super_method wrongly selected Class again,
and a prepend before the visibility entry skipped its observable owner.
The Class paths now use native_owner_method_after, the existing notification
Method traversal parameterized by its real native owner. Ordinary dispatch
and defined?(super) retain their implementation-chain query.

When that traversal selects a visibility-only Class entry, record the actual
body below it using existing Method definition metadata and native provenance.
Blockless and block-carrying Method calls share class_subclasses_method_call;
UnboundMethod binding, copies and to_proc retain the same selection and block.
No new top-level value, collector/pin/state, VM, AST or C API implementation
is changed by this repair. Changed existing functions: invoke_val_c0,
invoke_with_block0 and module_notification_method_after; the new and-helpers
are native_owner_method_after, class_subclasses_method_note and
class_subclasses_method_call. Main 49ad01e3 merges without a runtime conflict;
both independent documentation records are preserved.

Ordinary native macOS O2/compiler 408b03d9 source f3d22a1a versus
parent 161b40d0: all 72 focused default/evaluator/strict-VM and hash/MRO
comparisons match Ruby 4.0.9. Corpus 770 includes actual calls and yields,
private/protected/public visibility, singleton and Class prepends, inherited
Ruby bodies, bound/unbound methods, copies and to_proc. The original literal
review returns [nil, nil], versus the parent's [Class, Class].

Five complete original files retain 527 cases / 525 MATCH / 1 existing RED / 1 BOTH,
without a passing parent case lost. Class 62 uses its original own-header
fixture on both runtimes; parent/candidate 10,255 assertions versus reference 10,355
is retained as an existing difference. Module 195/1240, Super 50/109 and the
existing Method/Refinement skips remain unchanged. All nine existing loop RSS
gates and dead/duplicate definitions, GC roots, method writes, record hygiene
and bracket 155/1024 pass. Top-level let count remains 136.

All 748 corpus programs match in both hash-index modes,
488.748 seconds / 1,284,080 KiB under the original 900-second/2-GiB
bound. The first pre-final candidate's block-carrying probe failed and its
partial corpus was stopped; it is not counted as this final complete pass.
The receipt unittest/class_subclasses_visibility_review_r102.json retains
all actual identities, cases, mode comparisons, hashes and fixture context.
No original tests, accepted baselines, locks, exclusions or limits change.
Fresh hosted CI and latest-main per-file acceptance remain required.

### PR review: retain selected native Class methods behind prepends

Once the remaining-chain query selects Class's native subclasses entry,
mark that exact owner directly instead of searching Class's prepends again.
The new native_owner_method_mark helper is shared with Module's existing
marker. Both bound and unbound super_method preserve the selected Class
owner; method_unbind_fields carries an already-proven native owner into the
UnboundMethod. Changed functions: invoke_val_c0, method_unbind_fields,
module_notification_method_mark and new native_owner_method_mark.
Corpus724 adds Class.prepend with bound/unbound super_method, dup, clone,
unbind, bind and bind_call, including the native terminal super_method.
The original review reproduction and extra unbind comparison failed before
these repairs and now match Ruby4.0.9.

Normal O2 compiler01f5ad73 validation: **723/723 corpus**, hash index ON/OFF,
**488.378s / 1,070,864KiB** peak family RSS. All44 focused default/evaluator/
strict-VM and hash/MRO comparisons, all nine RSS gates, roots, dead definitions
and C depth155/1024 pass. Complete original Class/Module/Method/Super/
Refinement discover527 cases: **525 MATCH / 1 existing RED / 1 BOTH**, with
Class62, Module195, Method97, Super50 and Refinement121 MATCH retained.
Class's unchanged fixture uses each interpreter's own headers. The existing
Method compaction failure, Refinement skip and separate captured-native
metadata issue133 remain explicit. No original tests, exclusions, limits,
collector/state, VM/ISeq, AST/Prism, C API or gemtest code changed. Updated-head
hosted checks and the latest-main per-file gate remain required before merge.

### PR review: lexer context for continuations and class method heredocs

Record a continued newline only when the lexer consumes a backslash in code.
Comment and literal scanners never record it. Nested interpolation lexers use
separate invocation numbers and restore their parent's context; consumed
continuation entries are removed after lexing. The existing tc_st map holds
this context, with no additional top-level state. after_class_kw also checks
the preceding significant character across whitespace, so receiver `. class`
and `:: class` calls keep their bare, indented and quoted heredoc arguments.
Changed functions: lex_go, new lex_go_step/lex_cont_key/lex_cont_go,
lex_go_b, after_class_kw and prev_nonspace. Corpus761/762 adds both review
reproductions, tab/newline separators, comment-ending backslashes, quoted
hash bytes, real continuations, nested interpolation and repeated eval.

Normal O2 with the CI-pinned compiler01f5ad73: **721/721 corpus** matches
Ruby4.0.9 with hash index ON/OFF, **483.813s / 1,089,488KiB** peak family
RSS. All nine existing RSS gates, roots, dead definitions and C depth155/1024
pass. Corpus761-763 matches all36 evaluator/default/strict-VM and hash/MRO
comparisons. Three complete original Parse/Syntax/Literal files retain
**300 MATCH / 1 RED / 2 BOTH** across303 cases, identical per-file counts
to successful main d9826ac9. The existing Syntax invalid-symbol leak Timeout
and both reference skips stay visible. An initial nonexistent test_heredoc.rb
selection was rejected as incomplete; only the real test_literal.rb result
is counted here. No original tests, exclusions, API or resource limits change.
Hosted checks must still finish on the updated head before merging.

The follow-up review found the receiver's separator lost again when a comment
or a continuation stands between it and `class` (`p o. # note`, then
` class <<-EOS`; also `o::`, and a comment-only line between). The lexer now
records each comment it skips the way it records a continuation -- keyed by
the newline that ends it, holding where it began, removed once the rest of
the source is lexed (lex_comment_key) -- and after_class_kw's look back
passes over both. corpus/761 holds the five forms, and a real
`class <<self` after comment lines. 721/721, the VM's 761-763 the same, and
the twelve gems the same on both sides.

## 2026-11-22 (79): an alias round trip, and a Method made of a builtin (issues #124, #133)

Two of the open issues, both in what a method entry remembers about where it
came from.

**#124.** `alias saved example; alias example saved; def example = super`
raised "super: no superclass method 'saved'", the new definition's frame
labelled `AliasChild#saved`. The `alias` keyword (do_class_alias) recorded the
name it was given as the source, where alias_method already resolved an alias
of an alias to the first definition: example -> saved was kept, and a `def`
over it kept it too. The keyword now resolves the source's own pair (name and
origin) and drops the row when the name comes back to itself; and a new
definition -- every `def`, `define_method` with a block, `attr_*`, through
stamp_named_meth_src -- clears this key's alias_srcname and alias_origin. A
Method that captured the old entry keeps its own snapshot (msnap_save), so it
still answers for the old definition. corpus/776.

**#133.** `saved = Array.instance_method(:length)` then `def length(a, b =
nil)` made `saved.arity` -2 and its parameters the new method's. A Method or
UnboundMethod made of a builtin is marked so where it is made (bi_meth_mark:
`@~m_bi`, `@~m_biown`), and is called through the builtin for good; its
#arity and #parameters now read the builtin's metadata by that owner too,
once a Ruby definition has taken the name over (bi_meth_native;
bm_params_core with the method table set aside) -- before that the ordinary
reading is already the builtin's, and it alone knows a singleton's label:
`Dir.method(:glob).parameters`, Prism's named ones, went empty when every
marked Method took the new path (corpus/499 caught it). The
definition hooks had no arity row at all -- `Module.instance_method(:included)`
said -1 and [] where ruby says 1 and [[:req]] -- because the generator reads
public instance methods only: tools/gen_arity_table.rb now reads the eleven
private hooks the same way (nothing called), and only those rows were added
to the table (regenerating the whole table would drop rows added since).
corpus/777.

## 2026-11-22: module_function on an inherited method, String#encode on a subclass, IO#wait on a dead descriptor, and an inherited SIG_IGN

Four small differences listed in note 553 §6 as the interpreter's own (not
the C API's), and two met on the way.

**module_function.** `include E; module_function :y` left
`U.private_instance_methods(false)` empty: the entry was only made private
where the module already had one. ruby's rb_export_method writes a private
copy into the module for an inherited one, so modfunc_promote now copies the
entry (copy_meth_src, and alias_origin set to the module it came from, as
alias_method records, so the copy's `super` resumes above that module). A
module's copy that runs out of `super` said "for class U"; ruby says "for
module U", and an anonymous one by its inspect (`#<Module:0x...>`), where
this said `AnonModule_1` (super_missing_msg).

**String#encode** on a String subclass's instance answered a String; ruby's
str_encode duplicates the receiver, so the result is of the subclass. The
encode arm's result is tagged with the receiver's class (str_keep_sub, the
hng_store tag dispatch_cls_of reads); encode! answers the receiver itself.

**IO#wait on a descriptor closed behind the stream's back**
(`IO.for_fd(r.fileno).close`) answered the stream as ready: poll(2) reports
POLLNVAL, which the bits read as ready. ruby raises Errno::EBADF from wait,
wait_readable and IO.select. IO.__sel_wait now asks IO.__fd_ok of a
descriptor that came back ready and raises EBADF for a dead one -- only when
something came back, so a wait that blocks pays nothing. On the way:
wait_writable on a read end answered nil where ruby raises "not opened for
writing", and io/wait still defined `IO#ready?`, which io-wait 0.4 (ruby
4.0's) removed (ruby: NoMethodError; it answered nil here). The shipped
io/wait is now a comment, not empty: an empty source is "not shipped" and the
search would go on to the reference's file.

**A process started with SIGINT ignored** (`cmd &` in a non-interactive
shell, or `trap '' INT; exec ...`): ruby's install_sighandler keeps an
inherited SIG_IGN for the signals it handles, so `trap("INT", "DEFAULT")`
answers "IGNORE" and `Process.kill(:INT, $$)` is dropped. Here it answered
"DEFAULT" and raised Interrupt -- corpus/394 printed one line more when the
corpus ran under `&`. signal_inherited_ign asks once per name, the first time
it matters, with Mere's proc_sig_catch keep rule (an inherited SIG_IGN is put
back and reported; otherwise the default is given back at once), and
signal_initial / signal_deliver_self read it.

Not done here: Mere's spawn sets SIGINT/QUIT/TERM/HUP/PIPE to the default in
the child (POSIX_SPAWN_SETSIGDEF), so after `trap("INT", "IGNORE")` a child
does not inherit the ignore, where ruby's does. That is Mere's runtime
(codegen_c's spawn), recorded in KNOWN_GAPS.md.

corpus/778.
