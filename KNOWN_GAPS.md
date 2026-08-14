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

## `TracePoint` implements one event

`TracePoint.new(:class)` fires when a class or module body is entered, which
is the event zeitwerk watches to notice an explicit namespace — dry-logic
loads on it. `#enable`, `#disable`, `#enabled?`, `#self` and `#event` are
there; the block form of enable/disable and every other event (`:call`,
`:line`, `:return`, …) are not. Firing costs one lookup per class body while
no tracepoint is enabled.

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

## A Range walks integers and strings, and nothing else

A Range holds its bounds as values, so `("a".."e")`, `(1.0..2.0)`, `(1..)`
and `(..5)` are all Ranges with the bounds that were written. Comparison —
`cover?`, `include?`, `===`, `min`/`max`, `size` — works for any bound that
answers `<=>`. *Enumerating* one is the narrower thing: `each`/`to_a`/`map`
walk an integer range or a string range (by `succ`), and any other element
type raises `TypeError: can't iterate from …` rather than calling the
object's own `succ`. A Date range, which ruby enumerates, is the case this
excludes.

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

## The regex engine has no true subroutine calls

`\g<name>` is implemented by INLINING the named group's pattern at the call
site (its captures made shy), which is what ruby's RFC3986 URI pattern needs
and what makes `require "uri"` work here. A group that calls itself would
inline forever, so genuine recursion — `(?<p>\(\g<p>*\))` for balanced
parens — is not supported. Real subroutine calls need a call stack in the VM.

A MatchData holds 64 capture groups (ruby exposes only `$1`..`$9` as globals,
but `m[10]` and `m[:name]` are answered up to 64). A pattern with more than
that silently keeps the first 64.

## `openssl` is a hash function, and nothing else

`require "openssl"` gives `OpenSSL::Digest` (SHA1, SHA256, MD5 — the digests
mere-ruby already ships, wearing OpenSSL's class shape) and `OpenSSL::HMAC`,
written out in ruby: it is two hashes and an xor. Both were compared against
the real OpenSSL, not merely against themselves.

`OpenSSL::SSL`, `X509` and `PKey` are **not defined at all** — not even as
classes that raise. A gem that needs TLS should fail on the constant it
actually needs (`uninitialized constant OpenSSL::SSL`), which names the
missing capability, rather than load and fail somewhere further away. This is
where excon, fog-aws and aws-sdk-s3 stop, and all three stop there having
loaded everything else.
`OpenSSL::Cipher` is the one exception: its `CipherError` is a class that
activesupport names at load time, so the class exists and `Cipher.new`
raises.

Linking real TLS would be a decision, not a gap: Mere has `tcp_starttls`
(OpenSSL, native only), so the cost is a permanent libssl dependency that the
Wasm target cannot carry.

## `socket` speaks TCP, and only TCP

`TCPSocket`, `TCPServer`, `BasicSocket`, `IPSocket`, `Socket` (constants and
`Socket.tcp`) and a minimal `Addrinfo` are real, over Mere's own socket FFI:
connect, listen, accept, read, write, close, timeout. `UDPSocket`,
`UNIXSocket` and `UNIXServer` exist — code that mentions them loads — but
every one of their methods raises `NotImplementedError` rather than silently
doing nothing.

Two known holes inside TCP itself:

- **A listener cannot report the port it got.** `TCPServer.new(0)` binds an
  ephemeral port, and there is no `getsockname` in the FFI to read it back, so
  `#addr` answers 0. Tests that ask the kernel for a free port need a fixed one
  here.
- **There is no `select`.** A read blocks; `io/wait`'s `wait_readable` is the
  identity and `ready?` answers nil rather than guessing.

## `bigdecimal` is not implemented

`require "bigdecimal"` is a LoadError: it is a C extension, and a faithful
BigDecimal needs arbitrary-precision integers, which mere-ruby does not have
either. A Float-backed stand-in would load and then answer arithmetic
questions wrongly, which is worse than not loading — so it is left out. This
is where devise stops, having loaded activesupport, i18n, concurrent-ruby and
its own Concerns first.

## Loading all of rubocop slows to a crawl

`require "rubocop"` now gets past `socket` and through 537 of its ~600
requires, then effectively stops: the rate falls from 196 requires in the
first 30 seconds to 5 in the sixth, with 4–15 GB resident, and the process is
eventually killed. It is NOT a loop — progress continues the whole time, and
the node-pattern compiler (the earlier suspect) compiles map_to_set's pattern
in isolation without trouble. Something in the interpreter is superlinear in
the number of definitions already made. The gem gate now bounds each gem at
120 seconds so this reports as `TIMEOUT` instead of hanging the run.

## The Wasm playground cannot currently be rebuilt

`docs/build.sh` fails in the vendored mgz package (`unbound variable: skip` in
`deflate.mere`, Wasm codegen only) with the current Mere. The checked-in
`docs/mere-ruby.wasm` still works; it was built with an earlier compiler. The
socket capability's host imports are stubbed in `docs/index.html` for the day
the build works again, but they are unverified for exactly that reason.

