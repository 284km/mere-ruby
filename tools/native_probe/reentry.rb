require 'native_probe'
baseline = NativeProbe.__count
bias = 7
result = NativeProbe.__callback(->(x) { x + bias }, 35)
raise 'bad callback result' unless result == 42 && NativeProbe.__phase == 2
puts 'Ruby -> C -> Ruby closure: 42; C cleanup completed'
result = NativeProbe.__callback(->(x) { GC.start; x + 1 }, 41)
raise 'GC in callback failed' unless result == 42 && NativeProbe.__phase == 2
puts 'GC during callback: returned'
expected = RuntimeError.new('callback error')
begin
  NativeProbe.__callback(->(x) { raise expected }, 0)
  raise 'callback exception swallowed'
rescue RuntimeError => actual
  raise 'exception identity lost' unless actual.equal?(expected)
  raise 'native cleanup bypassed' unless NativeProbe.__phase == 2
  raise 'C resource was not released on exception' unless NativeProbe.__resources == 0
end
puts 'callback exception: same object; C cleanup completed'
result = NativeProbe.__callback(->(x) { -1 }, 0)
raise 'negative return confused with exception' unless result == -1
puts 'negative callback result: preserved'
result = NativeProbe.__callback(->(x) {
  NativeProbe.__callback(->(y) { y + 1 }, x) + 1
}, 40)
raise 'nested native reentry failed' unless result == 42 && NativeProbe.__phase == 2
puts 'nested Ruby/C reentry: preserved'
result = NativeProbe.__callback(->(x) {
  begin
    raise 'handled inside callback'
  rescue RuntimeError
    x
  end
}, 42)
raise 'handled Ruby exception escaped' unless result == 42 && NativeProbe.__phase == 2
puts 'internally rescued exception: normal return'
raise 'C resources leaked' unless NativeProbe.__resources == 0
puts 'C allocated resources: all released'
raise 'callback roots leaked' unless NativeProbe.__count == baseline
# A native-only root remains live while nested callbacks collect and unwind.
kept = NativeProbe.__seed_handle(0)
expected = RuntimeError.new('nested callback error')
begin
  NativeProbe.__callback(->(x) {
    NativeProbe.__callback(->(y) { GC.start; raise expected }, x)
  }, 0)
  raise 'nested exception swallowed'
rescue RuntimeError => actual
  raise 'nested exception identity lost' unless actual.equal?(expected)
end
GC.start
raise 'unrelated root lost' unless NativeProbe.__get(kept) == 'native-seed-' + 'x' * 4096
raise 'exception roots leaked' unless NativeProbe.__count == baseline + 1
NativeProbe.__release(kept)
raise 'remaining roots/resources' unless NativeProbe.__count == baseline && NativeProbe.__resources == 0
puts 'nested exception and GC: identity preserved, callback roots released'
