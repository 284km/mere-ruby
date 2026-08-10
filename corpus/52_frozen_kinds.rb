# frozen state is per (kind, handle): freezing an array must not freeze the
# hash that happens to share its handle id, and vice versa.
a = [1, 2].freeze
h = {}
p a.frozen?, h.frozen?
h[:x] = 1
p h

g = { k: 1 }.freeze
b = []
p g.frozen?, b.frozen?
b << 9
p b

s = "str".freeze
c = []
d = {}
p s.frozen?, c.frozen?, d.frozen?

# several of each, interleaved, so the ids definitely overlap
arrs = 5.times.map { [] }
hshs = 5.times.map { {} }
arrs.each(&:freeze)
p hshs.map(&:frozen?)
p arrs.map(&:frozen?)
hshs.each { |x| x[:a] = 1 }
p hshs

# the memo-cache shape that rubygems' Gem::Version uses
class Memo
  RADIX = [9, 3].freeze
  @@all = {}
  def self.get(k)
    @@all[k] ||= k * 2
  end
end
p Memo.get(3), Memo.get(3)

# dup / clone of a frozen collection
fa = [1].freeze
p fa.dup.frozen?, fa.clone.frozen?
fh = { a: 1 }.freeze
p fh.dup.frozen?
