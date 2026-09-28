# ObjectSpace.each_object did not exist. It walks the object table now --
# every live object whose class is-a the argument, classes and modules
# included -- and answers the count, or an Enumerator without a block.
class Widget
  attr_reader :name
  def initialize(name) = @name = name
end
keep = [Widget.new(:a), Widget.new(:b)]
names = []
n = ObjectSpace.each_object(Widget) { |w| names << w.name }
p n, names.sort
p ObjectSpace.each_object(Widget).class, ObjectSpace.each_object(Widget).map(&:name).sort
module Tagged; end
class Gadget; include Tagged; end
g = Gadget.new
p ObjectSpace.each_object(Tagged).to_a == [g]
base = Class.new
kids = [Class.new(base), Class.new(base)]
grand = Class.new(kids[0])
walked = ObjectSpace.each_object(base.singleton_class).to_a
p walked.size, ([base, grand] + kids).all? { |k| walked.include?(k) }
m = Module.new
p ObjectSpace.each_object(Module).include?(m), ObjectSpace.each_object(Class).include?(m)
p ObjectSpace.each_object(Class).include?(base), ObjectSpace.each_object(Class).include?(Widget)
begin
  ObjectSpace.each_object(42) { }
rescue TypeError => e
  p e.message
end
p keep.size
