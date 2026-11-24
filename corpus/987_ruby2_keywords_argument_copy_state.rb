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
