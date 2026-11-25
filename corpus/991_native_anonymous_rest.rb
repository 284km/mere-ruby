# Anonymous rest has no Ruby Array identity; explicit arrays remain observable.
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
