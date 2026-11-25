require 'tmpdir'
require 'rbconfig'

Dir.mktmpdir('corpus-990-') do |dir|
  ['@iv', '$g', '@@cv', '+', 'a='].each_with_index do |key, index|
    source = "case {} in {#{key}: 1} end"
    begin
      eval(source, TOPLEVEL_BINDING, 'pattern.rb', 7)
    rescue Exception => error
      p error.class
      puts error.message
    end

    path = File.join(dir, "pattern_#{index}.rb")
    File.binwrite(path, source + "\n")
    begin
      load path
    rescue Exception => error
      p error.class
      puts error.message.gsub(path, 'pattern.rb')
    end

    begin
      require path
    rescue Exception => error
      p error.class
      puts error.message.gsub(path, 'pattern.rb')
    end

    # Compare the core Prism report without the optional syntax_suggest addon.
    output = IO.popen([RbConfig.ruby, '--disable=syntax_suggest', path, err: [:child, :out]], &:read)
    p $?.exitstatus
    puts output.gsub(path, 'pattern.rb')
  end
end

# Quoted symbol labels remain valid even when they spell an ivar/global.
case {'@iv': 1, '$g': 2}
in {'@iv': x, '$g': y}
  p [x, y]
end
p eval(%q[case {'@iv': 1}; in {'@iv': x}; x; end])
