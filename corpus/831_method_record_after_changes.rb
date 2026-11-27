# What a call reads of a method's definition -- the name it was defined as,
# its cref, its parameters, its lines, its label in a backtrace -- follows
# the method through what is done to it after it was first called: an alias,
# a redefinition, module_function, ruby2_keywords, a refinement,
# remove_method, a Method held across a redefinition, a top-level method.
class C
  def a(x) = [:a, x, __method__]
  def b = a(1)
end
c = C.new
p c.b
class C; alias aa a; end
p c.aa(2)
class C; def a(x) = [:a2, x, __method__]; end
p c.b, c.aa(3)

held = c.method(:a)
class C; def a(x) = [:a3, x]; end
p held.call(4), c.a(5)

module M; def m = [:m, __method__]; end
class D; include M; end
p D.new.m
module M; module_function :m; end
p M.m

class E; def k(*a) = a; end
p E.new.k(1, {x: 1})
class E; ruby2_keywords :k; end
p E.new.k(1, x: 2)

module R; refine(C) { def b = [:refined] }; end
using R
p c.b

class C; remove_method :aa; end
p((c.aa(1) rescue $!.class))

def top(x) = [x, __method__]
p top(1)
alias top2 top
p top2(2)
def top(x) = [:again, x]
p top(3), top2(4)

class F; @@v = 1; def v = @@v; end
p F.new.v
class C; define_method(:dm) { |x| [x, __method__] }; end
p c.dm(5)

def where = caller(0).first(2).map { _1.sub(/^.*?:\d+:/, "") }
class G; def g = where; end
p G.new.g
class G; alias gg g; end
p G.new.gg

class H
  def go(n) = n.zero? ? __method__ : go(n - 1)
end
p H.new.go(3)
