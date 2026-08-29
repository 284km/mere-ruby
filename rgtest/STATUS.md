# rgtest — RubyGems' own tests under mere-ruby

`./run.sh <path/to/rubygems>` runs a rubygems test file under BOTH `ruby` and
`mere-ruby`, with `helper.rb` (a minitest-lite stand-in for rubygems' 1705-line
test helper) installed in place of the real one, and compares the tallies. Like
`SPEC_STATUS.md`, this is a checked-in record of where mere-ruby stands, not a
green CI.

Both sides enter the test with the same RubyGems in memory: `ruby` has its own
preloaded and takes `-I` to make the checkout win, mere-ruby unshifts
`$LOAD_PATH` and requires it. That symmetry is what makes the tallies
comparable — before `require "rubygems"` worked, mere-ruby ran these tests with
no RubyGems loaded at all and the numbers meant much less.

Scope is RubyGems' **pure-Ruby core** — the classes that drive gem activation.
`zlib` / `psych` / `openssl` are required lazily inside method bodies, not at
load time, so they bound what the tests can *do*, not what can be loaded.

## The library itself

Loaded straight from a rubygems checkout, no shims:

| what | result |
|---|---|
| `Gem::Version` (segments / `<=>` / `bump` / `prerelease?` / sort) | byte-identical to ruby 3.2.2 |
| `Gem::Requirement` (`~>` / multiple constraints / `parse` / `default`) | byte-identical |
| `Gem::Dependency` (`requirement` / `type` / `match?` / `=~`) | byte-identical |
| `lib/**/*.rb` that mere-ruby's parser accepts | **330 / 428** |

## The test suite (2026-08-29)

| file | ruby | mere-ruby |
|---|---|---|
| `test_gem_version.rb` | pass=32 fail=0 err=0 | pass=29 fail=0 err=3 |
| `test_gem_requirement.rb` | pass=34 fail=0 err=1 | pass=25 fail=8 err=2 |
| `test_gem_dependency.rb` | pass=22 fail=0 err=10 | **byte-identical** |

`test_gem_dependency.rb` was `pass=21 fail=1 err=10` and became byte-identical
during the Array arc (2026-08-29), which changed several equality paths at once
(a search compares with the ELEMENT's `#==`; `3.0 == obj` asks the object;
`Array#==` dispatches per element). Which of them the one failing example
needed was not isolated.

Eight of test_gem_requirement's examples moved from err to FAIL, with the pass
count unchanged, when a rescue clause's bare constant started resolving through
its lexical scope: rubygems' own rescues began working, so those examples now RUN
and compare instead of aborting. More reach, not a regression -- and what they
compare is worth naming. `test_parse` reads
`expected ["=", #<Gem::Version "1">], got ["=", #<Gem::Version "1">]`: the same
text, not equal. `test_initialize_copy` wants a different object from `dup` and
`test_parse_deduplication` wants the same object from a cache. Equality and
identity on Gem::Version, in other words, which is where this suite goes next.

The ruby column is not 100% either: the shim deliberately does not reproduce
the sandbox (temp gem home, installed gem fixtures) the real helper builds, so
tests that install and resolve gems error on both sides.

### Known gaps behind the remaining errors

- **`test_gem_requirement.rb`** no longer aborts: it used to die on
  `Gem.java_platform?`, which only exists once `rubygems.rb` itself has run.
- **`Gem::Version#canonical_segments`** returns `[12, 3, "pre", 1]` where ruby
  gives `[1, 2, 3, "pre", 1]`. Every piece of it (`_segments`, `slice!`,
  `reverse_each.drop_while.reverse`, `reduce(&:concat)`) is correct in
  isolation, so the fault is in how they compose. This also accounts for the
  `test_hash` and `test_spaceship` errors.
- **`test_gem_dependency`'s remaining errors** are mostly `util_spec` /
  installed-gem fixtures, i.e. the sandbox above — out of scope rather than a
  fidelity gap.
- Reading a private method through `send` (`v.send(:_split_segments)`) raises.
- Operators are not callable as methods: `1.+(2)`, `1.send(:+, 2)` and
  therefore `inject(&:+)`. (`inject(:+)` works — it is special-cased.)
