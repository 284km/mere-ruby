# A builtin method that changes its receiver refuses a frozen receiver also
# when it is reached by an ALIAS or by `super` from the class's own method of
# that name. The check was asked at the doors a call comes through by name,
# with the name that was called, and skipped for a name the class defines.
#
# HashWithIndifferentAccess writes through `alias_method :regular_writer,
# :[]=` from its own `[]=`, and deletes with `def delete(key) =
# super(convert_key(key))`. ActiveRecord's enum mapping is a frozen one, and
# `Book.statuses["bad_enum"] = 40` and `Book.statuses.delete("published")`
# changed it where ruby raises FrozenError.
def t
  yield
rescue => e
  [e.class, e.message]
end

class H2 < Hash
  alias_method :regular_writer, :[]=
  alias_method :regular_update, :update
  alias_method :regular_delete, :delete
  def []=(k, v)
    regular_writer(k.to_s, v)
  end
end
g = H2.new
g[:a] = 1
p g
g.freeze
p t { g[:b] = 2 }
p t { g.send(:regular_writer, "z", 1) }
p t { g.regular_update("q" => 1) }
p t { g.regular_delete("a") }
p g, g.frozen?

class A2 < Array
  alias_method :old_push, :push
  alias_method :old_set, :[]=
  alias_method :old_first, :first
end
a = A2.new
a.old_push(1)
p a, a.old_first
a.freeze
p t { a.old_push(2) }, t { a.old_set(0, 9) }, a, a.old_first

class S2 < String
  alias_method :old_concat, :<<
  alias_method :old_delete, :delete
  alias_method :old_upcase, :upcase
end
s = S2.new("xy").freeze
p t { s.old_concat("z") }, s
# (String#delete answers a new string: it is not a mutator)
p s.old_delete("x"), s.old_upcase

# on the classes themselves
class Array; alias_method :my_push, :push; end
class Hash; alias_method :my_store, :store; end
p t { [1].freeze.my_push(2) }, [1].my_push(2)
p t { { a: 1 }.freeze.my_store(:b, 2) }, { a: 1 }.tap { |h| h.my_store(:b, 2) }
# not frozen: the alias works as the builtin
u = H2.new
u.regular_writer("k", 1)
u[:j] = 2
p u, u.regular_delete("k"), u

# through super from the class's own method
class HS < Hash
  def delete(k) = super(k.to_s)
  def store(k, v) = super(k.to_s, v)
  def update(*a) = super
  def clear = super
end
hs = HS.new
hs["a"] = 1
hs.freeze
p t { hs.delete(:a) }, t { hs.delete(:zz) }, t { hs.store(:b, 1) }, t { hs.update("c" => 1) }, t { hs.clear }, hs
class AS < Array
  def push(*a) = super
  def delete(x) = super
  def <<(x) = super
end
as = AS.new([1, 2]).freeze
p t { as.push(3) }, t { as.push }, t { as.delete(1) }, t { as << 3 }, as
# (deleting what is not there changes nothing)
p t { as.delete(9) }
class SS < String
  def <<(x) = super
  def upcase! = super
  def delete(x) = super
end
ss = SS.new("xy").freeze
p t { ss << "z" }, t { ss.upcase! }, ss.delete("x"), ss
# not frozen: as before
hs2 = HS.new
hs2.store(:k, 1)
p hs2, hs2.delete(:k), hs2
