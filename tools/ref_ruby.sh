# tools/ref_ruby.sh -- SOURCE this before comparing anything with ruby.
#
# Every gate in this repository asks "does mere-ruby print what ruby prints",
# so the reference ruby is part of the subject: a different one is a different
# question, and the answer arrives looking like mere-ruby moved. On 2026-09-04
# it moved twice in one session. A reboot dropped rbenv's shims from PATH and
# `ruby` became macOS's own 2.6.10: a full ruby/spec sweep then read MATCH
# 762 -> 694, because 2.6 cannot parse fifty-four of the spec files and that
# counts as "ruby does not run it here". Later the same day the rbenv global
# version changed to 3.4.9 under a running session and the corpus dropped to
# 6 of 168 -- on Hash#inspect, which 3.4 prints as `{"x" => 1}`.
#
# 2026-09-04: the reference moved from 3.2.2 to 3.4.9. The suites this repo
# measures against (ruby/spec, bootstraptest) come from a 4.1-dev checkout, so
# a newer reference reproduces more of them: bootstraptest's DRIFT -- the pairs
# the reference cannot reproduce, and which are therefore excluded from the
# denominator -- went 58 to 37 on the same mere-ruby binary. Nineteen of those
# twenty-one newly measurable pairs fail, which is the point: they were failing
# before and could not be seen.
#
# 2026-09-05: 3.4.9 to 4.0.6, measured the same way before the move -- the two
# rubies diffed against each other, not against mere-ruby. 175 of 180 corpus
# programs print the same under both (Set#inspect, `require "set"`, strip's
# arity and an openssl message are the five). bootstraptest's DRIFT goes 37 to
# 6 with no pair lost; the thirty-one newly measurable pairs are all Ractor.
# ruby/spec's 1081 files in the recorded groups print the same in 1078, and the
# other three differ by an object address: the mspec shim's ruby_version_is
# never yields, so version-guarded blocks are skipped on BOTH sides whatever
# the reference is, and that record cannot see a reference move at all.
#
# 2026-10-25: 4.0.6 to 4.0.9, measured the same way. 380 of 382 corpus
# programs print the same under both (one prints `ruby -v`, one a thread's
# address on stderr), and every table tools/gen_*.rb asks ruby for comes out
# the same. The unittest record is where the move shows: the same binary read
# 6697 of 7366 against 4.0.6 and 6724 of 7426 against 4.0.9, RED 547 -> 578,
# because 4.0.9's test files carry the fixes they test -- Set keeping
# compare_by_identity, Regexp's range-repeat and null-check limits, curry's
# arity, gets on a character boundary, strftime's zone abbreviation. ruby/spec
# did not move (2487 on both): its tree is pinned separately.
#
# 2026-11-24: the reference is Ruby 4.0.10, tag a704b7cd95. Saved
# 4.0.9 measurements keep their original provenance; new runs use this pin.
#
# So: name the version, select it if rbenv has it, and refuse to run otherwise.
# Refusing is the point. A gate that runs against whatever ruby is on PATH
# reports a regression that did not happen, and the reader cannot tell.
REF_RUBY_VERSION="${REF_RUBY_VERSION:-4.0.10}"
if [ -n "${REF_RUBY_BIN:-}" ]; then
  # CI builds a reference with test-only C extensions. Verify that exact
  # binary rather than replacing it with an installed rbenv interpreter.
  ref_have="$("$REF_RUBY_BIN" -e 'print RUBY_VERSION' 2>/dev/null)"
  if [ "$ref_have" != "$REF_RUBY_VERSION" ]; then
    echo "reference binary reports ${ref_have:-none}, expected $REF_RUBY_VERSION" >&2
    exit 2
  fi
  export REF_RUBY_BIN
else
if [ "$(ruby -e 'print RUBY_VERSION' 2>/dev/null)" != "$REF_RUBY_VERSION" ]; then
  if [ -x "$HOME/.rbenv/versions/$REF_RUBY_VERSION/bin/ruby" ]; then
    RBENV_VERSION="$REF_RUBY_VERSION"; export RBENV_VERSION
    PATH="$HOME/.rbenv/shims:$PATH"; export PATH
  fi
fi
ref_have="$(ruby -e 'print RUBY_VERSION' 2>/dev/null)"
# ...and the REAL binary, not the shim. rbenv's shim exports RBENV_DIR,
# RBENV_HOOK_PATH, RBENV_ORIG_PATH and RUBYLIB into the process it execs, so a
# spec that counts one expectation per ENV key sees a different ENV on the two
# sides and can never match however right the interpreter is (core/env's
# keys / values / to_a / each_key / each_value: 15 expectations against 9).
# Gates that compare ENV should invoke this; the rest may keep saying `ruby`.
if [ -x "$HOME/.rbenv/versions/$REF_RUBY_VERSION/bin/ruby" ]; then
  REF_RUBY_BIN="$HOME/.rbenv/versions/$REF_RUBY_VERSION/bin/ruby"
else
  REF_RUBY_BIN="$(command -v ruby)"
fi
export REF_RUBY_BIN

if [ "$ref_have" != "$REF_RUBY_VERSION" ]; then
  echo "reference ruby is ${ref_have:-none}, expected $REF_RUBY_VERSION (which ruby: $(command -v ruby))" >&2
  echo "the recorded numbers are against $REF_RUBY_VERSION; another one is a different question," >&2
  echo "not a regression. Install it, or set REF_RUBY_VERSION to sweep against something else." >&2
  exit 2
fi
fi

# ...and the reference's OWN GEM DIRECTORY has to be the one that ruby ships.
# A gem that is neither a default gem nor a bundled one, installed there,
# changes what `require` finds on the reference side only. On 2026-11-24 an
# editor's language server installed itself into the pinned 4.0.10 (ruby-lsp
# and what it needs: prism 1.9.0, rbs, rdoc, irb, erb, reline, io-console).
# `require "prism"` then loaded 1.9.0 where ruby 4.0.10 ships 1.8.2, corpus
# 499 failed on Prism::VERSION, and it read as "the vendored Prism is behind
# the new reference" -- a plan to move the vendored copy was made before the
# gem was noticed.
#
# The bundled gems are the pinned version's gems/bundled_gems (ruby tag
# a704b7cd95 for 4.0.10), kept here because this file is sourced without the
# ruby source at hand. When REF_RUBY_VERSION moves, this list moves with it;
# for a version it has no list for, the check says so and does not judge.
# A gem this repository installs into the reference on purpose is named in
# ref_ruby_wanted (CI's `gem install nkf --version 0.2.0`, which
# tools/nkf_check.sh compares mere-ruby's NKF with).
# REF_RUBY_EXTRA_GEMS_OK=1 skips the check, for a sweep that means to have them.
ref_ruby_bundled_version="4.0.10"
ref_ruby_bundled="minitest 6.0.0
power_assert 3.0.1
rake 13.3.1
test-unit 3.7.5
rexml 3.4.4
rss 0.3.2
net-ftp 0.3.9
net-imap 0.6.4.1
net-pop 0.1.2
net-smtp 0.5.1
matrix 0.4.3
prime 0.1.4
rbs 3.10.0
typeprof 0.31.1
debug 1.11.1
racc 1.8.1
mutex_m 0.3.0
getoptlong 0.2.1
base64 0.3.0
bigdecimal 4.0.1
observer 0.1.2
abbrev 0.1.2
resolv-replace 0.1.1
rinda 0.2.0
drb 2.2.3
nkf 0.2.0
syslog 0.3.0
csv 3.3.5
repl_type_completor 0.1.12
ostruct 0.6.3
pstore 0.2.1
benchmark 0.5.0
logger 1.7.0
rdoc 7.0.4
win32ole 1.9.2
irb 1.16.0
reline 0.6.3
readline 0.0.4
fiddle 1.1.8"
ref_ruby_wanted="nkf 0.2.0"
if [ "${REF_RUBY_EXTRA_GEMS_OK:-0}" != 1 ]; then
  if [ "$REF_RUBY_VERSION" != "$ref_ruby_bundled_version" ]; then
    echo "reference ruby $REF_RUBY_VERSION: no bundled-gem list for it in tools/ref_ruby.sh (it has $ref_ruby_bundled_version's); extra gems in its gem directory are not checked" >&2
  else
    # (the reference prints the report itself: the gems, and the command
    #  that removes each. Nothing on stdout means a clean gem directory.)
    ref_extra="$(REF_RUBY_KNOWN="$ref_ruby_bundled
$ref_ruby_wanted" "$REF_RUBY_BIN" -e '
      known = ENV["REF_RUBY_KNOWN"].lines.map { |l| l.split.first(2).join("-") }
      specs = Dir[File.join(Gem.default_dir, "specifications", "*.gemspec")]
      extra = specs.map { |f| File.basename(f, ".gemspec") }.reject { |nv| known.include?(nv) }.sort
      exit if extra.empty?
      gem = File.join(RbConfig::CONFIG["bindir"], "gem")
      puts "reference ruby #{RUBY_VERSION} has gems that it does not ship, in its own gem directory"
      puts "(#{Gem.default_dir}):"
      extra.each { |nv| puts "  #{nv}" }
      puts "They are neither default nor bundled gems of #{RUBY_VERSION}, and `require` on the reference"
      puts "side finds them: what is compared is then no longer ruby #{RUBY_VERSION}. To remove them:"
      extra.each do |nv|
        name, version = nv.match(/\A(.+?)-(\d[^-]*(?:-.+)?)\z/).captures
        puts "  #{gem} uninstall #{name} --version #{version} --executables --ignore-dependencies"
      end
      puts "(a language server of an editor installs itself this way. REF_RUBY_EXTRA_GEMS_OK=1 skips this check.)"
    ')"
    # (a check that could not run is not a clean directory: the script's own
    #  failure stops here too, with what it said on stderr, rather than
    #  answering nothing and passing)
    ref_extra_rc=$?
    if [ "$ref_extra_rc" -ne 0 ]; then
      echo "reference ruby $REF_RUBY_VERSION: the check of its gem directory did not run (exit $ref_extra_rc); REF_RUBY_EXTRA_GEMS_OK=1 skips it" >&2
      exit 2
    fi
    if [ -n "$ref_extra" ]; then
      echo "$ref_extra" >&2
      exit 2
    fi
  fi
fi
