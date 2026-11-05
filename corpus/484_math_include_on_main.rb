# Math's namespace implementation must also answer private calls on main.
begin
  sqrt(4)
rescue NoMethodError => error
  p [:before_include, error.name]
end

include Math
p [:top_level, sqrt(4), sin(0), cos(0), hypot(3, 4), log(1)]
p [:block_ignored, sqrt(9) { raise 'must not yield' }]
p [:main_bound, instance_eval { sqrt(16) }]
p [:eval, eval('sqrt(25)')]

def main_math_value(value)
  sqrt(value)
end
p [:top_level_method, main_math_value(36)]

begin
  sqrt
rescue ArgumentError => error
  p [:bare_arity, error.class.name]
end
begin
  sqrt()
rescue ArgumentError => error
  p [:parenthesized_arity, error.class.name]
end
begin
  sqrt(-1)
rescue Math::DomainError => error
  p [:domain, error.class.name]
end

class MathIncluder
  include Math
  def value(x)
    sqrt(x)
  end
end
class MathChild < MathIncluder; end
p [:inherited, MathChild.new.value(49)]

[:sqrt, :atan2, :hypot, :ldexp, :log].each do |name|
  [[], [1, 2, 3]].each do |args|
    begin
      Math.send(name, *args)
    rescue ArgumentError => error
      p [:namespace_arity, name, error.message]
    end
  end
end
begin
  sqrt() { raise 'must not yield' }
rescue ArgumentError => error
  p [:block_arity, error.message]
end
p [:log_base, log(8, 2)]

# Real Ruby methods still win over the namespace fallback.
module MathOverride
  def sqrt(value)
    [:override, value]
  end
end
Object.include MathOverride
p [:object_override, sqrt(64)]
p [:object_override_with_block, sqrt(64) { raise 'must not yield' }]
def sqrt(value)
  [:main_override, value]
end
p [:main_override, sqrt(81)]
