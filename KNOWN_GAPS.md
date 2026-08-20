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

### What the language allows (measured, `bench/reclaim.sh`)

Reclamation was investigated before being attempted, and the first question is
not how to collect but whether anything *can* be given back. Asked in Mere, 1M
iterations each (peak MiB):

| what | peak | entries left |
|---|---|---|
| build 1M strings, store none | 170 | — |
| `map_set` then `map_delete` each time | 231 | 0 |
| `map_set` the same key each time | 200 | 1 |
| a fresh `Map` per iteration | 521 | — |
| ... the same, inside `region R { }` | 247 | — |

Nothing gives a container's memory back: not `map_delete`, not overwriting a
key, and **not a region block** -- a `Map` created inside one is still there when
it exits (26 MiB at 100k iterations against 247 at 1M: linear, not flat). What a
region block *does* reclaim is the values allocated in its body, which is the 2x
between the last two rows. This matches Mere's memory model: containers carry
identity and keep their own binding region.

Two consequences for this interpreter. **The Ruby heap cannot shrink while it
lives in Mere `Map`s** -- and the handle scheme rules out even trying, since
`arr_new` takes its id from `map_len arr_store`, so deleting an entry makes the
next handle collide with a live one. Any collector has to replace handle issuing
with a counter and a free list first. And **the frame is the bigger half**: 200k
plain calls leak 2588 MiB while adding *nothing* to any store -- that is `env` (a
`map_new` per call) and the temporaries a call builds, neither of which a region
block can take back today.

Where the entries actually go, at 200k iterations of each shape:

| workload | peak MiB | stores that grew |
|---|---|---|
| 200k interpolated strings | 3249 | none -- all temporaries |
| 200k objects with 2 ivars | 6339 | `arr_store` +4/iter, `ivars` +2, `ocls` +1 |
| 200k top-level calls | 2588 | none -- all temporaries |

And the size of the prize, on identical work with an identical live set (a
1000-node list summed 2000 times): **ruby 33 MiB against 11222-15267 MiB** --
two and a half orders of magnitude.

That last figure is a range for a reason worth recording. The program allocates
the same bytes every time, but once a run holds several GB the OS starts
compressing pages, and `maximum resident set size` then moves by a factor of two
between runs of the *same binary* (measured: 6227, 10614, 13346, 15664, 15803
MiB). Under ~6 GiB the same measurement repeats exactly (6286 MiB three times out
of three). So peak RSS is a usable number for the small cases and an
order-of-magnitude one for the large; `bench/reclaim.sh` prints a range over
three runs rather than one figure, and `bench/alloc_sites.sh` is where the
deterministic per-call counts live, since it counts inside the region allocator
instead of asking the OS.

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

### What would change it

A per-call region reclaims 6.4% today, 17% with the generated C patched so
`map_new` follows the current region. The rest is the `Map`s themselves. The one
capability that would change the picture is upstream: **a container whose memory
dies with its region** (or can be freed), which would let a region-per-call take
the whole frame -- the 13.4 KB a call leaks now. Failing that, the alternative
inside this repo is to stop using Mere `Map`s for the Ruby heap and put objects
in a self-managed arena with its own free lists, which is a rewrite of the value
representation rather than an addition to it.

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

What stops it now is measured and small to state: **`require "bundler/cli"`
raises `Bundler::GemfileNotFound` at load time**, where ruby loads the file
without touching a Gemfile. Something in that file's body is being evaluated
eagerly here that ruby leaves for later. Until that is found, every `bundle`
subcommand answers "Could not locate Gemfile", including `bundle version`, which
needs no Gemfile at all.