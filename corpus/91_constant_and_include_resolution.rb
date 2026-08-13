# `class X < Const` and `include Const` EVALUATE the constant: an alias, a
# lexically scoped name, and an autoload registration all have to resolve.
class Base
  def initialize(o = nil); @o = o; end
  def o; @o; end
end
Alias = Base
class ViaAlias < Alias
  def initialize(o = nil); super(o); end
end
p ViaAlias.new(1).o
p ViaAlias.superclass

module Cc
  module Impl
    class Backend
      def initialize(o = nil); @o = o; end
      def o; @o; end
    end
    Chosen = case
             when false then nil
             else Backend
             end
  end
  class Front < Impl::Chosen
    def initialize(o = nil); super(o); end
  end
end
p Cc::Front.new(2).o
p Cc::Front.superclass

# a module included into a module reaches the class that includes the outer one
module Deref
  def deref; :deref; end
end
module Wrapper
  include Deref
  def wrapped; :wrapped; end
end
class Uses
  include Wrapper
end
p Uses.new.deref
p Uses.new.wrapped
p Uses.ancestors

# constants of an included module are visible as Klass::NAME
module Sev
  WARN = 2
end
class Logg
  include Sev
end
p Logg::WARN
p defined?(Logg::WARN)
