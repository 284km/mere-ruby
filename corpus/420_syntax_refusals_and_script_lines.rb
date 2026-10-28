# Sources ruby refuses that read as something else, and the lines a
# SCRIPT_LINES__ Hash is given (note 446).

# (each as test_syntax asks: the class, and the part of the message it
#  matches -- prism lists more around it than mere-ruby does)
[
  ['{%"a": 1}', /unexpected ':'/], ["{%'a': 1}", /unexpected ':'/], ['{%Q"a": 1}', /unexpected ':'/],
  ["def n \"\u2208\"; end", /def n "\u2208"; end/],
  ["%[abcdef", /(\n|\| )        \^/], ["%[abcdef\n", /(\n|\| )        \^/],
  ["<<\"\r\"\r\n\r\r\n", /unterminated/], ["<<\"\r\"\n\r\n", /unterminated/],
  ["<<-TEXT\n\\\nTEXT\n", /unterminated/],
].each do |src, want|
  begin
    $VERBOSE = nil
    eval(src, nil, "t.rb")
    puts "no error: #{src.inspect}"
  rescue SyntaxError => e
    p [e.class, want.match?(e.message)]
  ensure
    $VERBOSE = false
  end
end

# ...and what still reads: a ternary's colon after a %-string, a label
p(true ? %(x):1)
p({"a": 1})

# a magic comment that names an encoding no source can be in
path = "/tmp/mere_ruby_420_#{$$}.rb"
File.write(path, "# -*- coding: UTF-16LE -*-\n")
begin
  load(path)
  puts "loaded"
rescue ArgumentError => e
  puts e.class
end

# SCRIPT_LINES__ is given each loaded file's lines, in its encoding
Object.const_set(:SCRIPT_LINES__, {})
File.write(path, "# -*- coding: EUC-JP -*-\n#----\nx = 1\n")
load(path)
p SCRIPT_LINES__[path].size
p SCRIPT_LINES__[path].map(&:encoding).uniq
File.delete(path)
