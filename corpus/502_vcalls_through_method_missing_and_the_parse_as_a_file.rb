# What test/prism's encoding and warnings tests found in the interpreter (note
# 511's stage 3, after the parser's 127): a bare name an object's class answers
# through method_missing, a constant a string instance_eval'd on an object
# looks up through the object's class, a bare `p` on a BasicObject, the
# encoding a quoted symbol takes from its escapes, a byte past ASCII in a
# US-ASCII source, the sign after a name that is no local (`foo -1` is
# foo(-1)), and RubyVM::AbstractSyntaxTree.parse reading its source as a FILE
# -- unused variables, void statements, indentation and all.
require "stringio"

class D
  def method_missing(n, *a) = [:mm, n, a]
  def f = zzz
  def g = zzz 1
end
p D.new.f, D.new.g, D.new.instance_eval("_0"), D.new.instance_eval { zzz }

class CC; def self.const_missing(c) = [:cm, c]; end
class BC < BasicObject
  def self.const_missing(c) = [:bcm, c]
  def method_missing(n, *) = n
end
module Outer
  X = 1
  def self.t
    p CC.new.instance_eval("A"), BC.new.instance_eval("A"), CC.new.instance_eval("X")
    p((CC.new.instance_eval { A } rescue $!.class))
    p BC.new.instance_eval("p"), BC.new.instance_eval("_0")
  end
end
Outer.t

# the encoding a quoted symbol takes: forced UTF-8 for a \u escape, binary for
# a byte escape in a US-ASCII source, the source's otherwise, and the two
# together "UTF-8 mixed within"
def enc(src)
  v = eval(src)
  [v.to_s.bytes, v.encoding]
rescue SyntaxError => e
  m = e.message.b
  m[/UTF-8 mixed within .+? source/n] || m[/invalid multibyte char\w*/n] || m[/invalid symbol/n]
end
p enc("# encoding: US-ASCII\n:\"\\x80\""), enc("# encoding: US-ASCII\n:\"\\u{80}\""), enc("# encoding: US-ASCII\n:\"\\M-\\C-?\"")
p enc("# encoding: US-ASCII\n:\"\\x80\\u{80}\""), enc("# encoding: US-ASCII\n\"\\u{80}\\M-\\C-?\"")
p enc("# encoding: Windows-1253\n:\"\\x80\""), enc("# encoding: Windows-1253\n:\"\\u{80}\""), enc("# encoding: Windows-1253\n:\"\\x7F\"")
p enc("# encoding: ASCII-8BIT\n:\"\\xFF\""), enc("# encoding: ASCII-8BIT\n\"\\u{80}\\xFF\"")
p enc("# encoding: US-ASCII\n'\xC4\x85'"), enc("# encoding: US-ASCII\n:\xC4\x85"), enc("# encoding: US-ASCII\n# \xC4\x85\n:a")
p enc(":\"\\xFF\"")

# `foo -1` is foo(-1) when foo is no local; after a local or a literal the
# minus is the operator
def foo(x = :none, *r) = [x, r]
def bar = 10
y = 3
p foo -1
p foo -1, 2
p(foo +2)
p y -1
p [1, 2].map { |v| v -1 }
p((A -1 rescue $!.class))
p((bar -1 rescue $!.class))
p bar - 1, bar-1

# RubyVM::AbstractSyntaxTree.parse reads the source as a file, under -w
def warnings(src)
  o, $stderr, v, $VERBOSE = $stderr, StringIO.new, $VERBOSE, true
  begin
    RubyVM::AbstractSyntaxTree.parse(src)
    $stderr.string.lines.map(&:chomp)
  rescue SyntaxError => e
    ["SyntaxError"]
  ensure
    $stderr, $VERBOSE = o, v
  end
end
[
  "foo = 1; foo", "x = 1", "if true\n  end", "_ = foo...", "_ = foo... #", "def foo(...) = bar ...", "p foo...bar",
  "def foo; END {}; end", "_ = 1.0e100000", "if\ntrue; end", "if true\nelsif\nfalse; end",
  "if (@@a = 2); end", "!(a = 2) and a", "not a = 2 and a", "if __ENCODING__; end", "if 1r; end", "if 1i; end",
  "foo # shareable_constant_value: none", "a &:b", "a &b", "a &:+", "a -b", "a +b", "a *b", "@foo", "1",
].each { |src| puts "#{src.inspect}: #{warnings(src).inspect}" }
