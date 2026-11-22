# A def after an alias round trip is a new definition: super searches its own
# name, and an alias of an alias names the first definition (issue #124)
class P; def example = :parent; def other = :p_other; end
class C < P
  def example = :old
  alias saved example
  m_old = instance_method(:example)
  alias example saved
  def example = [super, :new]
  p new.example, new.saved, instance_method(:saved).original_name, instance_method(:example).original_name
  p m_old.bind(new).call, m_old.original_name
  alias other2 other
  def other2 = :mine
  p new.other2, instance_method(:other2).original_name
end
module M; def hi = :m; end
class D; include M; alias hi2 hi; alias hi hi2; def hi = [:d, super]; end
p D.new.hi, D.new.hi2
