# `A::B` reads A first, from the scope it is written in, then B under it: in
# a module with an `A` of its own, `A::B` is that module's A::B even where a
# top-level A::B exists. A class defined at such a path, under `self::`, under
# a local, or under `::A::B`, goes where the path's head says -- on the
# evaluator and on the VM.

module R; module B; X = :top; end; end
module S
  module R; module B; X = :inner; end; end
  p R::B.equal?(::R::B), R::B.name, R::B::X, ::R::B::X, R.name
  class R::B::C; end
  class ::R::B::D; end
  class self::E; end
  owner = self
  class owner::F; end
  module R::B::G; end
end
p [S::R::B.const_defined?(:C, false), R::B.const_defined?(:C, false)]
p [S::R::B.const_defined?(:D, false), R::B.const_defined?(:D, false)]
p [S.const_defined?(:E, false), S.const_defined?(:F, false), S::R::B.const_defined?(:G, false)]

# from a method, a nested module, and a reopened scope
module S
  def self.read = [R::B::X, ::R::B::X]
  module Deeper
    def self.read = R::B::X
  end
end
p S.read, S::Deeper.read

# a head only the top level has
module T
  p R::B::X
end

# a head that names nothing
module U
  begin
    Nope::Thing
  rescue NameError => e
    p e.message
  end
end
