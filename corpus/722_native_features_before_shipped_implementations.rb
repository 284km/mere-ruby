# Build separately for the interpreter running this program; no native library
# crosses runtimes. The fixture observes require selection, not JSON behavior.
require "rbconfig"
require "tmpdir"
require "fileutils"
require "shellwords"

Dir.mktmpdir("native-feature-order") do |directory|
  native = File.join(directory, "native")
  ruby = File.join(directory, "ruby")
  [native, ruby].each { |root| FileUtils.mkdir_p(File.join(root, "json/ext")) }
  source = File.join(directory, "selection.c")
  File.write(source, <<~C)
    #include "ruby.h"
    void Init_parser(void) {
      rb_define_global_const("NativeSelectionParser", rb_str_new_cstr("native"));
    }
    void Init_generator(void) {
      rb_define_global_const("NativeSelectionGenerator", rb_str_new_cstr("native"));
    }
  C
  config = RbConfig::CONFIG
  header = config["rubyhdrdir"] || File.expand_path("../capi/include", __dir__)
  includes = [header, config["rubyarchhdrdir"]].compact.map { |path| "-I#{path}" }
  link = config.fetch("host_os").include?("darwin") ? %w[-bundle -undefined dynamic_lookup] : %w[-shared]
  extension = config.fetch("DLEXT")
  compiler = Shellwords.split(ENV["CC"] || config["CC"] || "cc")
  %w[parser generator].each do |part|
    target = File.join(native, "json/ext/#{part}.#{extension}")
    command = compiler + %w[-O2 -fPIC] + includes + link + [source, "-o", target]
    raise "native fixture compilation failed" unless system(*command)
  end
  File.write(File.join(ruby, "json/ext/generator.rb"), "NativeSelectionGenerator = :ruby\n")
  $LOAD_PATH.unshift(native, ruby)
  p $LOAD_PATH.resolve_feature_path("json/ext/generator").first
  p $LOAD_PATH.resolve_feature_path("json/ext/generator.rb").first
  p require("json/ext/generator")
  p NativeSelectionGenerator
  p $LOAD_PATH.resolve_feature_path("json/ext/parser").first
  p require("json/ext/parser")
  p NativeSelectionParser
  p require("json/ext/parser")
  p $LOADED_FEATURES.include?(File.realpath(File.join(native, "json/ext/parser.#{extension}")))
end
