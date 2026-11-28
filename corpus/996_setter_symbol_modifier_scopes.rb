require 'tmpdir'
require 'rbconfig'

# A setter symbol before a modifier must not push an extra if/loop scope.
# -w must be active before parsing, including when the file is required.
source = <<~'RUBY'
  module SetterSymbolScopes
    class Subject
      attr_accessor :line
      undef_method :NAME= MODIFIER
      def value
        42
      end
    end
  end
  p SetterSymbolScopes::Subject.new.value
RUBY

Dir.mktmpdir('corpus-996-') do |dir|
  [['UTF-8', 'line'], ['Windows-31J', '表'], ['Big5', '許']].each_with_index do |(encoding, name), index|
    ['if method_defined?(:NAME=)', 'unless true', 'while false', 'until true'].each_with_index do |modifier, variant|
      path = File.join(dir, "setter_#{index}_#{variant}.rb")
      fixture = source.gsub('MODIFIER', modifier).gsub('NAME', name)
      File.binwrite(path, ("# coding: #{encoding}\n" + fixture).encode(encoding))
      [[path], ['-e', "require #{path.inspect}"]].each_with_index do |args, mode|
        output = IO.popen([RbConfig.ruby, '-w', *args], err: [:child, :out], &:read)
        p [encoding, variant, mode, $?.exitstatus, output == "42\n"]
      end
    end
  end

  # Real indentation mistakes must still warn.
  path = File.join(dir, 'indented.rb')
  File.write(path, "module BadIndent\n  class Subject\n    def value\n      42\n  end\n  end\nend\n")
  output = IO.popen([RbConfig.ruby, '-w', '-c', path], err: [:child, :out], &:read)
  p [:real_indentation, $?.exitstatus, output.include?('mismatched indentations')]
end
