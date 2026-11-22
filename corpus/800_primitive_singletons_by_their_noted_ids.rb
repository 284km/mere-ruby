# A String, Hash, Proc or Binding with a class of its own -- a singleton
# method, an extend, a subclass's instance -- is found by its id, noted when
# the class is recorded (hng_put), before its "kind:id" key is made; one with
# none is not asked about by key at all (hng_key_q). The note follows a clone,
# goes with the entry when a collection drops it, and a value that never had
# one dispatches as its class does.
s = +"abc"
def s.shout = upcase + "!"
p s.shout
p s.singleton_methods
t = s.clone
p t.shout
u = s.dup
p((u.shout rescue $!.class))
p "plain".respond_to?(:shout)

h = {a: 1}
def h.first_key = keys.first
p h.first_key
p({b: 2}.respond_to?(:first_key))

pr = proc { |x| x * 2 }
def pr.twice(x) = call(call(x))
p pr.twice(3)
p proc { }.respond_to?(:twice)

b = binding
class << b
  attr_accessor :tag
end
b.tag = :marked
p b.tag
p binding.respond_to?(:tag)

module Loud
  def loud = to_s.upcase
end
a = [1, 2]
a.extend(Loud)
p a.loud
p [3].respond_to?(:loud)
hs = {k: :v}
hs.extend(Loud)
p hs.loud

class MyStr < String
  def kind = :mine
end
m = MyStr.new("x")
p m.class, m.kind
p (m + "y").class

# a singleton's method_missing on a String
q = +"q"
def q.method_missing(n, *a) = n == :zz ? [:mm, n] : super
p q.zz
p((q.yy rescue $!.class))

# values made and dropped: their notes do not answer for new values
10.times do |i|
  x = +"tmp#{i}"
  def x.only_me = :me
  x.only_me
end
GC.start
fresh = (1..10).map { |i| +"tmp#{i}" }
p fresh.map { |f| f.respond_to?(:only_me) }.uniq
p s.shout, h.first_key, pr.twice(1), b.tag, a.loud
