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
