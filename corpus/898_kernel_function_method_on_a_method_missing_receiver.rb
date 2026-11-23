# A Method of a Kernel function -- `method(:Integer)` -- runs Kernel's, also
# on a receiver with #method_missing: re-dispatched by name it went to the
# receiver's method_missing (rspec's example group answers that with "is not
# available from within an example"; msgpack's factory_spec unpacks with
# `unpacker: method(:Integer)`)
class Catcher
  def method_missing(n, *a) = "mm:#{n}"
  def respond_to_missing?(*) = true
end
m = Catcher.new.instance_eval { method(:Integer) }
p m.call("42")
p m.to_proc.call("43")
p m.("44")
p [m.owner, m.name, m.receiver.class]
p ["45"].map(&m)
p m.unbind.bind_call(Catcher.new, "46")
p Catcher.new.instance_eval { method(:Float) }.call("1.5")
p Catcher.new.instance_eval { method(:format) }.call("%03d", 7)
p Catcher.new.zork
# ...and a receiver whose class defines the name keeps its own
class Own
  def Integer(x) = :own
  def method_missing(*) = :mm
end
p Own.new.method(:Integer).call(1)
