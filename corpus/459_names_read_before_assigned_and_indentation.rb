# A bare name is a local only from where its scope assigns it on: before
# that (a block that runs later included) it is a method call, as ruby's
# parser decides.
def constants = [:c1, :c2]
def run_later
  pr = proc { constants.size }
  constants = [1, 2, 3]
  [pr.call, constants.size]
end
p run_later

# ...but a name a multi-line rescue list bound stays that local
def rescued
  begin
    raise IOError
  rescue ArgumentError,
         IOError => e
    e.class
  rescue => e
    e.class
  end
end
p rescued

# -w: "mismatched indentations", by prism's rules
require "tmpdir"
def indent_warnings(src)
  got = []
  Warning.singleton_class.class_eval { alias_method :__w459, :warn }
  Warning.define_singleton_method(:warn) { |m, **| got << m.sub(/\A.*?:(\d+):/, 'L\1:') }
  Dir.mktmpdir do |d|
    f = File.join(d, "t#{rand(1 << 30)}.rb")
    File.write(f, src)
    v, $VERBOSE = $VERBOSE, true
    begin
      load f
    ensure
      $VERBOSE = v
    end
  end
  got
ensure
  Warning.singleton_class.class_eval { alias_method :warn, :__w459 }
end
[
  "begin\n end\n",
  "if false;\n else ; end\n",
  "x = -> {\n }\n",
  "if true\nelse if false;\n end\nend\n",
  "_ = if true\nelse\n  end\n",
  "case nil\n when true; end\n",
  "  case nil\n when true; end\n",
  "begin\n    def f() = nil\n end\n",
  "begin rescue\n else ; end\n",
  "[1].each do\n  end\n",
  "def g\n\tx = 1\n        end\n",
  "# -*- warn-indent: false -*-\nbegin\n end\n",
  "while false\n  end\n",
  "def f459\n  begin\n    1\n  rescue LoadError\n    2\n  else\n    3\n  end\nend\n",
  "[1].each do\n  1\nrescue\n  2\nelse\n  3\n  end\n",
  "def g459\n  1\nrescue\n  2\n  else\n  3\nend\n",
].each { |src| p indent_warnings(src) }

# the lexer's own reading that the checks above lean on: a singleton def on an
# expression is no endless def, a keyword after `.` is a method name, and an
# operator Symbol ends an expression, so the `if` after them is a modifier
[
  "class C459\n  def t\n    def (o = Object.new).to_str\n      1\n    end\n  end\nend\n",
  "class R459\n  def b(q)\n    q.pp self.begin if !q\n  end\nend\n",
  "class F459\n  def f(a)\n    a << :** if a\n    a << :& if a\n  end\nend\n",
].each { |src| p indent_warnings(src) }

# a constant named in Windows-31J: its NameError message is in that encoding
n = "\u{391}".encode("cp932")
m = Module.new
begin
  m.const_get(n)
rescue NameError => e
  p e.message.encoding, e.message.valid_encoding?, e.message.b.end_with?("::\x83\x9F".b)
end
m.const_set(n, 42)
p m.const_get(n), m.constants.map { |c| [c.encoding, c.to_s.bytes] }
