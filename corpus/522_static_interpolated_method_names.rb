# frozen_string_literal: true
# Parse-time method names must see through quote metadata, including nested
# static interpolation and actual adjacent-literal folding.
class StaticInterpolatedNames
  def original; 42; end
  def nested; 43; end
  def adjacent; 44; end
  alias :"#{'copy'}" :"#{'original'}"
  alias :"#{"#{'nested_copy'}"}" :"#{'nested'}"
  alias :"#{'adjacent_' 'copy'}" :"#{'adjacent'}"
  attr_accessor :"#{'value'}"
  undef :"#{'original'}"
  undef :"#{"#{'nested'}"}"
  undef :"#{'ad' "#{'ja'}" 'cent'}"
end
object = StaticInterpolatedNames.new
p [:original, :nested, :adjacent].map { |name| object.respond_to?(name) }
p [object.copy, object.nested_copy, object.adjacent_copy]
object.value = 45
p object.value
GC.start
p object.copy

# A genuinely dynamic name still uses the runtime alias path exactly once.
$static_name_calls = 0
def runtime_alias_name
  $static_name_calls += 1
  'runtime_copy'
end
class StaticInterpolatedNames
  alias :"#{runtime_alias_name}" :"#{'copy'}"
end
p [object.runtime_copy, $static_name_calls]
