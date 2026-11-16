require '-test-/float'
$count = 0
def check(value)
  raise 'numeric conversion failed' unless value
  $count += 1
end
def raises(kind)
  begin
    yield
  rescue kind => e
    $count += 1
    return e
  end
  raise "expected #{kind}"
end
check(Bug::Float.system_nextafter(1, 2) == 1.0.next_float)
check(Bug::Float.system_nextafter(2**100, Float::INFINITY) == (2**100).to_f.next_float)
check(Bug::Float.system_nextafter(Rational(1, 2), 1) == 0.5.next_float)
obj = Object.new
def obj.to_f
  GC.start
  Bug::Float.system_nextafter(2, 3)
  1.0
end
check(Bug::Float.system_nextafter(obj, 2) == 1.0.next_float)
raises(TypeError) { Bug::Float.system_nextafter('1', 2) }
raises(TypeError) { Bug::Float.system_nextafter(nil, 2) }
raises(TypeError) { Bug::Float.system_nextafter(true, 2) }
raises(TypeError) { Bug::Float.system_nextafter(Object.new, 2) }
def obj.to_f; 1; end
raises(TypeError) { Bug::Float.system_nextafter(obj, 2) }
error = RuntimeError.new('conversion')
obj.define_singleton_method(:to_f) { raise error }
check(raises(RuntimeError) { Bug::Float.system_nextafter(obj, 2) }.equal?(error))
check(1.0 / Bug::Float.system_nextafter(0.0, -0.0) == -Float::INFINITY)
check(Bug::Float.system_nextafter(Float::NAN, 1.0).nan?)
puts "native numeric contracts: #{$count} passed"
