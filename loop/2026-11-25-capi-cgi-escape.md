# cgi/escape is ruby's C extension, linked in; a C-only feature is listed once

The two things #253 left (loop/2026-11-24-capi-erb-escape.md, "Left"):
cgi/escape's methods were the Ruby fallback (test_cgi_escape's two "C
extension not available" omits), and a library that is a C extension alone
in ruby's build was listed in $LOADED_FEATURES twice, as `<arch>/x.bundle`
and `x.rb`.

## What changed

- **cgi/escape.so is ruby's C.** `capi/vendor/cgi_escape.c` is ruby 4.0.10's
  `ext/cgi/escape/escape.c`, unchanged (the same as 4.0.9's). It is
  compiled in a file of its own, `capi/static_cgi_escape.c` -- erb's
  escape.c has static functions of the same names (escaped_length,
  optimized_escape_html, preserve_original_state) -- with `Init_escape` and
  `InitVM_escape` renamed, and listed in `mr_static_exts` as `cgi/escape`.
  The shipped feature `cgi/escape.so` (m_eval_leaf.mere, beside erb/escape)
  runs it through `Kernel.__capi_static_require`.
- **lib/cgi_escape_ext.rb is 4.0.10's lib/cgi/escape.rb byte for byte**
  under its header (checked with `cmp`): its `require 'cgi/escape.so'` now
  loads the C, whose CGI::EscapeExt is prepended to CGI::Escape and extended
  onto CGI, and the file aliases escape_html, h and unescape_html there. The
  StringValue patch this copy had in escapeURIComponent is gone -- the C
  does that now. A build with no C side raises LoadError at the require,
  which the file rescues, as on ruby's miniruby. m_pathname_lib.mere is
  regenerated (tools/gen_pathname_lib.rb; only cgi/escape's text changes).
- **CLASS_OF of a class is its metaclass** (capi_describe_x). escape.c's
  `CGI.unescape(str)` reads `rb_cvar_get(CLASS_OF(self), "@@accept_charset")`
  with self the class CGI; CLASS_OF answered Class, which has no such class
  variable (NameError). CRuby makes a metaclass with every class, so the
  answer is `(sng:CGI)`, through which the class variable CGI::Escape
  defines is found, as `CGI.singleton_class.class_variable_get` finds it. A
  module's is Module and a singleton class's Class, as before.
- **A C-only feature is its extension in $LOADED_FEATURES.** do_require
  (main.mere): a shipped feature that is a C extension alone in ruby 4.0's
  build (`cext_c_only`: etc, zlib, stringio, io/console, io/wait,
  io/nonblock, date_core, pty, fcntl, continuation, digest/md5, digest/sha1,
  digest/rmd160, json/ext/parser, json/ext/generator, prism/prism,
  rbconfig/sizeof, erb/escape -- each checked with
  `$LOAD_PATH.resolve_feature_path` on ruby 4.0.10) has
  `<rubyarchdir>/<name>.bundle` as its identity and only entry, also when
  asked for with `.so` (`require "stringio.so"` was `stringio.so.bundle`
  and `stringio.so.rb`); so does `cgi/escape.so`. Not another shipped
  feature asked for with `.so`: the shipped library of the bare name lists
  `<name>.bundle` when it starts, so bigdecimal.rb's
  `require 'bigdecimal.so'` read that as loaded and ran nothing -- the first
  version did so, and corpus 403 failed. cgi/escape's .rb no longer
  lists the extension itself: the extension lists itself when the .rb
  requires it, as on ruby. Features that are a .rb requiring the .so in
  ruby (socket, digest, openssl, monitor, objspace, coverage, ripper,
  digest/sha2) still list both, as ruby does.
- **A C-only library's methods are C.** Their file is now the extension's
  path, so `cext_lib_file` (which Refinement#import_methods asks: corpus
  579 imports Zlib's) knows that path too, and `#source_location` of such a
  method is nil, as ruby's (`Zlib.method(:crc32).source_location` was
  `[".../zlib.rb", 33]`). The continuation warning names
  `<arch>/continuation.bundle`, as ruby's does.
- capi/check: `CLASS_OF` of a class is its singleton class, and a class
  variable of a module it includes is read through it
  (`cvar_of_class_of`).
- corpus 918 (cgi/escape: the C methods and what they answer, source_location
  nil, the two entries) and 919 (eight C-only features, one entry each;
  `stringio.so` and `etc.so` after them; source_location nil for StringIO's
  and Etc's methods).

## Checked

On 81c42f56 (this branch with main ecd65075 merged, #284 among it), mere
9dec2ff6, reference ruby 4.0.10.

- What `require` adds for each library, against ruby 4.0.10 and main's
  build (the same script, `scratchpad` feat2.rb): etc, zlib, stringio,
  io/wait, io/nonblock, date_core, pty, fcntl, json/ext/parser,
  rbconfig/sizeof now list exactly what ruby lists (main listed a .rb beside
  each); erb/escape lists its extension alone (main: and erb/escape.rb);
  cgi/escape lists the extension and the .rb, in ruby's order; socket is
  unchanged (the same as ruby).
- cgi/test_cgi_escape.rb: 435 tests, 526 assertions, 0 skips, the same as
  ruby; main's build: 522 assertions and 2 skips (the omits).
- `unittest/run.sh` cgi/test_cgi_escape.rb, erb, ruby/test_encoding.rb and
  ruby/test_m17n.rb, on the evaluator and with `MERE_RUBY_VM=1`: both 665
  tests, MATCH 664, BOTH 1 (test_m17n's one that fails on both sides, as
  on main), RED 0.
- `run_corpus.sh --both`: the gates, then 948/948 with the hash index on
  and off; `MERE_RUBY_VM=1 run_corpus.sh --both`: 948/948, the same.
- capi_check: the contracts agree on both sides (api 376), hold under
  collection stress, and each negative control fails. capi_spec_check: the
  reference passes what is recorded and mere-ruby no less (2420 of 2602).
  capi_mkmf_check passes.
- capi_gem_check: seventeen gems install and behave the same on both
  sides (173 lines); the other-ruby control fails.

## Left

- Some differences in what `require` adds are not this change's and stay:
  `require "erb/escape"` and `"cgi/escape"` add `set.rb` here (ruby has it
  from the start); digest's `digest/version.rb` and `digest/loader.rb` are
  not listed; `require "io/console"` lists stringio too;
  `require "io/wait.so"` (and other `.so` names with no shipped entry) is a
  LoadError where ruby answers false; `require "zlib.so"` after `require
  "zlib"` answers true where ruby answers false (zlib's special case).
- strscan is left out of `cext_c_only`: ruby lists `strscan/strscan.rb`
  that its extension requires, which this interpreter does not have.
