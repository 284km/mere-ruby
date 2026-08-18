# `obj.singleton_class` and `class << obj` open the SAME singleton class, and
# only one of them worked on a String, Array or Hash. singleton_class built the
# class name and its superclass link but never recorded it as the value's class,
# which is where dispatch looks -- so a method defined through it was never
# found, silently, while the `class << obj` form worked.
a = []
a.singleton_class.define_method(:first) { :ok }
p a.first
p [].first                      # another array is untouched

s = +"x"
s.singleton_class.define_method(:upcase) { :up }
p s.upcase
p "x".upcase

h = {}
h.singleton_class.define_method(:size) { :sz }
p h.size

o = Object.new
o.singleton_class.define_method(:hi) { :hello }
p o.hi

# the two forms agree, and the second still sees the first
b = []
b.singleton_class.define_method(:one) { 1 }
class << b
  def two; 2; end
end
p [b.one, b.two]

# and the singleton's superclass is still the real class, so unaliased methods
# keep working
p b.length
p b.class
