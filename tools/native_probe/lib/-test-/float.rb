# Probe adapter, not a replacement implementation of nextafter.
require 'native_probe'
NativeProbe.__load(ENV.fetch('MERE_NATIVE_PROBE_MODULE'))
module Bug
  class Float
    def self.system_nextafter(x, y)
      NativeProbe.__call('system_nextafter', x, y)
    end
    def self.missing_nextafter(x, y)
      NativeProbe.__call('missing_nextafter', x, y)
    end
  end
end
