class FetchSuperHash < Hash
  def fetch(*args, &block)
    super
  end

  def fetch_values(*keys, &block)
    super
  end
end

def check_fetch_error(hash, *args, &block)
  begin
    p hash.fetch(*args, &block)
  rescue ArgumentError => error
    p [error.class, error.message]
  rescue KeyError => error
    p [error.class, error.message, error.key, error.receiver.equal?(hash)]
  end
end

h = FetchSuperHash.new(:unused)
h[:a] = 1
h[:nil] = nil
check_fetch_error(h)
check_fetch_error(h, :a, 2, 3)
check_fetch_error(h, :a, 2, 3) { :never }
check_fetch_error(h, :a)
check_fetch_error(h, :nil)
check_fetch_error(h, :missing)
check_fetch_error(h, :missing, :explicit)
check_fetch_error(h, :missing) { |key| [key, :block] }
check_fetch_error(h, :a) { raise 'a present key must not yield' }

module FetchWarningCapture
  def warn(message, **)
    $fetch_warnings << message.include?('block supersedes default value argument')
  end
end
Warning.singleton_class.prepend(FetchWarningCapture)
$fetch_warnings = []
verbose_before = $VERBOSE
$VERBOSE = true
check_fetch_error(h, :missing, :ignored) { |key| [key, :block_wins] }
p $fetch_warnings
$VERBOSE = verbose_before

p h.fetch_values
p h.fetch_values(:nil, :a, :a)
begin
  h.fetch_values(:a, :missing)
rescue KeyError => error
  p [error.class, error.message, error.key, error.receiver.equal?(h)]
end
p h.fetch_values(:a, :missing, :later) { |key| h[:later] = 7; [key, :block] }
p h.fetch_values(:missing, :after) { |key| break [:stopped, key] }

def fetch_values_return(hash)
  hash.fetch_values(:missing, :after) { return :returned }
  :did_not_return
end
p fetch_values_return(h)

class FetchOverrideTrap < FetchSuperHash
  def fetch(*)
    raise 'fetch_values must call the native fetch entry'
  end
end
trap = FetchOverrideTrap.new
trap[:a] = 3
p trap.fetch_values(:a)

module PrependFetch
  def fetch(*args, &block)
    [:outer, super]
  end
end

identity = FetchSuperHash.new.compare_by_identity
first = +'key'
second = +'key'
identity[first] = :found
p identity.fetch(first)
p identity.fetch(second, :absent)

class EquivalentFetchKey
  def hash = 17
  def eql?(other) = other.is_a?(EquivalentFetchKey)
  def inspect = 'equivalent-key'
end
keyed = FetchSuperHash.new
keyed[EquivalentFetchKey.new] = 42
p keyed.fetch(EquivalentFetchKey.new)
p keyed.fetch_values(EquivalentFetchKey.new)

FetchSuperHash.prepend(PrependFetch)
p h.fetch(:a)
