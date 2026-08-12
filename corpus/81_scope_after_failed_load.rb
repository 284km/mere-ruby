# A raise inside a class or module body must still restore the lexical scope.
# Without that, every top-level constant assigned afterwards is silently keyed
# under that class -- `TOP = 1` becomes Cls::TOP, and `defined?(TOP)` is nil.
File.write("/tmp/mrb_boom1.rb", "module Outer\n  class Inner\n    raise 'boom'\n  end\nend\n")
File.write("/tmp/mrb_boom2.rb", "class Alone\n  raise ArgumentError, 'nope'\nend\n")
File.write("/tmp/mrb_boom3.rb", "module Solo\n  raise 'in a module'\nend\n")
$LOAD_PATH.unshift("/tmp")

begin
  require "mrb_boom1"
rescue RuntimeError => e
  puts e.message
end
TOP_ONE = 1
p defined?(TOP_ONE)
p Object.const_defined?(:TOP_ONE)

begin
  require "mrb_boom2"
rescue ArgumentError => e
  puts e.message
end
TOP_TWO = 2
p Object.const_defined?(:TOP_TWO)

begin
  require "mrb_boom3"
rescue RuntimeError => e
  puts e.message
end
TOP_THREE = 3
p Object.const_defined?(:TOP_THREE)
p [TOP_ONE, TOP_TWO, TOP_THREE]

# the same in-process, without a require
begin
  class Direct
    raise "inline"
  end
rescue RuntimeError => e
  puts e.message
end
TOP_FOUR = 4
p Object.const_defined?(:TOP_FOUR)

# ...and a class that does NOT raise still scopes its own constants
class Fine
  INSIDE = 5
end
p Fine::INSIDE
p Object.const_defined?(:INSIDE)

%w[mrb_boom1 mrb_boom2 mrb_boom3].each { |f| File.delete("/tmp/#{f}.rb") }
