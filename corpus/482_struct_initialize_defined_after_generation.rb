# A generated Struct keeps its member initializer when initialize is replaced
# later. This must also work before any Struct with an initialize block exists.
CaseTest = Struct.new(:method_name, :attributes, :first_data, :follow_data)
CaseTest.class_eval do
  def initialize(method_name, attributes, first_data, follow_data=first_data)
    super
  end
end
p CaseTest.new(:upcase, [], 'a').to_a
p CaseTest.new(:downcase, [:ascii], 'A', 'B').to_a

BlockCase = Struct.new(:value) do
  def initialize(value)
    super(value * 2)
  end
end
p BlockCase.new(3).to_a

LaterCase = Struct.new(:left, :right)
LaterCase.class_eval do
  def initialize(left, right=left)
    super
  end
end
p LaterCase.new(4).to_a
class ChildCase < LaterCase
  def initialize(left, right=left)
    super(left + 1, right + 2)
  end
end
p ChildCase.new(4).to_a

class StructFactory < Struct
  def initialize(value)
    super(value * 3)
  end
end
FactoryCase = StructFactory.new(:value)
p FactoryCase.new(5).to_a

KeywordCase = Struct.new(:left, :right, keyword_init: true)
KeywordCase.class_eval do
  def initialize(left:, right: left)
    super
  end
end
p KeywordCase.new(left: 6).to_a
p KeywordCase.new(left: 6, right: 7).to_a

EmptyCase = Struct.new(:value)
EmptyCase.class_eval do
  def initialize(value='default')
    super
  end
end
p EmptyCase.new.to_a
begin
  LaterCase.new(1, 2, 3)
rescue ArgumentError
  puts 'custom initializer rejects excess arguments'
end

# A valid member name must not overlap interpreter initialization machinery.
CollisionCase = Struct.new(:__struct_init, :other)
c = CollisionCase.new(42, 43)
p [c.public_send(:__struct_init), c.respond_to?(:__struct_init)]
p CollisionCase.public_instance_methods(false).include?(:__struct_init)
c.__struct_init = 44
p c.to_a
CollisionCase.class_eval do
  def initialize(value, other=value)
    super
  end
end
p CollisionCase.new(45).public_send(:__struct_init)

KeywordCollisionCase = Struct.new(:__struct_init, :other, keyword_init: true)
k = KeywordCollisionCase.new(__struct_init: 46, other: 47)
p [k.public_send(:__struct_init), k.respond_to?(:__struct_init)]
KeywordCollisionCase.class_eval do
  def initialize(**args)
    super
  end
end
p KeywordCollisionCase.new(__struct_init: 48).to_a
class KeywordCollisionChild < KeywordCollisionCase
  def initialize(**args)
    super
  end
end
p KeywordCollisionChild.new(__struct_init: 49).public_send(:__struct_init)

OwnMethodCase = Struct.new(:value) do
  def initialize(value)
    super(value + 1)
  end
  def __struct_init(*)
    raise 'user method must not be used for member initialization'
  end
end
p OwnMethodCase.new(50).value
plain = Struct.new(:value)
p plain.private_instance_methods(false).include?(:__struct_init)
GC.start
p [CollisionCase.new(51).to_a, KeywordCollisionCase.new(__struct_init: 52).to_a]
