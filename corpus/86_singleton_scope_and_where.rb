# A `class << self` body's constant lookup continues the ENCLOSING lexical
# scope -- ruby walks the cref chain. Only the def target is the singleton.
# zeitwerk writes `module Zeitwerk; module X; class << self; extend Internal`.
module Z
  module Helper
    def marker = :m
  end
  CONST = 7

  module Inner
    class << self
      extend Helper
      p Helper
      p CONST
      INSIDE = 8
      def from_singleton = :fs
    end
  end

  module Inner2
    extend Helper
    p :direct_ok
  end

  class Klass
    class << self
      p CONST
      def kls_singleton = :ks
    end
  end
end

p Z::Inner.from_singleton
p Z::Klass.kls_singleton
p Z::Inner.respond_to?(:marker)
p Z::CONST

# the singleton body still defines methods on the singleton, not the module
p Z::Inner.singleton_methods.sort
p Z::Klass.singleton_methods.sort

# an error raised while loading is still an ordinary rescuable error
File.write("/tmp/mrb_where.rb", "module W\n  X = Integer(nil)\nend\n")
$LOAD_PATH.unshift("/tmp")
begin
  require "mrb_where"
rescue TypeError => e
  puts e.class
end
File.delete("/tmp/mrb_where.rb")
