# module_function copies a define_method body WITH its closure, from the
# module itself and from one it includes (erb's ERB::Util does
# `include ERB::Escape; module_function :html_escape`)
module M
  v = 5
  define_method(:x) { v + 1 }
  module_function :x
end
p M.x
module E
  w = 7
  define_method(:y) { |a = 1| w * a }
end
module U
  include E
  module_function :y
  alias z y
  module_function :z
end
p U.y, U.y(2), U.z(3)
p U.method(:y).arity, U.respond_to?(:y)
