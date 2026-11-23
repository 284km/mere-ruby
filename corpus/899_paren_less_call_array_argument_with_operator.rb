# `name [array] op rest` with no comma is a paren-less call whose ONE
# argument is the whole `[array] op rest` (name not a local): websocket-
# driver's `expect(@bytes).to eq [0x81, 0x7e, 0x00, 0xc8] + [0x48] * 40` was
# eq([...]) + ... -- and when name IS a local it is still the index
def eq(x) = [:eq, x]
def t(x) = x
p(t eq [1, 2] + [3] * 2)
x = t eq [1] + [2]
p x
p eq [1] + [2]
p(eq [1, 1] - [1])
p(eq [1] * 2)
p(eq [2] == [2])
p(eq [1] << 5)
p(eq [1] + [2] + [3])
y = eq [1, 0x7e] + [5] * 3
p y
eq = [10, 20, 30]
p eq [1] + 2
p eq [0] * 3
z = [7, 8]
p z [1] - 1
