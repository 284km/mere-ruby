# frozen_string_literal: true
# Standalone interpolation always makes a fresh mutable String. Actual adjacent
# literal folding is separate, and a + inside interpolation is a method call.
def interp_single; "#{'a'}"; end
def interp_empty; "#{''}"; end
def interp_nested; "#{"#{'a'}"}"; end
def interp_add; "#{'a' + 'b'}"; end
def interp_nested_add; "#{"#{'a'}" + 'b'}"; end
def interp_adjacent; "a" "#{'b'}"; end
def interp_suffix; "#{'a'}" "b"; end
def interp_many; "a" "#{'b'}" "c" "#{'d'}"; end
def interp_nested_adjacent; "a" "#{"#{'b'}"}"; end
def interp_adjacent_add; "a" "#{'b' + 'c'}"; end
def interp_empty_suffix; "#{'a'}" ""; end
def interp_dynamic_suffix
  value = 'a'
  "#{value}" ""
end

[:interp_single, :interp_empty, :interp_nested, :interp_add, :interp_nested_add,
 :interp_adjacent, :interp_suffix, :interp_many, :interp_nested_adjacent,
 :interp_adjacent_add, :interp_empty_suffix, :interp_dynamic_suffix].each do |name|
  first = send(name)
  GC.start
  second = send(name)
  p [name, first.class, first.frozen?, first.equal?(second), first.encoding.name]
  begin
    first << '!'
    p [first, second]
  rescue FrozenError => error
    p error.class
  end
end

# Only an actual + expression dispatches a replaced String#+.
$interpolation_plus_calls = []
class String
  alias_method :interpolation_original_plus, :+
  def +(other)
    $interpolation_plus_calls << other
    interpolation_original_plus(other)
  end
end
[:interp_single, :interp_add, :interp_nested_add, :interp_adjacent,
 :interp_many, :interp_adjacent_add].each do |name|
  $interpolation_plus_calls.clear
  value = send(name)
  p [name, value, value.frozen?, $interpolation_plus_calls]
end
