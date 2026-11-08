# Opt-in configuration for source-built native probes on macOS.
# This describes the prototype headers and linker, not a CRuby installation.
require 'rbconfig'
raise 'native probe builds currently require macOS' unless RUBY_PLATFORM.include?('darwin')
root = File.expand_path('../..', __dir__)
headers = File.join(__dir__, 'include')
target = nil
if ENV['MERE_NATIVE_CONFIG_DIR']
  require 'json'
  directory = File.expand_path(ENV.fetch('MERE_NATIVE_CONFIG_DIR'))
  target = JSON.parse(File.read(File.join(directory, 'config.json')))
  raise 'unsupported native configuration schema' unless target.fetch('schema') == 1
  headers = File.join(directory, 'include')
  raise 'native target headers missing' unless File.file?(File.join(headers, 'ruby/target_sizes.h'))
end
config = {
  'prefix' => root, 'exec_prefix' => '$(prefix)',
  'bindir' => root, 'ruby_install_name' => 'mere-ruby', 'RUBY_INSTALL_NAME' => 'mere-ruby',
  'rubyhdrdir' => headers, 'rubyarchhdrdir' => headers,
  'topdir' => root, 'hdrdir' => headers, 'archdir' => '$(libdir)',
  'libdir' => '$(exec_prefix)/lib', 'libdirname' => 'libdir',
  'sitedir' => '$(prefix)/lib', 'sitelibdir' => '$(sitedir)', 'sitearchdir' => '$(sitedir)',
  'sitehdrdir' => headers, 'sitearchhdrdir' => headers,
  'vendordir' => '$(sitedir)', 'vendorlibdir' => '$(sitedir)',
  'vendorarchdir' => '$(sitedir)', 'vendorhdrdir' => headers, 'vendorarchhdrdir' => headers,
  'CC' => ENV.fetch('CC', 'clang'), 'CXX' => ENV.fetch('CXX', 'clang++'),
  'CPP' => '$(CC) -E', 'CC_WRAPPER' => '', 'GCC' => 'yes',
  'CFLAGS' => '-O2', 'CXXFLAGS' => '-O2', 'ARCH_FLAG' => '',
  'CPPFLAGS' => '-DPROBE_TYPED_API', 'LDFLAGS' => '', 'DLDFLAGS' => '',
  'LDSHARED' => '$(CC) -bundle -undefined dynamic_lookup',
  'LDSHAREDXX' => '$(CXX) -bundle -undefined dynamic_lookup',
  'CCDLFLAGS' => '-fPIC', 'OUTFLAG' => '-o ', 'COUTFLAG' => '-o ', 'CSRCFLAG' => '',
  'OBJEXT' => 'o', 'LIBEXT' => 'a', 'EXEEXT' => '', 'DLEXT' => 'bundle',
  'ENABLE_SHARED' => 'no', 'LIBRUBY' => '', 'LIBRUBY_A' => '',
  'LIBRUBYARG' => '', 'LIBRUBYARG_STATIC' => '', 'LIBRUBYARG_SHARED' => '',
  'LIBS' => '', 'DLDLIBS' => '', 'RUBY_SO_NAME' => 'mere-ruby',
  'PATH_SEPARATOR' => ':', 'NULLCMD' => ':', 'RM' => 'rm -f',
  'AR' => 'ar', 'LD' => 'ld', 'RANLIB' => 'ranlib', 'configure_args' => '',
  'build_os' => RbConfig::CONFIG['host_os'], 'sitearch' => RbConfig::CONFIG['arch'],
  'INSTALL' => 'install', 'EXTOUT' => '.ext', 'MAKEDIRS' => 'mkdir -p', 'CP' => 'cp', 'TOUCH' => 'touch'
}
if target
  %w[CC CXX CFLAGS CXXFLAGS CPPFLAGS LDFLAGS].each do |key|
    config[key] = target.fetch('settings').fetch(key)
    if ENV.key?(key) && ENV[key] != config[key]
      raise "#{key} differs from generated native configuration; regenerate headers"
    end
  end
  config['CPPFLAGS'] = '-DPROBE_TYPED_API ' + config['CPPFLAGS']
end
config.each { |key, value| RbConfig::MAKEFILE_CONFIG[key] = value.dup }
config.each { |key, value| RbConfig::CONFIG[key] = value.dup }
config.each_key { |key| RbConfig.expand(RbConfig::CONFIG[key]) }
