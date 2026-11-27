# Rails-2: `def ~@` names the method `~`, and `~x` is a method call on any receiver

One RED of Rails-2 round 3 (activerecord, sqlite3 adapter): arel/visitors/to_sql_test, `Nodes::UnaryOperation` "should handle BitwiseNot". Round 3's wrong test names had hidden it until PR #246.

## `def ~@`

Arel's Math defines the operator with the `@` spelling:

```ruby
def ~@
  Arel::Nodes::BitwiseNot.new(self)
end
```

Ruby names both `def ~@` and `def ~` `:~`, as it names `def !@` and `def !` `:!`.
The parser had arms for `!` and for `-@` / `+@`, but `~` went to the generic operator arm, which took `~` and left the `@` behind.
The `@` was then read as a parameter, so the method had arity 1 and `~ Arel::Attribute.new(...)` raised "wrong number of arguments (given 0, expected 1)". The endless `def ~@ = expr` did not parse at all.
`~` now has its own arm, the same as `!`'s.

## Two more found on the way

- **A unary operator as a singleton method, on the evaluator.** `def o.-@`, `def o.+@`, `def o.!@` and `def o.~@` all left the `@` behind in the same way: the `def recv.op` arm took the operator alone. `-o` then found no `:-@` at all. That arm now takes the `@` too:
  `-@` / `+@` keep it in the name, and `!@` / `~@` drop it. The VM's compiler already had this right.
- **`~x` for any receiver.** The `~` operator dispatched only for an Integer, a Bignum, an object and a Regexp. A class with `def self.~@` (and any other receiver) raised "unary ~ on non-integer", on both engines. It is now an ordinary call of the receiver's `~`.
  For a receiver with no `~` this means NoMethodError, as in ruby. The send/dispatch arm also took `~` on nil, a String, an Array, a Hash, a Symbol and true/false as `-1 - x`, which raised a coercion TypeError ("nil can't be coerced into Integer"). Past the integers, that arm now takes only `!`.

## Overlap with #271

Codex's draft #271 (branch codex-misc-parser-followups) moves the operator-name arms of `parse_def_inner`, these among them, into a new `parse_def_op_name`, and the singleton arm calls it as well. `git merge-tree` reports a conflict in m_parse.mere between the two.
If #271 is merged first, the `~` arm here goes into `parse_def_op_name` after the `!` arm, and the singleton arm's change here is dropped: `parse_def_op_name` then handles `def o.~@` too.
If this one is merged first, #271 takes the `~` arm into `parse_def_op_name` the same way.

## The test file

Run alone in round 3's tree, seed 12345:

| file | round 3 | this change | ruby |
|---|---|---|---|
| arel/visitors/to_sql_test | 131 runs, 58 errors | 131 runs, 57 errors | 131 runs, 57 errors |

All 131 tests have the same result as ruby's, compared by name. The 57 errors are ruby's too, from the environment.

## Checked

- Corpus 1059 matches ruby 4.0.10 with and without `MERE_RUBY_VM=1`:
  `def ~@` and `def ~` in a module included into a Struct subclass (as `Arel::Attribute` is); send, public_send, arity, owner, instance_methods, respond_to?; `def ~@()`, a one-line body, a singleton `~@`.
  The four unary operators as instance and singleton methods, a class method `self.~@`, NoMethodError for `~` on a String, nil and a plain object, and Integer's own `~`.
  On main the file does not parse: the endless `def ~@ = :tilde` is a SyntaxError, since the `@` taken as a parameter leaves `= :tilde` with no name before it. Without that line it stops at the first `~` call, "given 0, expected 1".
- `run_corpus.sh --both`: 911/911. `MERE_RUBY_VM=1 run_corpus.sh --both`: 911/911.
- The source gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth. `tools/loop_rss_check.sh`. `mspec/record_hygiene.sh`.
