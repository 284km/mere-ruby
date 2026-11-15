require 'native_probe'
def check(ok, label)
  raise label unless ok
end
def invalid(label)
  begin
    yield
  rescue ArgumentError
    return
  end
  raise "accepted #{label}"
end
baseline = NativeProbe.__count
values = [nil, false, true, 123, 2**90, 1.25, :symbol,
          'payload-' + 'x' * 200, [1, 'nested'], {a: 'hash'}, Object.new, -> { 42 }]
tokens = values.map { |v| NativeProbe.__retain(v) }
tokens.each_with_index { |t, i| NativeProbe.__c_store(i, t) }
GC.start
GC.start
tokens.each_with_index do |t, i|
  check(NativeProbe.__get(t).equal?(values[i]), "identity #{i}")
  check(NativeProbe.__c_get(i).equal?(values[i]), "C token identity #{i}")
end
check(NativeProbe.__get(tokens[-1]).call == 42, 'retained proc')
same1 = NativeProbe.__retain(values[7])
same2 = NativeProbe.__retain(values[7])
check(same1 != same2, 'two independent ownership claims')
NativeProbe.__release(same1)
GC.start
check(NativeProbe.__get(same2).equal?(values[7]), 'other owner retained')
NativeProbe.__release(same2)
old = tokens[7]
cap = NativeProbe.__capacity
NativeProbe.__release(old)
replacement = NativeProbe.__retain('replacement')
check(replacement != old && NativeProbe.__capacity == cap, 'slot reuse without token reuse')
invalid('old token') { NativeProbe.__get(old) }
invalid('C retained stale token') { NativeProbe.__c_get(7) }
invalid('double release') { NativeProbe.__release(old) }
invalid('stale update') { NativeProbe.__update(old, 'bad') }
check(NativeProbe.__get(replacement) == 'replacement', 'replacement survived stale operations')
NativeProbe.__update(replacement, values[10])
GC.start
check(NativeProbe.__get(replacement).equal?(values[10]), 'updated root')
[0, -1, 2**31, 2**32 + tokens[0], 2**90, 1.5, nil, '1'].each do |bad|
  invalid('invalid id') { NativeProbe.__get(bad) }
  invalid('invalid release') { NativeProbe.__release(bad) }
  invalid('invalid C storage') { NativeProbe.__c_store(0, bad) }
end
check(NativeProbe.__c_get(0).nil?, 'invalid C writes preserved slot')
tokens.each_with_index do |t, i|
  NativeProbe.__release(t) unless t == old
  NativeProbe.__c_forget(i)
end
NativeProbe.__release(replacement)
check(NativeProbe.__count == baseline, 'all roots released')
puts 'mixed values, identity, independent owners, stale ids, update, C transport: passed'

# None of these objects has appeared in a Ruby local before collection.
def seed_many
  (0...96).map { |i| NativeProbe.__seed_handle(i % 3) }
end
kept = seed_many
GC.start
GC.start
GC.start
kept.each_with_index do |t, i|
  obj = NativeProbe.__get(t)
  case i % 3
  when 0
    check(obj == 'native-seed-' + 'x' * 4096, 'native-only string')
  when 1
    check(obj[0] == 'native-cycle' && obj[1].equal?(obj), 'native-only cycle')
  when 2
    check(obj.instance_variable_get(:@payload) == 'native-object-' + 'y' * 4096, 'native-only object graph')
  end
end
kept.each { |t| NativeProbe.__release(t) }
check(NativeProbe.__count == baseline, 'native-only roots released')
puts '96 native-only strings/cycles/object graphs across GC: passed'

cap = NativeProbe.__capacity
2000.times do |i|
  t = NativeProbe.__retain(i)
  check(NativeProbe.__get(t) == i, 'churn content')
  NativeProbe.__release(t)
end
GC.start
check(NativeProbe.__count == baseline && NativeProbe.__capacity == cap, 'bounded slot storage')
puts '2000 retain/release cycles: slot capacity unchanged'
