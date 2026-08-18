# `__FILE__`, `__dir__` and `require_relative` name the file the expression is
# WRITTEN in -- not whichever file the loader happens to be in when the code
# runs. A method or a block that runs after its own file finished loading used
# to see the entry script instead, so a `require_relative` in a method body (or
# in a block that another file yields, which is how bundler's settings.rb
# reaches its yaml_serializer) looked for its sibling in the wrong directory.
#
# The fixtures go in /tmp so that "the file it is written in" and "the file
# being run" are different directories -- that difference is the whole test.
File.write("/tmp/mrb_lex_sib.rb", "module Sib\n  VALUE = :from_sibling\nend\n")
File.write("/tmp/mrb_lex_yield.rb",
           "module Yield1\n  def self.around\n    yield 1\n  end\nend\n")
File.write("/tmp/mrb_lex_main.rb", <<~'INNER')
  module Lex
    def self.in_method
      require_relative "mrb_lex_sib"
      [Sib::VALUE, File.basename(__FILE__), File.basename(__dir__)]
    end

    def self.in_block
      Yield1.around do |_|
        require_relative "mrb_lex_sib"
        [Sib::VALUE, File.basename(__FILE__)]
      end
    end

    AT_LOAD = [File.basename(__FILE__), File.basename(__dir__)]
  end
INNER

require "/tmp/mrb_lex_yield"
require "/tmp/mrb_lex_main"

# at load time this was already right, and it stays right
p Lex::AT_LOAD
# ... and now so is a method that runs long after its file was loaded
p Lex.in_method
# ... and a block written there but called from another file
p Lex.in_block
# the entry script's own __FILE__ is still the entry script
p File.basename(__FILE__)

%w[mrb_lex_sib.rb mrb_lex_yield.rb mrb_lex_main.rb].each { |f| File.delete("/tmp/#{f}") }
