# 2026-11-24: erb/escape is ruby's C extension, linked into the executable

work2026-44 compared main's first complete CI since 11-21 (c2a26980) file by
file. erb/test_erb.rb's TestERB#test_html_escape_extension had gone RED:
`ERB::Util.method(:html_escape).source_location` is nil on ruby, because
html_escape is the C extension erb/escape. Here the method was erb/util.rb's
Ruby fallback. #147 made module_function copies keep their
source_location, which is right; before it, the nil here was an accident.

## What changed (branch capi-erb-escape, 55ff1456, from main 5c12209a)

- `capi/vendor/erb_escape.c` is CRuby 4.0.9's `ext/erb/escape/escape.c`,
  unchanged (`cmp` against ~/src/github.com/ruby/ruby-4.0.9 gives no
  difference).
- `capi/static_ext.c` compiles it with `Init_escape` renamed to
  `mr_static_Init_erb_escape`, and `HAVE_RB_EXT_RACTOR_SAFE` defined as its
  extconf.rb's have_func would. It also holds the table of statically linked
  extensions, `mr_static_exts`.
- `mr_capi_static_open` (capi/core.c) registers a table entry as a library
  with no handle, so `rb_ext_resolve_symbol` uses `RTLD_DEFAULT` for it. Then
  `capi_require_static` (main.mere) runs its Init_ through MR_RUN_INIT, as
  `capi_require_file` does for a library.
- `require "erb/escape"` runs the shipped source
  `Kernel.__capi_static_require('erb/escape')` (stdlib_src in
  m_eval_leaf.mere). A build with no C side (m_capi_none.mere answers -1)
  raises LoadError there, and erb/util.rb defines its Ruby html_escape, as for
  ruby's miniruby.
- corpus 914 checks:
  - source_location nil;
  - the same String back when nothing is escaped;
  - #to_s of a non-String;
  - binary and UTF-8 encodings kept;
  - a UTF-16LE String through CGI.escapeHTML;
  - one erb/escape.bundle in $LOADED_FEATURES;
  - `resolve_feature_path` gives :so;
  - an includer of ERB::Escape.

  It is the same on ruby 4.0.9, the evaluator, the VM and with the hash index
  off. It requires erb/escape, not erb: the corpus runs without the reference
  stdlib.

## Measured (2026-11-25, 8157f9e0 = main 2e402b94 merged, reference ruby 4.0.10)

`capi/vendor/erb_escape.c` is also byte-for-byte 4.0.10's
`ext/erb/escape/escape.c` (`cmp`). Built with Mere 9dec2ff6 (CI's MERE_REF).

- Gates, bracket_depth and record_hygiene pass.
- `run_corpus.sh --both`: 882/882 with the hash index on and off.
- `tools/iseq/vm_corpus.sh`: 882 on the VM, 0 fell back, 0 FAIL.
- capi_check (both sides and under collection stress, controls fail),
  capi_spec_check and capi_mkmf_check pass against 4.0.10.
- On mere-ruby, `MERE_RUBY_VM=1` and the reference, all the same:
  - erb/test_erb.rb: 80 tests, 217 assertions, 0 failures
  - erb/test_erb_command.rb: 2 tests, 0 failures
  - erb/test_erb_m17n.rb: 6 tests, 0 failures
- cgi/test_cgi_escape.rb: 435 tests, 0 failures, 2 skips on both mere-ruby
  and the VM; the reference has 0 skips. The two skips are the
  "C extension not available" omits (`CGI::EscapeExt` is undefined:
  cgi/escape is still Ruby here). main 2e402b94 skips the same two.
- test_erb.rb under `/usr/bin/time -l`, main 2e402b94 against this branch:
  1 failure (test_html_escape_extension) → 0; maximum resident set size
  193,314,816 → 187,023,360 bytes; 7.57 s → 7.58 s real.
- capi_gem_check (last, alone among this session's checks): seventeen gems
  with C extensions install with `gem install` and behave the same on both
  sides; the other-ruby control fails. The load average was 59.74 at the
  start and 33.58 at the end: several of Codex's corpus runs were going
  (work2026-44), and this session's native-gems-r3 puma cluster runs
  overlapped part of it. No gem hit a time limit.
- A difference not from this change: a shipped C-extension feature has two
  $LOADED_FEATURES entries here (`.../erb/escape.bundle` and
  `.../erb/escape.rb`), where ruby has the bundle alone. `etc` and
  `rbconfig/sizeof` are the same. corpus 914 counts the bundle entries only.

## Left

- cgi/escape as ruby's C extension (`ext/cgi/escape`), which would take the
  two omits above. The same static table would hold it.
- The two $LOADED_FEATURES entries above.
