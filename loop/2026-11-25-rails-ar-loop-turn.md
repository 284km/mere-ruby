# Rails-2: Kernel#loop is a frame of its own, and a turn's garbage goes with the turn

Rails-2 round 4 (activerecord, sqlite3 adapter): eager_test was stopped at its memory limit (2 GiB) in its last class, `EagerLoadingTooManyIdsTest`.
Its fixture, `citations.yml`, makes 65,536 rows with ERB. `YAML.load` of it grew about 130 MB per thousand rows and was past 6 GB when stopped by hand.

## The cause

Psych's parser here is `lib/psych_parser.rb`, in Ruby. `__block_map` reads a mapping's entries in `loop do ... end`.

A collection in the middle of a statement roots what each frame's statement has built so far: the ids from where the statement began to where the frame last called out (`fb_wm`).
`Kernel#loop` ran its turns in the caller's frame, so every turn's garbage was built by the one statement `loop do ... end`.
Nothing a turn made could be collected until the loop ended. `GC.start` inside the loop gave back nothing.

`times` and `each` do not keep it: a builtin runs in a frame of its own, with no env, and `run_block0x` starts that frame's interval again at each yield (note 270).

Measured with the same body (an Array, a String slice, a small Array) over 400,000 turns:

| | peak RSS growth | collections |
|---|---|---|
| `loop`, before | +241 MB | 5 |
| `loop`, after | +28 MB | 20 |
| `times` | +27 MB | 20 |
| `while` | +28 MB | 20 |

## The change

- `run_loop_builtin` pushes a builtin frame, `Kernel#loop`, as `ps_frame` does for `public_send`: the caller's interval ends where the loop is entered, and the loop's own starts again at each turn.
  The turns are `run_loop_turns`, unchanged apart from a safepoint at each turn, as an iterator's turn has (`run_block_turn`).
- ruby's backtrace has that frame too, `in 'Kernel#loop'` at the line of the call. Here it was missing, in `caller`, `caller_locations` and an exception's backtrace.

## Checked

- tools/loop_rss_check.rb has a `Kernel#loop` case: 2.06 before (FAIL), 1.01 after (ruby 1.00).
- corpus/1063 (new): the labels and lines of `caller_locations`, an exception's backtrace, a loop nested in an iterator, and `break`, `next`, StopIteration's result, `return`, `throw` out of a loop. It matches ruby on both engines; main differs from the first line.
- The fixture's YAML at 16,384 rows: 64 s and +2.16 GB before, 67 s and +0.97 GB after. Parsing to events only, 4,096 rows: +384 MB before, +62 MB after.
- `./run_corpus.sh --both`: 952/952, plain and with `MERE_RUBY_VM=1`.
- Gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth, loop_rss.

## Left

- eager_test still does not fit: the node tree of 65,536 rows is live while it is built, and each live object costs about 3.6 KB of RSS here (ruby: about 200 bytes a node).
  `GC.start` with live-object counts during the build shows only the tree's own nodes, arrays and strings growing. So it is the cost of an object, not garbage.
  At 16,384 rows that is +0.97 GB, so 65,536 rows need about 3.9 GB.
- The time is unchanged: about 4 ms a row, about 1,000 times libyaml's. `String#index` on a binary String takes time in proportion to the String's length (70-80 us at 64 KB), and the parser searches a 64 KB binary window with it, about 15% of the time.
