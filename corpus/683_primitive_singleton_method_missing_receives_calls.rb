hash = {value: :result}
def hash.method_missing(name, *arguments, **keywords, &block)
  return super unless name == :value
  [self[name], arguments, keywords, block && block.call]
end
p hash.value
p hash.value(1, flag: true) { :block }
p hash.send(:value, 2) { :sent }
p hash.public_send(:value, 3, flag: :public) { :public_block }
p hash.respond_to?(:value)
def hash.respond_to_missing?(name, all)
  name == :value || super
end
p [hash.respond_to?(:value), hash.respond_to?(:value, true)]
p hash.keys
p hash.to_hash.equal?(hash)
hash.define_singleton_method(:real) { :defined }
hash.singleton_class.send(:private, :real)
p hash.send(:real)

# A private existing method still reaches the visibility refusal path.
begin
  hash.public_send(:real)
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(hash)]
end

[[1], 'text', proc {}].each do |object|
  def object.method_missing(name, *args, **kwargs, &block)
    [self.class, name, args, kwargs, block && block.call]
  end
  p object.missing(1, key: 2) { :block }
  p object.send(:missing, 3) { :sent }
  p object.public_send(:missing, key: 4)
end

# The hook can call super, and removing it restores ordinary missing lookup.
begin
  hash.unknown(1)
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(hash), error.args]
end
hash.singleton_class.send(:remove_method, :method_missing)
begin
  hash.value
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(hash)]
end
p({}.respond_to?(:value))

# A real lexical refinement still wins before the singleton's missing hook.
module PrimitiveHookRefinements
  refine Hash do
    def answer(value, flag: false)
      [:refined, self.class, value, flag]
    end
  end
  refine Array do
    def answer(value, flag: false)
      [:refined, self.class, value, flag]
    end
  end
  refine String do
    def answer(value, flag: false)
      [:refined, self.class, value, flag]
    end
  end
  refine Proc do
    def answer(value, flag: false)
      [:refined, self.class, value, flag]
    end
  end
end
using PrimitiveHookRefinements
[{}, [], 'text', proc {}].each do |object|
  def object.method_missing(name, *arguments)
    [:missing, name, arguments]
  end
  p object.answer(:ordinary)
  p object.answer(:with_keyword, flag: true)
  p object.send(:answer, :sent)
  p object.public_send(:answer, :public)
  p object.unhandled(:missing)
end
