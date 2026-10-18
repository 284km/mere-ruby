# Paren-less calls as ruby reads them (note 369): `q *a`, `q **h` and `p &b`
# pass a splat / keyword splat / block as the first argument (a space before
# the operator, none after, and a method name before it -- -w says the
# operator was taken as an argument prefix); after a local or a literal it
# is the binary operator. `def f *a` and `attr_reader *names`. A do inside a
# command's `begin`, hash or array argument is the inner call's, and a brace
# block after a literal last argument is refused.
require 'stringio'
def q(*a, **k, &b) = [a, k, b ? b.call : nil]
x = q *[1, 2]; p x
p q **{a: 1}
p(q *[3], **{b: 2})
p *[1, 2]
pp *[5]
print *["a", "b", "\n"]
b = proc { :blk }
p q &b
x = 3; p x *2
p 3 *2
p [1, 2].size *1 rescue p $!.class
def f *a; a; end
p f(1, 2)
class C; attr_reader *%i[c1 c2]; end
p C.instance_methods(false).sort
def m(*a) = yield(a)
m *[7] do |v| p v end
def warns(src)
  old, $stderr = $stderr, StringIO.new
  ov, $VERBOSE = $VERBOSE, true
  eval(src, nil, "w.rb")
  out = $stderr.string
  $stderr = old; $VERBOSE = ov
  out.lines.map(&:strip)
end
p warns("def __q1(*a, **k, &b) = a; __q1 *[1]; __q1 **{}; b = nil; __q1 &b")
p warns("x = [1]; x.each &->(v) {}")
def chk(code)
  r = begin
    catch(:valid) { eval("BEGIN{throw :valid, :v}\n" + code); :ran }
  rescue SyntaxError => e
    e.message.include?("unexpected '{'") ? :brace : :err
  end
  p [code, r]
end
["p begin 1.times do 1 end end", "p -> { :hello }, a: 1 do end",
 "p :foo, {a: proc do end, b: proc do end}", "p :foo, {:a => proc do end, b: proc do end}",
 "p :foo, {\"a\": proc do end, b: proc do end}", "p :foo, {** proc do end, b: proc do end}",
 "p :foo, {proc do end => proc do end, b: proc do end}", "p :foo, [proc do end]",
 "cmd 1, 2 do end.m() { blk_body }",
 'm "x" {}', "m 1 {}", "m 1.0 {}", "m :m {}", "m ?x {}", "m 0..1 {}", "m x {}"].each { |c| chk(c) }
p(begin [1].map do |v| v * 10 end end)
