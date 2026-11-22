# RubyVM::AbstractSyntaxTree where Prism and parse.y part ways:
# - named captures in a regexp that parse.y splits at a `#@` / `#$` naming no
#   variable assign nothing (a DREGX), so the name is no variable until
#   something else assigns it;
# - error_tolerant, a body (def, class, module, begin, while, until, lambda,
#   if / unless without else) where something cannot follow a statement:
#   parse.y makes the body's statements so far one ERROR and reads on;
# - error_tolerant, an `end` after `.` that closes a def, a do block, an if,
#   an unless, a while or an until by its indent.
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

def show(src, tolerant = false)
  puts "-- #{src.inspect}"
  walk(AST.parse(src, error_tolerant: tolerant))
rescue SyntaxError
  puts "SyntaxError"
end

[
  '/(?<y>a)#@~/ =~ x; y',
  'y = 1; /(?<y>a)#@~/ =~ x; y',
  '/(?<y>a)#@~/ =~ x; y; y = 1; y',
  '/(?<y>a)#@~/ =~ x; z = 1; y = 2; y',
  'def f(y); /(?<y>a)#@~/ =~ x; y; end',
  '[1].each { /(?<y>a)#@~/ =~ x; y }',
  'y = 0; [1].each { /(?<y>a)#@~/ =~ x; y }',
  '/(?<y>a)#@~/ =~ x; y += 1; y',
  '/(?<y>a)#@~/ =~ x; a, y = 1, 2; y',
  '/(?<y>a)#@~/ =~ x; y = y',
  '/(?<y>a)#@~/ =~ x; case 1; in {k: y}; end; y',
  '/(?<y>a)#@~/ =~ x; z = 1; [1].each { y = 2 }; w = 3; y = 4; y',
  '/(?<y>a)#@~/ =~ x; [1].each { y = 2; y }; y',
  '/(?<y>a)#@~(?<z>b)/ =~ x; /(?<z>c)/ =~ x; [y, z]',
  '/(?<y>a)#$~/ =~ x; y',
].each { |s| show(s) }

/(?<w>a)#@~/ =~ "a#@~"
p defined?(w)

[
  "def f; 1q; end",
  "def f\n  x\n  y\n  1q\n  z\nend",
  "def f\n  x; 1q; z\nend",
  "def f\n  1q 2 3\n  z\nend",
  "def f\n  a = 1 2\nend",
  "class A\n  x\n  1q\nend",
  "class A; 1q; end",
  "module M\n  1q\n  z\nend",
  "begin\n  1q\nend",
  "if x\n  1q\nend",
  "while x\n  1q\n  z\nend",
  "unless x\n  1q\n  z\nend",
  "-> do\n  1q\n  z\nend",
  "class << self\n  1q\n  z\nend",
  "def f\n  x\n  1q\n  y\n  2w\n  z\nend",
  "def f\n  1q\nrescue\n  z\nend",
  "def foo\n  bar.\nend",
  "def foo\n  x\n  bar.\nend\nbaz",
  "foo do\n  bar.\nend",
  "foo do\n  x\n  bar.\nend\nbaz",
  "if x\n  y\n  bar.\nend\nbaz",
  "while x\n  bar.\nend\nbaz",
  "unless x\n  bar.\nend",
  "until x\n  bar.\nend",
  "class A\n  def foo\n    bar.\n  end\nend",
].each { |s| show(s, true) }

# Review regressions: relocated writes, explicit bindings and loop targets.
[
  '/(?<y>a)#@~/ =~ x; 1.times { y = 2; y = 3 }; y',
  '/(?<y>a)#@~/ =~ x; 1.times { y = 2; y += 3 }; y',
  '/(?<y>a)#@~/ =~ x; 1.times { y = 2; 1.times { y = 3 } }; y',
  'foo { |(y)| /(?<y>a)#@~/ =~ x; y }',
  'foo { |(x, *y)| /(?<y>a)#@~/ =~ x; y }',
  'foo { |; y| /(?<y>a)#@~/ =~ x; y }',
  '/(?<y>a)#@~/ =~ x; 1.times { for y in [1]; y; end }; y',
  '/(?<y>a)#@~/ =~ x; -> { for y in [1]; y; end }; y',
  '/(?<y>a)#@~/ =~ x; 1.times { for (x, y) in [[1, 2]]; y; end }; y',
  '/(?<y>a)#@~/ =~ x; 1.times { for y in y; y; end }; y',
  '/(?<y>a)#@~/ =~ x; for y in y; y; end',
  '/(?<y>a)#@~/ =~ x; for (x, y) in y; y; end',
].each { |source| show(source) }
[
  "def f\nbegin; x; end; 1q\nend",
  'if x; ; 1q; end',
  'unless x; ; 1q; end',
  'while x; ; 1q; end',
  'until x; ; 1q; end',
].each { |source| show(source, true) }

# Block-local declarations occur after parameter default expressions.
[
  '/(?<y>a)#@~/ =~ x; foo { |z=y; y| y }',
  '/(?<y>a)#@~/ =~ x; foo { |z: y; y| y }',
  '/(?<y>a)#@~/ =~ x; foo { |z=y, (y)| y }',
].each { |source| show(source) }
