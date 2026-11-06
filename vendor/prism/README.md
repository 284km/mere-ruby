# vendor/prism — libprism 1.8.2, the copy Ruby 4.0.9 ships

The C library behind `require "prism"` under mere-ruby. Prism's Ruby half
(lib/prism.rb, lib/prism/*.rb) is read from the reference's rubylibdir like
the rest of the standard library; its C half, the extension that builds the
node tree, is what mere-ruby cannot load. Instead the library itself is
compiled in (tools/build.sh), five entry points are reached through
`extern fn` (m_state.mere, tools/prism_glue.c), and the shipped
lib/prism_ext.rb answers `require "prism/prism"` by feeding the parser's
serialized answer to Prism's own deserializer -- the same shape as Prism's
FFI backend on other Ruby implementations.

This is the first of the two steps note 511 plans for Prism: compile the
library as it is so that `test/prism` can run, then write the parser in Mere
behind the same five externs.

## What is here

| | |
|---|---|
| `include/`, `src/` | Prism 1.8.2 as `ruby/prism/` in Ruby 4.0.9 (`3e93b23a`), with the files Ruby's build generates from `prism/templates` (`src/{diagnostic,node,prettyprint,serialize,token_type}.c`, `include/prism/{ast,diagnostic}.h`) |
| `LICENSE.md` | Prism's MIT license |
| `obj/` | the compiled objects and `libprism.a`, made by tools/build.sh and not checked in |

`extension.c` / `extension.h` (the Ruby C-API side) are not compiled: nothing
here calls into a Ruby. `api_pack.c` is not either, for the same reason.

## Regenerating

From a Ruby source tree at the version mere-ruby targets (tools/ref_ruby.sh):

```sh
sh tools/gen_prism_src.sh ~/src/github.com/ruby/ruby-4.0.9
```

It runs `prism/templates/template.rb` with the reference ruby for each
generated file and copies the hand-written ones. The templates are driven by
`prism/config.yml`, so a version bump regenerates everything; the diff that
needs reading is `src/prism.c`.
