require 'tmpdir'
Dir.mktmpdir('pathname-core') do |dir|
  feature = File.join(dir, 'pathname_builtin.rb')
  File.write(feature, "$pathname_user_feature = :physical_source\n")
  $LOAD_PATH.unshift(dir)
  begin
    path = Pathname('one/two')
    p [:core, path.to_s, path.basename.to_s]
    p [:ordinary_file, require('pathname_builtin'), $pathname_user_feature]
    p [:physical_source, $LOADED_FEATURES.include?(feature)]
    p [:library, require('pathname'), path.respond_to?(:find)]
  ensure
    $LOAD_PATH.delete(dir)
  end
end
