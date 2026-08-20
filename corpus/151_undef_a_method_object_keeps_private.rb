# `undef` names a method the object HAS -- and Object has private ones. ruby/spec's
# kernel fixtures open with `undef :respond_to_missing?`, one line that every file
# in the group loads, and refusing it took 88 of 118 files down before a single
# example ran. The name cannot simply join the primitive list either: it is
# private on Object, so `respond_to?(:respond_to_missing?)` stays false.
class A
  def pub; :pub; end
  def method_missing(m, *a); :mm; end
end
class B < A
  undef :respond_to_missing?
end
b = B.new
p [b.respond_to?(:pub), b.respond_to?(:zzz), b.respond_to?(:respond_to_missing?)]
p b.zzz                       # method_missing still answers

# a class that DEFINES the hook is consulted, as before
class C
  def respond_to_missing?(m, priv = false); m == :ghost; end
end
p [C.new.respond_to?(:ghost), C.new.respond_to?(:nope)]

# undef on a real method: the method is gone, and gone through inheritance too
class D < A
  undef :pub
end
p D.new.respond_to?(:pub)
p D.new.pub                   # ... so it reaches method_missing
p [A.new.respond_to?(:pub), A.new.pub]

# a name nothing provides is still a NameError (its wording is the interpreter's,
# so only the class is compared here)
begin
  class E; undef :no_such_method_anywhere; end
rescue NameError => e
  p e.class
end
