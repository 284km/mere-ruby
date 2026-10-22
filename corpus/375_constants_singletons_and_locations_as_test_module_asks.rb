# Private constants reached through `::`, private_constant over a missing
# name, `def nil.x` inside a method, one String per source file name, and
# the object_id redefinition warning only where there is one to replace

class A
  C = :Const
  def self.get_C = A::C
  A.get_C
  private_constant :C, :D rescue p $!.message
  begin
    A.get_C
  rescue NameError => e
    puts "A.get_C: #{e.message}"
  end
end

class Outer
  class Inner; def x = 1; end
  private_constant :Inner
  class Inner; def y = 2; end
  p Inner.new.y
  module Deep; end
  private_constant :Deep
end
p((begin; class Outer::Inner; end; rescue NameError => e; e.message; end))
p((begin; module Outer::Deep::M; end; rescue NameError => e; e.message; end))

class TE
  def t
    def nil.tb = :nil_ok
    def true.tb2 = :true_ok
    [nil.tb, true.tb2]
  end
end
p TE.new.t

o = Object.new
o.instance_eval "def foo() end", "generated code"
o.instance_eval "def bar() end", "generated code"
a, b = o.method(:foo).source_location[0], o.method(:bar).source_location[0]
p a, a.equal?(b), a.frozen?

$stderr = $stdout
$VERBOSE = false
class BO < BasicObject
  def object_id; 1; end
end
class OO
  def object_id; 2; end
end
p BO.new.object_id, OO.new.object_id
