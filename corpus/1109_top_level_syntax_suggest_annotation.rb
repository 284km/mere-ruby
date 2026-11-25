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
