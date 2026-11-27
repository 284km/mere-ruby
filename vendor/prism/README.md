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

The generator then applies `tools/prism_ripper_heredoc.patch`. This private
Ripper serializer enables EOF recovery while the actual parser and its local
scopes remain live. An internal empty interpolation-end marker lets the
parser unwind into its heredoc's normal EOF recovery, which resumes the
actual saved header cursor. Ripper hides the empty recovery markers after
LexCompat has flushed its buffers. No source fragment is reparsed and no
source location is synthesized. Ordinary Prism parse/lex/lex_compat do not
enable this entry point.

`tools/gen_prism_ripper_lex.rb` extracts the reference LexCompat#result using
its actual Prism DefNode span and changes only its native token producer.
The resulting `lib/prism_ripper_lex.rb` is a private subclass for this cold
recovery path. The public producer and ordinary valid Ripper lexing retain
their original path.

The private lexer also returns a zero-brace-nesting right brace with its
actual pre-closer state, as CRuby's tSTRING_DEND branch does. This is a real
source token, distinct from the hidden empty EOF recovery markers. Ripper
selects the private path only for a heredoc diagnostic or an actual stray
right-brace diagnostic. Public Prism lex/parse keeps its original behavior.
The extracted Ruby consumer preserves the reference file's frozen-string
pragma as well as its original lexical constant scope.
