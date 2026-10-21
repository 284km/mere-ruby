# Visibility inside a refinement and a refinement of a method the receiver
# only inherits, as test_refinement asks

class Cow
  private
  def moo() "Moo"; end
end
class CowSuper; private; def moo2() "Moo2"; end; end
class Cow2 < CowSuper; end
module PublicCows
  refine(Cow) { public :moo }
  refine(Cow2) { public :moo2 }
end
using PublicCows
p Cow.new.moo, Cow2.new.moo2

class Object
  private
  def m; :orig; end
end
module R
  refine Object do
    def m; :refined; end
  end
end
using R
p m, 42.m, "s".m, [1].m, nil.m

# a nearer ancestor's own method still beats a refinement further up
class Presenter < String; def red = "P"; end
module R2
  refine(String) { def red = "R" }
  refine(Object) { def to_s = "obj" }
end
using R2
p Presenter.new("a").red, "a".red, 42.to_s, Object.new.to_s, [1].to_s

module RB; refine(Object) { def foo; end }; end
p((begin; private(:foo); rescue NameError => e; [e.class, e.message]; end))
p((begin; private :foo; rescue NameError => e; [e.class, e.message]; end))
def top_m = 1
p private(:top_m), public(:top_m)
p Refinement.used_modules
