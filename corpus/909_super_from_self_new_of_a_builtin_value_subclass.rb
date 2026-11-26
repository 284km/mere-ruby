# `super` from a `def self.new` of a Hash, Array or String subclass is
# Class#new for that subclass: its instance is the builtin's storage, so the
# subclass's own `[]=` / `<<` reach Hash's / Array's / String's with super.
# It was a plain object, and the first `super` in a writer had nothing to
# reach -- puma's Util::HeaderHash (`self.new` is
# `HeaderHash === hash ? hash : super(hash)`), used by its CommonLogger.
class HeaderHash < Hash
  def self.new(hash = {})
    HeaderHash === hash ? hash : super(hash)
  end

  def initialize(hash = {})
    super()
    @names = {}
    hash.each { |k, v| self[k] = v }
  end

  def [](k)
    super(k) || super(@names[k.downcase])
  end

  def []=(k, v)
    canonical = k.downcase
    delete k if @names[canonical] && @names[canonical] != k
    @names[k] = @names[canonical] = k
    super k, v
  end
end
h = HeaderHash.new("Content-Type" => "text/plain")
p h, h.class, h["content-type"], h.size
p HeaderHash.new(h).equal?(h)
h["CONTENT-TYPE"] = "text/html"
p h

# ...with no initialize of its own, and with arguments and a block
class PlainH < Hash
  def self.new(*a, &b) = super
end
x = PlainH.new(0)
x[:a] += 1
p x, x.class, x[:missing]
y = PlainH.new { |hh, k| hh[k] = k.to_s * 2 }
p y[:ab], y

class Bag < Array
  def self.new(*a) = super
  def <<(v) = super(v * 3)
end
b = Bag.new
b << 1 << 2
p b, b.class, Bag.new(2, :z)

class Txt < String
  def self.new(*a) = super
  def <<(v) = super(v.upcase)
end
t = Txt.new("ab")
t << "cd"
p t, t.class, t.encoding
