require 'native_probe'
NativeProbe.__typed_load(ENV.fetch('MERE_NATIVE_TYPED_MODULE'))
module Bug
  class TypedData
    def self.allocate
      NativeProbe.__typed_call('Bug::TypedData.allocate', nil, nil)
    end
    def self.new
      allocate
    end
    def self.check(object)
      NativeProbe.__typed_call('Bug::TypedData.check', nil, object)
    end
    def self.make(count)
      NativeProbe.__typed_call('Bug::TypedData.make', nil, count)
    end
    def self.dynamic_type
      NativeProbe.__typed_call('Bug::TypedData.dynamic_type', nil, nil)
    end
  end
  class NativeBox
    def self.new
      NativeProbe.__typed_call('Bug::NativeBox.allocate', nil, nil)
    end
    def value
      NativeProbe.__typed_call('Bug::NativeBox.value', self, nil)
    end
    def value=(value)
      NativeProbe.__typed_call('Bug::NativeBox.value=', self, value)
    end
    def value_after_gc
      NativeProbe.__typed_call('Bug::NativeBox.value_after_gc', self, nil)
    end
    def self.duplicate_frees
      NativeProbe.__typed_call('Bug::NativeBox.duplicate_frees', nil, nil)
    end
    def self.freed
      NativeProbe.__typed_call('Bug::NativeBox.freed', nil, nil)
    end
  end
  module Exception
    class DataError < StandardError
      def __payload
        NativeProbe.__typed_call('Bug::Exception::DataError.__payload', self, nil)
      end
      def self.new(*args)
        object = NativeProbe.__typed_call('Bug::Exception::DataError.allocate', nil, nil)
        object.send(:initialize, *args)
        object
      end
    end
  end
end
