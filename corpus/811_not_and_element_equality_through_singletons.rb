# `!x` (and `not x`) is the receiver's own #! when its class -- or Object --
# has one, else the truth turned over; the VM answers the plain case without
# a scope. And an Array or Hash whose element has a singleton or subclass #==
# asks that #== for the element, even when the two are twins in content.
class Foo811; def ! = :foo_not; end
class Bar811; end
p [!true, !false, !nil, !1, !"a", ![], !Bar811.new, !Foo811.new, (not Foo811.new), !:sym]
a = [1]
n = 0
n += 1 while !a.empty? && n < 3
p n

x = +"k"; def x.==(o) = true
y = +"k"; def y.==(o) = false
class SubEq811 < String; def ==(o) = true; end
p [[x] == ["zzz"], {a: x} == {a: "zzz"}, [y] == ["k"], [y] == [y], [[x]] == [["q"]],
   [SubEq811.new("a")] == ["b"], ["zzz"] == [x], [1, x] != [1, "z"]]

class NilClass; def ! = :nil_not; end
p [!nil, (not nil)]
class Object; def ! = :obj_not; end
p [!1, !"z", !Bar811.new]
