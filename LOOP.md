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

### 1. Parallelise the sweep — 30 min to an estimated 5-6 min

The sweep is sequential and the machine is not: 1809s of wall clock for 1051s
of CPU (585 user + 467 sys) is **0.58 cores of ten**. Groups are independent
and each writes its own tag file, so the work partitions without contention;
`SPEC_STATUS.md` is merged at the end as it already is.

⚠ The shared tree is what makes this need care. Workers must not share ONE
tree, because a spec that writes into it would then race with another worker
rather than merely follow it. The shape is **one tree per worker** — six
clones, not 2,498 — which keeps today's win and adds the parallelism on top.

Verified the same way: every row identical to the sequential record.

This is the largest remaining lever by a wide margin. Six sweeps a day goes
from thirty minutes to five.

### 2. `-O0` for the probe loop — 82s off every build

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
