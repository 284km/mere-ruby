methods = [
  Class.new { def answer; :anonymous_receiver; end }.new.method(:answer),
  'kept string'.method(:upcase),
  [2, 3, 5].method(:sum),
  {marker: true}.method(:keys),
  proc { :kept_proc }.method(:call)
]
8.times { GC.start }
p methods.map(&:call)
p [methods.first.owner.equal?(methods.first.receiver.class), methods.first.name]

original = methods.shift
def original.tag; :singleton; end
original.instance_variable_set(:@marker, :public_ivar)
copies = [original.dup, original.clone]
original = methods = nil
8.times { GC.start }
p copies.map { |method| [method.call, method.tag, method.instance_variable_get(:@marker)] }
p copies.first.instance_variables

parent = Class.new { def answer; :parent; end }
child = Class.new(parent) { def answer; :child; end }
method = child.new.method(:answer)
above = method.super_method
unbound = method.unbind
method = child = parent = nil
8.times { GC.start }
p [above.call, unbound.bind(above.receiver).call]
copies = [above, above.dup, above.clone]
above = nil
8.times { GC.start }
p copies.map { |item| [item.call, item.name, item.receiver.class.equal?(unbound.owner)] }
