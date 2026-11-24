# A `shareable_constant_value` constant whose value is not a literal, in
# each kind of constant write and under each of the three settings.
#
# ruby compiles the write as it compiles any, and the value specially: a
# literal is made shareable as it is compiled; an Array or a Hash is built
# of its elements and made shareable; anything else is checked (under
# `literal`: "cannot assign unshareable object to X", with the constant's
# path) or made shareable, or copied and the copy made shareable. The ISeq
# VM ran no file with such a write: neither compiler compiled one.
def err
  yield
  :ok
rescue Ractor::Error, NameError, FrozenError => e
  [e.class, e.message]
end
def sh(*xs) = xs.map { |x| Ractor.shareable?(x) }
def owner = Holder
Holder = Class.new
src = [["x"], {"k" => ["v"]}]
one = 1

# shareable_constant_value: experimental_everything
EvLit = [[1], "s"]
EvVar = src
EvCall = [one.to_s, [one.to_s]]
EvHash = {one => "v", k: [one.to_s]}
EvStr = "a#{one}b"
Holder::EvPath = [one.to_s]
::EvTop = one.to_s
EvOr ||= [one.to_s]
EvOr ||= [:not_assigned]
Holder::EvPathOr ||= {a: one.to_s}
EvOp = [0]
EvOp += [one.to_s]
EvAnd = [0]
EvAnd &&= [one.to_s]
p sh(EvLit, EvVar, EvCall, EvHash, EvStr, Holder::EvPath, EvTop, EvOr, Holder::EvPathOr, EvOp, EvAnd)
p EvVar.equal?(src), src.frozen?, src[1]["k"][0].frozen?, EvOr, EvOp, EvAnd, EvStr.frozen?
# shareable_constant_value: none
src2 = [["y"]]

# shareable_constant_value: experimental_copy
CpVar = src2
CpArr = [src2, one.to_s]
CpHash = {src2 => src2}
Holder::CpPath = src2
CpOr ||= src2
p sh(CpVar, CpArr, CpHash, Holder::CpPath, CpOr), sh(src2)
p CpVar.equal?(src2), CpVar == src2, CpArr[0].equal?(src2), Holder::CpPath.equal?(src2), CpOr.equal?(src2)

# shareable_constant_value: literal
LtLit = [["a", :b], 1..2, nil, 1.5, {k: "v"}]
LtRef = EvLit
LtDstr = ["shareable", "constant#{nil}"]
p sh(LtLit, LtRef, LtDstr), LtRef.equal?(EvLit), LtDstr[1].frozen?
LtMix = {one => "bar", "k" => [one, :s]}
p LtMix, sh(LtMix)
p err { LtBad = ["Not " + "shareable"] }
p err { v = [:x]; LtVar = v }
p err { LtBegin = begin [] end }
p err { LtFrozen = [[1]].freeze }
p err { Holder::LtPath = ["N" + "s"] }
p err { ::LtTop ||= ["N" + "s"] }
p err { Holder::LtPathOr ||= ["N" + "s"] }
p err { owner::LtDyn ||= ["N" + "s"] }
p err { owner::Deep::LtDyn2 = ["N" + "s"] }
p err { LtInner = [1, [2, ["N" + "s"]]] }
p err { LtKey = {("N" + "s") => 1} }
LtOp = [0]
p err { LtOp += [[1]] }
p LtOp, sh(LtOp)
p defined?(LtBad), defined?(LtVar), defined?(Holder::LtPath), defined?(LtTop), defined?(LtInner)
# ...a value that is shareable passes the check, whatever it is
LtOk1 = one
LtOk2 = [one, :sym, one.to_s.freeze, nil, Object, (one..2)]
LtOk3 = "a#{one}b"
Holder::LtOk4 ||= [one.to_s.freeze]
p sh(LtOk1, LtOk2, LtOk3, Holder::LtOk4), LtOk3, LtOk3.frozen?
# shareable_constant_value: none
After = [["z"]]
p sh(After), After.frozen?

# inside a class body and a method's eval, the setting is the place's own
class Body
  # shareable_constant_value: experimental_everything
  inner = [[1]]
  In = inner
end
Out = [[2]]
p sh(Body::In, Out)
p eval("# shareable_constant_value: literal\nEvaled = [one, [one]]\nRactor.shareable?(Evaled)")
p err { eval("# shareable_constant_value: literal\nEvaledBad = [one.to_s]") }

# `X op= v` is the operation as it is, and only v is the shareable value: so
# the result of `+=` is an Array nobody made shareable, and under `literal`
# what is checked is v. With an owner too, a constant's or anything else.
# shareable_constant_value: experimental_everything
Holder::OpA = [0]
Holder::OpA += [one.to_s]
Holder::OpB = 1
Holder::OpB &&= [one.to_s]
owner::OpC = [0]
owner::OpC += [one.to_s]
::OpD = [0]
::OpD += [one.to_s]
p sh(Holder::OpA, Holder::OpB, Holder::OpC, OpD), Holder::OpA, Holder::OpC
# shareable_constant_value: literal
Holder::OpE = [0]
p err { Holder::OpE += [[1]] }, Holder::OpE, sh(Holder::OpE)
p err { Holder::OpE += [[one.to_s]] }, Holder::OpE
Holder::OpF = 1
p err { Holder::OpF &&= [one.to_s] }, Holder::OpF
p err { Holder::OpF &&= [one] }, Holder::OpF
OpG = [1]
p err { OpG = OpG + [[2]] }, OpG
# shareable_constant_value: none
