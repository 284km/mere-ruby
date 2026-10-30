# A singleton method on a literal is refused when the source is parsed
# ("cannot define singleton method for literals", marked at the literal --
# the last statement of a parenthesised receiver); nil, true, false, self,
# a Hash and a Range are not literals here.
[
  %q[def ("foo").foo; end], %q[def (1).foo; end], %q[def ((1;1)).foo; end],
  %q[def ((;1)).foo; end], %q[def ((1+1;1)).foo; end], %q[def ((%s();1)).foo; end],
  %q[def ((%w();1)).foo; end], %q[def ("#{42}").foo; end], %q[def (:"#{42}").foo; end],
  %q[def ([]).foo; end], %q[def ([1]).foo; end], %q[def (1.5).foo; end], %q[def (/x/).foo; end],
  %q[def (__FILE__).foo; end], %q[def (__LINE__).foo; end], %q[def (__ENCODING__).foo; end],
  %q[def __FILE__.foo; end], %q[def __LINE__.foo; end], %q[def __ENCODING__.foo; end],
].each do |src|
  begin
    eval(src)
    puts "defined: #{src}"
  rescue SyntaxError => e
    head, *frame = e.message.lines
    puts head.sub(/\A.*?:\d+: /, "")
    puts frame
  end
end
o = Object.new
eval("def (o).hi = :hi")
p o.hi
eval("def (nil).nil_hi = :nil_hi")
p nil.nil_hi

# The scope of a class or module name can be any primary value.
module if true; Object end::Comparable
  def self.reopened = :yes
end
p Comparable.reopened
class while true; break Object end::Integer
  def twice = self * 2
end
p 21.twice
# (...and a name under Object is a top-level one, from any nesting)
module Nest450
  class Object::Top450; end
end
p Top450, Nest450.constants

# Inside a rescue clause the method's own frame is seen again, at the line
# of the def (or begin / do) the clause belongs to: caller(1) starts there,
# caller(0) does not show it.
def def_level
  x = 1
  raise
rescue
  [caller_locations(1, 1)[0].lineno, caller(0, 1)[0][/:(\d+):/, 1].to_i, caller(1..1)[0][/:(\d+):/, 1].to_i]
end
p def_level

def begin_level
  begin
    raise
  rescue
    caller_locations(1, 2).map { |l| [l.lineno, l.label] }
  end
end
p begin_level

def block_level
  [1].each do
    raise
  rescue
    return caller_locations(1, 2).map { |l| [l.lineno, l.label] }
  end
end
p block_level

def after_clause
  begin
    raise
  rescue
  end
  caller_locations(1, 1)[0].lineno
end
p after_clause
