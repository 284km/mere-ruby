# Rails-2 round 3, part 1: a branch's locals, and whose block a `do` is

**Where this comes from.** Rails-2 round 3 measured activerecord (sqlite3 adapter, 427 files) on main 30de57d4 with #225, against ruby 4.0.10: MATCH 8,943, RED 133, MISSING 84. Round 2 (main 8c39dd51, against ruby 4.0.9) was 7,717 / 1,008 / 399. The RED by cause are in the third part of this series.
This part has two of the causes, 31 RED.

## A branch that is passed over declares its locals before the next one runs (23)

A local is a local from where its first assignment is written, whether or not that line runs. So in

```ruby
if loaded?
  size = records.size
else
  with_connection { |c| size, timestamp = c.select_rows(arel).first }
end
"#{size}-#{timestamp}"
```

the block writes the method's `size`: the `if` branch comes first in the text. That is ActiveRecord's `compute_cache_version`.
The names of a branch that did not run were declared only after the whole `if`, so the block made variables of its own, the method read nil, and every collection cache key ended in "-" with nothing after it.

`run_if`, `run_case` and `run_case_truthy` now declare each branch's targets once, in the order of the text: a branch that is passed over before the next one is tried, the branch that runs after it has run, and then the ones after it.
The statement arms no longer declare them all a second time after the statement.

Corpus 974: `if` / `elsif` / `else`, `unless`, `case` with and without a subject, a multiple assignment, a nested `if` in the skipped branch, and the two forms that must stay as they were (a name first written in a later branch is the block's own; the last branch passed over).

**Speed.** A loop of 2,000,000 passes around an `if` / `elsif` / `else` whose first two branches assign and do not run, and the same around a `case` with two `when`s (this machine, other jobs running, three runs each):

| | main 66a7afd0 | this change |
|---|---|---|
| if / elsif / else | 2.75 s, 2.78 s, 2.78 s | 2.57 s, 2.62 s, 2.70 s |
| case | 1.97 s, 2.01 s, 2.00 s | 1.89 s, 2.06 s, 1.93 s |

The first form of this change declared the skipped branches before the next one and left the declaration after the statement as it was. That scanned them twice and the same loop took 3.34 s. Each branch is scanned once now, as before the change.

## A `do` after a bracket or lambda first argument is the command's (8)

```ruby
tmp_yaml ["curious", "yml"], yaml do |t| ... end
assert_changes -> { topic.updated_at }, to: new_updated_at do ... end
```

A `do` after a paren-less argument list belongs to the command. When the first argument was an array literal or a `->` lambda, the rest of the list was read without the flag that keeps the `do` for the command, and the last argument took the block:
`yaml do |t| ... end` was a call of a method named yaml (NoMethodError for a local), and `{...}.to_yaml do ... end` left `tmp_yaml` with no block (LocalJumpError).

`puts_args_cmd` reads the rest of the list with the flag set, in the four places: a comma after the bracket, a binary operator after the bracket, a comma after a chain on the bracket, and a `->` first argument.

Corpus 975.

## The test files

Each file alone, in round 3's tree, starting from an empty `debug.log`:

| file | round 3 | this change | ruby |
|---|---|---|---|
| collection_cache_key_test | 33 runs, 23 failures | 33 runs, 0 failures | 33 runs, 0 failures |
| persistence_test | 169 runs, 4 errors | 169 runs, 0 errors | 169 runs, 0 errors |
| fixture_set/file_test | 14 runs, 4 errors | 14 runs, 0 errors | 14 runs, 0 errors |

**Checked.**

- `run_corpus.sh --both`: 879/879. `MERE_RUBY_VM=1 run_corpus.sh --both`: 879/879. On main, corpus 974 and 975 differ from ruby on the evaluator and match with `MERE_RUBY_VM=1` (the VM reads the program through Prism and keeps a method's locals in its own table). Here they match both ways.
- The source gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth. `tools/loop_rss_check.sh`. `mspec/record_hygiene.sh`.

Max RSS of the three files on this build: 692 MB, 1,014 MB and 648 MB (round 3: 690, 1,291 and 624 MB, with the round's 45 MB log behind it).
