require 'rbconfig'

# mkmf searches libdir before a dependency's configured -L directories.
# It must contain the runtime library it advertises, rather than naming an
# unrelated system directory which can shadow that dependency's library.
c = RbConfig::CONFIG
link = c.fetch('LIBRUBYARG').split.find { |flag| flag.start_with?('-l') }
raise 'runtime library not advertised' unless link
name = 'lib' + link[2..]
p %w[a so dylib].any? { |suffix| File.file?(File.join(c.fetch('libdir'), name + '.' + suffix)) }
p RbConfig.expand(RbConfig::MAKEFILE_CONFIG.fetch('libdir').dup) == c.fetch('libdir')
