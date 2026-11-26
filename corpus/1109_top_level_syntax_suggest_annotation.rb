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
