# Round 20 of note 544 (stage 5): parse.y's tokens for keep_tokens, a retry
# that does not run its ensure, a Hash copy that keeps its default, an alias
# of a builtin class method that outlives a redefinition and an undef, a
# reopened Struct class that sees its lexical nesting, a class's builtin class
# methods in #methods, and a deep Array read.

# keep_tokens: parse.y's names, every byte in some token, binary text
src = "x = [1,\n  2] # c\nfoo(<<~E, %w[a b])\n  hi\nE\n1.times do\nend\n__END__\nignored\n"
toks = RubyVM::AbstractSyntaxTree.parse(src, keep_tokens: true).all_tokens
toks.each { |id, type, text, pos| p [id, type, text, pos] }
p toks.map { _1[2] }.join == src.b.split("__END__").first
p toks.map { _1[2].encoding }.uniq
p RubyVM::AbstractSyntaxTree.parse("a").all_tokens

# retry re-runs the begin; its ensure runs once, when the begin is left
def retried
  tries = 0
  begin
    tries += 1
    raise ArgumentError, "again" if tries < 3
    tries
  rescue ArgumentError
    retry
  ensure
    puts "ensure after #{tries}"
  end
end
p retried

# a Hash copy keeps its default value and default proc
h = Hash.new { |hh, k| hh[k] = [] }
p h.dup[:missing], h.clone[:other]
p Hash.new(5).dup[0], Hash.new(5).compare_by_identity.clone.compare_by_identity?

# an alias of a builtin class method is the builtin, also after the name is
# redefined and undefined (minitest's Object#stub, rubygems' tests)
meta = class << Time; self; end
meta.send :alias_method, :saved_now, :now
meta.send :define_method, :now do |*| :stubbed end
p Time.now, Time.saved_now.class
meta.send :undef_method, :now
meta.send :alias_method, :now, :saved_now
meta.send :undef_method, :saved_now
p Time.now.class, Time.respond_to?(:saved_now)

# a class's own builtin class methods are among its methods
p Time.methods.include?(:now), Time.singleton_methods.include?(:now)
p File.methods.include?(:read), Time.singleton_methods.grep(/\A__/)

# a class made by Struct.new and reopened sees the scope it was written in
module Outer
  class Graph; end
  State = Struct.new(:a)
  class State
    def self.empty = Graph.new
  end
end
p Outer::State.empty.class

# a deep read of a long Array, and a Float sample count
big = Array.new(100_000) { _1 }
p big[99_999], big[50_000], big[-1], [1, 2, 3, 4].sample(2.7).size
