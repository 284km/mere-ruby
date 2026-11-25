def formatting_case_1111(label, format, initial, mutation, conversion = :to_s)
  array = []
  object = Object.new
  object.define_singleton_method(conversion) do
    mutation.call(array, object)
    conversion == :to_int ? 3 : 'x'
  end
  array.replace(initial.call(object))
  begin
    p [label, format % array]
  rescue => error
    p [label, error.class, error.message]
  end
end
pair = ->(object) { [object, 'old'] }
formatting_case_1111(:clear, '%s %s', pair, ->(a, _) { a.clear })
formatting_case_1111(:append, '%s %s', pair, ->(a, _) { a << 'extra' })
formatting_case_1111(:replace, '%s %s', pair, ->(a, o) { a.replace([o, 'new']) })
formatting_case_1111(:element, '%s %s', pair, ->(a, _) { a[1] = 'new' })
formatting_case_1111(:numbered, '%1$s %2$s', pair, ->(a, _) { a.clear })
formatting_case_1111(:final, '%s', ->(o) { [o] }, ->(a, _) { a.clear })
formatting_case_1111(:width, '%*s', pair, ->(a, _) { a.clear }, :to_int)
formatting_case_1111(:precision, '%.*s', pair, ->(a, _) { a.clear }, :to_int)
array = []
object = Object.new
object.define_singleton_method(:to_s) { array.clear; 'x' }
array.replace([object, 'y'])
wrapper = Object.new
wrapper.define_singleton_method(:to_ary) { array }
begin
  p '%s %s' % wrapper
rescue => error
  p [error.class, error.message]
end
# Kernel#sprintf receives its own argument vector; mutating an unrelated
# source array after splatting does not invalidate that call.
array.replace([object, 'y'])
p sprintf('%s %s', *array)
# Nested formatting has its own source array.
array = []
object = Object.new
object.define_singleton_method(:to_s) { '%s' % ['inner'] }
array.replace([object, 'outer'])
p '%s %s' % array

# Result encodings follow the values consumed at each directive, including
# replacements made by earlier conversions and strings returned by callbacks.
["\xFF".b, "あ".encode('EUC-JP'), "é"].each do |replacement|
  arguments = []
  first = Object.new
  first.define_singleton_method(:to_s) { arguments[1] = replacement; 'a' }
  arguments.replace([first, 'old'])
  result = '%s%s' % arguments
  p [result.bytes, result.encoding.name, result.valid_encoding?]
end
["\xFF".b, "あ".encode('EUC-JP')].each do |original|
  arguments = []
  first = Object.new
  first.define_singleton_method(:to_s) { arguments[1] = 'é'; 'a' }
  arguments.replace([first, original])
  result = '%s%s' % arguments
  p [result.bytes, result.encoding.name, result.valid_encoding?]
end
arguments = []
last = Object.new
last.define_singleton_method(:to_s) { arguments[0] = 'é'; 'z' }
arguments.replace(["\xFF".b, last])
result = '%s%s' % arguments
p [result.bytes, result.encoding.name, result.valid_encoding?]
[:to_s, :inspect].each do |conversion|
  value = Object.new
  value.define_singleton_method(conversion) { "\xFF".b }
  result = (conversion == :to_s ? '%s' : '%p') % [value]
  p [result.bytes, result.encoding.name, result.valid_encoding?]
end
# Each nested formatting invocation negotiates its own encoding.
value = Object.new
value.define_singleton_method(:to_s) { '%s' % ["\xFF".b]; 'é' }
result = '%s' % [value]
p [result.bytes, result.encoding.name, result.valid_encoding?]
