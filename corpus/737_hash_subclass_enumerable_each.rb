class ExpandedHashEach < Hash
  def each(*arguments)
    raise 'wrong each argument' unless arguments.empty? || arguments == [:extra]
    yield :one, 1
    yield :two, 2
    self
  end
end
h = ExpandedHashEach.new
p [:real_store, h.size, h.to_a]
p [:enumeration, h.count, h.entries, h.entries(:extra), h.count([:one, 1])]
p [:block, h.count { |key, value| value.even? }]
p [:break, h.count { break :stopped }]
p [:ignored, h.entries { raise 'entries block must be ignored' }]
class InheritedHashEach < ExpandedHashEach; end
p [:inherited, InheritedHashEach.new.count, InheritedHashEach.new.entries]
class PrivateHashEach < ExpandedHashEach
  private :each
end
p [:private_each, PrivateHashEach.new.count, PrivateHashEach.new.entries]
class RubyHashEnumeration < ExpandedHashEach
  def count; :ruby_count; end
  def entries; :ruby_entries; end
end
p [:override, RubyHashEnumeration.new.count, RubyHashEnumeration.new.entries]
class SuperHashEnumeration < ExpandedHashEach
  def count(*args, &block); super; end
  def entries(*args); super; end
end
p [:super, SuperHashEnumeration.new.count, SuperHashEnumeration.new.entries(:extra)]
class AliasHashEnumeration < ExpandedHashEach
  alias native_count count
  alias native_entries entries
  alias count size
end
p [:alias, AliasHashEnumeration.new.count, AliasHashEnumeration.new.native_count, AliasHashEnumeration.new.native_entries]
class YieldShapesHash < Hash
  def each
    yield
    yield :single
    yield :two, 2
  end
end
p [:shapes, YieldShapesHash.new.entries, YieldShapesHash.new.count]
begin
  h.count(1, 2)
rescue => error
  p [:arity, error.class]
end
