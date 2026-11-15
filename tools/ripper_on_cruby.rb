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
# The rubies a test starts (assert_separately, assert_no_memory_leak,
# assert_parse_files) get it too: tools/ripper_on_cruby/ripper.rb leads
# their load path (the parent's $LOAD_PATH, which assert_separately passes
# as -I, and RUBYLIB), so their own `-rripper` is the translation. Without
# that they load the C extension and their results say nothing about the
# translation. (RUBYOPT would not do: a command line's -r runs first.)
#
#   ruby tools/ripper_on_cruby.rb
#       checks that ::Ripper is the translation here, after the C
#       extension's own require names, and in a child ruby
#
# A result here and mere-ruby's differ only where the interpreter does (PR
# #81: parser_events 29 here and 31 there before the work, 3 and 5 after).
# Use the reference (tools/ref_ruby.sh): lib/ripper_ext.rb reopens the
# translation of ITS prism.
require "prism"
require "rbconfig"
# (quiet: a child under -w that writes to stderr fails assert_separately)
verbose, $VERBOSE = $VERBOSE, nil
begin
  load File.expand_path("../lib/ripper_ext.rb", __dir__)
ensure
  $VERBOSE = verbose
end
# (ripper's own names marked loaded, so that a test's `require "ripper"`
#  keeps this one and never loads the C extension -- whose feature is
#  ripper.<DLEXT> under the arch dir, whatever name the require gives)
%w[ripper.rb ripper/core.rb ripper/lexer.rb ripper/filter.rb ripper/sexp.rb].each do |f|
  $LOADED_FEATURES << File.join(RbConfig::CONFIG["rubylibdir"], f)
end
$LOADED_FEATURES << File.join(RbConfig::CONFIG["rubyarchdir"], "ripper.#{RbConfig::CONFIG["DLEXT"]}")
# (and the same for every ruby started from this one)
shim = File.expand_path("ripper_on_cruby", __dir__)
$LOAD_PATH.unshift(shim) unless $LOAD_PATH.first == shim
unless ENV["RUBYLIB"].to_s.split(File::PATH_SEPARATOR).first == shim
  ENV["RUBYLIB"] = [shim, ENV["RUBYLIB"]].compact.reject(&:empty?).join(File::PATH_SEPARATOR)
end

if $0 == __FILE__
  ok = true
  check = lambda do |what, got|
    puts "#{got ? "ok  " : "FAIL"} #{what}"
    ok &&= got
  end
  %w[ripper ripper.so ripper/core ripper/lexer ripper/sexp].each do |name|
    require name
    check.("require #{name.inspect} keeps the translation", Ripper.equal?(Prism::Translation::Ripper))
  end
  probe = "print Ripper.equal?(Prism::Translation::Ripper)"
  out = IO.popen([RbConfig.ruby, "-w", "--disable=gems", "-rripper", "-e", probe], err: [:child, :out], &:read)
  check.("a child ruby's -rripper is the translation (and quiet under -w)", out == "true")
  # (assert_separately's way: the parent's load path as -I)
  out = IO.popen([RbConfig.ruby, "-w", "--disable=gems", *$LOAD_PATH.map { "-I#{_1}" }, "-rripper", "-e", probe],
                 err: [:child, :out], &:read)
  check.("so is one given the load path as -I", out == "true")
  exit(ok ? 0 : 1)
end
