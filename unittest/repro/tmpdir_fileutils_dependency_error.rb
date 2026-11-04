# Only an absent FileUtils library permits the standalone fallback. A LoadError
# inside an available FileUtils file must keep its original dependency path.
directory = File.join(ENV['TMPDIR'] || '/tmp', "tmpdir-dependency-#{Process.pid}")
Dir.mkdir(directory, 0700)
path = File.join(directory, 'fileutils.rb')
File.write(path, "require 'tmpdir_missing_fileutils_dependency'\n")
$LOAD_PATH.unshift(directory)
begin
  require 'tmpdir'
  raise 'tmpdir swallowed a FileUtils dependency error'
rescue LoadError => error
  raise 'dependency path changed' unless error.path == 'tmpdir_missing_fileutils_dependency'
ensure
  File.delete(path)
  Dir.rmdir(directory)
end
puts 'tmpdir preserves FileUtils dependency errors'
