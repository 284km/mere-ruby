# rgtest — RubyGems' own tests under mere-ruby

`./run.sh <path/to/rubygems>` runs a rubygems test file under BOTH `ruby` and
`mere-ruby`, with `helper.rb` (a minitest-lite stand-in for rubygems' 1705-line
test helper) installed in place of the real one, and compares the tallies. Like
`SPEC_STATUS.md`, this is a checked-in record of where mere-ruby stands, not a
green CI.

Scope is RubyGems' **pure-Ruby core** — the classes that drive gem activation.
Everything past them (`Gem::Specification` and up) reaches zlib / psych /
openssl / rbconfig, which mere-ruby has no way to load: it has no C extension
mechanism at all. So `require "rubygems"` is out of reach by construction, and
the interesting question is how far the pure part goes.

## The library itself

Loaded straight from a rubygems checkout, no shims:

| what | result |
|---|---|
| `Gem::Version` (segments / `<=>` / `bump` / `prerelease?` / sort) | byte-identical to ruby 3.2.2 |
| `Gem::Requirement` (`~>` / multiple constraints / `parse` / `default`) | byte-identical |
| `Gem::Dependency` (`requirement` / `type` / `match?` / `=~`) | byte-identical |
| `lib/**/*.rb` that mere-ruby's parser accepts | **330 / 428** |

## The test suite (2026-08-10)

| file | ruby | mere-ruby |
|---|---|---|
| `test_gem_version.rb` | pass=32 fail=0 err=0 | pass=25 fail=0 err=7 |
| `test_gem_requirement.rb` | pass=34 fail=0 err=1 | (aborts while loading) |
| `test_gem_dependency.rb` | pass=22 fail=0 err=10 | pass=1 fail=0 err=31 |

The ruby column is not 100% either: the shim deliberately does not reproduce
the sandbox (temp gem home, installed gem fixtures) the real helper builds, so
tests that install and resolve gems error on both sides.

### Known gaps behind the remaining errors

- **`test_gem_requirement.rb` aborts while loading.** Reduced to: after
  `require "rubygems/requirement"`, referring to a constant of an enclosing
  class from a `self.` method of that class fails (`Gem::TestCase.inherited`
  reading `CASES`). It does not reproduce on a hand-written module of the same
  shape, so the trigger is still unidentified.
- **`Gem::Version#canonical_segments`** returns `[12, 3, "pre", 1]` where ruby
  gives `[1, 2, 3, "pre", 1]`. Every piece of it (`_segments`, `slice!`,
  `reverse_each.drop_while.reverse`, `reduce(&:concat)`) is correct in
  isolation, so the fault is in how they compose. This also accounts for the
  `test_hash` and `test_spaceship` errors.
- **`test_gem_dependency`'s 31 errors** are `util_spec` / `Gem::Specification`,
  i.e. the sandbox above — out of scope rather than a fidelity gap.
- Reading a private method through `send` (`v.send(:_split_segments)`) raises.
- Operators are not callable as methods: `1.+(2)`, `1.send(:+, 2)` and
  therefore `inject(&:+)`. (`inject(:+)` works — it is special-cased.)
