# A module in the ancestors twice, and the super that walks them (note 320):
# a prepended module stays where it is when the superclass prepends it too or
# the class also includes it ([M, C2, M, C1], [m, sc, m, c]), an include
# skips what the class had already prepended (a prepend made after an
# include does not undo it), and `super` resumes after the occurrence it was
# called from -- two steps through the same module, not a loop.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message[0,90]}"; end
  puts "#{n}: #{r.gsub(/0x\h+/, '0x')}"
end
t(1) { m = Module.new; c1 = Class.new { prepend m }; c2 = Class.new(c1) { prepend m }; [c2.ancestors.index(m), c2.ancestors[0, 4].map { |x| x == m ? :m : x == c2 ? :c2 : x == c1 ? :c1 : :other }] }
t(2) { m = Module.new { def x = [:m] + super }; c1 = Class.new { def x = [:c1] }; c2 = Class.new(c1) { def x = [:c2] + super; prepend m }; c1.class_eval { prepend m }; c2.new.x }
t(3) { c = Class.new { def m = [:c] }; sc = Class.new(c) { def m = [:sc] + super }; m = Module.new { def m = [:m] + super }; sc.include m; sc.prepend m; sc.prepend m; sc.new.m }
t(4) { c = Class.new { def m = [:c] }; sc = Class.new(c) { def m = [:sc] + super }; m0 = Module.new { def m = [:m0] + super }; m1 = Module.new { def m = [:m1] + super }; m1.prepend m0; sc.include m1; sc.prepend m1; r1 = sc.new.m; m = Module.new { def m = [:m] + super }; sc.prepend m; r2 = sc.new.m; sc.prepend m1; [r1, r2, sc.new.m] }
t(5) { c = Class.new { def m = [:c] }; p = Module.new { def m = [:p] + super }; q = Module.new { def m = [:q] + super; include p }; r = Module.new { def m = [:r] + super; prepend q }; s = Module.new { def m = [:s] + super; include r }; a = Class.new(c) { def m = [:a] + super; prepend p; include s }; a.new.m }
t(6) { m0 = Module.new { def x = [:m0, *super] }; m1 = Module.new { def x = [:m1, *super]; prepend m0 }; m3 = Module.new { include m1; prepend m1 }; m3b = Module.new { prepend m1; include m1 }; [m3.ancestors.size, m3b.ancestors.size] }
t(7) { m = Module.new; c = Class.new; c.prepend(m); c.include(m); m2 = Module.new; m2.prepend(m); c.include(m2); c.ancestors.size - Object.ancestors.size }
t(9) { m = Module.new { def f = [:m] + (defined?(super) ? super : []) }; a = Class.new { include m }; b = Class.new(a) { include m; def f = [:b] + super }; b.new.f }
