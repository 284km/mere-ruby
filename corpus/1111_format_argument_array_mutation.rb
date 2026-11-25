require 'tmpdir'
# Start with printf in a fresh process: a rescued earlier formatting error
# can leave the format-encoding context set and hide this regression.
Dir.mktmpdir do |dir|
  child = <<~'CODE'
    printf("日本語 Kernel\n")
    $stdout.printf("日本語 stdout\n")
    STDOUT.printf("日本語 STDOUT\n")
    $stderr.printf("日本語 stderr\n")
    File.open(ARGV.fetch(0), 'w+') do |io|
      printf(io, "日本語 explicit IO\n")
      io.printf("日本語 IO\n")
      io.rewind
      print io.read
    end
  CODE
  errors = File.join(dir, 'stderr')
  print IO.popen([RbConfig.ruby, '-e', child, File.join(dir, 'output'), err: errors], &:read)
  p $?.exitstatus
  print File.binread(errors)
end

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

# Inspect a value once, then stringify that returned value. Neither the
# original inspect nor the returned value's to_s may be called twice.
[123, nil, true, :symbol, [1, 2]].each do |returned|
  value = Object.new
  calls = 0
  value.define_singleton_method(:inspect) do
    calls += 1
    raise 'inspect called twice' if calls > 1
    returned
  end
  p ['%p' % [value], calls]
end
['é', "\xFF".b].each do |text|
  converted = Object.new
  conversions = 0
  converted.define_singleton_method(:to_s) { conversions += 1; text }
  converted.define_singleton_method(:to_str) { raise 'unexpected to_str' }
  value = Object.new
  calls = 0
  value.define_singleton_method(:inspect) { calls += 1; converted }
  result = '%p' % [value]
  p [result.bytes, result.encoding.name, result.valid_encoding?, calls, conversions]
end
class FormatResult1111
end
converted = FormatResult1111.new
conversions = 0
converted.define_singleton_method(:to_s) { conversions += 1; 123 }
converted.define_singleton_method(:to_str) { raise 'unexpected to_str' }
value = Object.new
calls = 0
value.define_singleton_method(:inspect) { calls += 1; converted }
result = '%p' % [value]
p [result.match?(/\A#<FormatResult1111:0x[0-9a-f]+>\z/), calls, conversions]

# Ruby copies literal text without negotiating it against converted values.
value = Object.new
value.define_singleton_method(:to_s) { "\xFF".b }
[
  '%sé' % ["\xFF".b],
  '%{a}é' % {a: "\xFF".b},
  '%<a>sé' % {a: "\xFF".b},
  '%sé' % [value]
].each { |text| p [text.bytes, text.encoding.name, text.valid_encoding?] }
# Literal text before a conversion still participates through the prefix.
begin
  p 'é%s' % ["\xFF".b]
rescue => error
  p [error.class, error.message]
end
