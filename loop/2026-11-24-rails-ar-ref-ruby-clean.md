# tools/ref_ruby.sh refuses a reference ruby whose own gem directory holds gems it does not ship

**What happened.** On 2026-11-24 an editor's language server installed itself into the pinned reference, ruby 4.0.10: ruby-lsp and what it needs, thirteen gems, prism 1.9.0 among them. ruby 4.0.10 ships Prism 1.8.2 as a default gem. `require "prism"` on the reference side then loaded 1.9.0. Corpus 499 prints `Prism::VERSION` and failed on it, on every branch, at the first corpus run against the new reference. It read as "the vendored Prism is behind the new reference", and a plan to move the vendored copy to 1.9.0 was made before the gem was noticed. The reference was not ruby 4.0.10 any more, and nothing said so.

**The change.** `tools/ref_ruby.sh` already refuses a reference of another version. After that check it now asks the reference for the gems in its own gem directory (`Gem.default_dir`, the top-level `specifications/`; default gems are in `specifications/default` and are not asked about). A gem there that is not a bundled gem of the pinned version, at the bundled version, stops the gate with exit 2. The message lists each gem and the `gem uninstall` command that removes it.

- **The bundled list** is the pinned version's `gems/bundled_gems` (ruby tag a704b7cd95 for 4.0.10, 39 gems), kept in the file itself: it is sourced by gates that do not have the ruby source at hand. When `REF_RUBY_VERSION` moves, the list moves with it.
- **A version it has no list for** (a sweep with `REF_RUBY_VERSION=4.0.9`): the check says in one line that it does not judge, and the gate goes on.
- **A gem this repository installs into the reference on purpose** is named in `ref_ruby_wanted`: nkf 0.2.0, which CI installs for tools/nkf_check.sh.
- **`REF_RUBY_EXTRA_GEMS_OK=1`** skips the check.

A newer version of a default gem counts too (erb 6.0.7 beside the default erb): RubyGems activates the newest, so it changes what `require "erb"` finds.

**Not covered.** A gem home named by `GEM_HOME` / `GEM_PATH` in the caller's environment is not looked at; the corpus and the gates run with neither set. railstest/framework sets both to its own output directory and runs `--disable-gems`, so the extra gems did not reach its reference side.

**Checked** (on this machine, with the thirteen gems still installed):

| case | result |
|---|---|
| the 4.0.10 with the thirteen gems | stops, exit 2, lists the thirteen and their uninstall commands |
| the same, given as `REF_RUBY_BIN` | stops the same way |
| `REF_RUBY_EXTRA_GEMS_OK=1` | goes on |
| `REF_RUBY_VERSION=4.0.9` | one line: no list for 4.0.9, not checked; goes on |
| `REF_RUBY_BIN` of a 4.0.9 with the pin at 4.0.10 | stops on the version, as before |
| the thirteen named as wanted (stands in for a clean directory) | goes on |
