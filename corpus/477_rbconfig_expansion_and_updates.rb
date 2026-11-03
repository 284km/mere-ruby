require 'rbconfig'
config = {'prefix' => '/opt/ruby', 'bindir' => '$(prefix)/bin', 'objects' => 'first.o second.o', 'loop' => '$(loop)'}
['$(bindir)/ruby', '${prefix}/lib', '$$HOME', '$(missing)', '$(objects:.o=.c)', '$(objects:.o)', '${objects:}', '$(loop)'].each do |text|
  original = text.dup
  result = RbConfig.expand(text, config)
  p [original, result, result.equal?(text)]
end
key = '__mere_expansion_probe'
makefile = RbConfig::MAKEFILE_CONFIG
config = RbConfig::CONFIG
begin
  makefile[key] = config[key] = 'old'
  makefile[key + '_child'] = '$(%s)/child' % key
  makefile[key + '_grandchild'] = '${%s_child}/grandchild' % key
  p RbConfig.fire_update!(key, 'new')
  p config.values_at(key, key + '_child', key + '_grandchild')
  p RbConfig.fire_update!(key, 'new')
ensure
  [key, key + '_child', key + '_grandchild'].each do |name|
    makefile.delete(name)
    config.delete(name)
  end
end
