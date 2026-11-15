# Sources of CRuby 4.0.9 compiled as they are

`st.c` is CRuby's hash table (`st_init_table`, `st_insert`, `st_foreach`, ...),
part of the public C API through `ruby/st.h`. It and the ten internal headers
it includes are copied here unchanged from the ruby 4.0.9 source tree
(`st.c`, `internal.h`, `ruby_assert.h`, `internal/{bits,compilers,hash,
sanitizers,set_table,st,static_assert,warnings}.h`) and compiled by `capi/st.c`, which
only says `RUBY_EXPORT` and includes it.

They are under Ruby's licence (`capi/include/COPYING`, `capi/include/BSDL`).
Nothing in this directory is edited; `capi/tools/headers_check.py` compares
it, and `capi/include`, with a ruby source tree.
