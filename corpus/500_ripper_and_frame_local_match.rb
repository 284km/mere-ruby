# Ripper under mere-ruby: Prism::Translation::Ripper as ::Ripper, with the
# Ruby half of ripper (Lexer, tokenize, slice, Filter, dedent_string) over
# Prism.lex_compat -- note 511's stage 5. And what loading it found: `$~`
# belongs to the frame, and a class body, a module body, a singleton class
# body and a required file's top level are frames of their own.
require "ripper"
require "stringio"

p Ripper::Version
p Ripper.lex("a = 1\n")
p Ripper.tokenize("def f(x) = x + 1\n")
p Ripper.sexp("1 + 2")
p Ripper.sexp_raw("a.b")
p Ripper.sexp("def")
p Ripper.slice("a = 1 + 2", "int"), Ripper.slice("foo(1)", "ident")
r = Ripper.new("1 + 1")
p r.column, r.lineno, r.state, r.filename, r.parse, r.end_seen?, r.encoding, r.error?
r = Ripper.new("__END__\nx", "f.rb", 3)
r.parse
p r.end_seen?, r.filename
p Ripper.new("# coding: iso-8859-15\n1").tap(&:parse).encoding
s = "  hello".dup
p Ripper.dedent_string(s, 2), s
s = "\thello".dup
p Ripper.dedent_string(s, 4), s
s = "\t hello".dup
p Ripper.dedent_string(s, 9), s
lexer = Ripper::Lexer.new("x = <<~EOS\n  a\nEOS\n")
p lexer.scan.map(&:event)
p Ripper::Lexer.new("1 +").scan.map { |e| [e.event, e.tok, e.message.nil?] }.uniq
p Ripper.lex("1 +").map { |e| e[1] }
p Ripper::PARSER_EVENTS.size, Ripper::SCANNER_EVENTS.size, Ripper::EXPR_BEG
p Ripper.lex("a = 1").first[3], Ripper.lex("a = 1").first[3] == Ripper::EXPR_CMDARG

class Counter < Ripper::Filter
  def on_default(event, tok, data)
    data[event] = (data[event] || 0) + 1
    data
  end
end
p Counter.new("a = 1 + b\n").parse({}).sort.to_h

class Events < Ripper
  def initialize(src)
    super
    @seen = []
  end
  attr_reader :seen
  PARSER_EVENT_TABLE.each do |event, arity|
    define_method(:"on_#{event}") { |*args| @seen << event; args }
  end
end
e = Events.new("x = 1; y = 2")
e.parse
p e.seen.sort.uniq

# `$~` is the frame's own: a class body, a module body, a singleton class
# body and a required file's top level start with none and leave the
# enclosing match alone; a block written in a class body matches into the
# body's.
"outer" =~ /out/
class K1
  p [:class_body, $~]
  "inner" =~ /inn/
  p [:class_block, [:on_x].grep(/\Aon_/) { $' }]
  EV = private_instance_methods(false).grep(/\Aon_/) { $'.to_sym }
end
module M1
  p [:module_body, $~]
end
class << self
  p [:singleton_body, $~]
end
p [:after, $~[0], K1::EV]
require "tmpdir"
Dir.mktmpdir do |d|
  File.write("#{d}/lib_match.rb", "p [:required_top, $~]\n\"file\" =~ /fi/\nclass K2; X = [:on_y].grep(/\\Aon_/) { $' }; end\np [:required_after, $~[0]]\n")
  "main" =~ /ma/
  require "#{d}/lib_match"
  p [:main_after, $~[0], K2::X]
end

# ...and three more things loading Ripper's tests found: `[] == obj` asks an
# object that answers #to_ary (Prism's lex tokens are delegators over
# arrays), `yield` in a class_eval body and in a define_method body written
# there is the enclosing method's block, and a magic comment's spaces are
# ruby's ISSPACE (a vertical tab too)
require "delegate"
class ArrLike < SimpleDelegator; end
p [[1, "a"], [2, "b"]] == [ArrLike.new([1, "a"]), ArrLike.new([2, "b"])]
p [1, 2] == Object.new, [[1]] == [Object.new]
class Hooked
  def hook(name)
    singleton_class.class_eval do
      define_method(name) { |*a| [:dm, yield(name, *a)] }
    end
    singleton_class.class_eval { yield :direct }
  end
  def each_with_hook
    singleton_class.instance_eval { yield :ieval }
  end
end
h = Hooked.new
h.hook(:f) { |n, *a| [n, a] }
p h.f(1, 2)
h.each_with_hook { |x| p [:got, x] }
p eval("# \s\t\v encoding \s\t\v : \s\t\v ascii \s\t\v\n__ENCODING__")
