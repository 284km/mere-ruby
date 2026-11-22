# A bare new builds the native container, just like self.new.
class BareHashFactory < Hash
  def self.build; new; end
end
hash = BareHashFactory.build
hash[:key] = 1
p [hash.class, hash[:key], hash.size]
class BareArrayFactory < Array
  def self.build; new; end
end
array = BareArrayFactory.build
array << 2
p [array.class, array[0], array.size]
class InitializedHashFactory < Hash
  def self.build; new; end
  def initialize
    super
    self[:initialized] = true
    self[:block] = block_given?
  end
end
p InitializedHashFactory.build { :not_forwarded }
class PrivateHashFactory < Hash
  private_class_method :new
  def self.build; new; end
end
private_hash = PrivateHashFactory.build
private_hash[:private] = 3
p [private_hash.class, private_hash[:private]]
class OverriddenFactory < Hash
  def self.new; [:own_constructor]; end
  def self.build; new; end
end
p OverriddenFactory.build
class OrdinaryFactory
  def self.build; new; end
  def initialize; @value = 4; end
  attr_reader :value
end
p [OrdinaryFactory.build.class, OrdinaryFactory.build.value]
