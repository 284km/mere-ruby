# frozen_string_literal: true

# Restore mkmf's build context without hard-coding the artifact's old prefix.
# The original Makefile, static library and generated header come from the
# same reference build; source lib/include come from the pinned checkout.
require "rbconfig"
require "fileutils"

source = File.realpath(ARGV.fetch(0))
arch = RbConfig::CONFIG.fetch("arch")
archive = RbConfig::CONFIG.fetch("LIBRUBY_A")
%W[Makefile #{archive} lib/mkmf.rb include/ruby.h .ext/include/#{arch}/ruby/config.h].each do |name|
  abort "reference build context is missing #{name}" unless File.file?(File.join(source, name))
end
config = $LOADED_FEATURES.find { |path| path.end_with?("/rbconfig.rb") }
abort "installed rbconfig was not found" unless config && File.file?(config)
context = File.join(source, ".unittest-reference")
FileUtils.mkdir_p(context)
File.write(File.join(context, "rbconfig.rb"), <<~RUBY)
  # Generated after restoring the reference runtime at its current location.
  load #{File.realpath(config).dump} unless defined?(RbConfig::CONFIG)
  RbConfig.fire_update!("topdir", #{source.dump})
RUBY
puts "reference mkmf build context ready"
