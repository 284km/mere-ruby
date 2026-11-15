# mere-ruby's Ripper, on the REFERENCE ruby: require this before anything
# else and ::Ripper is what mere-ruby answers `require "ripper"` with --
# Prism::Translation::Ripper plus lib/ripper_ext.rb -- instead of the C
# extension. Same Ruby code, a ruby several times faster, so test/ripper
# runs in seconds:
#
#   cd <ruby-src>/test/ripper
#   ruby -I<ruby-src>/tool/lib -I<ruby-src>/test \
#        -r<repo>/tools/ripper_on_cruby.rb -rtest/unit test_parser_events.rb
#
# A result here and mere-ruby's differ only where the interpreter does (PR
# #81: parser_events 29 here and 31 there before the work, 3 and 5 after).
# Use the reference (tools/ref_ruby.sh): lib/ripper_ext.rb reopens the
# translation of ITS prism.
require "prism"
load File.expand_path("../lib/ripper_ext.rb", __dir__)
# (ripper's own names marked loaded, so that a test's `require "ripper"`
#  keeps this one and never loads the C extension)
%w[ripper.rb ripper.so ripper/core.rb ripper/lexer.rb ripper/filter.rb ripper/sexp.rb].each do |f|
  $LOADED_FEATURES << File.join(RbConfig::CONFIG["rubylibdir"], f)
end
