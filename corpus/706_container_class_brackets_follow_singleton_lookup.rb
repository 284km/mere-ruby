# Ruby singleton methods precede a container's inherited native constructor.
class BracketHash < Hash
  def self.[](*args); [:hash_override, args]; end
end
class BracketArray < Array
  def self.[](*args); [:array_override, args]; end
end
p BracketHash[:key, 1]
p BracketArray[1, 2]
class BracketChild < BracketHash; end
p BracketChild[:child, 2]
module BracketWrapper
  def [](*args); [:wrapped, super]; end
end
BracketChild.singleton_class.prepend(BracketWrapper)
p BracketChild[:child, 3]
class NativeBracketSuper < Hash
  def self.[](*args); super.merge(:wrapped => true); end
end
p NativeBracketSuper[:key, 4]
class SavedBracket < Hash
  class << self
    alias saved_bracket []
    def [](*args); [:current, args]; end
  end
end
p SavedBracket.saved_bracket(:saved, 5)
p SavedBracket[:current, 6]
class PrivateBracket < Hash
  def self.[](*args); [:private_bracket, args]; end
  private_class_method :[]
end
begin
  PrivateBracket[:hidden]
rescue NoMethodError => error
  p [:refused, error.name, error.receiver == PrivateBracket, error.message.start_with?("private method")]
end
p PrivateBracket.send(:[], :sent)
class MissingBracket < Hash
  def self.[](*args); [:unreachable, args]; end
  private_class_method :[]
  def self.method_missing(name, *args); [:missing, name, args]; end
end
p MissingBracket[:hidden]
p MissingBracket.public_send(:[], :hidden)
p Hash[:native, 7]
p Array[8, 9]
class BracketConversion
  def to_hash; {:converted => BracketHash[:callback]}; end
end
p NativeBracketSuper[BracketConversion.new]
class RemovedBracketParent < Hash
  def self.[](*args); [:removed, args]; end
  class << self; undef_method :[]; end
end
class RemovedBracketChild < RemovedBracketParent
  def self.[](*args); super; end
end
begin
  RemovedBracketChild[:hidden]
rescue NoMethodError => error
  p [:removed_super, error.name]
end
module CoreArrayBracketWrapper
  def [](*args); super + [:core_wrapped]; end
end
Array.singleton_class.prepend(CoreArrayBracketWrapper)
p Array[10, 11]
class BlockBracket < Hash
  def self.[](*args, &block); [args, block && block.call]; end
end
p BlockBracket[:key] { :block }
class RefinedBracket < Hash
  def self.[](*args); [:ordinary, args]; end
end
module BracketRefinement
  refine RefinedBracket.singleton_class do
    def [](*args); [:refined, args]; end
  end
end
using BracketRefinement
p RefinedBracket[:key]
