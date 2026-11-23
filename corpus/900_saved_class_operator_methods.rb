# A class's operator Method saved before the class writes its own runs the
# builtin, as for #new (corpus 890): a saved `==` / `!=` under `def self.==`
# overflowed the stack (review of #178), and a saved `===` answered Kernel's
# identity instead of Module#===
class K1; EQ = method(:==); def self.==(o) = EQ.call(o); end
p K1 == K1, K1 == 1, K1 == Class.new
class K2; NE = method(:!=); def self.!=(o) = NE.call(o); end
p K2 != K2, K2 != 1
class K3; CMP = method(:<=>); def self.<=>(o) = [:own, CMP.call(o)]; end
p K3 <=> K3, K3 <=> Object
class K4; EQQ = method(:===); def self.===(o) = EQQ.call(o); end
p K4 === K4.new, K4 === 1
class K5; LT = method(:<); def self.<(o) = [:own, LT.call(o)]; end
p K5 < Object, K5 < String
class K6; TS = method(:to_s); def self.to_s = "own:" + TS.call; end
p K6.to_s
class K7; H = method(:hash); def self.hash = H.call; end
p K7.hash == K7.method(:hash).call
class K8; IN = method(:inspect); def self.inspect = "<#{IN.call}>"; end
p K8
# (`!=` asks the class's own `==`)
class K9
  NE = method(:!=)
  def self.==(o) = true
  def self.!=(o) = NE.call(o)
end
p K9 != 1
