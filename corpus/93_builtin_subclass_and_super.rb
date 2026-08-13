# A subclass of a builtin: its instances ARE the builtin value, so they need
# instance variables of their own, `super` in initialize has to reach the
# builtin, and an implicit-self call must see every method `self.name` would.
class Uncountables < Array
  def initialize
    @regex = []
    super
  end
  def add(words)
    concat(words)
    @regex += words.map { |w| /\b#{w}\Z/i }
    self
  end
  def uncountable?(s)
    @regex.any? { |r| r.match?(s) }
  end
end
u = Uncountables.new
u.add(%w[fish sheep])
p u
p u.uncountable?("a fish")
p u.uncountable?("a cow")
p u.class
p u.size

class Tagged < String
  def initialize(v); @tag = :t; super(v); end
  def tag; @tag; end
  def norm!; gsub!("a", "b"); self; end
end
t = Tagged.new("aaa")
p [t, t.tag, t.norm!, t.length]

class Computed < Hash
  def initialize; @hits = 0; super(); end
  def [](k)
    super || store(k, k.to_s * 2)
  end
  def hits; @hits; end
end
c = Computed.new
p c[:ab]
p c
p c[:ab]

# a bang method with a block, and the non-bang form beside it
w = "FooBar"
p w.gsub!(/([A-Z])(?=[A-Z][a-z])|([a-z\d])(?=[A-Z])/) { ($1 || $2) + "_" }
p w
p "xyz".gsub!(/q/) { "!" }
p "abc".sub!(/b/) { |m| m.upcase }
