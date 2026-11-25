# Argument copies are observable through identity, flags, subclass state and
# mutation. Native keyword copies must not invoke Ruby copy hooks.
def self.plain_method(*a) = a
def self.marked_method(*a) = a
singleton_class.send(:ruby2_keywords, :marked_method)
plain_proc = proc { |*a| a }
plain_lambda = ->(*a) { a }
marked_proc = proc { |*a| a }.ruby2_keywords
original = Hash.ruby2_keywords_hash(a: 1)
callables = [method(:plain_method), method(:marked_method), plain_proc, plain_lambda, marked_proc]
callables.each_with_index do |callable, index|
  tail = callable.call(*[original]).last
  p [index, tail.equal?(original), Hash.ruby2_keywords_hash?(tail), Hash.ruby2_keywords_hash?(original)]
end
class KeywordCopyHash < Hash
  def dup = raise('Ruby dup called')
  def initialize_copy(other) = raise('Ruby copy hook called')
end
special = KeywordCopyHash.new(:default).compare_by_identity
key = +'key'
special[key] = 1
special.instance_variable_set(:@value, 7)
special = Hash.ruby2_keywords_hash(special)
def special.only_original = :singleton
special.freeze
callables.each_with_index do |callable, index|
  tail = callable.call(*[special]).last
  p [index, tail.equal?(special) || tail.class == KeywordCopyHash, tail.default, tail.compare_by_identity?, tail[key],
     tail.instance_variable_get(:@value), tail.frozen?, tail.respond_to?(:only_original),
     tail.equal?(special), Hash.ruby2_keywords_hash?(tail)]
end
with_default = KeywordCopyHash.new { |_, k| k }
with_default[:a] = 1
with_default = Hash.ruby2_keywords_hash(with_default).freeze
copy = plain_proc.call(*[with_default]).last
p [:default_proc, copy[:missing], copy.default_proc.equal?(with_default.default_proc), copy.class]
copy = plain_proc.call(*[original]).last
copy[:a] = 9
p [:isolation, original[:a], copy[:a], Hash.ruby2_keywords_hash?(original)]
# A note from a builtin or an empty splat belongs to that invocation only.
[].push(*[original])
p [:direct_after_builtin, plain_proc.call(original).last.equal?(original)]
empty = Hash.ruby2_keywords_hash({})
plain_proc.call(*[empty])
p [:direct_after_empty, plain_proc.call(empty).last.equal?(empty)]
# Passing a Proc as a block must keep the same keyword policy as #call.
def self.pass_to_block(*a, &b) = yield(*a)
p [:plain_block, pass_to_block(original, &plain_proc).last.equal?(original)]
p [:marked_block, pass_to_block(original, &marked_proc).last.equal?(original)]
p [:block_given_at_call, plain_proc.call(*[original], &marked_proc).last.equal?(original)]
# Native Method/Symbol procs must leave conversion to their target method.
def self.keyword_target(a:) = a
p [:method_proc, method(:keyword_target).to_proc.call(*[original])]
class KeywordReceiver
  def take(a:) = a
end
p [:symbol_proc, :take.to_proc.call(KeywordReceiver.new, *[original])]
GC.start
p [:after_gc, plain_proc.call(*[original]).last.equal?(original), Hash.ruby2_keywords_hash?(original)]

# Notes must survive nested conversions and end when the callee raises.
converter = Object.new
converter.define_singleton_method(:to_proc) do
  plain_proc.call(*[original])
  marked_proc
end
p [:nested_conversion, pass_to_block(original, &converter).last.equal?(original)]
original[:a] = 1
begin
  Object.new.no_such_method(*[original])
rescue NoMethodError
end
p [:direct_after_error, plain_proc.call(original).last.equal?(original)]
# An evaluator-created method can be invoked from the VM's direct-send path.
eval('def self.evaluator_push(h); [].push(*[h]); end')
evaluator_push(original)
p [:direct_after_eval_method, plain_proc.call(original).last.equal?(original)]

def self.required_copy(x) = x
def self.optional_copy(x = nil) = x
p [:required_copy, required_copy(*[original]).equal?(original)]
p [:optional_copy, optional_copy(*[original]).equal?(original)]
begin
  keyword_target(original)
rescue ArgumentError => error
  p [:direct_is_positional, error.class, error.message]
end
keyword_lambda = ->(a:) { a }
p [:lambda_keywords, keyword_lambda.call(*[original])]

# Supplying a block must not bypass the called Proc's flag or lambda marker.
marked_lambda = ->(*a) { a.last }.ruby2_keywords
flagged_proc = proc { |*a| a.last }.ruby2_keywords
call_block = proc {}
[flagged_proc, marked_lambda].each_with_index do |callable, index|
  value = callable.call(*[original], &call_block)
  p [:marked_with_block, index, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
  value = callable.call(*[original]) {}
  p [:marked_with_literal, index, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
end
begin
  ->(x) { x }.call(1, 2) {}
rescue ArgumentError => error
  p [:lambda_block_arity, error.class, error.message]
end
def capture_keyword_yield
  proc { |*_| yield :captured }
end
captured = capture_keyword_yield { |value| [:home, value] }
p [:captured_yield, captured.call(1) { :call_site }]

# Direct marked calls keep the input; Method#call converts it at its boundary.
p [:direct_marked, marked_method(*[original]).last.equal?(original)]
p [:direct_marked_block, marked_method(*[original]) {}.last.equal?(original)]
p [:marked_method_proc, method(:marked_method).to_proc.call(*[original]).last.equal?(original)]
# Observer callbacks must not steal or leak the call's transient argument state.
def self.keyword_observer_work
  [1].each { |value| value.to_s }
end
trace = TracePoint.new(:call, :b_call, :c_call) { keyword_observer_work }
trace.enable do
  value = plain_method(*[original]).last
  p [:trace_plain, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
  value = marked_method(*[original]).last
  p [:trace_marked, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
  value = method(:marked_method).call(*[original]).last
  p [:trace_bound, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
  value = marked_proc.call(*[original]) {}
  p [:trace_proc_block, value.last.equal?(original), Hash.ruby2_keywords_hash?(value.last)]
end

# The native Method block path has the same conversion boundary.
bound_marked = method(:marked_method)
converted_marked = bound_marked.to_proc
[bound_marked, converted_marked].each_with_index do |callable, index|
  value = callable.call(*[original], &call_block).last
  p [:bound_with_proc, index, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
  value = callable.call(*[original]) {}.last
  p [:bound_with_literal, index, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
end

# Keyword origin belongs to a forwarding frame, not one shared Hash mark.
def self.repeated_keyword_target(a:) = a
def self.repeated_keyword_forward(...)
  [repeated_keyword_target(...), repeated_keyword_target(...)]
end
p [:repeated_keywords, repeated_keyword_forward(a: 23)]
def self.captured_keyword_forward(...)
  -> { repeated_keyword_target(...) }
end
forwarded_keywords = captured_keyword_forward(a: 24)
p [:captured_keywords, forwarded_keywords.call, forwarded_keywords.call]
eval('def self.evaluator_repeated_forward(...); [repeated_keyword_target(...), repeated_keyword_target(...)]; end')
p [:evaluator_repeated_keywords, evaluator_repeated_forward(a: 25)]

# A flagged Hash passed positionally stays positional through ... .
def self.forward_plain_identity(...) = plain_method(...).last
value = forward_plain_identity(original)
p [:forwarded_positional, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
value = forward_plain_identity(*[original])
p [:forwarded_splat, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
begin
  repeated_keyword_forward(original)
rescue ArgumentError => error
  p [:forwarded_direct_error, error.class, error.message]
end

class RepeatedKeywordSuperParent
  def take(a:) = a
end
class RepeatedKeywordSuperChild < RepeatedKeywordSuperParent
  def take(...) = [super, super]
end
p [:repeated_keyword_super, RepeatedKeywordSuperChild.new.take(a: 26)]
class ForwardedIdentitySuperParent
  def take(*args) = args.last
end
class ForwardedIdentitySuperChild < ForwardedIdentitySuperParent
  def take(...) = super
end
super_receiver = ForwardedIdentitySuperChild.new
value = super_receiver.take(original)
p [:super_positional_identity, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
value = super_receiver.take(*[original])
p [:super_splat_identity, value.equal?(original), Hash.ruby2_keywords_hash?(value)]
