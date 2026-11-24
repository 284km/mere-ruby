# Sources of CRuby 4.0.9 compiled as they are

`st.c` is CRuby's hash table (`st_init_table`, `st_insert`, `st_foreach`, ...),
part of the public C API through `ruby/st.h`. It and the ten internal headers
it includes are copied here unchanged from the ruby 4.0.9 source tree
(`st.c`, `internal.h`, `ruby_assert.h`, `internal/{bits,compilers,hash,
sanitizers,set_table,st,static_assert,warnings}.h`) and compiled by `capi/st.c`, which
only says `RUBY_EXPORT` and includes it.

`memory_view.c` is CRuby's memory view API (`ruby/memory_view.h`), also
unchanged, compiled by `capi/memory_view.c`. It includes two of CRuby's
internal headers that this C API has no equivalent of
(`internal/variable.h`, `vm_sync.h`); those are answered by the stand-ins in
`capi/standin/`, which are this repository's own files and hold only what
the vendored sources use.

`bignum.c` is CRuby's multiple-precision Integer code, also unchanged,
compiled by `capi/bignum_cruby.c`, so that the algorithms an extension can
call by name (`rb_big_mul_karatsuba`, `rb_big_mul_toom3`,
`rb_big2str_generic`, `rb_str2big_karatsuba`, `rb_big_divrem_normal`, ...)
run as CRuby runs them. It brings seven more internal headers, copied
unchanged (`internal/{bignum,complex,fixnum,numeric,object,serial,vm}.h`),
and two stand-ins in `capi/standin/`: `id.h` (the seven method IDs it names,
interned by name; the real one is generated) and `internal/gc.h` (NEWOBJ_OF
and two questions about slot sizes; the real one includes `vm_core.h`).
Every function it defines is renamed (`mr_vbig_*`) inside that one file, so
the C API's own Integer functions are not replaced; only the algorithms by
name are given under ruby's names. How a Bignum it makes -- a C struct, whose
VALUE is its address -- becomes an Integer when it reaches the interpreter
is written at the top of `capi/bignum_cruby.c`.

They are under Ruby's licence (`capi/include/COPYING`, `capi/include/BSDL`).
Nothing in this directory is edited; `capi/tools/headers_check.py` compares
it, and `capi/include`, with a ruby source tree.

`erb_escape.c` is CRuby's `ext/erb/escape/escape.c` (`ERB::Escape.html_escape`),
also unchanged, compiled by `capi/static_ext.c`, which links it into the
executable as ruby links an extension statically: `require "erb/escape"` runs
its `Init_escape` (renamed there to `mr_static_Init_erb_escape`, so that
another extension's `Init_escape` cannot meet it), and its methods are C
functions, so `Method#source_location` is nil as on ruby. `HAVE_RB_EXT_RACTOR_SAFE`
is defined there, as its extconf.rb's `have_func` would.
