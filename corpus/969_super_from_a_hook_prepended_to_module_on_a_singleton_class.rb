# A method prepended to Module can call super into Module's own, whatever
# module or class the receiver is -- the singleton class of an OBJECT too.
# That one is a Class, and its own chain is its metaclass's; it was taken
# to have the object's chain, with no Module in it, so the super had
# nowhere to go. Zeitwerk prepends #const_added to Module and ends it with
# `super`: `class << obj; X = 1; end` -- tmpdir.rb does it -- raised
# "super: no superclass method 'const_added'", and every activerecord file
# that loads tmpdir after Zeitwerk stopped there.
$seen = []
module CA
  def const_added(n)
    $seen << [inspect.sub(/0x\h+/, "X"), n]
    super
  end
end
Module.prepend(CA)
module T; A = 1; class << self; X = 1; end; end
o = Object.new
class << o; Y = 2; end
# a class written in `class << self` is the singleton class's constant
class K; class << self; Z = 3; class In; end; module Im; end; end; end
s = Class.new
s.const_set(:Q, 1)
s.singleton_class.const_set(:R, 2)
str = +"s"
class << str; W = 4; end
p $seen

# called by name, and the other hooks Module answers the same way
sc = o.singleton_class
module CA2
  def const_added(n) = (super; :ok)
  def method_added(n) = (super; ($added ||= []) << n; :added)
  def included(b) = (super; :inc)
end
Module.prepend(CA2)
p sc.send(:const_added, :Zz), Class.new.send(:const_added, :Q), sc.respond_to?(:const_added, true)
p sc.send(:method_added, :by_name), sc.send(:included, Object), $added
p sc.is_a?(Module), sc.singleton_class.ancestors.include?(Module)
