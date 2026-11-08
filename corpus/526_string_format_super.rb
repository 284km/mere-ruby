# Singleton, subclass and prepend super must reach the same String#% builtin.
format = '%s'
def format.%(value)
  value ? super : 'failed'
end
p [format % 'ok', format % nil, format % false]

class FormatString < String
  def %(*args)
    super
  end
end

module FormatWrapper
  def %(*args)
    $format_calls << :wrapper
    super
  end
end
class WrappedFormat < FormatString
  prepend FormatWrapper
  def %(*args)
    $format_calls << :class
    super
  end
end
$format_calls = []
p WrappedFormat.new('%s:%02d') % ['item', 7]
p $format_calls

array_like = Object.new
def array_like.to_ary
  @calls = (@calls || 0) + 1
  ['array', 9]
end
p FormatString.new('%s:%d') % array_like
p array_like.instance_variable_get(:@calls)
string_like = Object.new
def string_like.to_ary = nil
def string_like.to_s = 'scalar'
p FormatString.new('%s') % string_like
p FormatString.new('%{name}:%<n>02d') % {name: 'named', n: 3}

explicit = '%s/%s'
def explicit.%(value)
  super([value, 'explicit']) { raise 'String#% must ignore the block' }
end
p explicit % 'value'
changed = '%s'
def changed.%(value)
  value = 'changed'
  super
end
p changed % 'original'

frozen_format = FormatString.new('%s').freeze
result = frozen_format % 'mutable'
p [result, result.class, result.frozen?, frozen_format]
encoded = FormatString.new('%s'.encode('US-ASCII')) % "\u9ce5"
p [encoded, encoded.encoding.name]

[[], ['a', 'b']].each do |args|
  begin
    FormatString.new('%s').%(*args)
  rescue ArgumentError => error
    puts error.message
  end
end
bad_array = Object.new
def bad_array.to_ary = 1
[['%s', bad_array], ['%s:%s', ['only one']], ['%{absent}', {}]].each do |fmt, value|
  begin
    FormatString.new(fmt) % value
  rescue TypeError, ArgumentError, KeyError => error
    puts error.class
  end
end
# An exception must not leave a stale dispatch state for the next call.
p FormatString.new('%s') % 'after errors'

# The singleton fallback with a literal block also serves builtin iterators,
# while a missing superclass method must still raise.
values = [1, 2]
def values.each
  super { |value| yield(value * 2) }
end
seen = []
values.each { |value| seen << value }
p seen
def format.no_such_builtin
  super { :unused }
end
begin
  format.no_such_builtin
rescue NoMethodError => error
  puts error.class
end

# An undef entry must stop super before either builtin fallback.
class NoFormat < String
  undef_method :%
end
class ChildFormat < NoFormat
  def %(value)
    super
  end
end
class BlockChildFormat < NoFormat
  def %(value)
    super { raise 'format block must not run' }
  end
end
[ChildFormat.new('%s'), BlockChildFormat.new('%s')].each do |receiver|
  begin
    receiver % 'removed'
    raise 'super bypassed undef'
  rescue NoMethodError => error
    p [error.class, error.name, error.receiver.equal?(receiver), error.args]
  end
end

class NoEach < Array
  undef_method :each
end
values = NoEach.new([3, 4])
def values.each
  super { |value| yield value }
end
begin
  values.each { raise 'undefined iterator yielded' }
  raise 'singleton super bypassed undef'
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(values), error.args]
end
# The block-less singleton path must observe the same barrier.
plain = NoFormat.new('%s')
def plain.%(value)
  super
end
begin
  plain % 'removed'
  raise 'singleton super bypassed undef'
rescue NoMethodError => error
  p [error.class, error.name, error.args]
end

# A method defined before the barrier remains callable.
class RestoredFormat < NoFormat
  def %(value)
    "restored:#{value}"
  end
end
class WrappedRestoredFormat < RestoredFormat
  def %(value)
    super
  end
end
p WrappedRestoredFormat.new('%s') % 'ok'
module RestoredEach
  def each
    yield :restored
  end
end
values.extend(RestoredEach)
p values.each { |value| value }

# Missing-method handling retains arguments and the literal block.
class MissingFormat < ChildFormat
  def method_missing(name, *args)
    [name, args]
  end
end
p MissingFormat.new('%s') % 'missing'
# A separate receiver has no extended implementation above its undef entry.
missing_values = NoEach.new
class << missing_values
  def each(value)
    super(value) { |item| yield item }
  end
  def method_missing(name, *args)
    [name, args, yield(:missing)]
  end
end
p missing_values.each(:argument) { |item| [item, :block] }
p FormatString.new('%s') % 'after undef errors'
