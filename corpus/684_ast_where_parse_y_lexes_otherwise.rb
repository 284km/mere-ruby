# RubyVM::AbstractSyntaxTree where parse.y's lexer, not its grammar, decides
# the tree -- what Prism reads its own way: a percent literal closed by a
# line end, a comment and a `\` continuation before heredoc bodies, a `#@` /
# `#$` in a regexp that names no variable, text a heredoc body interrupts, a
# `<<~` heredoc whose indentation falls to none, `Foo::Bar { }`, a command's
# `do` block inside bracketed arguments, and an empty file.
require "tmpdir"
AST = RubyVM::AbstractSyntaxTree

def walk(node, depth = 0)
  pos = "#{node.first_lineno}:#{node.first_column}-#{node.last_lineno}:#{node.last_column}"
  puts "#{"  " * depth}#{node.type} #{pos}"
  node.children.each do |c|
    if c.is_a?(AST::Node) then walk(c, depth + 1)
    else puts "#{"  " * (depth + 1)}#{c.inspect}"
    end
  end
end

def show(src)
  puts "-- #{src.inspect}"
  walk(AST.parse(src))
rescue SyntaxError => e
  puts "SyntaxError"
end

# a percent literal closed by a line end ends on that line
show("1\n%\nfoo\n")
show("%\nfoo\n")
show("1\n%\nfoo\n\n")
show("x = %r\nab\n")
show("<<A+%r\nA\n\n")
# the program's end: past a comment, a blank last line, a continuation,
# heredoc bodies
show("1 # c\n  ")
show("1 \\\n\n")
show("x <<A \\\nA\n\n")
show("x <<A # c\nA\n")
show("x <<A # c\nA\n\n")
# a regexp's text splits at a #@ / #$ that names no variable
show('/a#@~b/i')
show('/a#@~b#$ c/')
show('/a\#@~b/')
# ...its pieces are the lexer's tokens: an escaped delimiter is the
# delimiter, a `\` and its line end go, \cX / \M-X are written \xHH
show('/a\/#@~/')
show('/a#@~\//')
show("/a\\\n#@~b/")
show('%r{a\}#@~}')
show('if /a\/#@~b/ then 1 end')
p AST.parse('/a\cA#@~\M-\C-b/').children[2].children
show('if /a#@~b/ then 1 end')
show('"a#@~b"')
# text a heredoc body interrupts is one token
show("p <<-A.gsub(/b\\\na\nA\nb/, \"\")\n")
show("p <<-A, %w[j\\\ni\nA\nj]\n")
show("p <<-A, %i[n\\\nm\nA\nn]\n")
# a <<~ heredoc with an unindented line, early or late
show("x=<<~E\n  a\n\#{1}\n  b\n\#{2}\n  c\nE\n")
show("x=<<~E\n  x\n  w\n\ny\n  q\nE\n")
show("x=<<~E\n  \#{1}\nb\nE\n")
show("x=<<~E\n  #{"a"} \#{1} c\n  b\n\#{2}\nE\n")
show("x=<<~E\n    x\n  \#{\"  y\"}\nE\n")
# Foo::Bar { } -- the call is placed with its block
show("Foo::Bar { |a| 42 }")
show("Foo.Bar { 1 }")
# a command's do block inside bracketed arguments is refused
["foo(bar baz do end)", "foo(bar do end)", "foo((bar baz do end))", "[bar baz do end]",
 "foo(k: bar baz do end)", "foo(*bar baz do end)", "foo(bar baz { })", "foo[bar baz do end]"].each do |s|
  print s, " => "
  begin
    AST.parse(s)
    puts "ok"
  rescue SyntaxError
    puts "SyntaxError"
  end
end
# an empty file has no line: its tree is at line 0; a String is not a file
Dir.mktmpdir do |d|
  path = File.join(d, "empty.rb")
  File.write(path, "")
  t = AST.parse_file(path, keep_script_lines: true)
  p t, t.script_lines, t.children
  t = AST.parse("", keep_script_lines: true)
  p t, t.script_lines
end
