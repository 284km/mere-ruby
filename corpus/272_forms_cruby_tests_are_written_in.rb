# Forms CRuby's own tests are written in, each one a file of test/ruby that
# could not be read at all until it was.
m = Module.new
n = :X
m.module_eval "#{n} = 42", __FILE__, line = __LINE__
p [m::X, line.class]
VS = [1, 2]
(VS + VS.map { |b| [b, b] }).each { |b, i = b| p [b, i] }
x = 1
p(defined? (
  x
))
p(defined? (
))
begin
  begin
    raise "x"
  rescue 1
  end
rescue TypeError => e
  p e.class
end
def r(*a, **k) = [a, k]
p r(1, "foo" => "bar", foo: "bar")
p(r "a" => 1, b: 2, **{c: 3})
def k(**kw) = kw
p k(random: nil, "invalid-argument": nil)
d = 1
p %W"cp932 #{d}/\225\\", %W[\u{7559 5b88}:\u{756a} \x41 a\tb], %I[a#{d} b]
h = Hash[
  1 => 'one', 2 => 'two',
]
p h, Array[
  1,
  2,
]
f = ->(a:, **kw) { [a, kw] }
p f[a: 1, **{x: 1}], f[**{a: 2}]
p("%#x"%255)
class C
  def default=
    :set
  end
  def self.a(b: 1, **) = [b, **]
  def self.g(*, **) = [*, **]
  def []=(a, b)
    block_given?
  end
end
p C.new.send(:default=), C.a(b: 2, c: 3), C.g(1, z: 2)
p C.new.[]=('', 1) {}
o = Object.new
def o.to_regexp() /foo/ end
p o.to_regexp
p Module.new { extend } rescue p $!.class
p(/\A[[:0]]\z/ =~ ":", /\A[[:0]]\z/ =~ "0", /\A[[:0]]\z/ =~ "a")
def t(x)
  return until x unless x
  :end
end
p t(true)
[1].each do |_,
  b = 2,
  *|
  p b
end
case {a: 2}
in {a:
      2}
  p :braced
end
case "x"
in "#{"x"}"
  p :interp
end
