require 'native_probe'
def seed_for_release
  (0...16).map { NativeProbe.__seed_handle(0) }
end
tokens = seed_for_release
token = tokens.first
GC.start
GC.start
GC.start
# Do not look up the Val before these collections: a transient interpreter
# stack copy from the observer would mask a missing native root.
NativeProbe.__watch(token)
raise 'registered string lost' unless NativeProbe.__watched_size == 4108
NativeProbe.__release(token)
GC.start
GC.start
GC.start
raise 'released root still retains native-only string' unless NativeProbe.__watched_size == 0
tokens.drop(1).each do |t|
  raise 'release damaged another root' unless NativeProbe.__get(t) == 'native-seed-' + 'x' * 4096
  NativeProbe.__release(t)
end
raise 'root table not empty' unless NativeProbe.__count == 0
puts 'registration preserves contents; release permits reclamation: passed'
