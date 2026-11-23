# Ruby's C API

An extension library written for CRuby 4.0 -- C that includes `ruby.h`,
defines `Init_<name>` and calls `rb_*` -- is compiled against the headers in
`capi/include` and loaded by `require`. Its source is not changed. The
library has to be compiled against these headers: one built for CRuby is not
loaded (see "Loading").

This is not complete. What is here was written to make ruby's own test
extensions (`ext/-test-`) build and run; the functions that are declared and
not written are listed under "What is missing".

## The headers

`capi/include` is ruby 4.0.9's `include/` directory. Ten files differ from
the original, by `capi/tools/headers.patch` and nothing else
(`capi/tools/headers_check.py <ruby source tree>` checks that):

- The macros that turn a VALUE into a pointer to one of CRuby's structs --
  `RBASIC`, `RSTRING`, `RARRAY`, `RDATA`, `RTYPEDDATA`, `ROBJECT`, `RFILE`,
  `RCLASS`, `RMATCH`, `RREGEXP` -- call a function (`rb_mere_basic`,
  `rb_mere_string`, ...) instead of casting. Everything built on them
  (`RSTRING_PTR`, `RARRAY_LEN`, `rb_type`, `RB_FL_TEST`, `TypedData_Get_Struct`,
  ...) is the original text.
- `rbasic.h` defines `rb_mere_extension_abi` in every extension, a number
  the loader reads before it runs anything from the library.

`ruby/config.h` is written by hand for this interpreter: type sizes from the
compiler's own macros, headers by `__has_include`, and the C library
functions listed per OS. `capi/tools/config_probe.py --check` links every
function it claims.

## What a VALUE is

Immediates are CRuby's, bit for bit: Fixnum, flonum, static Symbol, `nil`,
`true`, `false`, `Qundef`. `FIX2LONG`, `RB_FLOAT_TYPE_P`, `NIL_P` and the
rest of the inline tests work on them without a call.

Every other VALUE is `2^56 + 8 * n`: an entry number in a table the
interpreter keeps (`m_capi.mere`), from number to the Ruby value. The same
object gets the same number for as long as C can hold it, so `==` on two
VALUEs is `equal?`. A value that has no identity in this interpreter (a
Range, a Bignum, a Rational, a Regexp literal's value) is given one by its
entry: what C got once it gets again while the entry lives.

The number is not an address. When C asks for a struct (`RSTRING(str)`,
`RBASIC(obj)->flags`), it gets a **mirror**: a C struct made the first time
it is asked for, filled from the Ruby value, and kept with the entry. A
String's mirror has its bytes, a NUL after them, and its capacity; an
Array's has its elements as VALUEs. Mirrors are refreshed when control
comes back to C from the interpreter and the value has changed, and what C
wrote into one (`RSTRING_PTR(str)[0] = 'x'`, `rb_str_set_len`,
`RARRAY_PTR`) is written back when C returns to the interpreter or calls
into it. A frozen String written through its pointer raises FrozenError at
that point.

A pointer C took stays good across a Fiber switch: a mirror that a C call
in progress touched is watched -- written back at every crossing -- until
the last such call has ended, so two Fibers stopped inside C calls that hold
pointers into one String each write through their own when resumed.

A data object (`TypedData_Make_Struct`, `Data_Wrap_Struct`) is an ordinary
object of its class whose entry carries the C pointer and the type.

## Primitives

A function that is ruby's operation on a builtin class -- `rb_ary_push`,
`rb_str_strlen`, `rb_hash_aset`, `rb_obj_freeze`, ... -- does what ruby's C
does, whatever Ruby code made of the name: an override in a subclass or a
singleton, a module prepended to the builtin class, or a definition in the
builtin class itself. The call names its class (Array, String, Hash,
Kernel); where something overrides the name it goes to the definition from
the builtin class on, and where the program redefined the builtin class's
own, to the one the prelude made (or the native one). Functions whose
contract IS a method call -- `rb_funcall`, `rb_respond_to`, the
conversions, `rb_equal`, `rb_inspect` -- call the method.

## What keeps a value alive

The collector is the interpreter's own. For the C API it adds:

- what C registered: `rb_gc_register_address`, `rb_global_variable`,
  `rb_gc_register_mark_object`;
- while a call into C is in progress, every VALUE found on that C stack
  (scanned conservatively for numbers in the table's range) -- and the same
  for the stack of a Fiber or Thread that is stopped inside a C call;
- what a live data object's `dmark` marks (`rb_gc_mark`), run to a fixpoint
  with the rest of the marking. A `dmark` that runs with no call into C in
  progress has nobody to ask. It may read an object's header and an Array
  (`RARRAY_LEN`, `RARRAY_AREF`) as last fetched -- what those reach is
  reachable from the Array it already marked, which the interpreter marks
  itself -- and an internal instance variable (an ID with no `@`, which only
  C writes) as C last wrote or read it (sqlite3's `database_mark` and its
  aggregator pin do both). Anything else it asks of the interpreter -- an
  ordinary `@` ivar, a method call, `RSTRING_PTR`, `rb_hash_foreach` -- is
  refused with `mr_fatal`, never answered with a guess;
- the elements a live Array's or String's mirror holds.

An entry nothing reaches is dropped at the sweep; a data object's `dfree`
runs then, once. `MERE_RUBY_GC_STRESS=1` collects at every safepoint, and
the checks below run under it.

## Exceptions and non-local exits

No failure of the interpreter unwinds a C frame behind C's back. Every
request C makes of the interpreter (a method call, a constant lookup, an
allocation) returns to C with an outcome; if the outcome is an exception, a
`throw`, a `break` or a `return` through the C frame, C `longjmp`s to the
nearest guard it set up itself: `rb_protect`, `rb_rescue2`, `rb_ensure`,
`rb_catch`, or the entry of the C method. So `rb_ensure`'s cleanup runs,
`rb_protect` reports a state and `rb_jump_tag` continues it, and at the C
method's entry the outcome is handed back to the interpreter, which raises
(or throws, or breaks) it there as its own.

## Fibers and threads

Threads here take turns on one native thread, and a Fiber is a coroutine on
the same thread. The chain of C calls in progress belongs to the stack it is
on: when the interpreter switches stacks it says so (`mr_capi_switch`), and
each stack's chain is put aside and taken up again with it. A block that C
calls with `rb_yield` or `rb_block_call` may suspend its Fiber; another
Fiber's calls into C run meanwhile.

`rb_thread_call_without_gvl` runs the function: there is no lock to give up
and nothing else runs meanwhile. While it runs, a signal the program traps
calls the unblocking function, so a blocking wait in C can be ended; the
trap itself runs when the C function has returned. `rb_thread_create` makes
a Ruby Thread whose body is the C function.

## Loading

`require 'x'` finds `x.bundle` (macOS) or `x.so` on the load path. Before a
file is a candidate at all, the file is read for the name
`rb_mere_extension_abi`, which every extension compiled against these
headers defines: a library compiled for another ruby does not have it, is
passed over without being loaded (none of its code runs), and the feature
is whatever provided it before (a `.rb`, the shipped library). A library
that has it is opened once -- its constructors run once -- the number
behind the name is compared (a different one is a LoadError), its `Init_x`
is run, and the feature is recorded the way a `.rb` is. On Linux the
executable is linked with `-rdynamic`: the library finds `rb_*` in the
interpreter that loads it.

## Building an extension

```
clang -bundle -undefined dynamic_lookup -fPIC -I capi/include x.c -o x.bundle   # macOS
clang -shared -fPIC -I capi/include x.c -o x.so                                 # Linux
```

or, as a gem does it, with ruby's own mkmf:

```
mere-ruby extconf.rb && make && make install
```

`require "mkmf"` is ruby's `mkmf.rb`, unchanged. What it reads is RbConfig,
and an interpreter that finds `capi/include/ruby.h` beside its executable
says its build there: `rubyhdrdir` (that directory) and `rubyarchhdrdir`
(`capi/arch/<arch>`, where tools/build.sh puts this machine's
`ruby/config.h`, as ruby's layout has it),
`topdir` and `bindir` (the executable's), `ruby_install_name` (its name --
mkmf writes it into the Makefile as `$(RUBY)`, and RubyGems starts
`extconf.rb` with it), `CC` = clang and the flags above as `CCDLFLAGS`,
`LDSHARED` and `DLDFLAGS`, no libruby (`LIBRUBYARG` is empty: an extension
finds the API in the executable), and the POSIX tools a Makefile calls. The
values are how `tools/build.sh` builds the interpreter and how the two
commands above build an extension; nothing is copied from a CRuby
installation. A build without the C API has none of these keys.

`have_func("rb_ary_new")` -- mkmf links a test PROGRAM that names the
function -- is answered by an import library, `capi/lib/libmere-ruby-api`,
which tools/build.sh writes after the link
(`capi/tools/import_library.py`): one empty symbol for each function and
variable of the C API the executable exports. RbConfig names it as
`LIBRUBYARG`, which mkmf puts on the link line of its test programs only.
The functions of `capi/unsupported.c` are left out of it, so for them the
answer is "no" and an extension takes its other path. `ENABLE_SHARED` is
not said (see the comment where the keys are, in m_driver.mere). The installation directories (`prefix`, `libdir`,
`sitearchdir`) are still the stand-ins they were: `make install` is given
its directory, as RubyGems gives it.

`tools/capi_ext_build.py --ruby-source <tree> --output <dir>` builds every
directory of ruby's `ext/-test-` without running its `extconf.rb` (those are
written for ruby's own build tree: they reach into its internal headers).
The header, type and struct member probes an extconf.rb writes out are
asked of the compiler and passed as `-DHAVE_...`, the way mkmf passes them.

## What is missing

- `capi/unsupported.c` is the ledger of functions that exist only so that a
  library using them loads: each raises NotImplementedError, naming itself,
  when called. Its header comment says why each group is not there (CRuby's
  internal bignum routines by name, TracePoint and the debug inspector from
  C, profile frames, postponed jobs, the Random interface, encoding
  converters).
- A function that is declared in the headers and neither written nor in the
  ledger is an undefined symbol: `require` of a library that uses one raises
  LoadError with the loader's message, which names it. Of the roughly 1,300
  functions the headers declare, about 800 are written; the larger groups
  not yet written are Onigmo's own API, most of `rb_io_*` (the struct
  behind `RFILE` is there, filled from the IO; its buffers are not), the
  fiber scheduler hooks, `rb_econv_*`, `rb_reg_*` and Ractor.
- Internals a test may read and this has no equivalent of: a String's
  embedded / shared state and capacity classes, coderange caching, a Hash's
  `st_table` (`rb_hash_tbl`), a Rational that is not in lowest terms.

## How it is checked

- `tools/capi_check.py` (CI, macOS and Linux): ruby's own
  `ext/-test-/exception`, `typeddata`, `float` and `iter` sources and the
  fixtures in `capi/check` are built twice, against the reference ruby's
  headers and against these. The six contract scripts in `capi/check` must
  print the same on both sides, and again on this side with a collection at
  every safepoint. Then six guarantees are switched off one at a time
  (`MERE_RUBY_CAPI_WITHOUT=dmark|dfree|ensure|switch|fileprobe|builtin`) and the
  contracts that depend on each must fail.
- The unit test run builds all of `ext/-test-` and runs `test/-ext-` against
  it, file by file, like every other directory of ruby's tests.
- `tools/capi_mkmf_check.py` (CI, macOS and Linux): an extension whose
  `extconf.rb` asks the compiler about headers, functions, a macro, a size
  and a library, and ruby's `ext/-test-/float` by its own `extconf.rb`, are
  built with `extconf.rb`, `make`, `make install` on both rubies; the built
  libraries say what mkmf answered, and the contracts in
  `capi/check/mkmf.rb` print the same on both sides. A source that does not
  compile must fail at `make` on both, and mere-ruby given the libraries the
  reference's mkmf built must fail.
- `tools/capi_gem_check.py` (CI, macOS and Linux): fast_blank, redcarpet,
  msgpack, racc, bcrypt, nio4r and nokogiri (from source, on the system's
  libxml2), at
  fixed versions, are installed by each ruby with RubyGems' `gem install`
  from the same .gem files, and `capi/check/gems.rb` uses them on both
  sides and must print the same. mere-ruby pointed at the gems the
  reference built must fail.
- `tools/capi_spec_check.py` (CI, macOS): ruby/spec's `optional/capi` -- a
  spec file and a C extension for each part of the C API, 46 files -- with
  each extension built for both rubies. The count of passing examples per
  file is recorded in `capi/check/spec_expect.tsv`: the reference's must be
  the recorded one, mere-ruby's must not be lower. 2,269 of 2,584 pass.
- `test/mkmf` runs in a build tree staged for mere-ruby
  (`unittest/mkmf_context.sh`: links to `capi/include` in the places mkmf's
  build-tree mode looks, and a Makefile mere-ruby's own mkmf wrote).

## The files

| file | what |
|---|---|
| `core.c` | calls in progress and their guards, requests to the interpreter, the loader |
| `mirror.c` | the structs C sees, refreshed and written back; data objects |
| `gc.c` | registered addresses, marking, finalizers |
| `error.c` | `rb_raise`, `rb_protect`, `rb_rescue2`, `rb_ensure`, `rb_catch`/`rb_throw` |
| `object.c`, `symbol.c`, `globals.c` | classes, methods, ivars, constants, IDs, `rb_c*` / `rb_e*` |
| `numeric.c`, `bignum.c` | conversions, `rb_integer_pack` / `unpack` |
| `string.c`, `encoding.c`, `sprintf.c` | Strings, encodings, `rb_sprintf` with `PRIsVALUE` |
| `array.c` | Array, Hash, Range, Struct, Enumerator |
| `proc.c` | blocks, Procs, `rb_block_call`, `rb_funcall_with_block` |
| `system.c` | threads, time, IO, utilities |
| `needed.c` | what real gems asked for and nothing else had: conversions by method name, `rb_memhash`, `rb_ivar_foreach`, the calling frame's last match |
| `st.c`, `memory_view.c`, `vendor/`, `standin/` | CRuby's `st.c` and `memory_view.c`, compiled unchanged |
| `unsupported.c` | the ledger |
| `mr_capi.h` | what the files above share; not for extensions |
| `../m_capi.mere`, `../m_capi_api.mere` | the interpreter's side: the table, and what crosses |
