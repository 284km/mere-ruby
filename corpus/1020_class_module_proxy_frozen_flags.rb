require 'rbconfig'
require 'tmpdir'

Dir.mktmpdir('proxy-frozen-1020-') do |dir|
  source = File.join(dir, 'proxy_frozen_1020.c')
  library = File.join(dir, "proxy_frozen_1020.#{RbConfig::CONFIG.fetch('DLEXT')}")
  File.write(source, <<~C)
    #include "ruby.h"
    static VALUE flags(VALUE self, VALUE owner) {
      (void)self;
      return rb_ary_new_from_args(2, rb_obj_frozen_p(owner), RB_OBJ_FROZEN(owner) ? Qtrue : Qfalse);
    }
    void Init_proxy_frozen_1020(void) {
      rb_define_global_function("proxy_frozen_flags_1020", flags, 1);
    }
  C
  link = RUBY_PLATFORM.include?('darwin') ? ['-bundle', '-undefined', 'dynamic_lookup'] : ['-shared']
  headers = RbConfig::CONFIG.values_at('rubyhdrdir', 'rubyarchhdrdir').compact
  command = [RbConfig::CONFIG.fetch('CC'), '-fPIC', *link, *headers.flat_map { |path| ['-I', path] }, source, '-o', library]
  raise 'native fixture build failed' unless system(*command, out: File::NULL, err: File::NULL)
  require library

  [Class.new, Module.new, Object.new, +'', [], {}, proc {}, binding].each do |owner|
    $frozen_flag_queries = 0
    owner.define_singleton_method(:frozen?) { $frozen_flag_queries += 1; false }
    p [owner.class.name, :before, proxy_frozen_flags_1020(owner), $frozen_flag_queries]
    owner.freeze
    p [owner.class.name, :after, proxy_frozen_flags_1020(owner), $frozen_flag_queries]
  end
  # Regexp singleton methods are a separate interpreter limitation.
  regexp = Regexp.new('a')
  p [:regexp, proxy_frozen_flags_1020(regexp)]
  regexp.freeze
  p [:regexp_frozen, proxy_frozen_flags_1020(regexp)]
end
