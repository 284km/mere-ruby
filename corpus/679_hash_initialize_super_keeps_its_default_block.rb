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
