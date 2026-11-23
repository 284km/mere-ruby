# `super` from an override of #instance_exec / #instance_eval reaches the
# builtin, with the block: it was "super: no superclass method" once the
# override itself was reached (corpus 894), on an Array or Hash subclass too
module M
  def instance_exec(*a, &b)
    [:M, super]
  end
end
class X; include M; end
p X.new.instance_exec(1) { |v| [self.class, v] }
module E
  def instance_eval(*a, &b)
    [:E, super]
  end
end
class Y; include E; end
p Y.new.instance_eval { self.class }
p Y.new.instance_eval("self.class")
class A2 < Array
  def instance_exec(*a, &b)
    [:A, super]
  end
end
p A2.new([1]).instance_exec(2) { |v| [size, v] }
class H2 < Hash
  def instance_eval(*a, &b)
    [:H, super]
  end
end
p H2.new.instance_eval { size }
class Z
  def instance_exec(*a)
    [:Z, super]
  end
end
p Z.new.instance_exec(3) { |v| v * 2 }
o = Object.new
def o.instance_exec(*a, &b) = [:sng, super]
p o.instance_exec(4) { |v| v + 1 }
