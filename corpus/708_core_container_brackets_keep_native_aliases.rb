# A saved native constructor bypasses an override exactly once.
class PlainAliasSubclass < Hash
  class << self; alias saved_subclass_bracket []; end
end
class << Hash
  alias saved_review_bracket []
  def [](*args); [:hash_override, args]; end
end
p Hash.saved_review_bracket(:key, 1)
p Hash[:key, 2]
class << Array
  alias saved_review_bracket []
  def [](*args); [:array_override, args]; end
end
p Array.saved_review_bracket(3, 4)
p Array[5, 6]
class << Hash
  def [](*args); saved_review_bracket(*args).merge(:wrapped => true); end
end
p Hash[:key, 7]
begin
  Hash.saved_review_bracket(:odd)
rescue ArgumentError => error
  p [:native_arity, error.class]
end
p Hash[:after_error, 8]
class AliasCallbackHash < Hash
  def self.[](*args); [:callback, args]; end
end
class AliasConversion
  def to_hash; {:converted => AliasCallbackHash[:key, 9]}; end
end
p Hash.saved_review_bracket(AliasConversion.new)
p PlainAliasSubclass.saved_subclass_bracket(AliasConversion.new)
p Hash[:after_callback, 10]
