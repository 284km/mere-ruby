# Kernel#autoload registered in self's class -- Object for any call from a
# method -- where ruby registers in the caller's own class; Kernel.autoload
# registered under "Kernel::"; a nil or non-String path was accepted as "";
# a frozen namespace accepted a registration; and Module#autoload? never
# looked at the ancestors.
module Plugins
  def self.register = autoload(:Loader, "plugins/loader.rb")
  def setup = autoload(:Helper, "plugins/helper.rb")
end
class Host; include Plugins; end
Plugins.register
Host.new.setup
p Plugins.autoload?(:Loader), Plugins.autoload?(:Helper), Object.autoload?(:Helper)
anon = Class.new do
  def go
    autoload :Thing, "thing.rb"
    autoload? :Thing
  end
end
p anon.new.go, anon.autoload?(:Thing)
Kernel.autoload :TopLevelThing, "top.rb"
p Object.autoload?(:TopLevelThing), Kernel.autoload?(:TopLevelThing), Object.const_defined?(:TopLevelThing)
class Base; end
class Derived < Base; include Plugins; end
Base.autoload :FromBase, "base.rb"
p Derived.autoload?(:FromBase), Derived.autoload?(:Loader), Derived.autoload?(:FromBase, false)
path = Object.new
def path.to_path = "via_to_path.rb"
Plugins.autoload :ByPath, path
p Plugins.autoload?(:ByPath)
[nil, 3, ""].each do |bad|
  begin
    Plugins.autoload :Bad, bad
  rescue TypeError, ArgumentError => e
    p [e.class, e.message]
  end
end
frozen = Module.new.freeze
begin
  frozen.autoload :Nope, "nope.rb"
rescue FrozenError => e
  p e.class
end
