# Included/extended methods follow the native entry; prepend precedes it.
class NativeFirstAliasHash < Hash
  class << self; alias saved_native_bracket []; end
end
module LaterHashBrackets
  def [](*args); [:late_hash, args]; end
end
module LaterArrayBrackets
  def [](*args); [:late_array, args]; end
end
Hash.extend(LaterHashBrackets)
Array.singleton_class.include(LaterArrayBrackets)
p Hash[:key, 1]
p Array[2, 3]
class NativeFirstHash < Hash; end
class NativeFirstArray < Array; end
p NativeFirstHash[:key, 4]
p NativeFirstArray[5, 6]
class NativeAliasCallback < Hash
  def self.[](*args); [:callback, args]; end
end
class NativeFirstConversion
  def to_hash; {:converted => NativeAliasCallback[:key, 6]}; end
end
p NativeFirstAliasHash.saved_native_bracket(NativeFirstConversion.new)
module EarlierHashBrackets
  def [](*args); super.merge(:prepended => true); end
end
module EarlierArrayBrackets
  def [](*args); super + [:prepended]; end
end
Hash.singleton_class.prepend(EarlierHashBrackets)
Array.singleton_class.prepend(EarlierArrayBrackets)
p Hash[:key, 7]
p Array[8, 9]
p NativeFirstHash[:key, 10]
p NativeFirstArray[11, 12]
class OwnBracketHash < NativeFirstHash
  def self.[](*args); [:own_hash, args]; end
end
p OwnBracketHash[:key, 13]
