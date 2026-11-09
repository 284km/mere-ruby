# Finalizers cannot install a nil pending exception over later primitives.
# A terminated Fiber and a batch avoid depending on any single conservative
# native root becoming unreachable at an exact instant.
$VERBOSE = nil
$delivered = []
class FailingFinalizer
  def call(id)
    $delivered << id
    Integer('not-an-integer')
  end
end
def register_finalizers
  100.times { ObjectSpace.define_finalizer(Object.new, FailingFinalizer.new) }
  nil
end
Fiber.new { register_finalizers }.resume
begin
  raise 'outer exception'
rescue RuntimeError => original
  30.times do
    GC.start
    break unless $delivered.empty?
  end
  raise 'pending exception replaced' unless $!.equal?(original)
  raise 'message changed' unless original.message == 'outer exception'
end
raise 'finalizers missing' if $delivered.empty?
raise 'duplicate finalizer' unless $delivered.uniq == $delivered
begin
  Integer('still-invalid')
rescue ArgumentError
  puts 'primitive rescued'
end
begin
  Object.new.missing_after_collection
rescue NoMethodError
  puts 'method rescued'
end
puts 'pending state preserved'
