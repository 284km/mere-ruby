# Borrowed source Arrays stay observable; synthesized anonymous rest can be native.
def anonymous_collect(*values) = values
def anonymous_forward(*) = anonymous_collect(*)
def anonymous_array(*) = [*]
def anonymous_edges(*) = [0, *, 9]
def anonymous_mixed(a, option = :default, *, last)
  [a, option, anonymous_collect(*), last]
end
def anonymous_bare *; anonymous_collect(*); end
p [:plain, anonymous_forward(1, 2)]
input = [3, 4]
p [:spread, anonymous_forward(*input), input]
p [:nil, anonymous_forward(*nil)]
p [:array, anonymous_array(*input)]
p [:nil_array, anonymous_array(*nil).class, anonymous_array(*nil)]
def explicit_nil_splat_return
  return *nil
end
p [:nil_return, explicit_nil_splat_return.class, explicit_nil_splat_return]
assigned_nil_splat = *nil
p [:nil_assignment, assigned_nil_splat.class, assigned_nil_splat]
p [:edges, anonymous_edges(*input)]
p [:mixed, anonymous_mixed(1, 2, 3, 4, 5)]
p [:mixed_default, anonymous_mixed(1, 5)]
p [:bare, anonymous_bare(6, 7)]
def anonymous_keywords(*, **) = anonymous_keyword_target(*, **)
def anonymous_keyword_target(*positional, **keywords) = [positional, keywords]
p [:keywords, anonymous_keywords(8, a: 9)]
def anonymous_array_keywords(*, **)
  [*, **]
end
p [:array_keywords, anonymous_array_keywords(10, a: 11)]
def anonymous_capture(*)
  -> { GC.start; anonymous_collect(*) }
end
kept = anonymous_capture('retained', {a: 12})
anonymous_capture('other')
GC.start
p [:captured, kept.call]
class AnonymousRestParent
  def relay(*args)
    block_given? ? [args, yield] : args
  end
end
class AnonymousRestChild < AnonymousRestParent
  def relay(*) = super
end
p [:super, AnonymousRestChild.new.relay(13, 14)]
p [:super_block, AnonymousRestChild.new.relay(15) { :block }]
def anonymous_with_user_name(__anonrest, *)
  [__anonrest, anonymous_collect(*)]
end
p [:local_collision, anonymous_with_user_name(:user, 16, 17)]
def named_anonymous_spelling(*__anonrest)
  [__anonrest.class, __anonrest]
end
p [:named_rest, named_anonymous_spelling(18, 19)]
def anonymous_binding(*)
  b = binding
  b.local_variable_set(:__anonrest, :user)
  result = anonymous_collect(*)
  [b.local_variable_get(:__anonrest), result, b.local_variables.include?(:*)]
end
p [:binding, anonymous_binding(20, 21)]
p [:parameters, method(:anonymous_forward).parameters, method(:anonymous_bare).parameters]
large = (1..10_000).to_a
large_result = anonymous_forward(*large)
p [:large, large_result.length, large_result.first, large_result.last, large.length]
# Counts are measured after setup. Ruby also omits Arrays for these calls.
def unused_anonymous_rest(*); end
$anonymous_rest_counts = {}
def count_anonymous_arrays(label)
  ObjectSpace.count_objects($anonymous_rest_counts)
  before = $anonymous_rest_counts[:T_ARRAY]
  yield
  ObjectSpace.count_objects($anonymous_rest_counts)
  p [label, $anonymous_rest_counts[:T_ARRAY] - before]
end
unused_anonymous_rest
unused_anonymous_rest(*input)
GC.start
GC.disable
count_anonymous_arrays(:empty_arrays) { unused_anonymous_rest }
count_anonymous_arrays(:spread_arrays) { unused_anonymous_rest(*input) }
count_anonymous_arrays(:nil_arrays) { unused_anonymous_rest(*nil) }
GC.enable

# Captured anonymous rest retains Ruby's isolation and source-Array state.
class AnonymousRestIsolation
  def through(*) = Ractor.shareable_proc { super }
  def leading(first, *) = Ractor.shareable_proc { super }
  def post(*, last) = Ractor.shareable_proc { super }
  def capture(*) = proc { [*] }
end
isolation = AnonymousRestIsolation.new
def check_anonymous_isolation(label)
  result = yield
  p [label, result.class, Ractor.shareable?(result)]
rescue => error
  p [label, error.class, error.message]
end
check_anonymous_isolation(:direct_empty) { isolation.through }
check_anonymous_isolation(:nil_splat) { isolation.through(*nil) }
check_anonymous_isolation(:empty_splat) { isolation.through(*[]) }
check_anonymous_isolation(:frozen_empty) { isolation.through(*[].freeze) }
check_anonymous_isolation(:direct_one) { isolation.through(1) }
check_anonymous_isolation(:frozen_one) { isolation.through(*[1].freeze) }
check_anonymous_isolation(:empty_after_lead) { isolation.leading(1) }
check_anonymous_isolation(:splat_after_lead) { isolation.leading(1, *[]) }
check_anonymous_isolation(:spread_lead) { isolation.leading(*[1].freeze) }
check_anonymous_isolation(:post) { isolation.post(1) }
check_anonymous_isolation(:frozen_then_arg) { isolation.through(*[].freeze, 1) }
check_anonymous_isolation(:two_splats) { isolation.through(*[].freeze, *[].freeze) }
check_anonymous_isolation(:method_splat) { isolation.method(:through).call(*[]) }
check_anonymous_isolation(:send_splat) { isolation.send(:through, *[].freeze) }
source = [1]
captured_source = isolation.capture(*source)
source << 2
GC.start
p [:captured_source_array, captured_source.call]
singleton = Object.new
def singleton.through(*) = Ractor.shareable_proc { super }
check_anonymous_isolation(:singleton_splat) { singleton.through(*[]) }
check_anonymous_isolation(:singleton_direct) { singleton.through }

p [:super_empty, AnonymousRestChild.new.relay]
p [:super_nil, AnonymousRestChild.new.relay(*nil)]
p [:empty_array_keywords, anonymous_array_keywords]
p [:nil_array_keywords, anonymous_array_keywords(*nil, a: 1)]
converted = Object.new
def converted.to_a = [].freeze
check_anonymous_isolation(:converted_frozen) { isolation.through(*converted) }
check_anonymous_isolation(:frozen_unshareable_value) { isolation.through(*['unfrozen'].freeze) }

# Block conversion can change a borrowed source before the method binds.
conversion_source = [1]
conversion = Object.new
conversion.define_singleton_method(:to_proc) { conversion_source << 2; proc {} }
converted_capture = isolation.capture(*conversion_source, &conversion)
p [:conversion_appends_source, converted_capture.call, conversion_source]
replacement_source = [1]
replacement = Object.new
replacement.define_singleton_method(:to_proc) { replacement_source[0] = 9; proc {} }
replaced_capture = isolation.capture(*replacement_source, &replacement)
p [:conversion_replaces_source, replaced_capture.call, replacement_source]
prefix_source = [1]
prefix_capture = isolation.capture(0, *prefix_source)
prefix_source << 2
p [:prefix_is_independent, prefix_capture.call]

expression_source = [1]
expression_capture = isolation.capture(*expression_source, &(expression_source << 2; proc {}))
p [:block_expression_source, expression_capture.call]
refusal_source = [1]
refusal = Object.new
def refusal.to_proc = raise('conversion refused')
begin
  isolation.capture(*refusal_source, &refusal)
rescue => error
  p [:conversion_refusal, error.class, error.message]
end
check_anonymous_isolation(:after_conversion_refusal) { isolation.through }

def anonymous_mutating_block(source)
  source << 2
  proc {}
end
called_source = [1]
called_capture = isolation.capture(*called_source, &anonymous_mutating_block(called_source))
p [:called_block_snapshot, called_capture.call, called_source]

class AnonymousConversionValue
  def initialize = @value = :retained
  attr_reader :value
end
gc_conversion = Object.new
gc_conversion.define_singleton_method(:to_proc) { GC.start; proc {} }
gc_capture = isolation.capture(*[AnonymousConversionValue.new], &gc_conversion)
GC.start
p [:conversion_source_survives_gc, gc_capture.call.map(&:value)]

def anonymous_short_slot_user(__ar, *) = [__ar, anonymous_collect(*)]
p [:short_slot_local_collision, anonymous_short_slot_user(:user, 1, 2)]
