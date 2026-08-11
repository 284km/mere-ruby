require "delegate"

class Wrapped < SimpleDelegator
  def extra; :extra; end
end
w = Wrapped.new([1, 2, 3])
p w.size, w.first, w.extra
p w.respond_to?(:size), w.respond_to?(:extra), w.respond_to?(:nope)
p w.map { |x| x * 2 }
p w.to_s
w.__setobj__([9])
p w.size, w == [9]

d = SimpleDelegator.new("hi")
p d.upcase, d.length, d.inspect

Q = DelegateClass(Array)
q = Q.new([4, 5])
p q.size, q.last

# `super` inside an overridden respond_to? reaches the builtin one
class Asker
  def known; 1; end
  def respond_to?(m, include_private = false)
    return true if m == :virtual
    super
  end
end
a = Asker.new
p a.respond_to?(:known), a.respond_to?(:virtual), a.respond_to?(:missing)

# respond_to? knows about the classes whose methods are primitives, so a
# delegator can forward to one
require "tempfile"
f = File.open("/tmp/mrb_corpus_delegate.txt", "w")
p f.respond_to?(:write), f.respond_to?(:nope)
d = SimpleDelegator.new(f)
p d.respond_to?(:write)
d.write("through the delegator")
f.close
p File.read("/tmp/mrb_corpus_delegate.txt")
File.delete("/tmp/mrb_corpus_delegate.txt")

t = Time.now
p t.respond_to?(:year), t.respond_to?(:nope)

# ...including through an explicit &block forward, which takes the block path
def forward(target, m, *a, &b)
  target.__send__(m, *a, &b)
end
g = File.open("/tmp/mrb_corpus_delegate2.txt", "w")
forward(g, :write, "forwarded")
g.close
p File.read("/tmp/mrb_corpus_delegate2.txt")
File.delete("/tmp/mrb_corpus_delegate2.txt")

# Tempfile, which is a DelegateClass(File)
tmp = Tempfile.new("demo")
p tmp.path.class
tmp.write("hello")
tmp.close
p File.read(tmp.path), tmp.size
saved = tmp.path
tmp.unlink
p File.exist?(saved)
Tempfile.create("blk") do |file|
  file.write("x")
  p file.path.class
end
