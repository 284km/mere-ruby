require 'native_probe'
def stash
  s = 'native-only-' + 'payload' * 41
  NativeProbe.__hold(s)
  s.object_id
end
id = stash
3.times { GC.start }
s = NativeProbe.__fetch
raise 'native root lost identity' unless s.object_id == id
raise 'native root lost contents' unless s == 'native-only-' + 'payload' * 41
puts 'native-root string: preserved'
NativeProbe.__clear
raise 'root not released' unless NativeProbe.__fetch.nil?
puts 'native-root release: empty'
def stash_graph
  a = ['nested-' + 'payload' * 31]
  a << a
  NativeProbe.__hold(a)
  a.object_id
end
id = stash_graph
3.times { GC.start }
a = NativeProbe.__fetch
raise 'graph identity lost' unless a.object_id == id && a[1].equal?(a)
raise 'nested string lost' unless a[0] == 'nested-' + 'payload' * 31
puts 'native-root cyclic graph: preserved'
NativeProbe.__clear
