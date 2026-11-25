require 'rbconfig'
require 'tmpdir'
Dir.mktmpdir('frozen-class-1020-') do |dir|
  source=File.join(dir,'frozen_probe.c'); library=File.join(dir,'frozen_probe.'+RbConfig::CONFIG.fetch('DLEXT'))
  File.write(source, <<~C)
    #include "ruby.h"
    static VALUE status(VALUE self, VALUE owner) {
      return rb_ary_new_from_args(3, rb_obj_frozen_p(owner), rb_funcall(owner, rb_intern("frozen?"), 0), RB_OBJ_FROZEN(owner) ? Qtrue : Qfalse);
    }
    void Init_frozen_probe(void) { rb_define_global_function("frozen_probe", status, 1); }
  C
  flags=RUBY_PLATFORM.include?('darwin') ? ['-bundle','-undefined','dynamic_lookup'] : ['-shared']
  hdr=RbConfig::CONFIG.values_at('rubyhdrdir','rubyarchhdrdir').compact.flat_map{|v| ['-I',v]}
  raise 'native fixture build failed' unless system(RbConfig::CONFIG.fetch('CC'),'-fPIC',*flags,*hdr,source,'-o',library)
  require library
  [Class, Module].each do |factory|
    owner = factory.new
    p [:before, frozen_probe(owner)]
    owner.freeze
    p [:after, frozen_probe(owner)]
  end
end
