# Known gaps

Divergences from CRuby that are understood, reproduced, and deliberately
not fixed yet — as opposed to the things nobody has looked at. Each entry
says what it costs and what fixing it would take, so the decision can be
revisited rather than rediscovered.

## `p -1` parses as `p - 1`

```ruby
p -1        # mere-ruby: NameError (undefined local variable or method 'p')
p -1.5      # ruby: -1
x = 5
p -x        # same
```

A paren-less argument that begins with unary minus is read as binary
subtraction against the command word.

**Why it is still here.** Ruby decides this by knowing whether the name
on the left is a *local variable*: `a -b` is subtraction when `a` is a
local and `a(-b)` when `a` is a method. This parser does not track
assigned locals, so it cannot make that distinction, and guessing either
way breaks the other. `p a -b` (subtraction) works today and is the more
common shape in real code, so the current behaviour is the safer half.

**What fixing it takes.** A set of locals threaded through the parser —
assignments, block and method parameters, `for` targets, rescue bindings
— consulted when an identifier is followed by a space-minus-no-space. The
lexer already emits space-marked variants of `(`, `[`, `&` and `::` for
exactly this class of ambiguity, so the token side is a small addition;
the scope tracking is the real work.

**What it costs today.** Nothing measured. No gem in the sample hits it;
it surfaced only in a hand-written test. `p(-1)` and `puts -1` (where the
argument is not the first token) both work.

## `require "enumerator"` is answered without checking Enumerator

`enumerator` is satisfied like `thread` and `rbconfig` — no file, no
error — because Enumerator has been built into Ruby since 1.9. That is
right in principle, but mere-ruby's Enumerator is a subset, so the
require now promises more than the object delivers. A program that
requires it and then uses a lazy enumerator will fail later, and further
from the cause than a LoadError would have been.

## YAML is a loader subset, and `require "yaml"` can be lost after a failed load

`yaml` / `psych` ship as Ruby source: block mappings and sequences, flow
collections, the implicit scalar types (including YAML 1.1's rule that a
float needs a decimal point *and* a signed exponent, so `1.0e3` is a
String), comments, and multiple documents. No emitter, no anchors or
aliases, no explicit tags, no block scalars (`|` / `>`).


## `UnboundMethod#bind_call` re-dispatches by name

`Module.instance_method(:name).bind_call(mod)` returns whatever `mod.name`
returns, including an override. In Ruby the unbound method is the
*builtin* one and sees past any `def self.name` — which is the entire
reason zeitwerk holds onto it.

`bind_call` calls back through ordinary dispatch, so for a
builtin-backed origin there is no way to ask for the builtin
specifically. Fixing it means a dispatch entry point that skips the user
method table for a known origin. Every other part of the trick works:
the unbound method is produced, binds, and returns the right answer for
a module that does not override `name`.

## `**` with a negative base agrees with ruby except in the last ulp

A negative base raised to a non-integer power answers the principal Complex
root, and a half-integer exponent (a quarter turn) is exact — `(-8) ** 0.5` is
`(0.0+2.8284271247461903i)`, not `(1.7e-16+2.82…i)`. Any other angle goes
through `cos(pi*y)`, where multiplying by pi rounds first: ruby computes the
same product to more than double precision, so `(-8) ** (1.0/3)` differs in
the last place (`1.0000000000000002` where ruby prints `1.0`). Closing it
means a two-part pi and an argument reduction, for an input shape nothing in
the sample uses.

## `TracePoint`

Not implemented. zeitwerk uses it to notice when an explicit namespace
constant is defined, so `dry-logic` (and anything else that loads
zeitwerk's full autoloader) stops there.

## Corpus programs must be self-contained

Two were not, and both hid a real problem rather than causing one:

- `76_zlib.rb` read a zlib stream from `/tmp` that an earlier ad-hoc run had
  left there. When `/tmp` was cleared the gate stopped at that program — with
  `set -e`, silently, so `run_corpus.sh` reported the seventy-five programs
  before it and exited non-zero. The stream is inline now.
- `88_utf8_names_and_toplevel_const.rb` printed a non-ASCII symbol, and
  `Symbol#inspect` escapes those when the default external encoding is not
  UTF-8 — so the expected output depended on the shell's locale rather than
  on the interpreter. It compares bytes now.

A corpus program may write into `/tmp`, but it must create everything it
reads and delete it afterwards.

## `caller_locations` answers with one frame, even at the top level

mere-ruby keeps no call stack. `caller` is `[]`, and `caller_locations`
returns a single `Thread::Backtrace::Location` for the file being executed,
with `lineno` 0 — which is what activesupport's `mattr_accessor` passes to
`module_eval`. For a method called from a library's body that frame IS the
caller's file, so the answer is right where it matters; at the top level Ruby
would return an empty array and mere-ruby still returns the frame.

## The primitive dispatcher's internal `no <name>` failures

A handful of primitives (`to_i`, `to_f`, `to_a`, `size`, `empty?`, `[]`) raise
a mere-ruby StandardError rather than a Ruby NoMethodError when the receiver
is of a type they do not handle — `1.length` is not caught by
`rescue NoMethodError`. The receiver is named in the message now
(`mere-ruby: no [] for nil`), which is what made several gem failures
one-step diagnoses instead of bisections. Fixing it properly means a
"not applicable" signal from `prim_method_raw` back to the caller, which has
the world and can raise the real error.

## `$~` is global, not frame-local

Ruby scopes `$~` (and with it `$1`, `Regexp.last_match`) to the method frame
that performed the match, so a match inside a method is invisible to its
caller. Here it is one global, so a match performed anywhere is still
readable afterwards. Nothing in the gem sample depends on the difference;
it shows up as `Regexp.last_match` answering a stale MatchData where ruby
answers nil.

## An endless range is stored as one that ends at the largest integer

`Float::INFINITY` as a range bound becomes the largest integer, because a
Range here holds two integers. `(1..Float::INFINITY).end` therefore answers
that number where ruby answers `Infinity`, and arithmetic on it overflows
into a Bignum — which, as a bound, is clamped back rather than refused.
Membership, `begin`, `min`/`max` and iteration bounds all behave; only the
reported endpoint differs. Fixing it properly means a Range of two values
rather than two integers.

## `Object#methods` lists only the methods defined in Ruby

`1.methods`, `nil.methods`, `[].methods` answer with the methods *defined in
Ruby* on the receiver's class chain — the builtins are branches in a
dispatcher, not entries in a table, so they cannot be enumerated. The call
answers rather than raising, which is what code like rubocop's
`nil.methods - Object.new.methods` needs; the answer is a subset rather than
a wrong shape. A plain object's `methods` is complete, since all of its
methods are Ruby-defined.

## `puts` and `raise` cannot be local variable names

Every other command word can (`require = ...`, `include = ...`,
`attr_accessor = ...`), but these two are treated as reserved words by the
lexer and the expression parser, so `puts = 1` is a parse error where Ruby
assigns. No installed gem does it — the tree was searched before the two were
left out. Fixing it means letting them read as ordinary identifiers in
expression position, which is where their statement syntax is decided.

## rubocop stops at `socket.so`

`require "rubocop"` now gets through rubocop-ast (pattern compiler, generated
matchers, visitor registry) and most of rubocop itself; it ends at a C
extension, which is the documented boundary. Everything before it was a real
gap and is fixed: an alias that did not fire `method_added` (which left the
visitor registry short and made the pattern compiler recurse forever — that
is what the old "recurses without bound" entry here was), `%<name>s` /
`%{name}` format references, `:!~`, a space-marked `[` after a complete
expression, `define_method :"on_#{type}" do` losing its block, and
`protected :a, :b` not clearing an earlier `private`.
