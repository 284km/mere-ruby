# Rounds 8 and 9 of note 537 (the small core items and the libraries): a plain
# object key is its identity in the hash index; Hash#merge keeps the subclass
# and update/merge!/replace check frozen before #to_hash; String#=== asks an
# object with #to_str; Array#== under the cycle guard with an object's #==;
# the timezone protocol's #local_to_utc; Numeric#step's edges; #clone keeps a
# define_singleton_method closure; a class's protected singleton method is not
# respond_to?; `x&.m(&pr)`; Kernel.load / .puts / .format from a class that
# defines its own; WeakKeyMap's stored keys.

# --- object keys: identity, overwrite, delete, and the protocol beside them
class K
  attr_reader :v
  def initialize(v) = @v = v
  def hash = @v.hash
  def eql?(o) = o.is_a?(K) && o.v == @v
end
h = {}
objs = Array.new(2000) { Object.new }
objs.each_with_index { |o, i| h[o] = i }
p [h.size, h[objs[0]], h[objs[1999]], h[Object.new]]
h[objs[5]] = :five
h.delete(objs[6])
p [h.size, h[objs[5]], h.key?(objs[6]), h.key?(objs[7])]
h[K.new(1)] = :k
h[K.new(1)] = :k2
p [h.size, h[K.new(1)]]
c = {}.compare_by_identity
c[objs[0]] = 1
p [c[objs[0]], c[Object.new]]
S = Struct.new(:x)
p({S.new(1) => :s}[S.new(1)])

# --- Hash#merge keeps the subclass; update checks frozen before #to_hash
class SubH < Hash; end
p SubH[1, 2].merge({3 => 4}).class
th = Object.new
def th.to_hash = (raise "asked to_hash")
fz = {}.freeze
%i[update merge! replace].each do |m|
  begin
    fz.send(m, th)
  rescue => e
    p [m, e.class]
  end
end

# --- String#=== asks an object with #to_str for obj == self
ts = Object.new
def ts.to_str = "abc"
def ts.==(o) = o == "abc"
p ["abc" === ts, "abd" === ts]
class SubS < String; end
p SubS.new("q").to_str.class

# --- Array#== with self-holding arrays and an object answering #==
ao = Object.new
def ao.respond_to?(m, priv = false) = m == :to_ary ? true : super
def ao.==(o) = o == [1]
a1 = [[1]]; a1 << a1
a2 = [ao]; a2 << a2
p [[1] == ao, a1 == a2, a2 == a1]

# --- the timezone protocol: #local_to_utc's Time is its instant
z9 = Object.new
def z9.local_to_utc(t) = Time.new(t.year, t.mon, t.mday, t.hour, t.min, t.sec, 9 * 3600)
p Time.new(2000, 1, 1, 12, 0, 0, z9).utc_offset
zfar = Object.new
def zfar.local_to_utc(t) = Time.utc(t.year, t.mon, t.day + 1, t.hour, t.min, t.sec)
zu = Object.new
def zu.utc_to_local(t) = t
[zfar, zu, {}, Object.new].each do |z|
  begin
    Time.new(2000, 1, 1, 12, 0, 0, z)
    p :none
  rescue => e
    p [e.class, e.message]
  end
end

# --- Numeric#step at its edges
inf = Float::INFINITY
def st(*a) = (r = []; a[0].step(*a[1..]) { |x| r << x; break if r.size > 3 }; r)
p st(inf, inf, 1), st(-inf, -inf, -1), st(42, inf, 1), st(42, -inf, -1)
p 1.0.step.first(3), (-inf..0.0).step(2).first(2), (0.0...inf).step(2).first(3)
p [1.step(5, "x").class, 1.step(5, 1).class, 1.0.step(2.0, by: 0.5).class]
begin; 1.step(5, 1, to: 5) { break }; rescue ArgumentError => e; p e.message; end
begin; 1.1.step(5.1, by: "1") { }; rescue ArgumentError => e; p e.message; end

# --- #clone keeps a define_singleton_method body's closure
class Rec
  def initialize = (@t = {a: 1}; mk(:a))
  def mk(name) = define_singleton_method(name) { @t[name] }
end
r = Rec.new
r.freeze
p [r.clone.a, r.clone.frozen?]

# --- a class's protected singleton method is not respond_to?
class Pz
  class << self
    def pa = 1
    protected :pa
  end
end
p [Pz.respond_to?(:pa), Pz.respond_to?(:pa, true)]

# --- `x&.m(&pr)` passes the block
got = []
pr = proc { |x| got << x }
{"a" => [1, 2]}["a"]&.each(&pr)
p got

# --- Kernel's module functions from a class that defines the same names
class Lo
  def puts(*a) = Kernel.puts("k:" + a.join)
  def format(*) = "mine"
  def fmt = Kernel.format("%03d", 7)
end
Lo.new.puts("x")
p Lo.new.fmt

# --- WeakKeyMap: the stored key is the one given, by equality
wk = ObjectSpace::WeakKeyMap.new
k1 = "key"
wk[k1] = 1
wk["key".dup] = 2
p [wk.getkey("key").equal?(k1), wk["key"], wk.key?("key"), wk.delete("key"), wk.key?("key")]
begin; wk[:sym] = 1; rescue ArgumentError => e; p e.class; end

# --- three the eql matcher found: Rational#to_i truncates; Float#divmod's
# quotient is rounded as flodivmod rounds it; Numeric#eql? asks #==
p [Rational(-7, 4).to_i, Rational(7, 4).to_i, Rational(-1, 2).to_i]
p 0.59.divmod(7.761021455128987e-11), 7.5.divmod(2), (-7.5).divmod(2)
class MyNum < Numeric
  def ==(o) = o.is_a?(MyNum)
end
p [MyNum.new.eql?(MyNum.new), MyNum.new.eql?(1)]
