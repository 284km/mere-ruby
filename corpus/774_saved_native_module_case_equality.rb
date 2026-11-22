# A Ruby Module#=== wrapper over the SAVED native comparator: `case` against
# an ordinary class reaches Module's native === through it, by alias and by
# define_method(Module.instance_method(:===)); a saved Kernel#=== keeps
# Kernel's meaning (identity), whatever object it is called on.
# (first, before Module's own === is wrapped: the singleton wrapper of one
#  class over its own saved comparator)
class E
  class << self
    alias old_case ===
    def ===(x); old_case(x); end
  end
end
p(case E.new; when E; true; else; false; end)

class Module
  alias old_case ===
  def ===(x); old_case(x); end
end
class C; end
module Mixed; end
class D; include Mixed; end
p(case C.new; when C; true; else; false; end)
p(case 1; when C; true; else; false; end)
p(case D.new; when Mixed; :mixed; else; :no; end)
p C === C.new, Mixed === 3

class Module
  define_method(:saved, Module.instance_method(:===))
  def ===(x); saved(x); end
end
p(case C.new; when C; true; else; false; end)
p(case "s"; when C; true; when String; :string; end)
p C.saved(C.new), C.saved(C), Mixed.saved(D.new)

class Module
  define_method(:k_saved, Kernel.instance_method(:===))
end
p C.k_saved(C), C.k_saved(C.new), Mixed.k_saved(Mixed)
