require 'rbconfig'
require 'tmpdir'

Dir.mktmpdir('native-mixin-1025-') do |dir|
  source = File.join(dir, 'native_mixin_1025.c')
  library = File.join(dir, "native_mixin_1025.#{RbConfig::CONFIG.fetch('DLEXT')}")
  File.write(source, <<~C)
    #include "ruby.h"
    static VALUE insert(VALUE self, VALUE target, VALUE module, VALUE operation) {
      (void)self;
      int op = NUM2INT(operation);
      if (op == 0) rb_include_module(target, module);
      else if (op == 1) rb_prepend_module(target, module);
      else rb_extend_object(target, module);
      return target;
    }
    void Init_native_mixin_1025(void) {
      rb_define_global_function("native_mixin_insert_1025", insert, 3);
    }
  C
  link = RUBY_PLATFORM.include?('darwin') ? ['-bundle', '-undefined', 'dynamic_lookup'] : ['-shared']
  headers = RbConfig::CONFIG.values_at('rubyhdrdir', 'rubyarchhdrdir').compact
  command = [RbConfig::CONFIG.fetch('CC'), '-fPIC', *link, *headers.flat_map { |path| ['-I', path] }, source, '-o', library]
  raise 'native fixture build failed' unless system(*command, out: File::NULL, err: File::NULL)
  require library

  [Module, Class.new(Module)].each do |kind|
    3.times do |operation|
      mod = kind.new
      mod.module_eval { def native_value = 42 }
      [:append_features, :included, :prepend_features, :prepended, :extend_object, :extended].each do |hook|
        mod.define_singleton_method(hook) { |*args| raise 'Ruby hook called' }
      end
      target = operation == 2 ? Object.new : Class.new
      [:include, :prepend, :extend, :singleton_class].each do |name|
        target.define_singleton_method(name) { |*args| raise 'Ruby override called' }
      end
      p [operation, native_mixin_insert_1025(target, mod, operation).equal?(target), (operation == 2 ? target : target.new).native_value]
    end
  end
  3.times do |operation|
    target = operation == 2 ? Object.new.freeze : Class.new.freeze
    begin
      native_mixin_insert_1025(target, Module.new, operation)
    rescue FrozenError => error
      p [operation, error.class]
    end
  end
end
