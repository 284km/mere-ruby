# coding: US-ASCII
# Open ends of notes 461-464: a static heredoc of a US-ASCII source after an
# interpolated literal brought another encoding, an eval'd return in a block
# at the top level, respond_to? for a builtin alias in a String subclass, a
# builtin's Method called with a block past an override, and the :line of a
# parenthesised endless def body.

# a static heredoc is its source's encoding, whatever the last interpolated
# literal took
u = "\u00e9"
s = "#{u}x"
p s.encoding
h = <<-END
plain
END
p h.encoding

# an eval'd `return` in a block at the top level has nothing to return from
begin
  [1].each { eval("return 1") }
rescue LocalJumpError => e
  p [:lje, e.message]
end

# a value answers a name its class aliased to a builtin
class CorpusS < String; alias each each_char; end
p CorpusS.new("xy").respond_to?(:each)
p CorpusS.new("xy").each.to_a

# a builtin's Method holds the builtin with a block too
class CorpusSS < String; def upcase = "over"; def each_char = :over; end
m = String.instance_method(:each_char).bind(CorpusSS.new("ab"))
r = []
m.call { |c| r << c }
p r
pr = "abc".method(:each_char)
class String; alias __corpus_ec each_char; def each_char = :redef; end
r = []
pr.call { |c| r << c }
p r
class String; alias each_char __corpus_ec; end
p "q".each_char.to_a

# an endless def's body of parenthesised statements makes a :line
def corpus_one = (a = 1; a)
def corpus_two = 2
ev = []
TracePoint.new(:line) { |t| ev << t.lineno - __LINE__ }.enable { corpus_one; corpus_two }
p ev

# a %W word a \u escape made non-ASCII stays UTF-8 in a US-ASCII source
p %W"\u{00de} \u{00C0} plain".map(&:encoding)
