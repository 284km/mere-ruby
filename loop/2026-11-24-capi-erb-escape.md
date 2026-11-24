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

## Measured so far

- erb/test_erb.rb: 80 tests, 0 failures, 0 errors, 0 skips on mere-ruby, on
  `MERE_RUBY_VM=1` and on the reference.
- Gates and record_hygiene pass at 55ff1456.
- A difference not from this change: a shipped C-extension feature has two
  $LOADED_FEATURES entries here (`.../erb/escape.bundle` and
  `.../erb/escape.rb`), where ruby has the bundle alone. `etc` and
  `rbconfig/sizeof` are the same. corpus 914 counts the bundle entries only.

## Paused (2026-11-24, all sessions paused by the user via work2026-44)

The full check run was stopped after the gates: they and record_hygiene had
passed, and the corpus was running. Nothing is pushed.

On resume:
1. In `/Users/284km/src/github.com/284km/mere-ruby/.claude/worktrees/capi-erb-escape`,
   fetch origin. Merge main, grep for markers, then rebuild.
2. Run the full checks one at a time:
   - `run_corpus.sh --both`
   - `tools/iseq/vm_corpus.sh`
   - capi_check, capi_spec_check, capi_mkmf_check
   - erb/test_erb.rb, test_erb_command.rb, test_erb_m17n.rb and
     cgi/test_cgi_escape.rb on both sides
   - capi_gem_check last, alone
3. Push and open the PR. The body says:
   - escape.c is ruby 4.0.9's, unchanged (work2026-44 asked);
   - the two-entry $LOADED_FEATURES difference, which predates this PR.
