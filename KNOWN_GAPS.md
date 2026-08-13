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

## Integer `**` with a negative base and fractional exponent

`(-8) ** (1.0/3)` is `NaN` here; Ruby returns a Complex.

## `TracePoint`

Not implemented. zeitwerk uses it to notice when an explicit namespace
constant is defined, so `dry-logic` (and anything else that loads
zeitwerk's full autoloader) stops there.

## `Kernel.puts` and the other Kernel module functions

`Kernel.puts "x"` raises NoMethodError; the private Kernel methods are
reachable as `puts` but not as `Kernel.puts`. Long-standing, unrelated
to the dispatch order — it fails the same way at any commit tried.

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

## `private_constant` and `private_class_method` are parsed and ignored

`private_constant :A` accepts its arguments (including across a newline) but
records nothing, so `Consts.constants` still lists `A` and `Consts::A` still
reads. Nothing in the gem sample depends on the constant actually being
hidden — it depends on the call not being a parse error, which it no longer
is. Making it real means a per-constant flag consulted by `constants`, by
qualified reads, and by `const_get`.

## `caller_locations` answers with one frame, even at the top level

mere-ruby keeps no call stack. `caller` is `[]`, and `caller_locations`
returns a single `Thread::Backtrace::Location` for the file being executed,
with `lineno` 0 — which is what activesupport's `mattr_accessor` passes to
`module_eval`. For a method called from a library's body that frame IS the
caller's file, so the answer is right where it matters; at the top level Ruby
would return an empty array and mere-ruby still returns the frame.

## `Kernel.format` and friends on a BasicObject-derived class

`::Kernel.format(...)` raises NoMethodError, the same gap as `Kernel.puts`
above. It shows up in code that deliberately inherits from BasicObject and
reaches for Kernel by name.

## The primitive dispatcher's internal `no <name>` failures

A handful of primitives (`to_i`, `to_f`, `to_a`, `size`, `empty?`, `[]`) raise
a mere-ruby StandardError rather than a Ruby NoMethodError when the receiver
is of a type they do not handle — `1.length` is not caught by
`rescue NoMethodError`. The receiver is named in the message now
(`mere-ruby: no [] for nil`), which is what made several gem failures
one-step diagnoses instead of bisections. Fixing it properly means a
"not applicable" signal from `prim_method_raw` back to the caller, which has
the world and can raise the real error.

## `Marshal` is not implemented

`Marshal.load` / `Marshal.dump` raise; only `Marshal::MAJOR_VERSION` and
`MINOR_VERSION` exist. It is what stops rubocop-rails: unicode-display_width
ships its index as a gzipped marshal dump and reads it at load time with
`Zlib::GzipReader.new(file).read` — so that gem needs both the reader and
the format. mgz (the vendored zlib) can already inflate a gzip member, so
the reader is the smaller half.
