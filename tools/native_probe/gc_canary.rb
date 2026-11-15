require 'native_probe'
# The object never appears in a Ruby frame before collection. This avoids
# incidental retention in interpreter arguments masking a missing native root.
NativeProbe.__seed
GC.start
GC.start
GC.start
s = NativeProbe.__fetch
raise 'native-only string was swept' unless s == 'native-seed-' + 'x' * 4096
puts 'native-only root: preserved'
NativeProbe.__clear
raise 'native root remains registered' unless NativeProbe.__fetch.nil?
puts 'native-only root: unregistered'
