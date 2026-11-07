# Inside `class TestRipper::Ripper` the nesting is [TestRipper::Ripper] alone:
# `Ripper::Lexer` there is the TOP-LEVEL Ripper's (an alias of another class),
# not the test class's own -- the lexical walk took every prefix of the
# class's path as a scope (test/ripper's test_invalid_multibyte_character_in_
# regexp). And Ripper over mere-ruby: a source read through #gets at parse
# time, a Lexer that answers #error?, the whitespace after the last token,
# `\ ` as whitespace, an unterminated heredoc's missing end token, the
# `__END__` token alone, and yydebug's token trace.
module Q; class R; class L; class State; end; end; end; end
Z = Q::R
module TestZ; end
class TestZ::Z
  def t = Z
  def u = Z::L
  def v = Z::L::State
  def w = ::Z::L
end
p TestZ::Z.new.t, TestZ::Z.new.u, TestZ::Z.new.v, TestZ::Z.new.w
module A; class B; def s = B; end; end
p A::B.new.s
module CS
  CS_X = 1
  class Cont; end
  class Cont::Child
    def c = CS_X
    def d = Cont
  end
end
p CS::Cont::Child.new.c, CS::Cont::Child.new.d

require "ripper"
require "stringio"
class In
  def initialize(lines) = @lines = lines
  def gets = @lines.shift
end
r = Ripper.new(In.new(["x = 1\n", "__END__\n", "data\n"]))
p r.parse, r.end_seen?
r = Ripper.new(In.new([0]))
p((r.parse rescue $!.class))
p((Ripper.new(42) rescue $!.class))
lexer = Ripper::Lexer.new("def req(a, a) end")
lexer.scan
p lexer.error?, lexer.errors.size
p Ripper::Lexer.new("1").tap(&:scan).error?
p Ripper.lex("1\n\t \t")
p Ripper.tokenize("__END__\njunk junk")
p Ripper.lex("\\ ").map { |e| e[1..2] }, Ripper.lex(" ").map { |e| e[1..2] }
p Ripper::Lexer.new("<<EOS\nheredoc\nEOS \n").scan.map(&:event).reject { |e| e.to_s.include?("error") }
o = StringIO.new
r = Ripper.new("test_xxxx + \"woot\"")
r.yydebug = true
r.debug_output = o
r.parse
puts o.string.lines.grep(/\ANext token.*(local variable or method|literal content)/)
