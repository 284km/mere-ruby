class QueryParams < Hash
  def initialize(*)
    super() { |hash, key| hash[key.to_s] if key.is_a?(Symbol) }
  end
end
params = QueryParams.new
params['foo'] = 'bar'
p [params[:foo], params.default_proc.class, params.to_h[:foo]]

class ForwardedHash < Hash
  def initialize(*args, **keywords, &block)
    super(*args, **keywords, &block)
  end
end
callback = proc { |hash, key| [hash.class, key] }
hash = ForwardedHash.new(&callback)
p [hash[:missing], hash.default_proc.equal?(callback), hash.default]

class ImplicitHash < Hash
  def initialize
    1.times { :unrelated }
    super
  end
end
class ImplicitParenHash < Hash
  attr_reader :incoming
  def initialize(&block)
    @incoming = block
    super()
  end
end
class ImplicitRelayHash < ImplicitHash
  def initialize
    super
  end
end
[ImplicitHash, ImplicitParenHash, ImplicitRelayHash].each do |type|
  captured = type.new(&callback)
  p [captured.default_proc.equal?(callback), captured[:key]]
  begin
    type.new(&->(one) { one })
  rescue => error
    p [error.class, error.message]
  end
end
literal = ImplicitParenHash.new { |object, key| key }
p [literal.default_proc.equal?(literal.incoming), literal[:literal]]
class ReplacedBlockHash < Hash
  def initialize
    super() { :replacement }
  end
end
p ReplacedBlockHash.new(&callback)[:key]
class DroppedBlockHash < Hash
  def initialize
    super(&nil)
  end
end
p DroppedBlockHash.new(&callback).default_proc

def capture_yield_context(&block)
  block.call(1)
end
def wrap_yield_context
  capture_yield_context { |value| yield(value + 1) }
end
p wrap_yield_context { |value| value * 2 }
def wrap_yield_result
  capture_yield_context { |value| [:wrapper, yield(value)] }
end
p wrap_yield_result { |value| [:yielded, value] }
class YieldingReplacementHash < Hash
  def initialize
    super() { |object, key| [:replacement, yield(key)] }
  end
end
p YieldingReplacementHash.new { |key| [:yielded, key] }[:key]
hash[:present] = :value
hash.send(:initialize) { |object, key| [object.class, key.to_s] }
p [hash[:present], hash[:missing]]

strict = ->(object, key) { [object.class, key] }
strict_hash = ForwardedHash.new(capacity: 10, &strict)
p [strict_hash[:key], strict_hash.default_proc.equal?(strict)]
p ForwardedHash.new(&->(*args) { args.last })[:variable]
[-> {}, ->(one) {}, ->(one, two, three) {}].each do |invalid|
  begin
    ForwardedHash.new(&invalid)
  rescue => error
    p [error.class, error.message]
  end
end

begin
  ForwardedHash.new(:default) { |hash, key| :unused }
rescue => error
  p [error.class, error.message]
end
begin
  hash.freeze.send(:initialize) { |object, key| :unused }
rescue => error
  p [error.class, error.respond_to?(:receiver) && error.receiver.equal?(hash)]
end
