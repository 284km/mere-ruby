# $~ (and $1..$9, $&, $`, $', $+ read out of it) belongs to the METHOD FRAME a
# block is written in, wherever the block runs (note 351). A method yielding to
# a block does not see the block's match, and the block does not see the
# method's. A Fiber's or Thread's body has its own; an Enumerator's block
# matches into the code that made it, through #next.

# ---- 1. yield, &pr, lambdas, procs whose method has returned --------------
obj = Object.new; def obj.foo; yield; end; def obj.foo2(&pr) = pr.call
m1 = /foo/.match "foo"; obj.foo { /bar/.match("bar") }; p $~&.to_s
obj.foo2 { /baz/.match("baz") }; p $~&.to_s
def mm = (yield; $~&.to_s); p mm { /q/.match("q") }
p $~&.to_s
[1].each { /e/ =~ "e" }; p $~&.to_s
l = -> { /lam/ =~ "lam" }; l.call; p $~&.to_s
def obj.foo3; /in3/ =~ "in3"; yield; $~&.to_s; end
p obj.foo3 { p $~&.to_s; /blk3/ =~ "blk3" }; p $~&.to_s
class C; define_method(:dm) { /dm/ =~ "dm"; $~&.to_s }; end
/top/ =~ "top"; p C.new.dm; p $~&.to_s
def mk; /mk/ =~ "mk"; proc { $~&.to_s }; end
pr = mk; /after/ =~ "after"; p pr.call; p $~&.to_s
def nest; [1].map { [2].each { /deep/ =~ "deep" } }; $~&.to_s; end; p nest
def rec(n, &b) = n == 0 ? b.call : rec(n - 1, &b)
def outer; rec(3) { /rr/ =~ "rr" }; $1; $~&.to_s; end; p outer
/(x)/ =~ "x"; obj.foo { p $1 }; p $1
"a1".gsub(/\d/) { obj.foo { /z/ =~ "z" }; "" }; p $~&.to_s

# ---- 2. raise, break, throw, return, ensure, nesting, Ruby-written each ---
def r1; /r1/ =~ "r1"; raise "x"; end
/top/ =~ "top"; begin; r1; rescue; p $~&.to_s; end
def y1; yield; end
def b1; y1 { /b1/ =~ "b1"; break }; $~&.to_s; end; p b1; p $~&.to_s
def t1; catch(:k) { y1 { /t1/ =~ "t1"; throw :k } }; $~&.to_s; end; p t1
def ret1; y1 { /ret/ =~ "ret"; return $~&.to_s }; end; p ret1; p $~&.to_s
o = Object.new; o.instance_eval { /ie/ =~ "ie" }; p $~&.to_s
String.class_eval { /ce/ =~ "ce" }; p $~&.to_s
def rec(n); return y1 { /deep#{n}/ =~ "deep#{n}"; $~&.to_s } if n == 0; r = rec(n - 1); [r, $~&.to_s]; end; p rec(2)
h = {a: 1}; h.each_pair { /hp/ =~ "hp" }; p $~&.to_s
x = "abc".gsub(/b/) { y1 { /in/ =~ "in" }; $~&.to_s }; p x, $~&.to_s
e = Enumerator.new { |yy| /en/ =~ "en"; yy << $~&.to_s; yy << 2 }; p e.next; p $~&.to_s
def mkp; /mkp/ =~ "mkp"; proc { $~&.to_s }; end; pp1 = mkp; p y1(&pp1); p $~&.to_s
def ens; y1 { /ens/ =~ "ens" }; ensure; p $~&.to_s; end; ens
def nest2; y1 { y1 { /n2/ =~ "n2" } }; $~&.to_s; end; p nest2
p [1, 2].each_slice(1).map { |a| /sl/ =~ "sl"; $~&.to_s }; p $~&.to_s
def kw(a:) = a; begin; /pre/ =~ "pre"; kw; rescue ArgumentError; end; p $~&.to_s
p [3].sum { /su/ =~ "su"; 1 }; p $~&.to_s
s = Struct.new(:a); s.new(1).each { /st/ =~ "st" }; p $~&.to_s
class E2; include Enumerable; def each; yield 1; yield 2; end; end
p E2.new.select { |i| /se#{i}/ =~ "se#{i}" }; p $~&.to_s
def mm2; "q" =~ /q/; [1].map { $~&.to_s }; end; p mm2
p (1..2).each_with_object([]) { |i, a| a << ($~&.to_s) }

# ---- 3. Fibers, Threads, Enumerators ---------------------------------
def y1; yield; end
/top/ =~ "top"
f = Fiber.new { y1 { /fy/ =~ "fy" }; p $~&.to_s; Fiber.yield 1; p $~&.to_s; /f2/ =~ "f2" }
f.resume; p $~&.to_s; /mid/ =~ "mid"; f.resume; p $~&.to_s
def menum; /me/ =~ "me"; e = Enumerator.new { |y| /in/ =~ "in"; y << 1 }; e.next; $~&.to_s; end; p menum; p $~&.to_s
class E3; include Enumerable; def each; /each/ =~ "each"; yield 1; yield 2; end; end
en = E3.new.each_entry; p en.next; p $~&.to_s
en2 = E3.new.to_enum; x = en2.next; p $~&.to_s
t = Thread.new { y1 { /ty/ =~ "ty" }; $~&.to_s }; p t.value; p $~&.to_s
p (1..3).lazy.map { |i| /lz#{i}/ =~ "lz#{i}"; i }.first(2); p $~&.to_s
g = Enumerator.new { |y| 3.times { |i| y << i } }; p g.take(2); p $~&.to_s
def fib_in_m; /fm/ =~ "fm"; Fiber.new { y1 { /fz/ =~ "fz" }; $~&.to_s }.resume; end; p fib_in_m; p $~&.to_s
ext = [1,2].each_with_index; /ew/ =~ "ew"; p ext.next; p $~&.to_s
z = Enumerator.new { |y| y << $~&.to_s }; /zz/ =~ "zz"; p z.next
