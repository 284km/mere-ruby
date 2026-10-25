# What json asked of core: an Array or Hash subclass's own #to_s, an Array
# subclass's #<< that calls super, and Module's included hook aliased,
# removed and put back

require "json"

module CustomToS; def to_s = "#{self.class.name}#to_s"; end
class AWT < Array; include CustomToS; end
class HWT < Hash; include CustomToS; end
class AOwn < Array; def to_s = "own"; def inspect = "ins"; end
p AWT.new.to_s, HWT.new.to_s, AOwn.new.to_s, AOwn.new.inspect, "#{AOwn.new}"
p JSON.generate([AWT.new]), JSON.generate(AWT.new => 1), JSON.generate(HWT.new => 1)

class SubArray < Array
  def <<(v)
    @shifted = true
    super
  end
  def shifted? = @shifted
end
s = SubArray.new
s << 1 << 2
p s, s.shifted?, s.class
a = JSON.parse("[1, 2, 3]", array_class: SubArray)
p a, a.class, a.shifted?

inc = false
Module.send(:alias_method, :included_orig, :included)
Module.send(:remove_method, :included)
Module.send(:define_method, :included) { |base| included_orig(base); inc = true }
module JsMM; end
Class.new(String) { include JsMM }
p inc
Module.send(:remove_method, :included) if Module.method_defined?(:included)
Module.send(:alias_method, :included, :included_orig)
Module.send(:remove_method, :included_orig)
p Module.private_method_defined?(:included), Module.private_method_defined?(:included_orig)
