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
