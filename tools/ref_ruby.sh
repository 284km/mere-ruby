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
# So: name the version, select it if rbenv has it, and refuse to run otherwise.
# Refusing is the point. A gate that runs against whatever ruby is on PATH
# reports a regression that did not happen, and the reader cannot tell.
REF_RUBY_VERSION="${REF_RUBY_VERSION:-4.0.6}"
if [ "$(ruby -e 'print RUBY_VERSION' 2>/dev/null)" != "$REF_RUBY_VERSION" ]; then
  if [ -x "$HOME/.rbenv/versions/$REF_RUBY_VERSION/bin/ruby" ]; then
    RBENV_VERSION="$REF_RUBY_VERSION"; export RBENV_VERSION
    PATH="$HOME/.rbenv/shims:$PATH"; export PATH
  fi
fi
ref_have="$(ruby -e 'print RUBY_VERSION' 2>/dev/null)"
if [ "$ref_have" != "$REF_RUBY_VERSION" ]; then
  echo "reference ruby is ${ref_have:-none}, expected $REF_RUBY_VERSION (which ruby: $(command -v ruby))" >&2
  echo "the recorded numbers are against $REF_RUBY_VERSION; another one is a different question," >&2
  echo "not a regression. Install it, or set REF_RUBY_VERSION to sweep against something else." >&2
  exit 2
fi
