array = [1, 2]
hash = {a: 3}
class NoImplicitArray
  def to_ary
    raise "one positional parameter must not destructure"
  end
end
opaque = NoImplicitArray.new
identity = []
[array, hash, opaque].each do |value|
  identity << (value.equal?(array) || value.equal?(hash) || value.equal?(opaque))
end
p [:identity, identity]
plain = proc { |value| value }
p [:arity_shapes, plain.call, plain.call(1, 2), plain.call(array).equal?(array)]
p [:hash, plain.call(a: 3)]
p [:trailing_comma, proc { |value,| value }.call(array)]
p [:destructure, proc { |(first, second)| [first, second] }.call(array)]
p [:defaults, proc { |value = 9| value }.call, proc { |value = 9| value }.call(7)]
saved = []
[1, 2].each do |value|
  saved << binding
end
p [:bindings, saved.map { |scope| scope.local_variable_get(:value) }]
closures = [1, 2].map { |value| -> { value } }
p [:closures, closures.map(&:call)]
original = -> { :given }
p [:block_argument, proc { |value, &block| [value, block.equal?(original)] }.call(1, &original)]
begin
  ->(value) { value }.call
rescue ArgumentError => error
  p [:lambda_arity, error.message]
end
p [:break, [1, 2].each { |value| break :finished }]
p [:next, [1, 2].map { |value| next value * 2 }]
