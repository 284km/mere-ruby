require 'native_probe'
NativeProbe.__native_load(ENV.fetch('MERE_NATIVE_ENSURED_MODULE'))
module Bug
  module Exception
    def self.ensured(object)
      NativeProbe.__native_call('ensured', [object], nil)
    end
    def self.ensure_raise(object, exception, &block)
      NativeProbe.__native_call('ensure_raise', [object, exception], block)
    end
  end
end
