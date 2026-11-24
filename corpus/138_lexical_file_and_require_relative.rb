# `__FILE__`, `__dir__` and `require_relative` name the file the expression is
# WRITTEN in -- not whichever file the loader happens to be in when the code
# runs. A method or a block that runs after its own file finished loading used
# to see the entry script instead, so a `require_relative` in a method body (or
# in a block that another file yields, which is how bundler's settings.rb
# reaches its yaml_serializer) looked for its sibling in the wrong directory.
#
# The fixtures go in a directory of their own so that "the file it is written
# in" and "the file being run" are different directories -- that difference
# is the whole test. The directory is made for this run (Dir.mktmpdir) and
# not a fixed path under /tmp: two corpus runs at once wrote and deleted each
# other's files, and one of them failed here looking like an interpreter bug.
require "tmpdir"
dir = Dir.mktmpdir("mrb_lex")
$lex_dir = File.realpath(dir)
File.write(File.join(dir, "mrb_lex_sib.rb"), "module Sib\n  VALUE = :from_sibling\nend\n")
File.write(File.join(dir, "mrb_lex_yield.rb"),
           "module Yield1\n  def self.around\n    yield 1\n  end\nend\n")
File.write(File.join(dir, "mrb_lex_main.rb"), <<~'INNER')
  module Lex
    def self.in_method
      require_relative "mrb_lex_sib"
      [Sib::VALUE, File.basename(__FILE__), File.realpath(__dir__) == $lex_dir]
    end

    def self.in_block
      Yield1.around do |_|
        require_relative "mrb_lex_sib"
        [Sib::VALUE, File.basename(__FILE__), File.realpath(__dir__) == $lex_dir]
      end
    end

    AT_LOAD = [File.basename(__FILE__), File.realpath(__dir__) == $lex_dir]
  end
INNER

begin
  require File.join(dir, "mrb_lex_yield")
  require File.join(dir, "mrb_lex_main")

  # at load time this was already right, and it stays right
  p Lex::AT_LOAD
  # ... and now so is a method that runs long after its file was loaded
  p Lex.in_method
  # ... and a block written there but called from another file
  p Lex.in_block
  # the entry script's own __FILE__ and __dir__ are still the entry script's
  p File.basename(__FILE__), File.realpath(__dir__) == $lex_dir
ensure
  %w[mrb_lex_sib.rb mrb_lex_yield.rb mrb_lex_main.rb].each { |f| File.delete(File.join(dir, f)) }
  Dir.rmdir(dir)
end
