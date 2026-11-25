class ReflectHash1021 < Hash
  def method(name) = super
  def public_method(name) = super
end
class ReflectArray1021 < Array
  def method(name) = name == :length ? super : :custom
  def public_method(name) = super
end
class ReflectString1021 < String
  def method(name) = super
  def public_method(name) = super
end
[[ReflectHash1021[a: 1], :keys], [ReflectArray1021[1, 2], :length], [ReflectString1021.new('ab'), :upcase]].each do |object, name|
  p object.method(name).call
  p object.public_method(name).call
end
p ReflectArray1021.new.method(:custom)
class FrozenAliasArray1021 < Array
  alias_method :change, :map!
  def run = change { |v| v + 1 }
end
class FrozenDeleteHash1021 < Hash
  def delete(key, &block) = super
end
[FrozenAliasArray1021[1], FrozenDeleteHash1021[a: 1]].each do |object|
  object.freeze
  begin
    object.is_a?(Array) ? object.run : object.delete(:a) { :missing }
  rescue FrozenError => error
    p [error.class, error.message, error.receiver.equal?(object)]
  end
end
