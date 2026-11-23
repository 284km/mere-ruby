# Kernel#Array asks a Hash or a Range for #to_a; Kernel#String refuses a
# #to_str that answers no String; Kernel.global_variables is a module
# function; Encoding.list is in ruby's order of registration
p Array({"bar" => "foo"}), Array(1..3), Array("s"), Array(nil), Array([1])
p Array({})

class BadToStr
  def to_str = 1
  def to_s = "s"
end
class NilToStr
  def to_str = nil
  def to_s = "n"
end
p((String(BadToStr.new) rescue [$!.class, $!.message]))
p String(NilToStr.new)

p Kernel.global_variables.include?(:$stdout)
p Kernel.global_variables.sort == global_variables.sort

p Encoding.list.first(12).map(&:name)
p Encoding.list.index(Encoding::UTF_16), Encoding.list.index(Encoding::EUC_JP)
p Encoding.list.size == Encoding.list.uniq.size
