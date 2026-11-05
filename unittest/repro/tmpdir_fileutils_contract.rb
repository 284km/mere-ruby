require 'stringio'

directory = nil
result = Dir.mktmpdir('fileutils-contract') do |root|
  directory = root
  paths = [File.join(root, 'one', 'leaf'), File.join(root, 'two', 'leaf')]
  raise 'mkdir_p return value' unless FileUtils.mkdir_p(paths, mode: 0700) == paths
  raise 'mkdir_p permissions' unless paths.all? { |path| (File.stat(path).mode & 0777) == 0700 }

  noop = File.join(root, 'noop')
  FileUtils.mkdir_p(noop, mode: 0700, noop: true)
  raise 'mkdir_p noop created a directory' if File.exist?(noop)
  [:mkpath, :makedirs].each do |name|
    path = File.join(root, name.to_s)
    raise 'mkdir_p alias return value' unless FileUtils.public_send(name, path, mode: 0700) == [path]
    raise 'mkdir_p alias permissions' unless (File.stat(path).mode & 0777) == 0700
  end

  # FileUtils writes verbose messages to its configured output rather than
  # making callers drop the keyword. Capture paths so the corpus is stable.
  output = StringIO.new
  previous = FileUtils.instance_variable_get(:@fileutils_output)
  begin
    FileUtils.instance_variable_set(:@fileutils_output, output)
    FileUtils.mkdir_p(File.join(root, 'verbose'), verbose: true)
    raise 'mkdir_p verbose output' unless output.string.include?('mkdir -p')
  ensure
    FileUtils.instance_variable_set(:@fileutils_output, previous)
  end

  FileUtils.rm_rf(paths, noop: true)
  raise 'rm_rf noop removed a directory' unless paths.all? { |path| File.directory?(path) }
  FileUtils.rm_rf(paths, secure: true)
  raise 'rm_rf did not remove directories' if paths.any? { |path| File.exist?(path) }
  outside = File.join(root, 'outside')
  Dir.mkdir(outside)
  File.write(File.join(outside, 'keep'), 'keep')
  link = File.join(root, 'link')
  File.symlink(outside, link)
  FileUtils.remove_entry(link)
  raise 'remove_entry followed a symlink' unless File.read(File.join(outside, 'keep')) == 'keep'
  FileUtils.remove_entry(File.join(root, 'absent'), true)
  :block_result
end
raise 'mktmpdir return value' unless result == :block_result
raise 'mktmpdir leaked its contents' if File.exist?(directory)
puts 'tmpdir and FileUtils preserve methods, keywords, permissions and cleanup'
