require 'rbconfig'
require 'tmpdir'

# Exercise the native constant cache used by io-console, without depending on
# an externally installed gem. Build separately against each runtime's headers.
Dir.mktmpdir('hidden-constant-1018-') do |dir|
  source = File.join(dir, 'hidden_constant_1018.c')
  library = File.join(dir, "hidden_constant_1018.#{RbConfig::CONFIG['DLEXT']}")
  File.write(source, <<~C)
    #include "ruby.h"
    static VALUE cache(VALUE self, VALUE owner, VALUE operation, VALUE value) {
      ID id = rb_intern("console");
      switch (NUM2INT(operation)) {
        case 0: rb_const_set(owner, id, value); return value;
        case 1: return rb_const_get(owner, id);
        case 2: return rb_const_get_at(owner, id);
        case 3: return rb_const_get_from(owner, id);
        case 4: return rb_const_defined(owner, id) ? Qtrue : Qfalse;
        case 5: return rb_const_defined_at(owner, id) ? Qtrue : Qfalse;
        case 6: return rb_const_defined_from(owner, id) ? Qtrue : Qfalse;
        case 7: return rb_const_remove(owner, id);
        default: rb_raise(rb_eArgError, "unknown operation");
      }
    }
    void Init_hidden_constant_1018(void) {
      VALUE mod = rb_define_module("HiddenConstant1018");
      rb_define_singleton_method(mod, "cache", cache, 3);
    }
  C
  flags = RUBY_PLATFORM.include?('darwin') ? ['-bundle', '-undefined', 'dynamic_lookup'] : ['-shared']
  headers = RbConfig::CONFIG.values_at('rubyhdrdir', 'rubyarchhdrdir').compact
  command = [RbConfig::CONFIG.fetch('CC'), '-fPIC', *flags, *headers.flat_map { |path| ['-I', path] }, source, '-o', library]
  raise 'native fixture build failed' unless system(*command, out: File::NULL, err: File::NULL)
  require library

  parent = Class.new
  child = Class.new(parent)
  api = HiddenConstant1018
  p api.cache(parent, 4, nil)
  p api.cache(parent, 0, false)
  p [1, 2, 3, 4, 5, 6].map { |operation| api.cache(parent, operation, nil) }
  p [1, 3, 4, 5, 6].map { |operation| api.cache(child, operation, nil) }
  p parent.constants(false).include?(:console)
  begin
    parent.const_get(:console)
  rescue NameError
    p :ruby_lookup_rejected
  end
  p api.cache(child, 0, nil)
  p [api.cache(child, 5, nil), api.cache(child, 7, nil), api.cache(child, 5, nil)]
  p api.cache(parent, 7, nil)
  p api.cache(parent, 4, nil)
end
