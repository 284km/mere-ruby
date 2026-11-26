class DirectKeywordStruct < Struct.new(:a, :b)
  def initialize(a: nil, b: nil)
    self.a = a
    self.b = b
  end
end

class SuperKeywordStruct < Struct.new(:a, :b)
  def initialize(a: nil, b: nil)
    super
  end
end

class RestKeywordStruct < Struct.new(:a, :b)
  def initialize(**values)
    super
  end
end

class HashArgumentStruct < Struct.new(:a, :b)
  def initialize(value)
    self.a = value
  end
end

class FalseKeywordStruct < Struct.new(:a, :b, keyword_init: false)
  def initialize(a: nil, b: nil)
    super
  end
end

class TrueKeywordStruct < Struct.new(:a, :b, keyword_init: true)
  def initialize(a: nil, b: nil)
    super
  end
end

class NilKeywordStruct < Struct.new(:a, :b, keyword_init: nil)
  def initialize(a: nil, b: nil)
    super
  end
end

[DirectKeywordStruct, SuperKeywordStruct, RestKeywordStruct, HashArgumentStruct,
 FalseKeywordStruct, TrueKeywordStruct, NilKeywordStruct].each do |klass|
  p [klass.name, klass.new(a: 1, b: 2).to_a]
end

class InheritedKeywordStruct < DirectKeywordStruct
end
p [:inherited, InheritedKeywordStruct.new(a: 3, b: 4).to_a]

class StructParentInitializer < Struct
  def initialize(**values)
    @called = true
    super
  end
  attr_reader :called
end
parent_generated = StructParentInitializer.new(:a, :b)
value = parent_generated.new(a: 5, b: 6)
p [:parent_initializer, value.to_a, value.called]

normal = Struct.new(:a, :b)
explicit_false = Struct.new(:a, :b, keyword_init: false)
explicit_true = Struct.new(:a, :b, keyword_init: true)
[[:normal, normal], [:false, explicit_false], [:true, explicit_true]].each do |label, klass|
  p [label, :keywords, klass.new(a: 7, b: 8).to_a]
  p [label, :positional_hash, klass.new({ a: 9, b: 10 }).to_a]
  p [label, :empty, klass.new.to_a]
  p [label, :copy, klass.dup.new(a: 11, b: 12).to_a]
end

value = normal.allocate
value.send(:initialize, b: 13)
p [:allocate, value.to_a]
p [:constructor_block, normal.new(a: 16, b: 17) { :unused }.to_a]
p [:bracket_constructor, normal[a: 18, b: 19].to_a]

def normal.keyword_init?
  false
end
p [:overridden_metadata, normal.new(a: 20, b: 21).to_a]

normal.class_eval do
  def initialize(a: nil, b: nil)
    super
  end
end
p [:replaced_initializer, normal.new(a: 14, b: 15).to_a]

begin
  normal.new(unrecognized: 1)
rescue ArgumentError => error
  p [:custom_argument_error, error.message]
end

begin
  Struct.new(:a, :b).new(unrecognized: 1)
rescue ArgumentError => error
  p [:native_argument_error, error.message]
end
