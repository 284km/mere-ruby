owner = Class.new { def original; :original; end }
receiver = owner.new
bound = receiver.method(:original)
unbound = bound.unbind
fields = {bound => :@__m_name, unbound => :@__um_name}
fields.each do |method, field|
  p [method.instance_variable_get(field), method.instance_variable_defined?(field)]
  method.instance_variable_set(field, 'user data')
  p [method.name, method.instance_variables, method.instance_variable_get(field)]
end
held = bound.unbind
copy = unbound.dup
owner.class_eval { def original; :replacement; end }
bound = nil
unbound = nil
GC.start
p [held.name, held.bind(receiver).call, copy.bind(receiver).call,
   receiver.method(:original).call]
begin
  held.instance_variable_get(:'@~um_name')
rescue NameError
  puts :invalid_variable_name
end
