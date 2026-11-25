require 'tmpdir'
Dir.mktmpdir do |dir|
  error_path = File.join(dir, 'warnings')
  child = <<~'CODE'
    [1, 7].each do |first|
      begin
        eval("1\n2\nend\n", nil, 'eval-warning.rb', first)
      rescue SyntaxError => error
        puts error.class
        puts error.message.include?('syntax error')
      end
    end
    p eval("1\n2\n", nil, 'valid-eval.rb', 3)
  CODE
  out = IO.popen([RbConfig.ruby, '-W', '-e', child, err: error_path], &:read)
  print out
  p $?.exitstatus
  print File.binread(error_path)
end
