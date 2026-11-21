require 'tmpdir'
require 'fileutils'
Dir.mktmpdir('path-core') do |dir|
 File.write(File.join(dir,'pathname.rb'), "class Pathname\n def physical_extension; :actual_file; end\nend\n")
 $LOAD_PATH.unshift(dir)
 begin
  p [:load, require('pathname')]
  path=Pathname.new('one/two')
  p [:path,path.to_s,path.basename.to_s,path.dirname.to_s,path.physical_extension]
  p [:repeat,require('pathname')]
 ensure
  $LOAD_PATH.delete(dir)
 end
end
