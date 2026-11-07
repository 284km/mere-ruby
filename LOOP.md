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
