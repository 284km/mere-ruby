def report(label, receiver)
  yield
rescue NoMethodError => error
  p [label, error.class.name, error.name, error.args, error.receiver.equal?(receiver)]
end
report(:index_empty, nil) { nil[] }
report(:index_arg, nil) { nil[42] }
report(:index_many, nil) { nil[1, 2, 3] }
value = nil
report(:index_write, value) { value[42] += 1 }
report(:size, nil) { nil.size }
report(:length, false) { false.length }
report(:empty, 1) { 1.empty? }
array = []
report(:to_i, array) { array.to_i }
hash = {}
report(:to_f, hash) { hash.to_f }
report(:to_a, 1) { 1.to_a }
report(:unary, nil) { -nil }
report(:ordinary, nil) { nil.missing_probe(1) }
class NilClass
  def [](index) = [:override, index]
end
p nil[42]
class NilClass
  remove_method :[]
end
report(:index_restored, nil) { nil[42] }
