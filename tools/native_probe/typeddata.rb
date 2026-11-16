require '-test-/typeddata'
$checks = 0
def check(name, condition)
  raise name unless condition
  $checks += 1
end
class Bug::NativeBox
  def ruby_gc
    GC.start
    GC.start
  end
end

def collect
  3.times { GC.start }
end
native = defined?(NativeProbe)
errors = Array.new(16) { Bug::Exception::DataError.new('message') }
collect
begin
  errors.each { |error| check('original dmark preserves native payload', error.__payload == '[Bug #9167] error') }
rescue ArgumentError
  # The negative control returns an expired C VALUE. Its error path must also
  # release the invocation's temporary roots before propagating the failure.
  raise 'expired result leaked temporary roots' if native && NativeProbe.__typed_stat(11) != 0
  raise
end
# New payloads originate in C and have never been returned to Ruby.
boxes = Array.new(48) { Bug::NativeBox.new }
collect
boxes.each { |box| check('native-only payload survives mark', box.value == 'native-only-box-payload') }
box = boxes.first
check('GC during C reentry', box.value_after_gc == 'native-only-box-payload')

# Both C edges and ordinary Ruby edges must participate in the same fixpoint.
root = Bug::NativeBox.new
middle = Bug::NativeBox.new
leaf = {'payload' => ['kept-' * 300]}
root.value = middle
middle.value = leaf
leaf = nil
middle = nil
collect
check('transitive C and Ruby graph', root.value.value['payload'] == ['kept-' * 300])
root.value = root
collect
check('reachable native cycle', root.value.equal?(root))

value = Object.new
box.value = value
collect
check('identity through C payload', box.value.equal?(value))
[nil, false, 42].each do |v|
  box.value = v
  collect
  check('immediate VALUE through C payload', box.value.equal?(v))
end

check('typed check identity', Bug::TypedData.check(Bug::TypedData.new).is_a?(Bug::TypedData))
begin
  Bug::TypedData.check(box)
  raise 'wrong descriptor accepted'
rescue TypeError
  check('wrong descriptor rejected', true)
end

# Leave allocation frames before collecting, so their locals are not roots.
def make_garbage(n)
  n.times do
    a = Bug::NativeBox.new
    b = Bug::NativeBox.new
    a.value = b
    b.value = a
  end
  nil
end
collect
before = Bug::NativeBox.freed
make_garbage(30)
collect
# Conservative stack scanning may delay a subset of these objects. Require
# actual reclamation, and check unique allocation generations for double free.
released = Bug::NativeBox.freed - before
check('unreachable C cycles are reclaimed', released > 0 && released <= 60)
collect
check('repeated GC never frees a generation twice', Bug::NativeBox.duplicate_frees == 0)
check('free count bounded by discarded owners', Bug::NativeBox.freed <= before + 60)

# Exercise the original dynamically allocated type: dfree frees the descriptor.
def dynamic_garbage
  100.times { Bug::TypedData.dynamic_type }
  100.times { Bug::TypedData.new }
  nil
end
before_native = native ? NativeProbe.__typed_stat(1) : 0
dynamic_garbage
collect
check('dynamic descriptor cleanup returned', true)
if native
  check('original dfree callbacks ran', NativeProbe.__typed_stat(1) > before_native)
  check('active typed roots released', NativeProbe.__typed_stat(11) == 0)
  check('no stale dmark tokens', NativeProbe.__typed_stat(13) == 0)
  check('C and Ruby owner counts agree', NativeProbe.__typed_stat(0) == NativeProbe.__typed_stat(12))
end
check('live owners remain usable', boxes.last.value == 'native-only-box-payload')
puts "typeddata contracts: #{$checks} passed"
