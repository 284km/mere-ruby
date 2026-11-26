# Generic forwarding keeps arguments in the owning frame until a callee
# needs a Ruby rest Array. GC must follow escaped forwarding closures.
def forwarding_sink(*args, **kwargs, &block)
  [args, kwargs, block && block.call(:yielded)]
end
def forwarding_once(...) = forwarding_sink(...)
def forwarding_twice(...) = forwarding_once(...)
def forwarding_prefix(first, ...) = forwarding_sink(:prefix, first, ...)
p forwarding_once
p forwarding_twice(1, 2, a: 3) { |value| value }
p forwarding_prefix(4, 5, b: 6) { |value| [value] }
class ForwardingParent
  def call(*args, **kwargs, &block) = [args, kwargs, block && block.call]
end
class ForwardingChild < ForwardingParent
  def call(...) = super
end
p ForwardingChild.new.call(7, c: 8) { :parent }
def capture_forwarded(...)
  -> { GC.start; forwarding_sink(...) }
end
kept = capture_forwarded('retained', {position: true}, d: 'keyword') { :kept_block }
GC.start
p kept.call
p kept.call
# A later invocation must not overwrite an escaped packet's arguments.
other = capture_forwarded('other', e: 9)
GC.start
p other.call
p kept.call
# Values constructed by the evaluator can be forwarded by a VM caller.
eval('def evaluator_forwarding(...) = forwarding_sink(...)')
p evaluator_forwarding(10, f: 11) { :crossed }
# The private packet must not become a visible Ruby local.
def forwarding_locals(...)
  [binding.local_variables, binding.local_variable_defined?(:__fwd)]
end
p forwarding_locals(12)
# No input Array is mutated when the target materializes its named rest.
def mutating_sink(*args)
  args << :changed
end
def mutating_forward(...) = mutating_sink(...)
input = [13, 14]
p [mutating_forward(*input), input]
# Count only the real calls, after setup and before any result Array.
def forwarding_empty(...) = nil
$forwarding_counts = {}
GC.start
GC.disable
ObjectSpace.count_objects($forwarding_counts)
before = $forwarding_counts[:T_ARRAY]
forwarding_empty(1, 2, 3)
ObjectSpace.count_objects($forwarding_counts)
p [:forwarded_arrays, $forwarding_counts[:T_ARRAY] - before]
GC.enable

# Ruby locals and Binding writes cannot replace the internal forwarding data.
def forwarding_user_local(...)
  __fwd = :user
  [__fwd, forwarding_sink(...)]
end
p forwarding_user_local(15, g: 16)
def forwarding_binding_write(...)
  binding.local_variable_set(:__fwd, :injected)
  forwarding_sink(...)
end
p forwarding_binding_write(17, h: 18)
def forwarding_private_get(...)
  binding.local_variable_get(:__fwd)
rescue NameError => error
  error.class
end
p forwarding_private_get(19)

# A real rest parameter named __fwd remains a normal, visible Ruby Array.
def named_forwarding_local(*__fwd) = __fwd
p named_forwarding_local(20, 21)
p method(:named_forwarding_local).parameters
p method(:forwarding_once).parameters

fiber = Fiber.new { kept.call }
GC.start
p fiber.resume
p [:large_forward, forwarding_once(*Array.new(10_000, 1)).first.length]
def raising_forwarding_sink(*) = raise('forwarding failure')
def raising_forwarding(...) = raising_forwarding_sink(...)
begin
  raising_forwarding('temporary', i: 22)
rescue RuntimeError => error
  p [:forwarded_error, error.class, error.message]
end
GC.start
p kept.call
