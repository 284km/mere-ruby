# A singleton's undef hides the primitive builtin, as well as Ruby methods.
hash = {}
p [hash.class, hash.respond_to?(:to_hash), {}.respond_to?(:to_hash)]
hash.singleton_class.send(:undef_method, :to_hash)
p [hash.class, hash.respond_to?(:to_hash), hash.respond_to?(:to_hash, true)]
p [hash.singleton_class.method_defined?(:to_hash), {}.respond_to?(:to_hash)]
[:literal, :send, :public_send, :literal_block, :send_block, :public_send_block].each do |kind|
  begin
    case kind
    when :literal then hash.to_hash
    when :send then hash.send(:to_hash)
    when :public_send then hash.public_send(:to_hash)
    when :literal_block then hash.to_hash { :unused }
    when :send_block then hash.send(:to_hash) { :unused }
    when :public_send_block then hash.public_send(:to_hash) { :unused }
    end
  rescue NoMethodError => error
    p [kind, error.name, error.args, error.receiver.equal?(hash), error.private_call?]
  end
end
asked = []
hash.define_singleton_method(:respond_to_missing?) do |name, include_all|
  asked << [name, include_all]
  name == :to_hash
end
hash.define_singleton_method(:method_missing) do |name, *args, &block|
  return super(name, *args, &block) unless name == :to_hash
  [name, args, block && block.call]
end
p [hash.respond_to?(:to_hash), hash.respond_to?(:to_hash, true), asked]
p hash.to_hash
p hash.to_hash(1) { :block }
begin
  hash.missing(2)
rescue NoMethodError => error
  p [error.name, error.args, error.receiver.equal?(hash)]
end
hash.define_singleton_method(:to_hash) { :redefined }
p [hash.to_hash, hash.respond_to?(:to_hash)]

[[[], :to_ary], ['text', :to_str], [proc {}, :call]].each do |object, name|
  object.singleton_class.send(:undef_method, name)
  p [object.class, object.respond_to?(name), object.respond_to?(name, true)]
  begin
    object.public_send(name) { :ignored }
  rescue NoMethodError => error
    p [error.name, error.receiver.equal?(object)]
  end
end

aliased = {}
class << aliased
  alias saved_to_hash to_hash
  undef to_hash
end
p [aliased.saved_to_hash.equal?(aliased), aliased.respond_to?(:saved_to_hash)]
