# Argument forwarding as test_syntax asks (note 367): passing an anonymous
# `*`, `**`, `&` or `...` the method did not take is a SyntaxError, and so is
# one a block or lambda between took for itself; a string eval sees the
# calling method's; `def foo ...` and `def (expr).foo ...` without parens;
# `...` refused in a lambda, after a rest parameter, in yield, and with a
# block on super.
def chk(code, re = nil)
  r = begin
    catch(:valid) { eval("BEGIN{throw :valid, :v}\n" + code); :ran }
  rescue SyntaxError => e
    re ? (e.message =~ re ? :err_ok : :err_other) : :err
  end
  p [code, r]
end
chk("def b; c(&); end", /no anonymous block parameter/)
chk("def b(&) ->(&) {c(&)} end", /anonymous block parameter is also used/)
chk("def b(&) ->() {c(&)} end")
chk("def b; c(*); end", /no anonymous rest parameter/)
chk("def b; c(1, *); end", /no anonymous rest parameter/)
chk("def b(*) ->(*) {c(*)} end", /anonymous rest parameter is also used/)
chk("def b(a, *) ->(*) {c(1, *)} end", /anonymous rest parameter is also used/)
chk("def b(*) ->(a, *) {c(*)} end", /anonymous rest parameter is also used/)
chk("def b(*) ->() {c(*)} end")
chk("def b(a, *) ->() {c(1, *)} end")
chk("def b(*) ->(a) {c(*)} end")
chk("def b; c(**); end", /no anonymous keyword rest parameter/)
chk("def b; c(k: 1, **); end", /no anonymous keyword rest parameter/)
chk("def b(**) ->(**) {c(**)} end", /anonymous keyword rest parameter is also used/)
chk("def b(k:, **) ->(**) {c(k: 1, **)} end", /anonymous keyword rest parameter is also used/)
chk("def b(**) ->(k:, **) {c(**)} end", /anonymous keyword rest parameter is also used/)
chk("def b(**) ->() {c(**)} end")
chk("def b(k:, **) ->() {c(k: 1, **)} end")
chk("def b(**) ->(k:) {c(**)} end")
chk("def f(*, **, &); g(...); end", /unexpected \.\.\./)
chk("def f(...); g(*); end", /no anonymous rest parameter/)
chk("def f(...); g(0, *); end", /no anonymous rest parameter/)
chk("def f(...); g(**); end", /no anonymous keyword rest parameter/)
chk("def f(...); g(x: 1, **); end", /no anonymous keyword rest parameter/)
chk("def f(...); g(&); end", /no anonymous block parameter/)
chk('def foo(...) bar(...) end')
chk('def foo(...) end')
chk('def foo(a, ...) bar(...) end')
chk("def foo ...\n  bar(...)\nend")
chk("def foo a, ...\n  bar(...)\nend")
chk("def foo b = 1, ...\n  bar(...)\nend")
chk("def foo ...; bar(...); end")
chk("def foo a, ...; bar(...); end")
chk("def foo b = 1, ...; bar(...); end")
chk("(def foo ...\n  bar(...)\nend)")
chk("(def foo ...; bar(...); end)")
chk("def (1...).foo ...; bar(...); end")
chk("def (tap{1...}).foo ...; bar(...); end")
chk('def ==(...) end')
chk('def [](...) end')
chk('def nil(...) end')
chk('def true(...) end')
chk('def false(...) end')
chk('iter do |...| end', /unexpected/)
chk('iter {|...|}', /unexpected/)
chk('->... {}', /unexpected \.{3}/)
chk('->(...) {}', /unexpected \.{3}/)
chk('->(a,...) {}', /unexpected \.{3}/)
chk('->(a=1,...) {}', /unexpected \.{3}/)
chk('def foo(x, y, z) bar(...); end', /unexpected/)
chk('def foo(x, y, z) super(...); end', /unexpected/)
chk('def foo(...) yield(...); end', /unexpected/)
chk('def foo(...) return(...); end', /unexpected/)
chk('def foo(...) a = (...); end', /unexpected/)
chk('def foo(...) [...]; end', /unexpected/)
chk('def foo(...) foo[...]; end', /unexpected/)
chk('def foo(...) foo[...] = x; end', /unexpected/)
chk('def foo(...) defined?(...); end', /unexpected/)
chk('def foo(*rest, ...) end', /\.\.\. after rest argument/)
chk('def foo(*, ...) end', /\.\.\. after rest argument/)
chk('def foo(...) super {}; end')
chk('def foo(...) super() {}; end')
chk('def foo(...) super(...) {}; end', /both block arg and actual block/)
chk('def foo(...) super(1, ...) {}; end', /both block arg and actual block/)
def b1(&); c1(&) end
def c1(&); yield 1 end
a = nil; b1 { |c| a = c }; p a
def ev1(&) = eval("c1(&)")
p ev1 { |x| x + 1 }
def r1(*); c2(*) end
def c2(*a); a end
def r2(*); r1(*, *) end
def r3(*); eval("r1(*)") end
p r1(1, 2), r2(1, 2), r3(1, 2)
def k1(**); k2(**) end
def k2(**kw); kw end
def k3(**); k1(k: 1, **) end
def k4(**); k1(**, k: 1) end
def k5(a: nil, **); k1(**) end
def k6(**); eval("k1(**)") end
p k1(a: 1, k: 3), k3(a: 1, k: 3), k4(a: 1, k: 3), k5(a: 1, k: 3), k6(a: 1, k: 3)
o = Object.new
def o.bar(*args, **kws, &block) = block ? block.call(args, kws) : [args, kws]
o.instance_eval("def foo ...\n  bar(...)\nend")
p o.foo(4, 2, a: 1), o.foo(4) { |x, y| [y, x] }
p eval("-> (a: nil) {a...1}").call(a: 0)
chk("def b(*) = [1].each { |*| c(*) }", /anonymous rest parameter is also used within block/)
chk("def b(*) = [1].each { |a| c(*) }")
chk("def b(&) = [1].each { c(&) }")
chk("def b(*) = [1].each do |x, *| c(*) end", /anonymous rest parameter is also used within block/)
chk("def b(*); def c; d(*); end; end", /no anonymous rest parameter/)
chk("def b(...) = [1].each { c(...) }")
chk("def b(*) = proc { |*a| c(*) }")
chk("def b(**nil) = c(**)", /no anonymous keyword rest parameter/)
chk("def f(&) = yield(&)", /block argument should not be given/)
o2 = Object.new
def (o2).foo a, b = 2; [a, b]; end
p o2.foo(1)
