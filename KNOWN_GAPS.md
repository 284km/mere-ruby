# Known gaps

Divergences from CRuby that are understood, reproduced, and deliberately
not fixed yet — as opposed to the things nobody has looked at. Each entry
says what it costs and what fixing it would take, so the decision can be
revisited rather than rediscovered.

## `Proc` subclass clone/dup runs the copy hooks; ruby 3.2.2 runs none

```ruby
class MyProc < Proc
  attr_reader :initializer
  def initialize_clone(other) = (@initializer = :clone)
end
MyProc.new { }.clone.initializer   # mere-ruby: :clone
                                   # ruby 3.2.2: nil
```

Every other object runs `#initialize_clone` / `#initialize_dup` (and through
them `#initialize_copy`) when it is cloned or duplicated; `Kernel#clone`'s own
spec is built on that. A `Proc` subclass is the one kind where the reference
ruby calls nothing at all, so `core/proc/clone_spec.rb` is a file mere-ruby
PASSES and ruby 3.2.2 FAILS -- which the gate records as a DIFF, because the
gate compares the two rather than grading either.

**Why it is still here.** The divergence is in the oracle. Reproducing it
would mean a `Proc`-shaped exception inside the copy path -- "run no hook when
the receiver is a Proc" -- with no rule behind it, written to be deleted again
the moment the reference ruby moves. ruby/spec flags the neighbouring example
in the same file with `ruby_bug "cloning a frozen proc is broken on Ruby 3.3"`,
so this corner is known-broken upstream through 3.3.

**What fixing it would take.** A newer reference ruby. Nothing in mere-ruby.
The row is expected to go back to MATCH when the gate's ruby is upgraded; if
it does not, this entry is wrong and the hook suppression is real.

## A bare `mere-ruby` prints usage; ruby reads stdin

```sh
echo 'puts 1' | ruby           # ruby: 1
echo 'puts 1' | mere-ruby      # mere-ruby: usage: ... (exit 2)
echo 'puts 1' | mere-ruby -    # mere-ruby: 1
```

`-` reads the program from stdin and agrees with ruby. What diverges is the
*bare* invocation with no arguments at all.

**Why it is still here.** `read_stdin` blocks until EOF, so making the bare
form read stdin means a caller that runs the binary with no arguments and no
input HANGS instead of failing. A hanging gate is worse than a failing one:
the failing one names a defect, the hanging one has to be killed from outside
and reports nothing. Every caller that wants stdin can write `-`, which is
what a pipeline writes anyway.

**What fixing it would take.** A way to ask whether stdin is a terminal.
`isatty` exists inside the C backend's terminal builtins but is not reachable
as a Mere function, so this needs a host builtin (`stdin_is_tty : unit ->
bool`) before the bare form can read stdin only when something is piped in.
Until then the gate records this as a DELIBERATE divergence with a bounded
wait, so a regression to blocking fails rather than hangs
(`clitest/run.sh`).

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

## Tracing sees calls, returns and class bodies — not lines

`TracePoint.new(:class)` fires when a class or module body is entered, which
is the event zeitwerk watches to notice an explicit namespace — dry-logic
loads on it. `#enable`, `#disable`, `#enabled?`, `#self` and `#event` are
there; the block form of enable/disable and every other event are not.

`#enable` takes `target:` and narrows a tracepoint to one method, matching it by
name — `tp.enable(target: method(:foo))` fires for `foo` and nothing else. Ruby
matches the method *object*, so a same-named method on another class would be
told apart there and not here; `target_line:` and `target_thread:` are accepted
and ignored. A tracepoint created for an event this interpreter never fires
(`:line` most of all) enables quietly and simply never runs its block, which is
a wrong answer rather than a refusal — a program that asks "did my line tracer
fire?" is told no.

`set_trace_func(proc)` installs a tracer and fires it for **call**, **return**
and **class**, and a `TracePoint` watching `:call` / `:return` / `:class` fires
from the same place (with `#method_id`, `#callee_id`, `#defined_class`, `#path`
and `#event`). Ruby also has `line`, `end`, `c-call`, `c-return`, `raise` and
`b-call`, and passes a real line number and a Binding; here the line is 0 and
the binding is nil, because this interpreter keeps neither at run time. A
tracer that counts calls or watches classes works; one that follows lines does
not, and one that prints its events prints fewer of them.

`c_call` / `c_return` are a distinction this interpreter does not have: an attr
accessor is a C method in CRuby and an ordinary one here, so those events would
be reported for a different set of methods than ruby reports them for. They are
not fired at all rather than fired wrongly.

Both cost one map lookup while nothing is installed — per class body for
TracePoint, per method call for set_trace_func.

## An alias of a builtin Kernel method cannot be called with no receiver

`alias original_puts puts` inside `module Kernel` records that the new name
delegates to the builtin `puts`, because `puts` has no entry in the method table
to copy (it is a statement in this parser). That delegation is read when there is
a receiver -- `STDOUT.original_puts` style dispatch -- and not on the
implicit-self path, so a bare `original_puts "x"` raises NoMethodError.

Reaching the builtin *past* an override is the other half of it: the wrapper
that aliases `puts` and then defines `puts` wants the alias to reach the ORIGINAL,
which means suppressing the very override check that makes the wrapper work.
Overriding these methods works (corpus/142); keeping hold of the original does
not. `require` is not affected -- it is a real entry in the table, which is why
rubygems can wrap it (corpus/141).

## `Exception#exception` and `#cause` are absent, and respond_to? says so

An exception answers `message`, `to_s`, `inspect`, `==`, `backtrace`,
`set_backtrace`, `backtrace_locations` and `full_message`. `#exception` (which
returns self, or a copy with a new message) and `#cause` (the exception that was
in flight when this one was raised) are not implemented, and `respond_to?`
answers false for them rather than promising what is not there.

## `encode` has no character tables, and `$?` is not set

Transcoding here works by codepoints: a string is decoded to codepoints and
re-encoded. That covers UTF-8, UTF-16BE/LE (surrogate pairs included),
ISO-8859-1 and the ASCII range of anything ASCII-compatible -- ASCII being the
one range every ASCII-compatible encoding agrees on. It does not cover the
encodings that need a TABLE: `"あ".encode("Shift_JIS")` is 2 bytes in ruby and
`Encoding::UndefinedConversionError` here. Refusing is the point; the branch
this replaced emitted the codepoint as a single byte for every target it did not
know, so `"ab".encode("UTF-16BE").bytesize` answered 2 where ruby says 4, and a
Latin-1 character "converted" to Shift_JIS by accident.

A command literal and `system` do run the command (Mere's `run`, through a file
for the output, since `run` answers with the exit status). Two limits: `$?` is
not set, because there is no Process::Status here, so code that reads
`$?.success?` gets a NoMethodError on nil rather than an answer; and `system`
answers false both for a command that ran and failed and for one that could not
be executed, where ruby answers false and nil. On the Wasm host `run` is 127 by
construction, so a browser sees every command as not found -- which it is.

## `File#fileno` refuses: there is no descriptor to report

A File here is a path, a mode, a read position and a write buffer; the host
interface reads and writes whole files. `fileno` therefore has nothing to
answer, and it raises NotImplementedError rather than inventing a number --
the same choice the UDP and UNIX sockets make. `flush`, `sync`, `sync=`,
`tty?` and `isatty` are real: the buffer exists, so flushing it is a real
operation, `sync = true` makes each write flush, and a file is not a terminal.

sidekiq-pro and devise ask for `fileno` when they are loaded without a CRuby
stdlib on `-I`, and stop there.

## A block's own `&b` parameter used to bind nil, and the comment said why

`proc { |x, &b| b.call(x) }.call(7) { |v| v + 1 }` is 8 in ruby and was
NoMethodError on nil here, because the binder set a block parameter to nil with a
comment stating that blocks are not re-passed through block params. They are, and
the mechanism the comment implied was missing -- capturing a block as a real Proc
-- was already there, three hundred lines away, in the binder for *method*
parameters. **A comment that explains why something is not done outlives the
reason**, and it is read as a decision rather than a gap.

That was also the whole of the `Method#to_proc` gap: the Proc it builds forwards
`(*args, &blk)` to the method, so with the block parameter bound
`method(:m).to_proc.call(5) { }` reaches m's yield. The Proc also answers the
METHOD's arity and is a lambda, where the forwarder's own `*args` would say -1
and false -- kept in a side table rather than by rewriting the forwarder.
`corpus/153` covers all of it.

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
`module_eval`. `caller_locations` now answers one Location per frame, built from
the same per-depth arrays `caller` reads, and a Location prints as the frame it
names. It used to answer a single location with an empty label and lineno 0, and
its comment said there was no call stack and no line tracking to build them from
-- true when written, and untrue since the frames and the line markers landed:
`caller` was updated and this was not. A Location's printed form has to be
answered TWICE, in the dispatcher and in the value printer, because an element
inside an array goes through the second one (`Encoding` and `MatchData` are in
the same position).

There IS a call stack now: `caller` answers real frames, formatted as the
reference ruby writes them, an uncaught error names `file:line:in 'meth'`, and
`Exception#backtrace` answers the frames of the raise.

Two limits. **A block gets no frame at all**: inside `[1].each { }` in a method
`outer`, ruby's labels are `["block in outer", "each", "outer"]` and this answers
`["outer", "<main>"]` -- the block and the builtin that called it are both
missing, rather than the block being mislabelled. Giving a block a frame means
three more per-depth entries per block invocation, and the reclamation
measurements above say what that costs: a call already leaks 13.4 KB and nothing
is ever given back. So this is a cost decision waiting on reclamation, not an
oversight. And a backtrace belongs to the raise that is
IN FLIGHT: the built-in exception representation is a class and a message with no
identity, so there is nowhere on it to keep a copy. The frames live in one slot,
answered for the exception in `$!`; an exception that was rescued and put aside
answers nil rather than another raise's frames. Capturing them costs 4-6% on an
ordinary program and 9% on one that raises in a loop -- measured, not guessed,
and the reason a lazy capture is impossible is that the frames are overwritten
by whatever the handler calls next.

`Bundler.setup` answers what ruby answers now, and `bundlertest/run.sh` has no
recorded divergence left: reading the Gemfile, resolving it, building the
definition and setting up the load paths all agree, with the same rubygems and
bundler on both sides.

**2026-09-03 update.** For two weeks the whole harness read FAIL with
`Illformed requirement [""]`: a collection during the rubygems preload blanked
the interned frozen strings (`"lit".freeze`) because their table was not a GC
root, and bundler's gemspec is exactly a file of `"...".freeze` literals that
gets loaded twice. Fixed by rooting the table (and the four others
`tools/gc_roots_check.sh` found the same way); the gate now runs that check.
**2026-09-04, second update.** With the reference at ruby 3.4.9 the `versions`
divergence retired itself -- both sides answer the same bundler now -- and a
new one took its place, one step further in. Bundler 2.6.9 does
`require "bundled_gems"` inside `rescue LoadError`, a Ruby 3.3+ path 2.4.10
never took; mere-ruby cannot load that file and raises NoMethodError, which
the rescue does not catch, so `Bundler.setup` raises where ruby answers `:ok`.
Reading the Gemfile and building the definition still agree.

Two different things would each unblock it: raising LoadError for a file it
cannot load, which is what bundler is written to expect and would let it carry
on; or loading the file, which is the real answer. The first is not a fix for
the second -- a LoadError there means `Gem::BUNDLED_GEMS` does not exist and
bundler simply skips the warning it wanted to give.

**2026-09-05, third update: the last step agrees, and `bundlertest/run.sh` has
no recorded divergence left again.** Moving the reference to ruby 4.0.6 (whose
bundler is 4.0.16) broke `setup` three times over, each one a different fault
in this interpreter rather than a boundary:

1. Every step, `dsl` included, failed on `require "bundler"`. RubyGems 4's
   vendored uri writes `class << self; EscapedChars = "..."; def escape(name)
   ... EscapedChars`, and a method defined in a `class << self` body could not
   see a constant that body defined -- the body could. `register_class_sng_in`
   never set the lexical scope that `register_class_v` records for a `def`, so
   the methods carried the ENCLOSING class's scope.
2. `Bundler.setup` then raised `undefined method 'missing?' for an instance of
   Array` from bundler's materialization. Bundler sorts platform candidates
   through rubygems' `matching.sort_by.with_index {|spec, i| ... }`, and
   `with_index` answered `[spec, index]` PAIRS: it materialised the elements
   and re-ran the source method over pairs, where ruby calls the source once
   with the block wrapped in a counter. The same two phases truncated every
   short-circuiting source (`[3,1,2].find.to_a` was `[3]`, because the walk
   that materialises has to answer something and an Array is truthy).
3. `bundled_gems.rb` reads `RbConfig::CONFIG["rubylibdir"]` and appends "/" to
   it. This interpreter's RbConfig is a stand-in with the handful of keys
   libraries actually read, and that was not one of them, so the answer was
   `nil + "/"`. `rubylibdir`, `rubyarchdir` and `DLEXT` are derived from the
   same prefix now.

## `minmax_by`'s enumerator walks its source twice, and `break` does not leave a `with_index`

Two small edges of the same machinery, both measured against ruby 4.0.6:

`[3,1,2].minmax_by.to_a` answers `[3, 1, 2, 3, 1, 2]` where ruby answers
`[3, 1, 2]` -- materialising that enumerator drives `minmax_by`, which walks
its receiver once for the minimum and once for the maximum. Every other source
in `corpus/183` materialises in one pass. `minmax_by.with_index` is not
affected: with_index calls the source once with a wrapped block and never
materialises.

`break` inside a `with_index` block ends that block, not the walk:
`[1,2,3].map.with_index { |x, i| break :b if i == 1; x }` answers
`[1, :b, 3]` where ruby answers `:b`. The wrapper reaches the caller's block
through a Proc, and a break inside a proc called with `#call` is that call's
value here. Propagating it would need the flow to travel back out through the
call, which is the same missing piece as `proc { break }.call` (ruby raises
LocalJumpError there; this answers the value).

`Exception#backtrace` is the same gap seen from the other side: it answers
`nil` rather than the frames the exception was raised through. It has to
answer *something*, because a library reads a backtrace while it is
**reporting** an error — bundler's `eval_gemfile` builds its `DSLError` out of
`e.backtrace` — so raising NoMethodError there replaces the error being
reported with one about the reporting. `set_backtrace` stores and returns a
value on an exception object; on the built-in representation (a class and a
message, no identity) there is nowhere to store one, so it is absent rather
than a setter whose value cannot be read back.

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

## Integers wider than int64 were a different value with fewer methods

Fixed, and worth recording because of the shape rather than the bug. An integer
that does not fit in an int64 is held as a decimal string (`VBig`) rather than a
machine word, and the arms that handle it were written one at a time:

| | `2**62` | `2**63` and up |
|---|---|---|
| `+ - * / % & \| ^ even?` | worked | worked |
| `>> << ~` | worked | **"type error"** |
| `bit_length` `digits` `to_r` | worked | **"undefined method"** |

`1 << 64` was worse than either: it returned **0**, and `1 << 63` returned a
negative number, because the native shift wraps at 64 bits. A wrong answer with
no error is the one failure a corpus cannot catch, and nothing in a program that
stays under 2**63 can produce it.

Two things came out of fixing it:

- **Shifts are arithmetic, so they are arithmetic.** `x << n` is `x * 2**n` and
  `x >> n` is `x` floor-divided by `2**n`; the bignum divide already floors, so
  `-1 >> 1 == -1` follows without a special case. The native path is kept, but
  guarded by a **round trip** (`shr_int (shl_int x n) n == x`) rather than by a
  hand-written bit bound -- a bound would be a claim about where the shift
  overflows, and the round trip is a check of it.
- **`divmod` already had its wide arm.** The mechanism existed and had been
  applied once. That is the same shape as the self-referential containers below,
  and it is worth looking for the OTHER arms whenever one is written.

`corpus/159_wide_integers_and_cycles.rb` pins the boundary from both sides.

## A container that contained itself died in three of four places

Fixed. `[1, [...]]` printed correctly, and the same cycle:

- in a **hash** ran the stack out (`{:x=>{...}}` is what ruby prints)
- through **`Array#hash`** ran the stack out
- through **`Array#<=>`** ran the stack out

One guard, `insp_seen`, written once for arrays inside the printer, in a file
with two printers and two other walks that recurse through the same values.

The interesting part is the key. Array handles come from one counter and hash
handles from another, both starting at zero, so a guard keyed on the bare
integer would have made "array 3" and "hash 3" the same entry -- and an array
that merely sat inside hash 3 would print `[...]`. The key carries the kind
(`a3` / `h3`), and the corpus program checks the case that would have caught it.

The non-printing walks use their own map rather than sharing the printer's: a
mark left by an inspect in progress would make a hash computed underneath it
return the cycle constant instead of the real value.

## A method call costs ~9 KB that is never given back

The interpreter allocates in a region it never reclaims, so **memory is linear
in the number of calls executed** — 100k calls is 0.9 GB, 200k is 1.8 GB, 400k
is 3.6 GB (`bench/alloc_per_call.sh`). Definitions are cheap by comparison:
1600 classes with two methods each is 0.06s and 25 MB.

What that 9 KB is made of, measured with `bench/alloc_sites.sh` (2026-08-20):
**240 allocations per empty method call, 7.4 KB of them requested**, and 19 in
every 24 are 32 bytes or smaller. It is not one big allocation that could be
made lazy -- it is hundreds of small ones, so reclaiming any of it means
reclaiming *objects*, which is a garbage collector or reference counting rather
than a tweak. A bare block iteration is 130 allocations and 3.7 KB, so the frame
machinery is most of it either way.

One tempting shortcut was measured and does NOT work: the region doubles its
block size and abandons the previous block, so the waste looked like it might be
the 2x between 7.4 KB requested and ~9.5 KB resident. Capping the growth at 8 MB
changed 400k calls from 3.947 GB to 3.958 GB -- nothing. The resident bytes are
the requested bytes; there is no packaging to win back.

That is the whole of the rubocop timeout. `require "rubocop"` is ~250 files
and some millions of calls; it reaches tens of GB (117 GB peak footprint on a
ten-minute run), the machine starts faulting for every access, and the gem
gate's 120-second bound reports `TIMEOUT`. For a library that does finish,
`rubocop-ast` is CRuby 0.3s / 50 MB against mere-ruby 4.5s / 3.2 GB — 15× the
time and 64× the memory.

A profile of the slow load spent half its samples in `strcmp`. Half of that
turned out to be a cause rather than a symptom: the C backend emitted a fresh
region copy of every string literal *at every evaluation*, so each `str_eq
name "..."` in the dispatch chains allocated and memcpy'd before comparing.
Making literals static constants (Mere v0.1.258) took 32% off both time and
memory here; memoizing the ancestor chain took a little more. What is left is
the allocation that is inherent to the design above.

Two earlier readings of this were wrong and are worth recording. It is not
superlinear in the number of definitions (definitions measure linear and
cheap). And `racc/cparse` did not take 61 seconds — a require that *raises*
never returns, so a trace that closes files on return charges everything after
the raise to it; `bench/require_trace.rb` closes them in an `ensure`.

**A region per call is not the fix, and that was measured rather than
reasoned.** Wrapping every method body in `region R { }` reclaims **6.4%** of
what a call allocates: Mere's `map_new` and closure environments take the
default region explicitly, so the frame — the biggest thing a call builds —
never lands in the block region at all. Patching the generated C so both
follow the *current* region raises it to **17%**.

The other 83% is writes into global maps, and those are the Ruby heap: the
string / array / hash / object stores, which every value lives in and which
outlive any call by construction. No call-scoped region can reclaim them.
Reclaiming them means collecting the stores — reference counting or a GC over
the store maps — which is a different and much larger piece of work than the
escape analysis a per-call region would have needed.

So the honest statement is: allocation per call is now within ~2× of what a
tree-walking interpreter of this shape costs, and the remaining factor is that
**nothing is ever collected**, not that temporaries are held too long.

**2026-09-03 update.** The numbers above are from before the frame pool, the
statement/iteration regions and the store collector (Aug 2026); the section is
kept because the reasoning in it is still how this is measured. Where it stands
now, from `bench/block_env.sh` (400k iterations, region allocator's own
counters -- peak RSS at this scale is not reproducible run to run):

| program | default-region bytes | held by the loop statement | RSS slope |
|---|---|---|---|
| `while` + method call | 40 MB | 1 MB | 300 B/iter |
| `n.times { f(x) }` | 69 MB | 66 MB | 317 B/iter |
| CRuby, either | -- | -- | flat at 34 MB |

Still linear, but the slope of the block loop came down from 1121 B/iter in
one day of named changes: block envs now come from the frame pool and give
their `lv_up` entry back (`blk_env_get` / `blk_env_put`), parameter binding
and the body run in their own regions, and the per-call / per-statement
bookkeeping (`cur_pos`, `struct_ctr`, `call_lines`, `live_frames`, the
`call_*_s` names, run_block's ok-flag) stopped boxing scalars into the default
region -- `bench/def_maps.sh` had charged 260 of 302 MB to those eleven maps.
What remains is named in `bench/README.md`: ~165 B per block invocation held by
the iterator's enclosing statement until the loop returns (a `while` gets a
region per iteration, a block loop does not), and the collector's trigger,
which watches the object stores and so never fires for a loop that allocates
only frames.

### What the language allows (measured, `bench/reclaim.sh`)

**A container created inside `region R { }` IS reclaimed with the block.** A
million such blocks, each building a Map with a key and a value:

    init=2  bytes=5242880  acquire=1000000  release=1000000

The region is acquired and released a million times, reused every time, and the
region allocator asked malloc for 5 MiB in total. The map, its keys and its
values go with the block.

**This corrects the opposite conclusion recorded here earlier**, and the way it
was wrong is the useful part. Those probes measured peak RSS, and peak RSS grew
linearly with the iteration count -- so the report said "a Map created inside a
region block is still there when it exits". What actually grew was the STACK: a
region block in a recursive function's body stops clang turning the self-call
into a loop (the C codegen says so in its own comment), so the recursion keeps
about 250 bytes a frame. Three probes separate it:

| probe | peak MiB | what it says |
|---|---|---|
| a recursion that allocates nothing | 1 | the tail call IS optimized when nothing interferes |
| the same plus 1M strings, no region block | 162 | strings in the default region stay |
| the same with a region block and a Map | 247 | heap is 5 MiB (above); the rest is stack |

**Peak RSS cannot answer "was this reclaimed?"** — it answers "how much did the
process hold", which sums a reclaimed heap and an un-optimized stack. The harness
now reads the region runtime's own counters, which is the measurement that can.

(2026-08-22 correction: the "~250 bytes a frame of stack" attribution above was
itself wrong. Those probes format a string per iteration, and each format leaked
its asprintf buffer -- the v0.1.294 leak below. With the leak fixed, the
region+Map probe peaks at **1 MiB**, not 247; and a region block in a 10M-deep
tail recursion runs in the default 8 MB stack with a 1 MiB peak, so the
self-call stays a tail call. The numbers in the table above are of their date.)

What is still true from the earlier round: `map_delete` and overwriting a key do
not give memory back **within a living container** (231 MiB after a million
set-then-delete pairs, zero entries left), and the handle scheme forbids deleting
anyway, since `arr_new` takes its id from `map_len arr_store`. And the frame is
still the bigger half of what this interpreter leaks: 200k plain method calls
cost 2588 MiB while adding nothing to any store.

But the conclusion that follows is the opposite of the earlier one. **Reclamation
does not wait on new language support.** A per-call `region R { }` in the
interpreter's own source would put the frame's `map_new` in that region -- the
typer binds a container created inside a block to the block's region, the way it
already does for `strbuf_new` -- and the block would hand it back. A prototype was written, and it does not compile yet -- for two reasons that are
worth more than a working patch would have been.

**A frame has two lifetimes, and the typer said so.** Wrapping `run_meth`'s body
in `region CALL { }` fails with `expected &__heap unit, got &CALL unit` on the
frame binding: a `define_method` body's frame is a child of the scope the block
was written in, so a closure reads it after the call returns and it has to live
as long as that closure; an ordinary method's frame is reachable only while the
call runs. They were one `if` with two branches, and the language refused to give
them one type. Written the other way round -- one lifetime for both -- a closure
would be reading a freed region.

**A shared helper cannot be region-polymorphic inside a recursive group.** Split
the two lifetimes into two branches and give them a common `run_meth_in frame
...` and the same error moves to the call: the helper's frame parameter unifies
with `__heap` from the first branch. Annotating it `Map['r, str, Val]` does not
help. `let rec ... and ...` is monomorphic in its own group, and this interpreter
is one enormous group.

**And closure environments always take the default region.** In the generated C
there are 2558 references to the default region against 1346 to the current one,
and **2548 of those are closure environments** -- so even with the block in
place, every closure the body builds would stay. That is consistent with the
older measurement: patching the generated C so `map_new` follows the current
region reclaimed 17%, and the rest is mostly these.

One of those two landed upstream and was then measured here, which changed what is
left. Closure environments now follow the current region and carry a copier that
lets them leave one -- so a region block in this interpreter's own source can
reclaim what it allocates.

A region **per statement** (every statement of a body but the last, whose value is
discarded) was tried, and it works: it needs no region-polymorphic helper, because
a statement creates no frame. Measured on 200k plain method calls it was **1181
MiB against 1358-1996 before, and the same number three times out of three** --
bounding what is live is what makes peak RSS repeatable, which is worth as much as
the megabytes -- and it was FASTER, 1.16-1.20s against 1.43-1.58s, because less
allocation is less page faulting. A block-storing loop went 1068 to 651 MiB.
corpus stayed at 157/157.

**It is taken.** Getting there corrected two claims of mine, and the corrections
are the useful part.

The first attempt attributed the cost to the closure struct growing from two
pointers to three -- a closure is passed by value through every frame of this
interpreter's dispatch, so that is a real per-frame cost, and `ld` caps
`-stack_size` at 512 MB on arm64 with this interpreter already there. Upstream
then moved the copier into a header on the env, so the closure is two pointers
again for every program. **The pair still overflowed**, so the third pointer was
not the cause, or not the only one.

What the pair actually is: `Thread.new { while true; // =~ "" end }` plus a regex
loop, and its outcome depends on WHICH LIMIT TRIPS FIRST -- the interpreter's
50M-iteration step budget or the native stack. It flips on changes that have
nothing to do with either: the same source at `-O1` overflows and at `-Os` does
not. It is a canary sitting on the line, not a signal about a change. Recorded
here so the next person to see `err=59` does not read it as a fresh regression:
**bootstraptest is pass=1568 fail=12 err=59**, and the 59th is that pair.

Everything else is at its record with the region in place: corpus 157/157, rgtest
at its tallies, bundlertest all four MATCH, and the memory and time numbers above.

Still open, unchanged: region-polymorphic functions inside a mutually recursive
group, which is what a region per CALL needs -- a frame has two lifetimes (an
ordinary method's dies with the call, a define_method body's is read by a closure
afterwards) and every frame-taking function here is in one recursive group.

### Where the remaining memory sits, split by pool (2026-08-22)

`bench/region_split.sh` counts every bump allocation into one of two pools with
opposite fates: the DEFAULT region (nothing reclaims it, ever) and BLOCK regions
(statement regions; handed back at each block's exit). 200k iterations each,
after the v0.1.294 leak fix below:

| workload | peak MiB | def bumped | def blocks | blk high-water |
|---|---|---|---|---|
| `i += 1` and nothing else | -- | 38 | 60 | **1024** |
| temp strings (w1) | 929 | 138 | 252 | **1024** |
| dead objects (w2) | 1795 | **1051** | **2044** | 1025 |
| plain calls (w3) | 1133 | 352 | 508 | **1025** |

Three mechanisms, now separately sized:

**A loop is one statement, so the statement region does not help inside it.**
The while's own region holds every iteration's temporaries until the loop ends:
~1 GB high-water even for a body of `i += 1` (4-13 KB per iteration). The
statement-region work reclaims BETWEEN statements; a 200k-iteration loop never
gets there. The counterpart move -- a region per loop ITERATION -- needs no
region-polymorphic helper for the same reason statements did not: an iteration
creates no frame. Untried, and it is the largest single number in every
workload above.

**A local-variable write permanently costs 60-190 bytes.** Differential probes
(1 vs 4 writes per iteration): an int overwrite is ~64 B, a small string ~178 B,
copied into the env map's region -- the default -- where the orphaned previous
copy is unreachable and unreclaimed. `map_set` on a bump arena never reuses the
slot. This is the whole of w3's def growth: its census shows NO store growing;
352 MiB of def is nothing but assignment copies.

**Dead guest objects are the def majority in object code, and the oracle says
they are all collectable.** w2's 200k objects leave 1.4M store entries
(ivars 2/obj, ocls 1/obj, arr_store 2/`new` + 2/instance-call -- the recorded
`__args`/`__params` pair) and 1051 MiB of def. The same program under ruby holds
**17,657 live slots after GC.start** -- less than an empty interpreter's
baseline. Everything mere-ruby keeps here, a guest collector may take.

And one runtime inefficiency that costs time rather than footprint: statement
regions NEST, the region-struct cache is one deep, and releases arrive out of
cache order -- so w2/w3 malloc and free ~196 GB of 1 MB seed blocks over a run
(`blk_blocks_cum`). A small stack of cached regions would end it.

### A region per loop iteration (taken, 2026-08-22)

The largest number in the pool split -- ~1 GB of block high-water held because a
loop is one statement -- is gone. `run_while` / `run_dowhile` wrap each
iteration, CONDITION INCLUDED, in `region ITER { }`; "condition false" leaves
the block as `FBreak VNil`, which already means "leave the loop with nil" to
the match around it. A first version wrapped only the body and a 10M-iteration
loop still held 19 GB of condition temporaries and flow copies; wrapping the
condition took it to 2.2 GB, all of it the def-region write cost below.

| workload | before | after | blk high-water |
|---|---|---|---|
| `i += 1` x200k | 807 | **46** | 1024 -> 9 |
| temp strings (w1) | 929 | **142** | 1024 -> 9 |
| dead objects (w2) | 1795 | **1021** | 1025 -> 10 |
| plain calls (w3) | 1133 | **359** | 1025 -> 10 |

w2's remainder is the def region almost exactly (1051 bumped): dead guest
objects, the collector's half of the problem, untouched by construction. Time
got slightly better (w3 1.33s -> 1.27s), as with the statement region. The
self-call stays a tail call with the region in the body -- measured, 10M deep,
default stack, 1 MiB peak -- because block regions are heap structs behind a
per-thread cache since v0.1.290-293.

The one-deep cache is now the visible cost: the iteration region nests inside
the while-STATEMENT's region and around the body's statement regions, releases
arrive out of cache order, and one 1 MB seed is malloc'd and freed per
iteration (~200 GB of churn per 200k x N-statement run, `blk_blocks_cum`).
Time says libc absorbs it; a small stack of cached regions upstream would end
it.

Loop-flow semantics against ruby: break-with-value, next, redo, begin/end
while, until, a raise crossing iterations, and a stored string outliving its
iteration all match byte-for-byte. Gates: corpus 158/158, bootstraptest
pass=1570 fail=12 err=58 (one better than the record; the canary pair fell on
its passing side), parsetest 34 (was 37), rgtest / bundlertest at their
tallies.

### Strings, arrays and hashes are collected too (slice 2, 2026-08-22)

The collector now takes the value stores, with ZERO threading: mere v0.1.297
gave containers `map_compact` / `vec_compact` (a compacted container owns its
own arena and swaps generations -- semantically invisible, allocator-visible),
so the globals stay global and their helpers keep their shape. The planned
alternative -- threading the stores through their access paths -- was measured
first and killed by the measurement: 518 functions in the transitive no-world
closure, on top of ~2100 direct call sites.

At a collection, after ivars/ocls rebuild: dead arrays are dropped from
arr_store (survivors out, `map_clear`, survivors back, compact), dead hash and
string slots are blanked ONCE in their vecs (ids are positional, so a dead id
stays valid-and-empty: ~17 bytes of stub forever), both vecs compact, and the
str_enc / str_frozen side tables are filtered the same way. Array ids come
from a counter now (map_len shrinks when entries drop). VStr joined the mark.

What it took to get right, each measured:

- `map_delete` rebuilds the hash index INTO THE MAP'S REGION per call --
  deleting a store's dead entries key by key grew its fresh private arena to
  68 GB. mere v0.1.298's `map_clear` is the mass-deletion primitive; the
  clear-and-reset pattern replaced every deletion loop. (This interpreter
  also had its OWN `map_clear` -- a delete-per-key quadratic version --
  shadowing the builtin; it is gone and its six callers now hit the builtin.)
- The trigger charges the vec scans: a collection walks every slot EVER
  created (positional ids), so the scan term includes `vec_len str_store` --
  without it, arr_store's deletion shrank the old term to its floor and a
  200k-object run collected 100+ times, 83 seconds of walking a million
  string slots.
- Blanking is idempotent-guarded: re-blanking every dead slot every
  collection allocated a fresh "" per slot per collection.

Measured: a string-dominated run (20k dead objects x 20 KB strings) peaks at
365 MiB against slice 1's 464. A frame-dominated run is unchanged (1059 vs
1001 within arena-slack noise) -- frames were never this slice's target.
corpus 158/158, bootstraptest pass=1570 fail=12 err=58 (the record),
bundlertest 4 MATCH, gemtest 21/6/2.

Honest limits, recorded as next lanes: the trigger counts ENTRIES, so a
byte-heavy store (20 KB per entry) under-collects -- an allocation-volume
counter is a language lane; vec dead slots are stubs forever (id reuse needs
a free list); and frame env maps remain the largest uncollected share.

### `require "rubocop"` loads (2026-08-23)

The 68 GB arena had a name after all: **an infinite ancestor walk**, triggered
twelve requires in by pp.rb. Two fidelity bugs, found by correlating the
require timeline with >128 MB block allocations, then prefix-bisecting pp.rb:

- **`class Object < BasicObject` (pp.rb line 609) put a cycle into the
  default ancestor chain.** The reopen legitimately writes
  sup["Object"] = "BasicObject" -- but four walkers (has_meth, lookup_meth,
  meth_private, meth_protected) knew only "Object" as their terminal and
  defaulted everything else to Object: BasicObject -> Object -> BasicObject,
  forever, allocating per step -- one method call after the reopen was the
  whole 68 GB. The walkers now know the real root (BasicObject terminal,
  Object -> BasicObject by default), matching what ancestors_of_raw always
  knew; the superclass-mismatch check's default had the same blind spot.
- **`class << ENV` (pp.rb line 389) hid ENV's builtins.** Opening an object's
  singleton retags ocls with the singleton-class name so mixed-in methods
  dispatch -- but the builtin arms match by class NAME, and "(sng:...)"
  matches none of them: ENV['HOME'] was a NoMethodError for every reader
  after pp loaded. When the singleton chain does not answer a name, dispatch
  falls back to the singleton's superclass, where the builtins live.

With both fixed: `require "rubocop"` -- ~250 files, the load that defined
this interpreter's memory problem -- **completes: OK in 89 s at 19.8 GB
peak**, against 117 GB and a 10-minute timeout when this arc began. The
remaining 19.8 GB is dominated by frames (the env-store lane), which is now
the last big number standing.

### The collector reaches inside require chains now, and what it found there (2026-08-23)

Four pieces landed together, each gated on corpus/bundler (bootstraptest on
the final tree):

- **The world's region loop is gone.** Since map_compact, every store --
  ivars and ocls included -- reclaims by rebuilding in place through its
  stable handle, so a collection is a plain function (gc_collect, its scratch
  in its own `region GCC` block) callable from any depth, and the driver is
  plain recursion. The carry, the cursor tuples and the arena swap all
  dissolved.
- **Top-level while chunking shipped on the third attempt**, after classifier
  v2 -- which reads the GENERATED C's map value types instead of guessing
  from setter sites -- found 12 missed roots (load_ctx, holding the current
  require's file and dir as VStr, was the one that broke bundler). w2-shaped
  loops: 1020 -> ~815 MiB.
- **In-stack safepoints**: between any two statements of any body, when no
  eval context above may hold an unrooted in-flight value (gc_unsafe == 0)
  and the stores have outgrown gc_collect's own thresholds. Method and block
  bodies count as unsafe -- their callers' half-evaluated expressions are
  invisible to the mark -- EXCEPT a call that is exactly `name literal...`
  as a whole statement (the gc_bare baton): literal arguments admit no
  intervening call to steal the baton, and a bare statement holds nothing
  else, which is precisely the shape of a require chain under rubygems'
  Kernel#require replacement.
- **A region per call, body only.** The 2026-08-20 attempt died on the
  frame's type; creating the frame OUTSIDE and running only the body inside
  `region MCALL` passes the typer, and nested calls' machinery now dies with
  the nearest enclosing call instead of landing in whatever ancestor
  statement's arena was current.

What rubocop measured after all of it: **still ~88 GB**, and the pool split
finally names the remaining two beasts precisely. (1) The default region
holds 12 GB at 75 seconds -- frames, the D-lane, as expected. (2) In the
final phase ONE block arena's doubling chain explodes from ~2.7 GB live to
~68 GB (blk_bump +86 GB in the same phase) -- a single held region absorbing
a giant allocation episode, present before the per-call region and not
dented by it. Unattributed. The next probe is a require-timeline correlation
(bench/require_trace.rb) to name the file being loaded when it detonates,
and the candidate mechanisms to check first are: a giant while inside a
method whose per-iteration copy-outs cascade into a held arena; a single
method body whose MCALL arena absorbs a parse; and the collection itself
running inside region GCC against some store it walks quadratically.

### The interpreter minted a string id per method call, for backtraces (2026-08-22)

The largest string churn in the interpreter was its own position bookkeeping:
every call recorded its name, file and method as VStr Vals -- one fresh
str_store slot PER RECORDING, immediately overwritten. Measured: one slot per
`i += 1` (operator dispatch records too), eleven per `P.new`; a 45-second run
minted 2.6M slots, and since vec ids are positional, every collection walks
every slot ever minted, forever. The bookkeeping maps (call_names, call_files,
call_meths, cur_pos "m"/"f") hold RAW strs now: an overwrite is map-internal,
reclaimable by the map's own compaction, and no id is ever issued. A 10k-
iteration `i += 1` loop went from 10,209 str slots to 202; w3 (plain calls)
from 359 to 287 MiB, w1 142 -> 134, w2 1104 -> 1078.

Top-level while chunking was attempted AGAIN on top of this (its first
precondition, the churn, now fixed) and held back AGAIN, one bug further in:
w2 with chunking measured 816 MiB at normal speed (the storm is gone), but
bundler's definition/setup steps regressed to DSLError. Bisected: the churn
fix alone keeps bundler green; the chunking's byte-pressure trigger makes a
collection fire at a NEW moment between the probe's statements, and that
collection eats something bundler needs -- a missed root. The root list was
classified from setter sites whose value argument is a LITERAL constructor;
setters that store a VARIABLE were classified by hand, and at least one
Val-holding global slipped through. Precondition for the third attempt: a
root classifier that covers variable-argument setters (or: enumerate the gap
by diffing "maps whose values unify with Val" from the typer's view against
the root list).

### What the collector still cannot reach, measured to its edges (2026-08-22)

Three measurements close the day, each naming the next wall precisely:

**`require "rubocop"` is one statement, so the collector never runs.** 88 GB
peak, died at ~155 s -- barely moved from the pre-collector 117 GB, and the
byte-pressure trigger (below) moved it not at all, because the entire ~250-file
load happens INSIDE one top-level `require`: the safepoint discipline (collect
only at the driver's loop head, where no arena handle is on the interpreter's
stack) never gets a turn. rubocop-ast, which loads as its own statement chain,
went 3.2 GB -> 0.99 GB. The lesson generalizes: this collector helps programs
whose life is many statements, and a safepoint INSIDE the call stack -- which
is the frame-collection problem again -- is what rubocop-class loads need.

**A byte-pressure trigger exists upstream now (mere v0.1.299 map_bytes /
vec_bytes) and it fixed the byte-blind case**: a store of 20 KB values went
365 -> 190 MiB. Absolute byte floors do NOT work -- vec stub mass grows
monotonically past any constant and pins the pressure true (a collection per
iteration, each copying every slot ever issued). Incremental (2x the
post-collection baseline) is the shape that held.

**Top-level while chunking was built, measured, and REVERTED.** Bounded
stretches of a top-level while with collections between them work
mechanically (corpus stayed green), but the measurement found a pre-existing
churn this file had never seen: w2-shaped code creates ~30-60 VStr per
iteration (invisible before -- they accumulated silently in the default
region; the collector makes them visible because every one becomes a vec slot
that every blank-and-compact pass walks), and late in a run each collection
is O(slots-ever) against a trigger interval that stopped scaling with it. A
GC storm: 164 collections in 45 s. Until the per-iteration string churn is
attributed (its source is NOT obvious: the workload allocates no Ruby
strings) and the trigger charges the vec-scan cost on the byte axis the way
it does on the entry axis, the chunking stays out. The branch's diff is
preserved in this entry's history; corpus/bootstraptest were green when
reverted -- the revert is about the storm, not correctness.

### gemtest went red the day the rubygems preload landed, and nobody ran it

The interpreter preloads the stdlib's rubygems now; gemtest exists to load a
CHECKOUT's rubygems. Both at once redefine `Gem::LoadError` with different
parents, so every gem "CRASH"ed with a superclass mismatch -- ok=0 fail=29,
both with and without the loop change, which is what cleared the loop change.
The gate now sets `MERE_RUBY_NO_GEMS=1` (the preload's own escape hatch):
ok=21 fail=6 skip=2, its recorded shape. The lesson is the CI one at repo
scale: a gate that is not in the routinely-run set is not green, it is
unknown.

### A guest collector, over the world the region loop carries (2026-08-22)

The interpreter now has a garbage collector for Ruby objects. The world's four
maps (meths / sup / ocls / ivars) are created inside `region GCW loop` in
run_src -- they were already threaded through every function, so not one call
site changed -- and the driver runs top-level statements in chunks: when the
object stores grow past a threshold at a safepoint (the loop head, where
nothing on the interpreter's own stack holds an arena handle), it marks every
reachable object id from the roots, rebuilds ivars / ocls with only the live
entries into maps born in the loop's scope, and `Continue` swaps arenas. The
copy is the compaction; dead entries and every dead map-internal copy stay
behind in the released arena.

What made it possible, and what it cost to learn:

- **Object ids come from a counter now** (`"$next"` inside ocls, seeded from
  map_len on first use), not from `map_len ocls` -- with entries being dropped,
  map_len shrinks and a fresh object would collide with a survivor.
- **One line had pinned the whole world to `__heap`.** Five sites built a
  placeholder blk tuple with `ivars` in the env slot ("unused; must be
  Map[str,Val]"). That unified the world's region with the env region -- envs
  are genuinely __heap, through bind_store -- and the carried world became a
  type error 5,000 lines away. The placeholder is now one shared empty map
  (per-call `map_new` placeholders cost ~200 bytes per `new` -- measured as a
  112 MiB regression before being shared).
- **The root set is every Val-holding global, classified from all 120
  setter sites, not picked by intuition.** The intuitive ten collected the
  current Thread object out from under bundler (Monitor#synchronize raised
  ThreadError). The type checker keeps the list honest in one direction only
  -- a non-Val map here will not build; a MISSING map is the direction to fear.
  The env-shaped stores (bind_store, lv_up scope-chain parents, proc_store /
  proc_yblk captured envs) are walked through their map values.
- **The collection trigger charges cost against garbage**: a collection scans
  arr_store / hash_store whole (not compacted in this slice), so triggering on
  ivars growth alone went quadratic (450 collections, +28% time) and
  triggering on total size collected twice and reclaimed nothing. Live size
  plus half the scan size: several collections a run, and FASTER than no
  collector on the collector's home turf (2.42s vs 2.56s -- less allocation is
  less page faulting).

Measured, 200k dead objects of 10 ivars across 200k top-level statements:
**1012 -> 848 MiB**, faster. Final census after 20k dead objects: ivars=298,
ocls=174 -- bounded. corpus 158/158, bundlertest 4 MATCH, gemtest 21/6/2,
rgtest at its tallies.

What this slice does NOT collect, in order of size: frame env maps (lane (2);
they are __heap by unification with captured envs), arr_store / hash_store /
str_store entries (their helpers close over the globals; threading them
through ~500-1300 call sites is the next slice), and anything inside a single
top-level statement -- the safepoint is the loop head, so a program that is
one big `while` never collects (w2: +8% peak from the second arena's doubling
slack, the honest price until top-level whiles run chunked, which is the
planned counterpart of the statement chunking).

### The formatter leaked, and it wore the mask of a different problem

Mere v0.1.294 (2026-08-22): both native backends copied every asprintf result
into the region at the `__lang_str_of_cstr` boundary and never freed the buffer
-- 160 bytes per `str_of_int`, quadratic for `show` of a list. Found by
`bench/region_reuse.sh` asking an unrelated question: whether a region whose
chain GREW past one block hands memory back in reusable form (the property a
compacting collector stands on). The answer looked like no -- peak grew ~38 MiB
per sibling region, linear in the count -- while the runtime's own counters
said everything was returned. Both meters were honest; the gap between "we
returned it" and "it came back" was a third party holding it.

With the fix, the original question answers itself: 1, 8, and 32 sibling ~64 MB
grown regions all peak at 36-39 MiB. **Released grown chains are fully reusable
through plain libc; a compaction loop's footprint is bounded by about one live
generation, and no runtime block pool is needed.** On this interpreter the fix
alone was worth 16-30% of peak: w1 1297 -> 929, w2 2555 -> 1795, w3 1354 -> 1133.

### Two wastes the census found, and what they were worth

`senc_set` recorded `"UTF-8"` for every string, in a map whose *absence* of an
entry already means UTF-8: 200k interpolated strings left **1.2M permanent
entries** saying nothing. Skipping the default (and clearing a tag when one is
there, which is a real change) takes that to **0** -- but peak RSS moves about
1%, because 1.2M entries are ~34 bytes each and the memory is in the strings and
the frames. **Entry counts are not proportional to memory**, which is worth
knowing before optimising against a census.

Every call into a user-defined method stores `__args` and `__params` as two fresh
arrays in `arr_store`, permanently, and the only reader of either is a bare
`super`. Removing them entirely (which breaks `super`) is worth **6.6%** on
object-heavy code -- 6286 MiB to 5874, three runs each, identical every time --
and nothing at all on top-level calls, which do not take that path. Doing it
properly needs a per-method "contains a bare super" flag, computed once and
cached; it is recorded here rather than done, because 6.6% does not change what
the interpreter can run.

### What tagging an encoding costs, and it is measurable

`Integer#to_s` answers US-ASCII now, which is right, and 200k interpolated
strings therefore leave **200k permanent entries** in the encoding map -- one per
number that became text. Correctness bought a per-temporary entry, at ~34 bytes
each. The census is what makes that visible rather than mysterious, and it is a
reason the encoding side table wants to become something reclaimable rather than
a program-lifetime map.

### What would change it

A per-call region reclaims 6.4% today, 17% with the generated C patched so
`map_new` follows the current region -- and the paragraph above says why that
patch is not the only way: the language already reclaims a container bound to a
block's region, so the interpreter's own source is where the block belongs. The rest is the `Map`s themselves. The one
capability that would change the picture is upstream: **a container whose memory
dies with its region** (or can be freed), which would let a region-per-call take
the whole frame -- the 13.4 KB a call leaks now. Failing that, the alternative
inside this repo is to stop using Mere `Map`s for the Ruby heap and put objects
in a self-managed arena with its own free lists, which is a rewrite of the value
representation rather than an addition to it.

### The upstream capability arrived, and the frames came back (2026-08-22)

Mere v0.1.300 added `map_recycle`: wipe a map AND wind its private arena back
to one warm 4 KB seed, freeing the growth blocks through libc. That is the
"container whose memory dies" the paragraph above asked for, in the form this
interpreter can actually use -- not tied to a region's lexical extent, because
a frame's extent is dynamic (it dies at return, UNLESS a proc captured it).

On top of it, the frame pool: `call_method` / `run_meth` take each method
call's frame from a pool of recycled frames and hand it back at return. The
one soundness question is capture -- a proc, a captured yield block, or a
Thread body holds its env beyond the call -- and the answer is a `__captured`
mark written at the choke points every proc-shaped store already goes through
(`store_proc` / `store_yblk`, wrapping the twenty-two `proc_store` and four
`proc_yblk` write sites), walking the scope chain via `lv_parent_of`. A marked
frame is simply never pooled. Bindings need nothing: `binding` stores an
`lv_flat` copy, not the frame.

Measured (all on the same day, same machine, three runs each):

| workload | before | after |
|---|---|---|
| dead objects (w2) | 815 MiB | **454 MiB** |
| plain calls (w3) | 296 MiB | **174 MiB** |
| rubocop load, peak RSS | 12.1-13.9 GB | 11.2-12.6 GB |
| rubocop load, frames created | one per call | **5,967 for 5.47M calls** |

The counters (`MERE_RUBY_STORE_STATS=1` prints them) are the deterministic
answer peak RSS is not at this scale: 5.47M method calls were served by 5,967
actual frames (916x reuse, zero pool drops), and 22.4 GB of frame-arena bytes
were wound back over the load -- with the caveat that ~4 KB of that figure per
return is the seed floor, so it measures traffic through the pool, not what
the old code would have leaked. What peak RSS does say: the frame share of a
rubocop load is gone (the honest ~1.5 GB, not the 12 GB a single noisy run
suggested the day before -- yesterday's 19.8 GB baseline measured 12.1-13.9
today, same binary semantics; the non-reproducibility section above exists for
a reason). The mountain that remains is the other stores -- str_store /
arr_store / ivars and friends, the "next slice" threading already recorded.

### The mountain was not the stores, and "the last statement runs bare" (2026-08-22)

The prediction above was wrong, and the byte rows that `MERE_RUBY_STORE_STATS=1`
now prints are what killed it: after the frame pool, ALL the object stores
together hold ~430 MB of a ~10 GB rubocop load. The resident memory lives in
REGIONS -- and sampling the default region's allocation sites (a scratch
instrumented build; the sampler pairs each allocation's PC with its caller)
named two causes, one here and one upstream.

Here: `run_stmts` wrapped every statement of a body in `region STMT { }` --
EXCEPT the last one, whose value is the body's result and which therefore ran
bare, "into whatever region is current". When the current region is the
default one and the last statement is `require "rubocop"`, the entire 250-file
subtree runs with every method call's copy-out (~600 bytes each, one per
call, 3.3 GB of a load) and every statement's scratch going to the region
that never frees. The last statement now runs under the same region and
per-type copy-out as every other statement; sound by the same two rules
(flow values copy out, stores copy in on write).

Upstream (mere v0.1.301): a `fail` that longjmped out of nested region blocks
leaked every chain it jumped over -- recorded in the compiler as acceptable
when regions were rare. An interpreter that wraps every call in a region and
models every guest exception as a fail leaked ~1 MB per caught failure
(measured: 2,000 rescues = 2.1 GB; flat at 4 MB with the fix). The C backend
now unwinds an active-region stack from try_or's catch arm.

Measured after both (same day, same machine, three runs each): rubocop load
11.2-12.6 -> **9.1-10.1 GB**, time unchanged; w1/w2/w3 unchanged (their
last statements were cheap). What remains is quantized arena slack (the
default region's doubling chain counts 17.2 GB of address space for ~2 GB
of use -- blocks that grew and were abandoned half-empty) plus what the load
genuinely keeps live; the next honest step is a compacting pass or a
smaller-doubling policy, not another leak hunt.

## The Wasm playground has no sockets, no files, and no stderr of its own

`docs/build.sh` works again (Mere v0.1.259 — four Wasm-backend bugs, of which
the first was `unbound variable: skip` in the vendored mgz package). What the
page cannot give the module, it stubs: every socket call fails, so
`TCPSocket.new` raises `Errno::ECONNREFUSED`; `File.read` of a real path
returns nil; and stderr is a separate import now, which the page routes to the
same output panel the program's own output goes to. A program that needs any
of those needs the native build.


## `pack`/`unpack` cover the integer, string and float directives, not all of them

`pack("E")` and its family (`E`/`e`/`G`/`g`/`D`/`d`/`F`/`f`) hand out real
IEEE-754 bytes, recovered by arithmetic rather than by looking at the
representation: scale the value into `[1, 2)` to find the exponent, and the
remaining fraction is an exact integer. Zero (both signs), subnormals,
infinities and NaN are all handled, and `unpack` inverts every one of them.
The directives that remain unimplemented are the width-suffixed and
platform-dependent integer ones (`l`, `q`, `w`, `j`, `!`-suffixed), `B`/`b`
bit strings, `M`/`m`/`u` encodings, and `@`/`X` positioning.

## A String's instance variables do not survive `dup`

`str.instance_variable_set(:@x, 1)` works, and so does reading it back — the
storage is keyed by the string's handle. `dup` copies the string but not that
storage, so the copy answers nil. An object's `dup` does copy its ivars; this
is the primitive path, which does not have the world to copy them through.

## A character literal is one BYTE unless it is an escape

`?a`, `?\001`, `?\x41`, `?\n`, `?\s` and `?\u00e9` all read as ruby reads
them. A literal *multibyte* character — `?é` written directly — takes only its
first byte, because the source is scanned as bytes there. Written as an escape
it is correct, and inside a string (`"é"`) it is correct either way.

## A top-level `def` is reachable without a receiver, or on Object if made public

Ruby puts a top-level `def` on Object as a **private** method. Here it lives in
a table of its own, which is what a bare call looks in; `"str".m` therefore
raises NoMethodError, exactly as it does in ruby for a private method. What
`public def m` (or `public :m`) adds is a copy in Object's table, so every
receiver finds it — which is the whole observable difference between the two
in ruby. A top-level method that is redefined *after* being made public
updates the original, not the copy.

## `block_given?` inside a define_method body sees only the immediate frame

A `define_method` body is a block, and Ruby's `block_given?` inside it asks about
the frame the block was **written in** — never about the call that reached the
method. `C.new.dm { }` answered `true` here, where Ruby answers `false`; it does
now too, and a body defined inside a method that *was* called with a block
answers `true`, as Ruby does.

Both were fixed in later slices: a block asks about the enclosing *method* frame,
which records whether its call was given one, and a `define_method` written
inside a block records that same answer from the environment it was written in.
`def mk; C.module_eval { define_method(:m) { block_given? } }; end` called as
`mk { }` answers true, as it does in Ruby.

`yield` inside a define_method body is a SyntaxError in Ruby and is accepted here
(it reaches the block captured at definition time). `|&b|` receives the caller's
block in both, which is the supported way to take one.

## An exception in flight lives in one slot, and that slot has been consumed twice

The pending exception is one entry (`$exc`) plus a few keys recording where it was
raised. Anything that *handles* an exception consumes them, so any handling that
happens while an exception is already in flight destroys the one in flight. Two
such places were found by asking the interpreter where the loss happened rather
than by guessing — `MERE_RUBY_LOST_EXC=1` prints the internal message, the frames
of the last raise, and the frames of the spot that reports the loss:

- `rescue *[]` — an empty splat — rescued *everything*, because it reached the
  matcher as the same empty list that a bare `rescue` does. In ruby it rescues
  nothing. bundler writes `rescue *[const_get_safely(:ENOTSUP, Errno)].compact`.
- an `ensure` body that handles an exception — inline, or inside a method it calls
  — consumed the slot of the exception it was running under, which then came out
  as `StandardError` with an interpreter message. bundler's `Definition#lock` does
  this on every write.

Both are covered by `corpus/150_exception_identity.rb`.

A third report of the same placeholder was **not** a lost exception, which is
worth keeping written down: the diagnostic said the last raise was shallower
than the report, and that reads as "something destroyed it" only if you assume a
raise happened at all. Nothing had. `File.open` was refusing bundler's Pathname
below the level that has a ruby exception to raise (see the path-argument entry),
so there was no exception to lose. The lesson is about the diagnostic, not the
bug: "no raise since" and "the raise was destroyed" produce the same evidence,
and only reproducing the failing call separates them.

## Error message wording follows ruby 3.4, and every gate compares against 3.2.2

`undefined method 'x' for an instance of C` is 3.4's wording, chosen here on
purpose (`undef_blame`): it names the receiver, where 3.2's `for x:C` names the
receiver's inspect output. The reference ruby in every gate is 3.2.2, which also
quotes differently (`` `x' `` against `'x'`). So any spec file that prints a
NoMethodError or NameError message is a DIFF **by construction** -- not a missing
feature, and not something a corpus program can hold, since the corpus is
byte-exact against 3.2.2. corpus/151 prints `e.class` for that reason.

**It has been measured, and it is negligible**: of 6791 failing examples across
the 629 DIFF/CRASH files, **12** are a message whose shape differs (`mspec/classify.sh`,
which buckets mere-ruby's own FAILED/ERROR lines by cause rather than by file).
So the DIFFs are real gaps, and changing the wording policy would buy almost
nothing. The ranked causes, from the same run:

| cause | examples |
|---|---|
| `NoMethodError` -- the method does not exist | 1168 |
| an encoding tag (`expected #<Encoding:US-ASCII>, got #<Encoding:UTF-8>`) | 816 |
| `ArgumentError` / `TypeError` expected and not raised | 673 |
| errors out with NameError / ArgumentError / StandardError | 476 |
| a method answering nil where a number belongs | 700+ |
| the wording of a message | 12 |

The encoding row was **774 of its 816 in one file**, `core/integer/chr_spec.rb`,
and one method: `Integer#chr` tagged everything UTF-8. It is now 25 (see the chr
entry below). A concentration like that is what the classifier is for -- a
per-file list makes every cause look equally rare, and the largest one had no
name.

One thing the classifier makes plain: **a file's verdict and its examples are
different measurements**. `chr_spec.rb` went from 774 failing examples to 25 and
is still a DIFF, because a file MATCHes only when every example does. Progress on
a cause has to be counted in examples.

## instance_variable_get accepts a name that is not an instance variable name

`Object.new.instance_variable_get("x")` raises `NameError: 'x' is not allowed as
an instance variable name` in ruby. Here it answers nil -- a silently wrong
answer, the kind that is worse than a refusal. `instance_variable_set` has the
same hole.

## Errno exceptions raised from ruby code do not prefix the system message

`raise Errno::ENOENT, "boom"` reads `No such file or directory - boom` in ruby:
an Errno class puts its own strerror text in front of whatever message it is
given. Here the message is `boom`. The Errno exceptions this interpreter raises
itself carry ruby's full text (`No such file or directory @ rb_sysopen - path`,
which is what `rescue SystemCallError => e` reports and what bundler prints), so
the gap is in the class, not in the file layer: it needs a strerror table, and a
table of some names would answer wrongly for the rest -- worse than answering
short. `corpus/152` covers the raises that come from the interpreter.

## `Integer#chr` answers a byte or a codepoint, and knows when it cannot

With no encoding argument `n.chr` is a BYTE: US-ASCII under 128, ASCII-8BIT at or
above it, `RangeError: N out of char range` outside 0..255. With one it is a
codepoint in that encoding -- UTF-8 to 0x10FFFF, US-ASCII to 0x7F (beyond it,
`invalid codepoint 0x80 in US-ASCII`), ASCII-8BIT / BINARY / ISO-8859-1 to 0xFF.
`Integer#to_s` is US-ASCII too, in any base.

For an encoding whose character table this interpreter does not have (Shift_JIS,
EUC-JP, CESU-8), two things can still be said, because they hold in every
encoding: a negative number and one past Unicode's last codepoint are out of char
range. Producing the bytes for a codepoint that IS valid needs the table, and
that is refused with NotImplementedError rather than answered with a byte that
means something else -- which leaves about 14 of chr_spec's examples failing, the
ones that ask what is invalid in Shift_JIS.

## A signal handler is recorded and never delivered

`Signal.trap` / `Kernel#trap` accept a handler, return the previous one, and
store it unread; `Signal.list` and `Signal.signame` answer from a name table.
Nothing in this interpreter delivers a signal -- there is no source for one -- so
the handler cannot fire. Refusing instead was measurably worse: every CLI traps
INT on its first line (`bundle` does, line 5), so refusing stops the program
before it starts, while accepting loses only a handler that could never run.

`Process.kill` is not implemented, which keeps the picture consistent: nothing
sends a signal here and nothing receives one.

## rubygems is preloaded when it can be found, as ruby does

ruby loads rubygems before the program (`--disable=gems` turns that off), and
this did not: `bundle --version` stopped at `uninitialized constant
Gem::Requirement`, because bundler expects the gem library to be there already.
Now, if `rubygems.rb` is on the load path, it is required first. With no `-I` and
no `RUBYLIB` -- the corpus, the playground -- nothing is found and nothing is
loaded, so nothing slows down. `MERE_RUBY_NO_GEMS=1` is this interpreter's
`--disable=gems`.

## How far `bundle` gets as a command

`bundle` now runs bundler's own code rather than failing in the interpreter: four
walls came down for that -- `Signal.trap`, the rubygems preload, a module
appearing twice in the ancestor chain (which made thor's `super`-calling
`method_added` recurse 15000 deep), and `Array#*` with a String separator, which
`ui/shell.rb` uses to join its wrapped lines.

That `require "bundler/cli"` raised `Bundler::GemfileNotFound` was NOT eager
evaluation, which is what the first guess said. ruby evaluates the same
`method_option ... :lazy_default => Bundler.settings[...]` at class-body time;
the difference was that `Bundler.settings` **rescues its own GemfileNotFound**
and the rescue did not match, because a rescue clause's bare name was compared as
text rather than resolved through its lexical scope. Five more walls came down
after it (Exception#cause on both representations, RUBY_REVISION, RbConfig.ruby,
`yield "str"`, and a module appearing twice in the chain), and `bundle` now runs
bundler's own code from end to end of its startup.

What stops `bundle --version`, measured with a backtrace rather than guessed:

    NotImplementedError: IO.pipe is not implemented here
      bundler/cli.rb:34:in `dispatch'
      thor/base.rb:485:in `start'
      bundler/cli.rb:28:in `start'

`dispatch` sends `warn_on_outdated_bundler`, which in ruby returns immediately for
a parseable command -- `PARSEABLE_COMMANDS` is `%w[check config help exec platform
show version]` and it is asked `PARSEABLE_COMMANDS.include?(current_command.name)`.
Here that early return is **not taken**, so bundler goes on to its version check,
which reaches Open3 and therefore `IO.pipe`.

Half of that is now fixed, and the half tells the story. thor asks
`public_method_defined?(meth)` inside `method_added` and returns unless the method
is public -- and this interpreter fired the hook BEFORE recording the visibility,
so every one of bundler's `private` helpers looked public to thor and was
registered as a command. Six of them, warned about by name. **The hook fires after
the visibility now, and those warnings are gone (6 to 0).** The same commit fixed
where the hook fires at all: a `def` inside a block or an `if` never reached it,
because it was fired from the class-body walker rather than from the place a
method is installed -- which is the shape `no_commands do ... def ... end` needs.

What remains is one call, and the hunt for it ruled out a lot -- worth writing
down so the next attempt does not repeat it. Not the aliases (`normalize_command_name("--version")`
answers `"version"`, and `map` / `all_aliases` are identical to ruby's); not the
command registry (`all_commands.key?("version")` is true and its value is a
`Thor::Command`, though mere-ruby registers 29 commands against ruby's 31, which
is its own thread to pull); not the visibility or the hook (both now verified);
not hash aliasing through calls and ivars; and **not
`warn_on_outdated_bundler`** -- running with `BUNDLE_DISABLE_VERSION_CHECK=true`,
which returns that method early, changes nothing, so the pipe is reached from
`print_command`'s side of `dispatch`'s block. thor gets its terminal width from
backticks (`stty size`), not from Open3, so the pipe is somewhere else again.

Two things made the caller hard to name, and both are gaps of their own:

- **A block has no frame**, so `dispatch`'s `super do |i| ... end` is the innermost
  thing a backtrace shows: the two methods it sends are invisible.
- **A user-defined singleton method on a builtin class does not win.** `def
  IO.pipe(*a); ...; end` is ignored -- the builtin branch answers first -- so the
  usual trick of overriding a primitive to print `caller` does not work here. That
  is a fidelity gap in its own right: in ruby a singleton definition on IO wins
  over IO's own method.

`IO.pipe` itself now refuses by name -- a real pipe pair needs the OS and nothing
here can hand one out (the socket FFI has no pipes, and `run` shells out instead
of plumbing descriptors). A named refusal is worth more than a NoMethodError on
IO: it says which primitive is missing.

Also open, and found while fixing the rescue clause: a rescue whose class name
resolves to nothing should raise NameError (ruby does) and here it simply does
not match, so the original exception continues. And `Exception#cause` on the
built-in class-and-message representation is always nil, since there is nowhere
on it to record one -- an exception OBJECT records its cause properly.
## `rationalize` is not answered, and now says so

`Numeric#rationalize` returns the SIMPLEST rational within the receiver's
precision -- `0.3.rationalize` is `(3/10)`, where `0.3.to_r` is the float's
exact value `(5404319552844595/18014398509481984)`. Those are two different
algorithms, and only the second one is implemented.

The name used to be in `is_num_method`, the curated list of primitive method
names, with nothing behind it. That made `respond_to?(:rationalize)` answer
**true** and the call raise -- the list asserted a method the dispatcher did
not have. It is out of the list now, so `respond_to?` answers false: a
divergence from ruby that is at least honest about which way it goes.

`integer?` and `to_c` were in the same state and are now implemented, so the
list and the dispatcher agree on everything else it claims. What found all
three was counting from the definition side -- every name the list asserts,
against every name that appears in a dispatch condition -- rather than reading
the list and believing it.

## ENV shadowed everything it had not thought of

Fixed. ENV's dispatch matched on the RECEIVER -- "is this the EnvHash object?"
-- and then handled a fixed list of names, ending in

```
else raise_exc world "NoMethodError" ("undefined method '" ++ name ++ "' for ENV")
```

That last line is the bug. A branch keyed on the receiver **ends the search**, so
every name it did not enumerate was reported absent, including the ones no
object gets to decline: `ENV.equal?(ENV)`, `.frozen?`, `.hash`, `.itself`,
`.object_id` all raised on the one object in the program where they do not work.
Some universal names happened to be answered earlier in the chain and worked,
which is why this looked like a scatter of missing methods rather than one
structural fault.

Two changes, and the second is the one worth copying:

- The arm now declines the universal protocol (`is_prim_method`), keeping only
  `to_s` and `inspect`, which ENV genuinely owns. Anything else falls through to
  the code that answers it for every other object.
- **What ENV answers, it answers as a hash** -- because it is one. The fallback
  builds a hash from the environment and re-dispatches, which is where `each`,
  `invert`, `select`, `values_at`, `slice`, `except`, `merge`, `rassoc`,
  `has_value?`, `group_by`, `sum` and the rest come from. The mutating names
  delegate the same way and then write the resulting hash back.

A delegation like that has one hazard: a mutator that runs on the **copy**
reports success while the environment stands still. That is a silently wrong
answer, so the fallback refuses anything ending in `!` or `=` that it has not
explicitly handled. It is a rule rather than a list, so a name nobody thought of
fails loudly. (Without a block those same names do not mutate at all -- they
answer an enumerator -- so that path is exempt, deliberately.)

`ENV.shift` and `ENV.rehash` are implemented; `ENV.delete_if` with no block
answers a hash where ruby answers an Enumerator, which is the general
enumerator-from-a-method gap rather than an ENV one. `ENV.class` is still
`EnvHash` where ruby says `Object`.

Delegating found two bugs that had nothing to do with ENV, below.

## `Hash#slice` returned the value instead of the sub-hash

Fixed. `slice` was an unconditional alias of `[]`, which is right for String and
Array and wrong for Hash: `{"a"=>1,"b"=>2}.slice("a")` answered `1` instead of
`{"a"=>1}`. A value where a Hash belongs, and quiet about it -- nothing raises,
the caller just gets the wrong type.

It surfaced by delegating ENV to Hash, which is the general shape: **routing one
implementation through another tests the second one with inputs it had not seen.**

## "A bang method answers nil when it changed nothing" was a rule applied to two methods

Fixed. Ruby's in-place methods answer `nil` when they made no modification, and
`self` when they did. mere-ruby had that for `Array#compact!` and
`String#upcase!` and not for:

| | before | ruby |
|---|---|---|
| `[1,2].reject! { false }` | `[1, 2]` | `nil` |
| `[1,2].select! { true }` | `[1, 2]` | `nil` |
| `[1,2].uniq!` | `[1, 2]` | `nil` |
| `[1,2].flatten!` | `[1, 2]` | `nil` |
| `{"a"=>1}.reject! { false }` | `{"a"=>1}` | `nil` |
| `{"a"=>1}.select! { true }` | `{"a"=>1}` | `nil` |

`delete_if` and `keep_if` answer self either way and were already right, which is
what made the inconsistency easy to miss: two of the five names in the same
branch had the opposite contract, correctly.

`flatten!` needed a different test from the others. Length cannot see it --
`[[1],[2]]` flattens to `[1,2]`, same length, different value -- so it asks
whether any element was an array. A rule copied without checking what it is
measuring gives the wrong answer in exactly one of the six cases.

## The numeric protocol was answered by some of the classes that share it

Fixed. `numerator` / `denominator` are Numeric's, not Rational's: Integer and
Rational answered them and Float and Complex said "undefined method". `fdiv` was
missing on Rational. `Numeric#i` was missing everywhere. `polar` returned a Float
angle where ruby returns the Integer `0` for a non-negative real.

Measuring it mattered more than the list did. The absent-name list built from
spec filenames suggested fifteen names each under `integer` and `rational`; a
matrix of every protocol name against every receiver showed **most of the
protocol was already there** and the real gap was five rows. `conj`, `imag`,
`real`, `angle`, `rect`, `abs2`, `magnitude`, `to_c` all worked on all four.

The first matrix was wrong, which is worth recording too: it called `quo` and
`fdiv` with **no argument**, so both showed as absent on every receiver. A probe
that does not pass what the method needs measures the arity error, not the
method. Re-run with arguments, they were fine.

## `rationalize` is implemented, and it is not `to_r`

`Numeric#rationalize` answers the SIMPLEST fraction within the receiver's
precision; `to_r` answers the exact value. `0.3.rationalize` is `(3/10)` where
`0.3.to_r` is `(5404319552844595/18014398509481984)`.

This file used to say the name was deliberately unclaimed, because putting
`to_r` behind it would be "a wrong answer wearing a right one's face". That was
the right call on the wrong premise: the simplest-fraction search is a **defined
algorithm** -- the continued-fraction descent through the Stern-Brocot tree,
which is what CRuby's `nurat_rationalize_internal` runs -- so it could be
implemented exactly rather than approximated.

The interval is what needed care. With an explicit tolerance it is
`[x-|eps|, x+|eps|]`. With none, it is **half an ulp on each side**, taken from
the neighbouring floats (`prev_float` / `next_float`) rather than from the
denominator of the exact expansion: `1.5`'s exact pair is `3/2`, so a
denominator-derived interval would be `±1/4` and happen to give the right answer,
while `0.3`'s would be `±1/2^55` and give back the exact value instead of
`(3/10)`. One case agreeing is not the interval being right.

The name went back into `is_num_method` **with** the implementation. A claim
removed while a thing is absent and restored when it exists is the only order in
which a name list stays true.

## A Struct answered part of its own read surface

Fixed. `to_a`, `values`, `members`, `to_h`, `[]` and `each` were generated for
every Struct class; `size`, `length`, `values_at`, `dig`, `deconstruct_keys` and
`each_pair` were not. Part of one protocol implemented and the rest never reached
for -- the same shape as ENV's missing Hash methods and the numeric tower's
missing arms, in a third place.

They are defined in terms of `to_a` and `to_h` rather than per member, so a
struct of any width gets them and each answer has one source. `deconstruct_keys`
is `to_h.slice(*(keys || members))`, which makes the `nil` case fall out.

**The yield was one file.** `core/struct` went 8 to 9 MATCH for six methods,
where ENV's structural fix moved six. That is worth calibrating against: the
absent-names table in `CAUSES.md` ranks files by their **first** divergence, so
supplying the name it names often just reveals the next thing wrong in the same
file. Five of the remaining 21 are still NoMethodError, three NameError, and the
rest are argument checks and a `to_h` on a keyword-init struct.

The table says where to look, not how much each fix is worth.

## A pair that takes 87 seconds is not an error, and the tally said it was

`bootstraptest/test_yjit_30k_methods/p0` is a generated program of **121,024
lines** that sums to 1000000. mere-ruby gets the right answer and takes about
**87 seconds** on an unloaded machine. The harness's alarm is 60. So the pair
timed out, `perl` exited 142, and `all.sh` counted it under `err` — the same
column as a `NoMethodError`.

That put a number which moves with **machine load** into a gate. It cost a whole
investigation: the tally read `1571/12/57` against a recorded `1572/12/56`, which
reads exactly like a regression from the change in the working tree. It was not.
Rebuilding the recorded commit and running it produced **57**, with an err set
that was **byte-identical** to the new one. Nothing had regressed; the meter had
moved.

`mspec/scoreboard.sh` already knew this. It grew a **SLOW** column on 2026-08-19
for the same reason — "ran past this harness's per-file limit — working, not
aborting" is a different claim from "the interpreter aborted". bootstraptest never
got that fix, so one fact about this project had two writers and only one of them
had written it down.

Now `all.sh` reports `slow=` as its own column and `triage.sh` writes the timed-out
pairs to `bootstraptest/SLOW.txt` instead of grouping them with the causes. Both
key on exit 142/14 so the two scripts cannot disagree about what a timeout is.

**Raising the alarm is not the fix.** It was already raised once — 15 to 60,
because a 241k-line if/else chain ran ~16s and flipped the tally run to run — and
a bigger generated test walked past the new number anyway. A limit that a passing
program can cross will always be crossed by the next one; only a separate verdict
stops the tally from moving when nothing did.

The pair itself stays unpassed, and that is the honest reading: this is a
tree-walking interpreter, and 121k lines of generated method definitions cost 87
seconds. That is a speed gap, recorded as one, in a column that says so.

## Five spec files allocate past 6GB, and the sweep only bounds time

Measured with `mspec/rss_guard.sh` polling every 5s during a full sweep:

| file | RSS when the guard saw it |
|---|---|
| `core/integer/even_spec.rb` | **15.3GB** (reached in under 5s) |
| `core/integer/*` (a second file) | 14.5GB |
| `core/method/call_spec.rb` | 6.8GB |
| `core/method/*` (a second file) | 6.7GB |
| `core/rational/to_f_spec.rb` | 6.9GB |

`run_one` puts a 60s alarm on each file and no bound at all on bytes. Those are
not symmetric: at this interpreter's measured allocation rate (~2.7GB/s) a 60s
alarm still permits ~160GB, and macOS offers no `ulimit -v`/`-d` to fall back on.
The sweep is therefore a harness that can take the machine with it, and did.

The five show up in `mspec/tags/` as CRASH with the cause `(no output before
aborting)` — which reads as "the interpreter aborted" when what happened is that
the guard shot it. That text is the honest limit of where the bound currently
sits: outside `run_spec.sh`, where mere-ruby's exit status is no longer visible.
Moving it inside would let a killed run have a verdict of its own, the way a
timeout does.

What the numbers are NOT is a claim about which construct is at fault. A 15GB
`even?` spec says a bignum path is running away; it does not say which one. That
is the next measurement, not a conclusion from this one.

### The measurement, 2026-09-04: a digit was costing the whole number

Asked of the interpreter directly rather than through a spec file, and beside
the reference:

| | before | after | ruby 3.4.9 |
|---|---|---|---|
| `99999**621` | 8.72 GB | **287 MB** | 18 MB |
| `2**10000` (3011 digits) | 12.0 GB | **268 MB** | 18 MB |
| `(2**10000).to_s.size` | 15.7 GB | **286 MB** | 18 MB |
| `(1..300).reduce(:*)` (615 digits) | 0.10 GB | — | 18 MB |

The fourth row is what pointed at the answer: 615 digits cost 0.1GB and 3011
digits cost 12GB, so the cost was not in the size of the number.

`mag_add`, `mag_sub` and `mag_mul1` each built their result by prepending one
character per digit — `chr d ++ acc`. A string here is immutable, so that
allocates a fresh one of the current length every time round the loop: an
n-digit operation allocates **n²/2 bytes to produce n of them**, and none of it
returns before a safepoint. At 3011 digits one addition is 4.5 MB, and
`2**10000` did ten thousand of them, because `big_pow` multiplied `e` times
where fourteen squarings will do.

Both are fixed: the magnitude routines push into a `StrBuf`, which grows in
place, and reverse once at the end; `big_pow` reads the exponent's bits. The
loops are the same loops. (Probe first, so the claim was not a hope: 200,000
pushes into a StrBuf is 2 MB, where the same by concatenation is 20 GB.)

Ruby is 18 MB for all three, so this is not finished. What is left is a
different order of problem, and worth naming separately: a digit still costs a
byte here where CRuby packs nineteen into a 64-bit limb, the multiply is still
schoolbook where CRuby switches to Karatsuba above a threshold, and
intermediates are still not reclaimed until a safepoint. Those are three
choices, each with a known shape; the quadratic was not a choice, it was an
idiom that reads as O(n) and is not.

Five of the seven spec files the guard was shooting now run to an answer. The
two that still do not are not the same finding as each other:
`core/integer/bit_length_spec` peaks at 7.1 GB running many bignum examples in
one process that never reclaims, while `core/method/call_spec` reaches 15 GB
**with no bignum in it at all** — that one is the interpreter's own per-call
growth (see "A method call costs ~9 KB that is never given back"), and it is
the arc this one is not.

## The record was measured a slice at a time, and the untouched groups drifted

A full 28-group re-sweep against the same binary the previous slices were built
with put the total at **491/1081 MATCH** where the checked-in table said
**517/1072**. Nothing regressed between those two runs; the table had simply never
been remeasured for the groups each slice did not name:

| group | recorded | measured |
|---|---|---|
| core/float | 38 | **29** |
| core/kernel | 54 | **47** |
| core/integer | 27 | **20** |
| core/method | 13 | **8** |
| core/proc | 9 | **5** |
| core/complex | 29 | **26** |
| core/unboundmethod | 9 | **7** |

Against that, `core/env` moved 16 to 25 and `core/exception` and `core/rational`
each gained one, so the net is -26 across 1081 files. The gains are this session's
work; the losses were already pushed.

The rule the slices followed was "gate on corpus, bootstraptest, and a sweep of the
group you touched". The group is the wrong unit when the change is not group-shaped:
the alias and reflection work touched `original_name`, `canon_alias`,
`builtin_has_meth` and `===` on callables — machinery every builtin class goes
through — and then swept `core/method`, `core/unboundmethod`, `core/queue` and
`core/sizedqueue`, because those were the groups the work was *about*.

Confirmed with the binaries rather than inferred: sweeping `core/float` with the
previous commit's binary also gives 29/50, so this is the state that was already
pushed, not something the working tree did. `Float.instance_method(:inspect) ==
Float.instance_method(:to_s)` is `true` in ruby and `false` here, and
`original_name` answers `:inspect` where ruby answers `:to_s` — builtin aliases
are not in the table the new code consults.

Two file counts also moved (`core/integer` 67 to 70, `core/method` 25 to 26): the
ruby checkout the specs come from is newer than the run that recorded those rows.
A row carries no note of what it was measured against, which is why this took a
rebuild of two older binaries to tell apart from a regression.

## The locale fix named a tool, and the exposure was never tool-specific

`scoreboard.sh` has pinned `LC_ALL=C` on one `tr` since 2026-08-19, because that
`tr` was what failed the day the bug was found: a spec whose output carries bytes
that are not valid UTF-8 (core/string's `chars`, `chr`, `grapheme_clusters`) made
it exit, the captured output came back empty, and the verdict became SKIP.

`run_one` also puts that same output through `sed` and `grep`. BSD `sed` exits
"illegal byte sequence" on the same bytes, an empty `rb` is read as "ruby did not
run this file", and the verdict is SKIP again — by a second route that the first
fix did not close. Measured on core/string with one binary and one spec tree:

| locale | MATCH | DIFF | CRASH | SKIP |
|---|---|---|---|---|
| ja_JP.UTF-8 | 32 | 69 | 1 | **12** |
| LC_ALL=C | 32 | 81 | 1 | **0** |

`mspec/causes.sh` had it a third time, in awk: it stopped on the first bad byte
with "towc: multibyte conversion failure" and then wrote out what it had
classified so far as though that were everything — 430 records and 24 CRASHes
where the tags hold 584 and 28. A record that silently drops a third of its input
is worse than one that fails, because the ranking it prints still looks plausible.

Both scripts now export `LC_ALL=C` for their whole body rather than for the tool
that happened to fail. The check that this is enough is not that the number looks
right: core/string swept twice in a row gives 32/81/1/0 both times, and that
agrees with what the table already said, which is what a reproducible measurement
of an unchanged group is supposed to do.

This one cost a wrong conclusion before it was found. The contaminated sweep
showed several groups losing MATCH, and the first reading was that the record had
drifted; the second reading was that the locale explained it. Re-measuring under
`LC_ALL=C` settled it: **core/string and core/symbol were the locale, and the
other groups had really regressed.** Two causes were live at once, and each one
was a complete-sounding explanation of the other's evidence.

## A cause field held the whole process environment, and it was published

`core/env`'s specs print ENV. Once `ENV.filter` became reflectable here, the first
line on which mere-ruby and ruby disagree became a Method object whose inspect
carries **the entire environment** — and that line is copied verbatim into
`mspec/tags/` and `CAUSES.md` as the DIFF's cause.

So an 11KB "cause" was committed and pushed to a public repo, containing `PATH`,
`HOME`, `SSH_AUTH_SOCK`, `SECURITYSESSIONID`, a session id, and an internal
package-index host. One commit, at the tip; every earlier one is clean, because
before that fix `ENV.filter` raised NameError and the cause was one short line.

Three things were wrong, and only the first is about ENV:

- `strip_noise` masked the tmpdir and heap addresses and not `$HOME`. Those are
  the same kind of thing — text that identifies the machine rather than the
  interpreter — and only two of the three were named.
- **The cause field had no bound.** Its contract is "short enough to read in a
  table"; nothing enforced it. ENV is merely the first object big enough to show
  that. A large hash, a long array or a deep struct reaches it the same way, so
  the fix is a cap (`CAUSE_MAX`, 240 chars) rather than a mask for ENV.
- There was no check. `mspec/record_hygiene.sh` is now one, and it is a real
  detector rather than a claim: run against the leaking records it named both
  files and every pattern, and it fails the gate rather than warning.

What it does NOT fix is the group being environment-dependent at all. `core/env`
measures the process it runs in, so its MATCH count moves between sessions with
no change to the interpreter — 43 in one session and 25 in another, from the same
binary. A gate whose subject includes its own execution environment cannot be
compared across runs, and that one is still open.

## A spec that accepts both answers is still a DIFF, because the harness counts assertions

`core/method/source_location_spec.rb`'s "works for core methods" example is
written to accept two answers:

```ruby
loc = method(:tap).source_location
if loc == nil
  loc.should == nil
else
  loc[0].should.start_with?('<internal:')
  loc[1].should.is_a?(Integer)
end
```

ruby 3.2 answers `["<internal:kernel>", 89]` — `Kernel#tap` is genuinely written
in Ruby, in a file CRuby carries inside its own binary. mere-ruby's `tap` is a
primitive with no source file, so it answers `nil`, which is the branch the spec
puts first and the truthful answer for a method that was never written in Ruby.

Both branches pass. But they run a **different number of assertions** — one in
the nil branch, two in the other — and the gate compares mere-ruby's
`pass=/fail=/err=` line against ruby's byte for byte. So the row reads `pass=16`
against `pass=17` and stays DIFF while every example passes on both sides.

The only way to close it is to invent an `<internal:kernel>` line number for a
method that has no source, which is a worse answer than `nil`: it would name a
file that does not exist and a line inside it. The row is left DIFF.

This inverts the usual reading of the counts. A lower `pass=` here means
mere-ruby **asserted less**, not that it failed more; `fail=0 err=0` on both
sides is the part that says the behaviour agrees. Any row whose two sides differ
only in `pass=` is worth reading this way before it is treated as a gap.

## Ten CRASH rows, and what each one actually was

The 2026-09-04 sweep left ten spec files classified CRASH — mere-ruby aborting
where ruby does not. Read as a list of missing features it would have suggested
ten feature gaps. It was nothing of the kind: **four of the ten were one
algorithm each doing linear work where the answer is logarithmic**, one was a
regression I had introduced two commits earlier, and only three were genuinely
absent behaviour — and one of those three was four constructs wearing one
error message. The classification names the symptom, not the cause, and the
symptoms collapsed into far fewer causes than there were rows.

| spec file | reported as | what it was |
|---|---|---|
| `core/proc/compose_spec` | stack overflow | **my own regression**: `f >> g` is composition, the `EBin` arm hands `>>` to the dispatcher, and my new operator-in-method-form arm handed it back |
| `core/float/exponent_spec` | stack overflow | `9.5 ** 0xffffffff` walked `b * pow_flt b (e - 1)` — 4294967295 frames for an answer of `Infinity` |
| `core/integer/digits_spec` | stack overflow | `12345.digits(1)` divided by 1, which never reaches zero |
| `core/range/bsearch_spec` | stack overflow | `(0...Float::INFINITY).bsearch` MATERIALIZED the range first |
| `core/integer/bit_length_spec` | killed at the memory cap | `(2**10000).bit_length` halved a 3011-digit string 33220 times; building the number itself costs 0.27 GB, the halving 6.56 GB |
| `core/numeric/step_spec` | killed at the memory cap | `1.step(to: Float::INFINITY, by: 42).size` materialized the sequence to count it |
| `core/integer/left_shift_spec` | killed at the memory cap | `0 << (2**40)` built 2^(2**40) in order to multiply by it |
| `core/integer/right_shift_spec` | `raised StandardError, expected TypeError` | two of them: `arith_bin` is a leaf helper with no world to raise from, so every shift refusal came out as a bare `StandardError`; and `1 >> (2**40)` halved one step at a time |
| `language/constants_spec` | `uninitialized constant CS_SINGLETON4_CLASSES` | `class << obj` ran with the singleton's own name as its lexical scope |
| `language/assignments_spec` | `expected end of statement` | **four separate parse gaps in one file**; see below |
| `language/for_spec` | `expected a variable after for` | two `match` arms for the same token kind; the first won, so the splat arm was dead code |

Six notes worth keeping.

**A quadratic-or-worse inner loop reports as four different failures.** The
memory cap kills one process, the stack limit aborts another, and a third
merely takes long enough to look like a hang — but `bit_length`, `pow_flt`,
`digits(1)` and the materializing `bsearch`/`step` are all the same mistake:
walking a structure one step at a time when the answer follows from its size.
`(2**10000).bit_length` now comes from the DIGIT COUNT (`10^(d-1) <= m < 10^d`
bounds `log2 m` inside one decimal digit) with each candidate checked against a
real power of two, so the estimate decides nothing and the walk is four
divisions instead of 33220.

**A shift wider than the number is not a shift.** Every one of the shift specs'
huge-width examples — `0 << (2**40)`, `1 << -(2**40)`, `-1 << -(2**40)` — has a
trivial answer: everything is shifted out, and ruby's `>>` floors, so a
negative value lands on `-1` rather than `0`. Nothing in the spec ever needs
2^(2**40) to exist. The width is now compared against the DIGIT COUNT (a
d-digit magnitude has fewer than 4d + 8 bits, so no exact `bit_length` is
needed to decide it), and the native `shr_int` keeps the widths it can hold —
routing every shift through the bignum divide would have made `x >> 3` pay for
the fix. A decimal-string bignum still makes a genuine `1 << 100000` slow;
that is the representation, and it is a different question from these rows.

**A refusal that has no world to raise from becomes the wrong class.** The
shift specs were not asking for a feature; the behaviour was right and only its
name was wrong. Any refusal reached from a leaf helper is worth checking for
this — the helper has `fail`, and `fail` is a `StandardError`.

**`class << self` hid a missing cref for a long time.** That singleton's
ancestors include the enclosing module, so a bare constant in its body was
found by the ancestor route and the lexical one was never exercised. Only
`class << some_other_object` — whose singleton inherits from Object — showed
that the scope was wrong. The fix has to satisfy two things at once: a class
DEFINED in the body belongs to that singleton (so `class << a` and `class << b`
each get their own `X`), and a constant READ in the body continues up the
enclosing chain. Naming the enclosing module alone gave up the first, and the
second body's `CONST` overwrote the first's. The scope now keeps the singleton
as its innermost segment — `N::(sng:111)` — because `lex_const_key` already
walks a qualified name one segment at a time.

**One parse error hides every construct behind it.** `language/assignments_spec`
was a single `expected end of statement`, and the line it named was not even the
line that failed — the reported number moved every time the file was truncated.
Behind it were **four** separate gaps, each of which had to be fixed before the
next became visible:

1. `(list << :a; obj).attr, ... = ...` — a parenthesized RECEIVER as a masgn
   target. The same `(` opens a destructuring group; which one it is shows up
   only AFTER the matching close paren (a group is followed by `,` or `=`, a
   receiver by a call), and every `(` was read as a group.
2. A `;` lexes as a newline, and the scan that decides "is this a multiple
   assignment" stopped at one — so the statement above was not read as an
   assignment at all.
3. A grouped target list may WRAP after its comma (ruby/spec writes one nested
   group across five lines). Leaving the newline in place made the next target
   a `TNL`, which is not an assignment target.
4. `self[k1], self[k2] = ...` and `self::A, self::B = ...`. Only `self.attr`
   was recognised as a self-receiver target.

...and behind those, one behaviour gap: a constant write (`m::A`) was the only
target kind whose receiver was not pre-evaluated, so it ran AFTER the RHS and
the recorded evaluation order came out reversed. The file now MATCHes.

Fixing #2 alone turned a clean parse error into a SIGABRT with no output at all
— worse than the failure it replaced, because a multi-line grouped target then
drove the parser somewhere it could not report from. A change that widens what
a scanner accepts has to be paired with the parser actually handling the wider
input.

**Two `match` arms for one constructor make the second dead.** `parse_for_vars`
had `Cons (TP lp, r0)` for the paren form and, further down, `Cons (TP star, r)`
for the splat. The compiler said nothing; every `for *r in` reached the first
arm, failed `is_lparen`, and raised "expected a variable after for" — the error
of the arm that did not want it.

### The result

| | before | after |
|---|---|---|
| ruby/spec CRASH | 10 | **0** |
| ruby/spec MATCH | 750 | **756** |
| runs killed at the memory cap | 3 | 0 |
| corpus | 170 | 175 |
| bootstraptest | `pass=1586 fail=19 err=54 drift=37` | unchanged |
| rgtest / bundlertest | baseline | unchanged |

Five of the ten files now MATCH outright (`bit_length`, `exponent`, `digits`,
`for`, `assignments`); the other five report an ordinary DIFF. The sweep was
measured with one pinned binary from end to end, and `mspec/rss_kills.log` is
empty.

### What is left in `core/range/bsearch_spec`

The row is DIFF, not CRASH, and the 18 remaining assertions are all the same
thing: ruby's float `bsearch` bisects the **integer encodings** of doubles, so
`±Float::MAX` and `±Infinity` are ordinary elements of the search and come back
as answers. mere-ruby bisects the doubles themselves, which cannot reach
`-Float::MAX` from an `-Infinity` bound (an infinite bracket end halves to NaN,
so the bracket is first narrowed by probing outward). Closing it needs a
double↔int64 bit mapping, which this language has no direct way to write —
`ldexp` is the only libm route in, and there is no `frexp` with an out-parameter.

## `defined?` was answering a different question, 116 times in one file

`language/defined_spec.rb` failed 116 of its assertions — the largest single
concentration of failures in the record, and all of one keyword. Working it
down took eleven separate rules, and the shape of the mistake was the same in
most of them: **mere-ruby was answering "is there a method with this name",
where ruby asks something narrower.**

The rules, in the order the oracle gave them up:

1. **`&&`, `||`, `and`, `or` are control flow, not method calls.** They answer
   `"expression"` however undefined their operands are, and nothing is
   evaluated. `EBin (_, _, _) -> "method"` covered them along with `+` and
   `==`, and that one line was most of the 116.
2. **Every other operator IS a method call, and ruby EVALUATES its operands.**
   `defined?(1 == nope)` is nil because evaluating `nope` raises;
   `defined?(DS.side_effects == 1)` really does run `side_effects`. Then it
   asks whether the value the left operand produced *has* the operator, which
   is why `defined?(DS.side_effects / 2)` is nil while
   `defined?(DS.fixnum_method / 2)` is `"method"`.
3. **A desugared string or regexp literal is `"expression"`**, not the `+`
   chain it is built from — including one whose interpolation would raise,
   because `defined?` never evaluates it. The lexer opens both with an empty
   `TStrL`, so the leftmost leaf of the chain is the marker.
4. **`a[0] = 1` is the `[]=` CALL** (`"method"`); `x = 1` is an
   `"assignment"`. Only a plain `=` splits that way — an op-assign is
   `"assignment"` whatever it writes through — and the two tokens before the
   `=` say which.
5. **`$!` and `$~` are `"global-variable"` even when nothing was raised or
   matched** (MRI special-cases them, and the spec says so in a comment).
   `$&`, `` $` ``, `$'` and `$+` are read out of `$~`, so they follow the last
   match rather than having slots of their own.
6. **A bare word inside `defined?(...)` is taken as a NAME by the parser**, so
   `__LINE__` never becomes an `EInt` and `break` never becomes an `EFlow`.
   Read as names they were neither a local nor a method, and every one of them
   was nil where ruby says `"expression"`.
7. **An array literal is defined only if every element is.**
8. **The answer is a frozen string**, which the spec checks. The parser answers
   some forms without evaluating them, and those went out unfrozen until they
   were routed through the same wrapper as everything else.
9. **`defined? super` without parens is a real super node** — the
   parenthesised spelling reaches `EVar "super"` instead — so that arm was
   missing and all of them answered `"expression"`.
10. **`super` walks the ancestors, modules included**, exactly as a real super
    does. Reading only the direct superclass missed every super that lands in
    an included module, which is the shape ruby/spec uses to test it.
11. **A constant read walks the lexical nesting and then the ancestors.** Only
    the bare name was tried, so `defined?(MixinConstant)` inside a class that
    includes `Mixin` was nil.

116 failures became 8. Five of the remaining eight are `defined?` asked about a
receiver's method in ways this dispatcher cannot yet answer; two are
`const_missing` suppression; one is the `$~`-in-a-block gap below. ruby's own
side of that file fails one assertion and errors on five, all of them this
shim's missing mocks rather than the interpreter's.

### ...and `respond_to?` did not know the operators

Rule 2 needs `1.respond_to?(:/)`, and it was **false** — as were `+ - * % **`,
the bit operators, the shifts and the orderings, on every primitive. The
dispatcher answers `1.send(:+, 2)` and `1.+(2)` through one allowlist, so the
question and the call were the same fact spelled two ways and only one of them
was right. Every arithmetic operator was invisible to a duck-type check.

The operator sets are now asked **per receiver kind**, from ruby: a Float has
no `<<` or `~`, a Complex has no ordering, a Hash orders but does not add, an
Array has `&` and `|` but no `^`. `!` and `===` come from Object and belong to
everything. Symbol had no arm in `respond_to?` at all, so `:s.respond_to?(:to_proc)`
was false for a method that works; its list was built by asking mere-ruby to
CALL each of ruby's Symbol instance methods, so the claim cannot be wider than
the implementation.

## `$~` is scoped to the frame that matched, and a block is not a frame

```ruby
def yielder; yield; end
"abc" =~ /a(b)c/
yielder { $~ }     # ruby: #<MatchData "abc" 1:"b">   here: nil
```

`$~` (and with it `$1`..`$9`, `$&`, `` $` ``, `$'`) is frame-scoped: a method's
match is invisible to its caller and the caller's invisible to the method.
mere-ruby implements that by saving and clearing one global slot around each
method frame, and **the comment on that code asserts the wrong rule** — that a
block is not a frame and shares the method's. It does share a frame, but the
frame it shares is the one it was DEFINED in, not the one it is yielded into.
So a block passed to a user-defined method sees that method's (empty) match
instead of its own scope's.

A block passed to a BUILTIN is fine (`[1].each { $& }` works — no frame is
made), and `proc.call` and `lambda.call` are fine, so the gap is narrow: a
block that reads its caller's match while yielded from a user-defined method.

Closing it properly means `$~` living in the frame rather than in a global,
with the read walking the env chain — and the eighteen places that publish a
match are leaf regexp helpers with no env to write into. The single global slot
is what makes them possible, so this is a design change, not a patch.

The visible cost meanwhile: a helper like `def show(l); puts yield; end` cannot
be used to test the match globals, because it tests this instead. corpus 176
reads them at top level for that reason.

## The predefined globals accepted everything, and one refusal found a wrong default

`language/predefined_spec.rb` failed 75 of its assertions, and almost all of it
was one shape: **mere-ruby accepted every assignment and answered nil for every
switch**, where ruby refuses, coerces, or has a default.

| | ruby | was |
|---|---|---|
| `$& = ""` written literally | SyntaxError `Can't set variable $&` | silent write |
| `alias $x $&` then `$x = ""` | NameError `$x is a read-only variable` | silent write |
| `$! = []`, `$: = []`, `$" = []`, `$< = []`, `$? = []` | NameError, every spelling | silent write |
| `$/ = 1` | TypeError `value of $/ must be String` | silent write |
| `$-0 = 1` | TypeError `value of $-0 must be String` | silent write |
| `$; = 1` | TypeError `value of $; must be String or Regexp` | silent write |
| `$~ = 1` | TypeError `wrong argument type Integer (expected MatchData)` | silent write |
| `$. = "x"` | TypeError, and `#to_int` converts | silent write |
| `$0 = nil` | TypeError, and `#to_str` converts | silent write |
| `$stdout = obj` with no `#write` | TypeError `$stdout must have write method, Object given` | silent write |
| `$VERBOSE = 1` | `true` — only nil/false/true are kept | `1` |
| `$-d`, `$-v`, `$-w` | aliases of `$DEBUG` / `$VERBOSE` | separate slots reading nil |
| `$-a`, `$-l`, `$-p` | `false` | `nil` |
| `$+` | the last NON-NIL capture | `nil` |
| `$_` after `gets` | the line read, `nil` at EOF | `nil` always |
| `STDOUT.external_encoding` | `nil` (STDIN has one) | NoMethodError |
| `STDOUT.set_encoding(a, b)` | records both, answers self | NoMethodError |

**The long spellings are now real aliases**, not separate slots. `$LOAD_PATH`,
`$-I`, `$LOADED_FEATURES`, `$FILENAME`, `$PROGRAM_NAME` and `$-0` had slots of
their own that happened to hold the same array as `$:` / `$"` / ... — which made
`.equal?` accidentally true while `object_id` disagreed, and left `$-I` with
nothing keeping it in step. Three readers had to be moved onto `gvar_slot` with
them: the one that searches the load path and the two that record a loaded
feature read the long spelling directly, and aliasing it emptied that slot.
`require` stopped working entirely until they were found — the same rule written
in four places, and only one of them changed.

### ...and `$.` was nil where ruby starts it at 0

The `$.` refusal above broke **bundlertest completely**, and the trace pointed
at rubygems:

```ruby
saved_lineno = $.           # rubygems/stub_specification.rb
...
ensure
  $. = saved_lineno         # TypeError: no implicit conversion from nil to integer
end
```

rubygems saves and restores `$.` around every gemspec stub it reads. In ruby
`$.` starts at **0**, so restoring it is harmless; here it started at **nil**.
The check was right and the value it refused was this interpreter's own default,
which nothing had ever read strictly enough to notice.

Worth keeping: **that failure could not come from the spec.** The spec reads
`$.`; only real third-party code writes it back. A refusal is worth running
against the gates that execute someone else's library, not only against the
suite that describes the behaviour.

`predefined_spec` went from 75 failures to 25. What is left is the encoding of
the matched string (7 — `$&` has to carry the source string's encoding, and the
spec compares `Encoding` objects by identity), the `$~`-in-a-block gap above
(5), `$@` as a rescued exception's backtrace (2), and singles.

## Four layers so a secret cannot reach a record again

The leak above was masked and the history rewritten, but "we added the missing
name to the list" is what was said in August too. What follows is what changed
so that the *class* of accident is closed, and every layer was poison-tested --
run against a record that really does hold a secret-shaped value -- before
being trusted.

### 1. Elimination: the spec subprocesses get an ALLOWLISTED environment

`mspec/run_spec.sh` now starts both interpreters under `env -i` with an
explicit list: `PATH`, `HOME`, `TMPDIR`, a fixed `LANG`/`LC_ALL`, and the
`RBENV_*` / `GEM_*` / `RUBYOPT` / `RUBYLIB` values they need to find a stdlib.
Anything else on the machine is simply not in their environment.

This is the layer that matters, because the other three are all "notice it
afterwards". A variable added to this machine tomorrow -- any name, any
contents -- cannot reach a record, because the process that would have printed
it was never given it.

It was worth checking whether the dump could be removed at the source instead,
and it cannot: **ruby does this too.** `ENV.method(:filter).inspect` is 6143
characters of environment under ruby 3.4.9 and 4845 under mere-ruby. The
receiver is part of `Method#inspect` on both sides, so agreeing with ruby means
carrying it.

The same change closes the drift this file has had open on `core/env`: its
MATCH count moved between sessions with no change to the interpreter, because
its subject WAS the session. The subject is now that list.

### 2. The mask collapses a hash literal WHOLE

`{"` up to its `}` (or to the end of a clipped line) becomes `{...}`. Two
earlier versions tried to keep the keys and rewrite only the values, and each
failed differently:

- the first knew only ruby 3.4's `"K" => "V"` spacing. The records span the
  reference-ruby upgrade and 3.2 writes `"K"=>"V"`, so **three older commits
  kept the token through the first pass of the scrub** -- the same question
  asked in one spelling.
- the second matched pair by pair and ran off its quote boundaries on a line
  the other masks had already rewritten, producing
  `{"K" => "V"LC_ALL" => "en_US.UTF-8"`: a mask that leaves half of what it was
  meant to remove.

Collapsing costs a little readability -- an ordinary `{"a" => 1}` in a cause
goes too -- and removes a whole class of accident, because there is no boundary
left to get wrong.

### 3. The check is STRUCTURAL, not a list of names

`record_hygiene.sh` refuses any record containing `{"` at all. It still carries
the named patterns for home paths and the tmpdir, but the environment is no
longer enumerated: the list is what failed, and `CLAUDE_CODE_SESSION_ID` being
on it while the token beside it was not is the whole argument.

### 4. It is REQUIRED, in three places

- `a/gates.sh` runs it first and exits 3 if it fails, before anything that
  takes time.
- `.github/workflows/ci.yml` runs it as its first step, so it is enforced for
  anyone, not only for whoever remembers.
- `.githooks/pre-push` refuses the push. Install it with
  `git config core.hooksPath .githooks` -- git does not share hooks, so this
  one is a local guard rather than a repository guarantee, which is why the CI
  job exists as well.

The reason for the third layer is not that the second was wrong. It is that on
2026-09-04 the push-time check was run **by hand**, looked for the previous
incident's shapes, and reported clean -- and a check nobody is required to run
is a check that gets skipped on the day it matters.

## A range is valid when `<=>` answers, not when its class is on a list

`(["a"]..["f"])` is an ordinary ruby range. `Array#<=>` is element-wise, so the
endpoints compare, so `Range.new` accepts them. mere-ruby raised
`ArgumentError: bad value for range` at CONSTRUCTION, because it decided
validity by enumerating the kinds it knew compared: numeric, String, Symbol,
and an object whose class defines `<=>`. Array was not on that list.

The comment above the check already stated ruby's actual rule -- *"does the
class define `<=>` is NOT the question ruby asks; ruby asks whether `lo <=> hi`
ANSWERS"* -- and the code below it still enumerated kinds. Asking is now what
it does: `cmp_possible_w`, which for an object invokes its own `<=>` and reads
a nil as "no", and for two Arrays asks `arr_spaceship_w` (Array#<=> itself,
cycle guard and nested pairs included) rather than restating the rule a second
time. `([1]..[2])` is valid, `([1]..["a"])` is not, and `([1,[2]]..[1,["a"]])`
is refused by the pair that decides.

Refusing at construction hid every later question about such a range. Once it
was built, seven more answers were wrong -- and they were wrong for a second,
separate reason.

## The BEGIN alone decides whether a range can be walked

ruby walks a range from its begin, comparing against its end. So the begin
alone decides whether a walk is possible, and the end only has to be something
the walk can compare against:

    (1..10.0).max(2)          # => [10, 9]     -- integer begin, Float end
    (1.0..10).max(2)          # => TypeError: can't iterate from Float
    (["a"]..["f"]).max(2)     # => TypeError: can't iterate from Array
    (["a"]..["f"]).min        # => ["a"]       -- no walk needed
    (["a"]..["f"]).minmax     # => [["a"], ["f"]]
    (["a"]...["f"]).minmax    # => TypeError -- an exclusive end must be NAMED

mere-ruby decided walkability from EITHER endpoint, so all three `(1..10.0)`
forms were refused, and it hard-coded the class in the message, so
`(["a"]..["f"]).max(2)` reported *"can't iterate from Float"*. The question is
now asked in one place (`rng_walk_from`) and the message names what it was
asked about.

That question turned out to be written in THREE spellings. `rng_iter_refusal`
-- the one `#to_a` consults -- had an arm for an integer begin with a bignum
end but none for a bignum BEGIN, so `(2**64..2**64+2).to_a` said "can't iterate
from Integer" while `#each`, `#map`, `#count` and `#include?` all walked the
same range happily. The third spelling now derives from the first.

## An empty list reads as "no elements", never as "cannot iterate"

`range_vals_raw` answers `Nil` for a range it cannot walk. Every caller read
that as *no elements*, so a whole family of methods answered instead of
refusing:

| | ruby | mere-ruby was |
|---|---|---|
| `(["a"]..["f"]).sum` | TypeError | `0` |
| `(["a"]..["f"]).first` | `["a"]` | `nil` |
| `(["a"]..["f"]).first(2)` | TypeError | `[]` |
| `(["a"]..["f"]).minmax` | `[["a"], ["f"]]` | `[nil, nil]` |
| `(..5).sum` | TypeError | `0` |
| `(1.0..3.0).sum` | TypeError | `0` |
| `(t1..t2).to_a` | `can't iterate from Time` | `can't iterate from Object` |

Two shapes of bug in one table. The refusals are missing because an empty list
is indistinguishable from an empty range; the endpoint answers are missing
because `#first`, `#min` and `#minmax` never needed the walk in the first
place. And `class_name` reads any object as `Object`, so even the refusals
mere-ruby did produce could not name the class -- naming it needs the world,
which is why the object cases are now answered at the world level, where
`display_cls_msg` can.

## A bignum bound is not an unwalkable bound

`(2**64..2**64+2)` has three elements. `(1..2**64)` has a size, a count, a sum
and a first two -- ruby answers all four instantly, because none of them is a
walk:

    (1..2**64).size      # => 18446744073709551616
    (1..2**64).count     # => 18446744073709551616
    (1..2**64).sum       # => 170141183460469231740910675752738881536
    (1..2**64).first(2)  # => [1, 2]

`#size` and `#count` are arithmetic on the bounds; `#sum` is Gauss; `#first(n)`
counts n times from the begin. mere-ruby materialised the range for all of
them, and materialising gave up on a bignum end, so the answers were `nil`,
a TypeError, `0` and `[]` respectively. They are arithmetic now, on decimal
strings, so the width of the bound does not matter.

`#to_a` and `#each` DO walk, and now walk bignum bounds -- up to a million
elements, past which the walk is not attempted (that is where ruby exhausts
memory rather than answering).

## `#minmax` is `#min` and `#max`, and has to agree with them

mere-ruby computed `#minmax` a second way -- materialise the range, take the
ends of the list -- and it disagreed with the very methods it is defined as:

    (1...10.0).minmax   # ruby: TypeError (cannot exclude non Integer end value)
                        # mere: [1, 9]
    (1.5...3).minmax    # ruby: TypeError (cannot exclude end value with non
                        #                  Integer begin value)
                        # mere: [nil, nil]

Both of those are `#max`'s refusals, and `#max` was already producing them
correctly when asked directly. `#minmax` now asks `#min` and `#max`, so there
is one rule rather than two. An empty range still answers `[nil, nil]`,
because that is what `#min` and `#max` say.

## `#size` is not "how many elements" but "how many WITHOUT walking"

    (1..10).size        # => 10
    ("a".."f").size     # => nil     -- walkable, but not counted
    (["a"]..["f"]).size # => TypeError
    (1.5..3.5).size     # => TypeError  (ruby 3.4; 3.2 answered 3)
    (Succ(1)..Succ(3)).size  # => nil  -- an object range with #succ

Three different answers for three different begins, and mere-ruby had one:
count the elements. `("a".."f").size` was already nil, but an object range with
`#succ` answered 3 (it had the walked array to hand), a Float begin answered 3,
and an Array begin answered nil.

## Membership in a half-open range says so in ruby's words

    ("aa"..).include?("a")   # => TypeError: cannot determine inclusion in
                             #    beginless/endless ranges
    (["a"]..).include?(["b"]) # => the same message

A walk needs both ends. mere-ruby raised the WALK's error there instead --
`can't iterate from String` -- naming the missing end for a question that never
got as far as iterating. Numeric and Time endpoints still compare, so
`(1..).include?(5)`, `(1.5..).include?(2)` and `(t1..).include?(t)` are all
true.

## One question, four places to answer it: Range#inspect

`p (a..b)` inspected the bounds through the world and printed `Cmp(1)..Cmp(2)`.
`(a..b).inspect` fell through to the world-free printer and said
`#<object>..#<object>`. `(a..b).to_s` said the same. An ARRAY holding those two
objects printed them correctly -- which is the tell: a container that knew how,
next to one that did not.

The world-free printer cannot dispatch a user's `#inspect`, so a Range asked
for its own rendering has to be answered where the world is. It is, now, in
both spellings -- and this is the same shape as the note two sections up about
`respond_to?` and the operators, and the one about `rng_iter_refusal`: **when a
question has more than one spelling, the spellings drift.**

## What ruby cannot answer, a corpus program cannot ask

`(0...2**64).max(2)` is arithmetic for mere-ruby and an infinite enumeration
for ruby: `Range#max(n)` hands off to `Enumerable#max(n)`, which walks. The
reference never returns, so the line cannot go in a corpus program -- not
because mere-ruby is wrong, but because the oracle has no answer to compare
against. Corpus 179 says so where the line would have been.

The same asymmetry, the other way around, is why the reference is run with
`$stdout.sync = true` when locating a hang: a block-buffered pipe loses
everything the process printed before it was killed, so "ruby produced no
output" read as "ruby failed immediately" when ruby had in fact printed 90
lines and then hung on line 91.

## Time is a stub

`Time#strftime`, `#zone`, `#utc_offset` are undefined, and `Time#to_s` /
`#inspect` render `#<Time:0x...>` where ruby renders `1970-01-01 09:00:00
+0900`. What Time DOES have is `<=>` (in the dispatcher, not the method table),
which is why Time ranges compare, cover and refuse to walk exactly as ruby's
do. The formatting is untouched.

## A block used to leak into the calls made inside a proc (fixed)

    def w(&b); b.call; end

    (0...2**64).min(2)        # => [0, 1]
    w { (0...2**64).min(2) }  # => []      <- mere-ruby, before

A plain call -- no block literal, no `&` -- passed the FRAME's block on, so
inside a proc invoked through an `&b` parameter every builtin that asks "was a
block given?" saw one that was never passed. `yield` never had the problem
(it runs the body under no block); `&b` + `#call` did, and every ruby/spec
example runs in exactly that shape, which is why min_spec disagreed with the
same expression typed at a prompt.

The fix is two lines: the receiver call's final dispatch hands `invoke_val_c`
an empty block instead of `blk`. The frame block is still what `yield` reads.
Twenty-nine block-sensitive builtins were checked in that shape before and
after (they were already right, because the iterating path is chosen before
the question is asked); corpus, rgtest, bundlertest, bootstraptest and a
twelve-file spec sample did not move by one assertion. Corpus 181 pins the
shape.

## `(0...Float::INFINITY).max` -- fixed, and a retraction

This file said the one-branch fix took mere's type inference "from 73 seconds
to over 10 minutes" and blamed a quadratic cliff. That was wrong. Re-timed in
isolation the next morning, the same branch compiled in 77 seconds, in all
three shapes tried (bind the flag only; a helper outside the chain; the inline
form itself). The slow compiles had another cause -- most likely a compile
orphaned by a timed-out command and still running while the next attempts
were timed -- and "reverting made it fast again" coincided with that orphan
finishing. The branch is in: an excluded infinite end is "cannot exclude non
Integer end value", as ruby says.

## The mspec shim's mock used to ignore `.with` (fixed)

    @x.should_receive(:<=>).with(@y).and_return(-1)
    @x.should_receive(:<=>).with(@x).and_return(0)

`MockObject#method_missing` answers from the FIRST registration for that
symbol, so both send -1. Six of `core/range/minmax_spec`'s nine examples error
under BOTH mere-ruby and ruby because of it -- the shim is the limit there,
not either implementation. Two more errored under mere-ruby alone, and those
were real: `cmp_possible_w` reads a bare object as comparable with ITSELF
(Object#<=> is 0 for the same object) while `cmp_vals_w` sent that same pair
to the world-free comparison, which raises. Two functions answering "can these
compare?" and "what IS the comparison?" have to agree, or the first one's yes
walks straight into the second one's raise.

`.with(args)` is recorded now and `method_missing` answers from the first
registration whose arguments match (one without `.with` matches any call).
core/range/minmax_spec went from six shared errors to MATCH.

## A singleton class is a second name for the same class

    t = Time.utc(1970)
    def t.succ; self + 1; end
    t + 1                  # => "Integer can't be coerced into Object"  <- before
    t == Time.utc(1970)    # => false                                    <- before

`def t.succ` gives the object a singleton class, and from then on the
bookkeeping name of its class is "(sng:111)" rather than "Time". Every place
that compared the class name to the literal "Time" -- the operator table, the
arithmetic arm, the primitive-equality list, the routing into the Time
methods, the builtin `<=>` lookup -- stopped matching, and the object fell
through to Object's answers. `display_cls` resolves a singleton to the class
it stands for; those comparisons go through it now. ruby/spec's Range#each
Time example is exactly this shape, and it is why the example was a TypeError.

The same family: `[t1] == [t2]` and `[t1].include?(t2)` compared identity
while `t1 == t2` alone was true, because the element search asked only the
method table for a `==` and Time's is a primitive. `has_own_eq` answers both
questions in one place now.

## The `#succ` walk stepped past the end

ruby's walk yields the END object itself when the walk reaches it and asks
`#succ` no further. mere-ruby asked `#succ` of a value that merely EQUALLED
the end and reached an object the end never was -- a Time one second on,
without the singleton `#succ` the spec had defined on the end -- and raised
NoMethodError where ruby was already done. At the end, the end is the last
element.

## `Range#bsearch` over doubles bisects the ORDINAL

A double's sign, exponent and fraction read as one integer order exactly like
the values do, so bisecting ordinals visits every double once and can land on
Infinity (ordinal 2047 * 2^52) and Float::MAX (one below). Doubling outward
from a finite point never got there: `(-inf..0.0).bsearch { true }` answered
-1.8e19 after 64 doublings where ruby answers -Infinity, and an excluded
infinite end was approached rather than refused.

Two ordinals of opposite sign do not subtract: the difference between the
ordinals of -Infinity and +Infinity does not fit an int, and `lo + (hi - lo)
/ 2` produced a garbage midpoint, so `(-inf..inf).bsearch { |x| x >= 3 }`
answered Infinity. The midpoint is `lo/2 + hi/2` (the float bisection had the
same note for the same reason). When the bracket closes, the lowest candidate
is asked directly, so a boundary that satisfies is the answer --
`(1.0..3.0).bsearch { |x| 3.0 - x }` is 3.0, which a midpoint walk never
lands on.

## `Range#step` over Floats and Strings, and a zero step

Float bounds on either side make an ArithmeticSequence, exactly as
`1.0.step(2.0, 0.5)` does, and the block form walks `begin + i*step` for a
count computed once. The exclusive count follows ruby_float_step_size: after
flooring with the error allowance, one more term still counts if it lands
strictly before the excluded end, so `(1.0...55.6).step(18.2)` has four terms
(bugs.ruby-lang.org/issues/16612); the floor alone said three.

A String range steps by `#succ` k times per yield, a Float step there is "no
implicit conversion of Float into String", and without a block the result is
a plain Enumerator (nothing is added). A zero step is refused when the
sequence is MADE, block or not. A beginless numeric range makes the sequence
(ruby/spec asks its class) and walking it is the TypeError; with a block ruby
says "#step iteration for beginless ranges is meaningless" for every kind of
end. A stray object as the step makes a plain Enumerator and is refused when
walked.

`(1..).step(Object.new).first(1)` is [1] in ruby (the begin is yielded before
the step is ever added) and a TypeError here. Not in ruby/spec's unguarded
set; left.

## `ruby_version_is` is a no-op in the shim

The shim skips every `ruby_version_is` block, on both sides. mere-ruby
reports RUBY_VERSION 3.2.2 and the reference is 3.4.9, so honouring the
guards would run DIFFERENT subsets on the two sides and the record would
compare different examples. Skipping them is the cheaper asymmetry -- but it
means the guarded examples (String `#step` with a String step, beginless
`#step` refusals, `#to_int` conversions of a step) are unmeasured, not
passing.

## Ranges are values, so `dup` is the same object

    r = (1..2)
    r.dup.equal?(r)   # ruby false, mere-ruby true

A Range is an immediate value here; `dup`, `clone` and `equal?` see one
value. Giving ranges heap identity is a representation change, not a Range
fix, and core/range/clone_spec and dup_spec are the two files it costs.

## Time as a Hash key

`{Time.utc(1970) => 1}[Time.utc(1970)]` is nil: Hash lookup uses `eql?` and
`hash`, and Time's are still identity. Same family as `Time#inspect` and
`#strftime`: the Time stub, not Range.
