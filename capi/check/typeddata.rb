# Ruby's own ext/-test-/typeddata and exception/dataerror, with typed_fixture.c
# beside them (capi_check.py builds the three as one extension).
require 'typed_probe'
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
errors = Array.new(16) { Bug::Exception::DataError.new('message') }
collect
errors.each { |error| check('original dmark preserves native payload', error.__payload == '[Bug #9167] error') }
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
dynamic_garbage
collect
check('dynamic descriptor cleanup returned', true)
check('live owners remain usable', boxes.last.value == 'native-only-box-payload')

# A dmark that reads RARRAY_LEN / RARRAY_AREF and an internal ivar, run by a
# collection between C calls: it was "called with no call from the
# interpreter in progress" (sqlite3's database_mark, its aggregator pin).
# The child is held by C alone and marked when the ivar read says so.
# ...and an Array C handed to Ruby (empty when C read it), which Ruby
# fills between C calls; C then makes a child it holds alone, marked only
# when the dmark reads the gate's current length, not the copy C fetched.
readers = Array.new(8) { Bug::ReadingBox.new }
readers.each { |reader| reader.gate << true; reader.arm }
10.times { collect }
readers.each do |reader|
  check('a reading dmark keeps its array', reader.list == %w[item-0 item-1 item-2 item-3])
  check('a reading dmark keeps the ivar it reads', reader.held == ['held'])
  check('a reading dmark reads the ivar truly', reader.child == 'native-child')
  check('a reading dmark reads an Array as it is now', reader.gated_child == 'gated-child')
end
# A typed data object is DATA to ObjectSpace, and its struct is its type's
# wrap_struct_name (sqlite3's test_typed_data_struct_name reads this)
require 'objspace'
dumped = ObjectSpace.dump(Bug::NativeBox.new)
check('a typed data object dumps as DATA', dumped.include?('"type":"DATA"'))
check('a typed data object dumps its struct name', dumped.include?('"struct":"native_box"'))
check('a plain object is no DATA', ObjectSpace.dump(Object.new).include?('"type":"OBJECT"'))
# ...and count_objects makes nothing per C data object: what one call
# allocates is the same with 100 more of them alive
def count_objects_cost
  GC.disable
  ObjectSpace.count_objects
  before = GC.stat(:total_allocated_objects)
  ObjectSpace.count_objects
  GC.stat(:total_allocated_objects) - before
ensure
  GC.enable
end
few = count_objects_cost
held = Array.new(100) { Bug::NativeBox.new }
many = count_objects_cost
check('count_objects allocates nothing per C data object', many <= few)
check('the data objects are still there', held.size == 100)
puts "typeddata contracts: #{$checks} passed"
