# A custom key's hash/eql? lookup must still distinguish a miss from stored nil.
class DefaultKey
  attr_reader :name
  def initialize(name); @name = name; end
  def hash; 17; end
  def eql?(other); other.is_a?(DefaultKey) && name == other.name; end
end
key = DefaultKey.new(:a)
equal_key = DefaultKey.new(:a)
missing = DefaultKey.new(:missing)
plain = Hash.new(:fallback)
plain[key] = nil
p [plain[equal_key], plain[missing], plain.size]
calls = []
memo = Hash.new { |hash, k| calls << k.name; hash[k] = [k.name] }
p [memo[key], memo[equal_key], memo[missing], calls, memo.size]
memo[equal_key] = nil
p [memo[key], calls]
class DefaultHash < Hash
  def default(key)
    [:override, key.name]
  end
end
p DefaultHash.new[missing]
begin
  Hash.new { raise 'from default' }[missing]
rescue => error
  p [error.class.name, error.message]
end
# Bundler::Resolver uses a Hash with Package keys and a default proc in this
# shape; reading a new Package used to return nil before the block ran.
class VersionCache
  def initialize
    @cache = Hash.new { |cache, package| cache[package] = versions(package).sort }
  end
  def versions(package)
    [package.name.to_s, 'version']
  end
  def for(package)
    @cache[package]
  end
end
p VersionCache.new.for(key)
