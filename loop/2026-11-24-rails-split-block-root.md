# String#split and Array#zip with a block: what a collection took

`ActiveSupport`'s `json/encoding_test.rb` stopped before its first test in
the framework measurement of `68588737` (main `03c2869a`'s runtime), at
`require "bundler/setup"`:

    Your bundle only supports platforms [] but your local platform is ruby

By hand the file passed. Under the harness it failed or passed depending on
how many environment variables there were (one more or one fewer passed; four
more failed again). `MERE_RUBY_GC_TIGHT=1` made it pass and
`MERE_RUBY_GC_STRESS=100` made it fail with any environment. The value was
never the problem. The difference was when a collection came.

## The cause

Bundler's `LockfileParser` reads the lockfile with
`lockfile.split(/((?:\r?\n)+)/) { |line| ... }`. With a block, `split` builds
every piece first (`prim_method recv "split" args`, an Array) and then
yields them one by one from `deref aid`. Nothing roots that Array:

- the builtin's frame starts its watermark interval again at every yield
  (`run_block0x`, "when the caller is a BUILTIN"). That interval was made
  to keep `300_000.times { ... }` from rooting everything the loop built;
- the rule there says that what a builtin keeps from earlier turns, it holds
  in C variables, which the stack scan reads. This walk held only the list
  taken from the Array.

A collection in the block's body swept the Array and the pieces not yet
yielded. They were yielded as `""`, and the parser, which skips blank lines,
never saw `PLATFORMS` or its `ruby`.

Shrunk, without Bundler (`MERE_RUBY_GC_STRESS=20`):

    ("line one\n" * 3000).split(/\n/) { |l| ... }   # "" from the 12th piece on

`split(...).each`, `scan`, `gsub`, `each_line`, `each_char` and the others
the survey below tried did not lose anything.

## The change

`iter_held` keeps a value in `gc_hold`, which is a root, while the body runs.
The key is the call depth plus the Array's id, and the entry is removed
afterwards, also when the body fails. The `split` arm walks its pieces inside
it, and so does `zip` (below). The evaluator and the VM both reach these arms.

Witness: `corpus/936_block_walks_of_built_arrays_under_gc.rb`. It turns on
`GC.stress` and parses a small lockfile the way Bundler does, then splits with
a Regexp, with a capture, with a String and in awk mode with a limit, then
zips with a block. Before the change it printed `["GEM"]`, `[]` for PLATFORMS
and 49 empty pieces of 60, and stopped at the zip. It now matches ruby on the
evaluator and on the VM.

## The survey

Other builtins that build their whole result before the first yield, run with
`MERE_RUBY_GC_STRESS=3` on the build before and after the change, each compared
with the same call without a block ("same": every yielded value equal):

| case | before | after |
|---|---|---|
| `split(/\n/) { }` | 11th of 40 differs | same |
| `split(/(\n)/) { }` | 11th of 80 differs | same |
| `zip(...) { }` | stops: `map_get: key not found` | same |
| `split("\n")`, `split` (awk), `each_line`, `lines`, `each_line(chomp: true)`, `chars`, `each_char`, `grapheme_clusters`, `each_grapheme_cluster`, `bytes`, `scan` (with and without groups), `each_slice`, `each_cons`, `Hash#each` (one and two parameters), `Hash#map`, `Hash#select`, `each_key`, `each_value`, `each_with_index`, `combination`, `product`, `digits.each`, `sort_by`, `group_by`, `each_entry`, `Float#step`, `partition`, `String#upto`, `each_char.map` | same | same |

`zip` stopped only when its argument was built in the same statement
(`a.zip(a.dup) { }`, `a.zip(a.map(&:upcase)) { }`). With the argument in a
local variable first, it passed. That was the same shape as `split`: the arm
took the tuples from the Array that the blockless `zip` answered, and walked
them with `arr_each`. `product`'s arm also takes its lists from Arrays, but
those are the arguments, which the call itself holds. It matched ruby under
`MERE_RUBY_GC_STRESS=1` with arguments built in the statement.

In the code, the other `arr_each` walks in `builtin_iter_raw` take a list
built directly (`utf8_chars_enc`, `rb_graphemes`, `str_lines_of`,
`val_slices`, `val_cons_windows`, ...) or the receiver's own. Every `deref`
in it was read. `split` and `zip` were the two that walked an Array they had
just made and that nothing else held. Why a directly built list survives and
an Array's does not was not looked into further. The survey shows only
that it does.
