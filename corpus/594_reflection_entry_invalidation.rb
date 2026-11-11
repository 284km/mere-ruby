def reflect(object)
  object.method(:value).unbind
end
plain = Class.new { def value; :plain; end }.new
p reflect(plain).bind(plain).call

hidden = Class.new do
  def value; :hidden; end
  private :method
end.new
p hidden.send(:method, :value).unbind.bind(hidden).call
p reflect(plain).bind(plain).call

custom_result = Object.new
def custom_result.unbind
  :custom_unbind
end
custom = Class.new do
  def value; :custom_value; end
end.new
custom.define_singleton_method(:method) { |name| custom_result }
p reflect(custom)

module ReflectedUnbind
  refine Method do
    def unbind
      :refined_unbind
    end
  end
end
class ReflectedUnbindCaller
  using ReflectedUnbind
  def self.call(object)
    object.method(:value).unbind
  end
end
p ReflectedUnbindCaller.call(plain)

Method.send(:protected, :unbind)
begin
  p plain.method(:value).send(:unbind).bind(plain).call
ensure
  Method.send(:public, :unbind)
end
