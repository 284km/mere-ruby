# A loop on one line, and the collector's watermark on the VM

#260's review found the VM's memory growing in a loop with no formatting in it at all:

```ruby
n = ARGV[0].to_i; x = "ab"; i = 0; while i < n; s = x + "c"; i += 1; end; p s
```

Under `MERE_RUBY_GC_TIGHT=1` the VM's maximum RSS was 101 MB at 100,000 turns and 301 MB at 800,000, about 300 bytes a turn; the evaluator's was flat. The same loop written over several lines was flat on the VM too.

## Why the line mattered

The collector does not take what was made since the current statement of a frame began: such a value may still be held by a C frame of the statement (the statement watermark, `fb_wm`). A statement's start moves the mark (`fb_wm_stmt`). On the VM, an instruction that starts a statement (a line event) with nothing on the stack is that start: `vm_step` winds the stack back, moves the mark and lets a collection run.

A loop on one line has no statement start inside it. For that, `vm_run_stmt` ends a turn at one backward jump in 64 and lets a collection run there, but it did not move the mark. So everything every turn made stayed younger than the mark, and nothing of it was collected. The allocations that stayed were the Strings the turns made (`mkstr` from `vm_step`) and the copies `setlocal` made into the frame's env.

Neither the top level nor `while` was the point: a one-line loop in a method or a block grew the same, and an `Integer#times` block does not, since each call of the block starts a statement.

## The change

At a turn's end, with nothing on the stack, the mark moves too (`fb_wm_stmt`), as at a statement's start: the turn's values are on the VM's stack, which the collector reads, or in the env.

## Numbers

Maximum RSS under `MERE_RUBY_GC_TIGHT=1`, on the VM:

| program | turns | main | here |
|---|---|---|---|
| the loop above | 100,000 | 101.0 MB | 86.5 MB |
| | 800,000 | 301.1 MB | 86.6 MB |
| the same, `x + "c"` not assigned | 800,000 | 301.0 MB | 88.5 MB |
| `s = [1]` | 800,000 | 263.2 MB | 85.0 MB |
| `s = i.to_s` | 800,000 | 219.0 MB | 84.3 MB |
| the loop in a method | 800,000 | 282.4 MB | 88.8 MB |
| the loop in a block | 800,000 | 285.8 MB | 92.9 MB |
| the loop over several lines | 800,000 | 86.3 MB | 86.4 MB |

Without the tight setting, the median of three runs alternating main and this branch, 800,000 turns:

| program | main | here |
|---|---|---|
| the loop above | 225.5 MB, 12.71 G instructions | 106.7 MB, 12.95 G |
| the same over several lines | 106.5 MB, 14.00 G | 106.5 MB, 14.00 G |
| the loop in a method | 277.9 MB, 12.92 G | 103.5 MB, 12.68 G |
| `i += 1` alone | 92.0 MB, 2.42 G | 92.1 MB, 2.42 G |

The instructions move by the collector's own work, which now finds something to take.

## Recorded

A loop that makes nothing, `while i < n; i += 1; end`, still grows a little on the VM, and as much over several lines: 70 MB at 100,000 turns, 91.5 MB at 800,000, 99.6 MB at 1,600,000, under the tight setting (the evaluator: 69.7, 74.6, 74.7). It slows as it goes; not this round's.

CHECKED
