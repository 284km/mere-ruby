# Refinements as test_refinement asks for them (note 353).

# ---- 1. a refined operator is a method call ------------------------------
module IntSlash; refine Integer do; def /(o) = Rational(self, o); end; end
module IntPlus; refine Integer do; def +(o) = "overridden"; end; end
module SL; using IntSlash; def self.t = 1 / 2; def self.u = [3].map { |x| x / 2 }; end
p SL.t, SL.u, 1 / 2
module PL; using IntPlus; def self.t = 1 + 2; def self.u = (x = 1; x += 2; x); end
p PL.t, PL.u, 1 + 2

# ---- 2. case/when compares with a refined === ----------------------------
module RS; refine Symbol do; def ===(o) = true; end; end
module CaseUse; using RS; def self.t = (case :a; when :b then "refinement used" else "not used" end); end
p CaseUse.t, (case :a; when :b then "used" else "not used" end)

# ---- 3. a private refined method is refused to a receiver ----------------
class Foo3; def b = "Foo3#b"; end
module FooExt3; refine Foo3 do; def z = "FooExt3#z"; private def b = "private b"; end; end
module Client3
  using FooExt3
  def self.t(f) = [f.public_send(:z), (f.public_send(:b) rescue $!.class), (f.b rescue $!.class), f.send(:b)]
end
p Client3.t(Foo3.new), Foo3.new.public_send(:b)

# ---- 4. two refinements of one class are both active ---------------------
module RA4; refine Object do; def ra = 1; end; end
module RB4; refine Object do; def rb = 2; end; end
module Comb4; using RA4; using RB4; MODS = Module.used_modules; RFS = Module.used_refinements.map(&:inspect); def self.t = [ra, rb]; end
p Comb4::MODS, Comb4::RFS, Comb4.t
module RefA4; refine(String) { def shout = upcase + "!" }; end
module RefB4; include RefA4; refine(Integer) { def twice = self * 2 }; end
module UseB4; using RefB4; MODS = Module.used_modules; def self.t = ["a".shout, 3.twice]; end
p UseB4::MODS, UseB4.t
# ...and `using` inside a refine body adds to what that body's methods see
class C5; def foo = :orig_foo; end
module R15; refine C5 do; def foo = [:R1_foo, super]; end; end
module R25
  refine C5 do
    def bar = [:R2_bar, C5.new.foo]
    using R15
    def baz = [:R2_baz, C5.new.foo]
  end
end
module MU5; using R25; module_function; def f1 = C5.new.bar; def f2 = C5.new.baz; end
p MU5.f1, MU5.f2

# ---- 5. undef in a refine body, and the refusals of refine --------------
module NoPlus; refine String do; undef +; end; end
module UP; using NoPlus; def self.t = ("a" + "b" rescue $!.class); end
p UP.t, "a" + "b"
p((Class.new { refine(Integer) { } } rescue $!.class))
p((Module.new { refine(String, &Proc.new {}) } rescue [$!.class, $!.message]))

# ---- 6. a binding made in a module body keeps its lexical scope ---------
module Sandbox; BINDING = binding; end
eval(<<-EOS, Sandbox::BINDING)
  module MM; end
  p Module.nesting
  module M2; p Module.nesting; p MM; end
EOS
p((eval("recv = self; recv.using Module.new", Sandbox::BINDING) rescue [$!.class, $!.message]))
p((eval("$main = self; module MX; end; module M3; $main.send(:using, MX); end", Sandbox::BINDING) rescue [$!.class, $!.message]))

# ---- 7. where main.using may be called -----------------------------------
p((using(1) rescue [$!.class, $!.message]))
p((using(1) {} rescue [$!.class, $!.message]))
p((Module.new { using(1) {} } rescue [$!.class, $!.message]))
p((self.using(Module.new) rescue $!.class))
recv = self
p((recv.using(Module.new) rescue $!.class))
mm = Module.new
p((Module.new { TOPLEVEL_BINDING.receiver.send(:using, mm) } rescue [$!.class, $!.message]))
class UsingInM; def t(m) = TOPLEVEL_BINDING.receiver.send(:using, m); end
p((UsingInM.new.t(mm) rescue [$!.class, $!.message]))

# ---- 8. a refined Kernel method called with no receiver ------------------
module K1; refine(Kernel) { def f1 = :f1 }; end
module K2; refine(Kernel) { def f2 = :f2 }; end
class Foo8; using K1; using K2; def test = [f2, f1]; end
p Foo8.new.test
module M18; refine Kernel do; def foo = 'foo called!'; end; end
module M28; refine Kernel do; def bar = 'bar called!'; end; end
using M18
p foo, self.foo
p((bar rescue $!.class))
