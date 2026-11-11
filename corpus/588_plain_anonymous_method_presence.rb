# Shared parent presence must notice own writes, parent writes and dependency
# lookups made for descendants, and leave mixin/undef/visibility rules intact.
base = Class.new do
  def own
    :own
  end
end
child = Class.new(base)
p [base.method_defined?(:own), base.new.method(:own).owner.equal?(base)]
p [base.method_defined?(:future), child.method_defined?(:future)]
base.define_method(:future) { :future }
p [base.method_defined?(:future), child.method_defined?(:future), child.new.future]
base.send(:remove_method, :future)
p [base.method_defined?(:future), child.method_defined?(:future)]

p base.method_defined?(:parent_added)
Object.class_eval { def parent_added; :parent; end }
p [base.method_defined?(:parent_added), base.new.parent_added]
Object.send(:remove_method, :parent_added)
p base.method_defined?(:parent_added)

base.send(:private, :own)
p [base.method_defined?(:own), base.private_method_defined?(:own), base.new.respond_to?(:own)]
base.send(:public, :own)
p base.new.respond_to?(:own)

mix = Module.new { def mixed; :mixed; end }
p base.method_defined?(:mixed)
base.include(mix)
p [base.method_defined?(:mixed), child.new.mixed]
pre = Module.new do
  def own
    [:prepend, super]
  end
end
base.prepend(pre)
p [base.method_defined?(:own), base.new.own]
pre.send(:undef_method, :own)
p base.new.respond_to?(:own)
begin
  base.new.own
rescue NoMethodError
  puts 'prepend undef respected'
end

class AnonClass_900001
  def marker
    :named
  end
end
p AnonClass_900001.new.marker
