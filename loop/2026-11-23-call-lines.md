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

## Review of #180: defined? and the marks inside arguments

`ln_strip` took the marks off the outer expression and its receivers only. `defined?` walks arguments, keyword values and elements as calls of their own, so a `__lnb~` left there was asked about as a method. It called the receiver to find it: `defined?(take(⏎ value⏎))` ran `value` and answered nil. The same happened with a keyword value, a local-variable argument, an array element in an argument, `x, k: 1`, `value.then(⏎ value⏎)` and `*[⏎ value⏎]`. `ln_strip` now goes through call arguments, keyword hashes (`EKwHash`), array and hash literals, splats, block passes and binary operands. corpus 852 has each of those under `defined?`, with a counter showing that nothing ran.

The marks also carry their line as an `EInt` argument now (`EMethod (x, "__lnb~", [EInt n])`) instead of in the name. Reading it took a `substring` and an `int_of_str` per evaluation. 300,000 calls of `f(⏎ x,⏎ y,⏎ z⏎)`, against main 94aa899b:

| | single-line call | multi-line call |
|---|---|---|
| main | 10.169e9 | 10.154e9 |
| first version | 10.244e9 | 10.445e9 (+2.9%) |
| now | 10.192e9 (+0.2%) | 10.249e9 (+0.9%) |

The remaining cost is the mark itself (a line set and one more match arm per marked argument). A local variable is still marked: the lexer's table of locals describes the end of the source by the time the parser runs, so it cannot say what a name is at that point.

**Not changed** (older than this PR, listed by the review): a later line inside a hash value, string interpolation, the right side of `+` / `&&` / `?:`, `**{⏎…}`, `raise("x")` as an argument, arguments of a call without parentheses, and the line of `foo(⏎…⏎) + nil`.

## Second review of #180: a mark at any depth

`ln_strip` reaches only the node kinds it names. A statement-shaped call such as `puts(⏎ value⏎)`, which is `EStmt (SPuts …)`, and a unary operand (`!`, `EUn`) kept their marks, and other kinds would have followed. `defined?` asks about every operand, argument and element by coming back through `eval_e`'s `EDefined` arm, so that arm now takes the marks off first (`ln_unmark`). A mark at any depth is seen through there, whatever node holds it. `ln_strip` stays for the outer expression, as before.

corpus 852 gained `puts`, `print` and `p` arguments, a unary operand, a ternary, a range, a hash value, an interpolation and an `&&` operand, all on later lines and all under `defined?` with the counter. They match ruby, as main does.
