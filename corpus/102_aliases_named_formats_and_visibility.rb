# An alias adds a method, so `method_added` fires for the new name. This is
# how rubocop-ast builds its visitor registry, and a quiet alias left the
# registry short by three entries -- which made its compiler recurse forever.
class Reg
  @seen = []
  class << self
    attr_reader :seen
    def method_added(m)
      @seen << m
      super
    end
  end

  def visit_symbol
    :sym
  end
  alias visit_number visit_symbol
  alias_method :visit_string, :visit_symbol
  def other
    :other
  end
end
p Reg.seen
p [Reg.new.visit_number, Reg.new.visit_string]

# Named references in format strings.
p format("%<a>s-%<b>d", a: "x", b: 5)
p format("%{a}/%{b}", a: 1, b: 2)
p format("%<w>-6s|%<w>6s|", w: "L")
p format("%<h>x %<o>o", h: 255, o: 8)
p("%{x} and %<y>s" % { x: 1, y: 2 })
p format("100%% %{n}", n: "done")
begin
  format("%<nope>s", other: 1)
rescue KeyError => e
  p [e.class, e.message]
end
begin
  format("%{nope}", other: 1)
rescue KeyError => e
  p e.message
end

# `:!~` is a method name, like `:=~`.
p [:[]=, :<<, :=~, :!~, :<=>].map(&:to_s)
p("abc" !~ /z/)
p 1.respond_to?(:!~)

# A space-marked `[` after a complete expression indexes it.
def conf(_key)
  { "P" => 1, "Q" => 2 }
end
p conf("Style") ["P"]
p [[3, 4]] [0] [1]

# `define_method` with an interpolated symbol keeps its do-block.
class Gen
  %w[x y].each do |t|
    define_method :"on_#{t}" do |n|
      "on #{t}:#{n}"
    end
  end
end
p [Gen.new.on_x(1), Gen.new.on_y(2)]

# Naming methods after a bare `private` re-marks them: visibility is one
# state, not two flags.
class Vis
  def use(other)
    [other.a, other.b, other.c]
  end

  private

  def a
    1
  end

  def b
    2
  end

  def c
    3
  end
  protected :a, :b, :c
end
p Vis.new.use(Vis.new)

class Vis2
  def m
    :m
  end
  protected :m
  private :m
end
begin
  Vis2.new.m
rescue NoMethodError => e
  p e.class
end
