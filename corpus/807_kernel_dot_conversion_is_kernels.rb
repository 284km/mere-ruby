# `Kernel.Integer(x)` (and Float, String, Array, ...) is Kernel's own
# conversion, whatever the caller's self has under the name. A bare
# `Integer(x)` is a call on self, so in a module with a module function
# Integer -- OpenSSL::ASN1's -- it calls that one; `Kernel.Integer` and
# `::Kernel.Integer` do not, and neither sees a program's `Kernel#Integer`.
module Conv807
  def self.Integer(x) = [:own, x]
  def self.Float(x) = [:own_f, x]
  def self.k = [Kernel.Integer("12"), ::Kernel.Integer(3), Kernel.Float("1.5"), Kernel.String(4), Kernel.Array(nil)]
  def self.bare = [Integer(1), Float(2)]
  def self.sent = Kernel.send(:Integer, "5")
end
p Conv807.k, Conv807.bare, Conv807.sent

module Kernel
  def Integer(x) = :kernel_instance
end
p Kernel.Integer("6"), Integer("7")

class Conv807C
  def self.load(*) = :own_load
  def self.check = Kernel.respond_to?(:load)
end
p Conv807C.check
