require 'tmpdir'
Dir.mktmpdir do |dir|
  path = File.join(dir, 'broken.rb')
  error_path = File.join(dir, 'error')
  File.write(path, "def unmatched\n  [1, 2\n")
  [[], ['--disable=syntax_suggest'], ['--disable=gems']].each do |flags|
    output = IO.popen([RbConfig.ruby, *flags, path, err: error_path], &:read)
    p [flags, output, $?.exitstatus]
    error = File.binread(error_path)
    # Compare the complete gem-provided annotation. Parser diagnostic
    # framing is a separate existing surface after this header.
    annotation = error.lines.take_while { |line| !line.include?('syntax error') && !line.include?('(SyntaxError)') }.join
    annotation = '' unless annotation.include?('--> ')
    print annotation.gsub(path, 'broken.rb')
  end
end

# Startup decoration must retain the parser's diagnostic for -e programs.
["class X; BEGIN {}; end", "x = (1", "p 1 +", "x = (1\n", "p 1 +\n"].each do |source|
  reader, writer = IO.pipe
  pid = spawn(RbConfig.ruby, '-W0', '-e', source, out: File::NULL, err: writer)
  writer.close
  Process.wait(pid)
  error = reader.read
  reader.close
  p [$?.exitstatus, error.lines.first, error.include?('^')]
end

# A -r override must still receive and decorate the actual parser message.
Dir.mktmpdir do |dir|
  loader = File.join(dir, 'decorate.rb')
  error_path = File.join(dir, 'error')
  File.write(loader, 'class SyntaxError; def detailed_message(**); "custom: #{message.lines.first}"; end; end' + "\n")
  IO.popen([RbConfig.ruby, '-r', loader, '-e', 'class X; BEGIN {}; end', err: error_path], &:read)
  p [$?.exitstatus, File.binread(error_path)]
end

Dir.mktmpdir do |dir|
  loader = File.join(dir, 'count_message.rb')
  error_path = File.join(dir, 'error')
  File.write(loader, '$syntax_message_calls = 0; class SyntaxError; def message; $syntax_message_calls += 1; super; end; def detailed_message(**); "custom: #{message.lines.first}calls: #{$syntax_message_calls}"; end; end' + "\n")
  IO.popen([RbConfig.ruby, '-r', loader, '-e', 'x = (1', err: error_path], &:read)
  p [$?.exitstatus, File.binread(error_path)]
end

# OptionParser and its relative subfeatures must share the normal load path.
Dir.mktmpdir do |dir|
  error_path = File.join(dir, 'optparse_error')
  # Configure the real stdlib, as the corpus harness does for external Ruby libraries.
  # Only directory discovery uses the reference; every probe uses RbConfig.ruby.
  reference = ENV.fetch('REF_RUBY_BIN', RbConfig.ruby)
  paths_query = 'print $LOAD_PATH.join(File::PATH_SEPARATOR)'
  reference_paths = IO.popen([reference, '--disable-gems', '-e', paths_query], &:read)
  runtime_paths = IO.popen([RbConfig.ruby, '--disable-gems', '-e', paths_query], &:read)
  normal = [runtime_paths, reference_paths, ENV['RUBYLIB']].compact.join(File::PATH_SEPARATOR)
  library_env = {'RUBYLIB' => normal}
  ['time', 'ac', 'kwargs'].each do |feature|
    source = "$VERBOSE = true\nrequire 'optparse'\nrequire 'optparse/#{feature}'\np :loaded\n"
    output = IO.popen([library_env, RbConfig.ruby, '-e', source, err: error_path], &:read)
    p [feature, output, $?.exitstatus, File.binread(error_path)]
  end
  source = "$VERBOSE = true\nrequire 'optparse/time'\nrequire 'optparse'\np :loaded\n"
  output = IO.popen([library_env, RbConfig.ruby, '-e', source, err: error_path], &:read)
  p [:relative_first, output, $?.exitstatus, File.binread(error_path)]
  custom = File.join(dir, 'custom')
  Dir.mkdir(custom)
  File.write(File.join(custom, 'optparse.rb'), "class OptionParser; LOCAL_VERSION = :from_load_path; end\n")
  env = {'RUBYLIB' => [custom, normal].join(File::PATH_SEPARATOR)}
  source = "$VERBOSE = true\nrequire 'optparse'\np OptionParser::LOCAL_VERSION\n"
  output = IO.popen([env, RbConfig.ruby, '-e', source, err: error_path], &:read)
  p [:custom_optparse, output, $?.exitstatus, File.binread(error_path)]
  # The path-cache conversion-count difference is recorded separately;
  # this regression checks the actual selected library.
  source = 'calls = 0; entry = Object.new; entry.define_singleton_method(:to_path) { calls += 1; ARGV.fetch(0) }; $LOAD_PATH.unshift(entry); require "optparse"; p OptionParser::LOCAL_VERSION'
  output = IO.popen([library_env, RbConfig.ruby, '--disable-gems', '-e', source, '--', custom, err: error_path], &:read)
  p [:path_object, output, $?.exitstatus, File.binread(error_path)]
end
