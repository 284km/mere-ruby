# A call on a later line than its statement runs on its own line (corpus 852)

**The request** (Rails-1, through work2026-fd). activesupport's `backtrace_cleaner_test.rb` has 8 REDs. `first_clean_frame` and `first_clean_location` are compared with `__LINE__ + 1`, inside this shape:

```ruby
-> do
  @bc.first_clean_frame.tap { @line = __LINE__ + 1 }
end.call
```

The frame of the method holding it said the line of `->`, where ruby says the line of `end.call`. The same happened to an argument on a line of its own (`foo(⏎ 1,⏎ caller(0, 1)[0]⏎)`), which said the line of `foo(`. `MERE_RUBY_VM=1` already agreed with ruby, because it compiles from Prism's positions. The evaluator moved its line only at a statement (`SLine`).

**What was there.** `ln_mark` already wrapped a receiver of a call on a later line (`[1]⏎.map`) in `__ln~N`, which sets the line once the receiver has its value. But it did so only for receivers whose own evaluation moves the line: calls, arrays, hashes, `begin`.

**The change.**

- `ln_mark` takes a lambda literal as well. Making a lambda moves no line, but the `.call` after it is on its own line.
- `ln_before` marks an argument that starts on a later line than its statement and that calls something, with `__lnb~N`. The mark sets the line *before* the argument is evaluated.
  - It applies to positional arguments, keyword values and array elements.
  - "Calls something" means a call, a block call, a safe call, or a bare name, which may be a call without parentheses.
  - Literals and internal pieces (`__…`) are left alone, so the literal-shape checks see what they saw before.
- `eval_args` puts the call's own line back once its arguments have their values. In ruby the call's frame line is its node's, whatever an argument (or a block an argument ran) did to it.
- The marks look like method calls (`EMethod (x, "__lnb~N", Nil)`), as `__ln~` does. So the 66 functions that walk `Expr` already descend into them, and `defined?` strips them (`ln_strip`).
- The two guards that recognise the marks use `str_starts_with` instead of `substring`, which allocated on every zero-argument call with a name longer than five bytes.

**Left as it was.** `self⏎.send(:m)` still reports the line of `self`. Marking a `self` receiver would hide it from the private-call check, and the request does not need it.

**Witness.** corpus 852 covers the two requested shapes and the class-shaped `-> do … end.call` from activesupport. It also covers arguments, keyword values, array elements, a splat of a multi-line array, a chain, a raise with its message on the next line, a block argument before a later one, and `defined?` across lines. On main, 7 of its lines differ.
