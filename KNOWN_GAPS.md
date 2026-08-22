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
