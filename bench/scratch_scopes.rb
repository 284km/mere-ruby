# Run with MERE_RUBY_STORE_STATS=1 to compare pool_news as count grows.
count = Integer(ARGV.fetch(0, '20000'))
marker = :kept
keep = proc { marker }
cell = Struct.new(:value).new(0)
items = [0]
count.times do |i|
  raise 'comparison' if i + 1 != 1 + i
  cell.value += 1
  items[0] += 1
end

class ScratchFailure
  def value
    raise 'getter'
  end
  def [](_index)
    raise 'index'
  end
  def ==(_other)
    raise 'comparison'
  end
end
bad = ScratchFailure.new
errors = 0
count.times do
  begin
    bad.value += 1
  rescue RuntimeError => error
    raise unless error.message == 'getter'
    errors += 1
  end
  begin
    bad[0] += 1
  rescue RuntimeError => error
    raise unless error.message == 'index'
    errors += 1
  end
  begin
    bad == Object.new
  rescue RuntimeError => error
    raise unless error.message == 'comparison'
    errors += 1
  end
end
raise 'values' unless cell.value == count && items[0] == count && errors == count * 3
raise 'capture' unless keep.call == :kept
puts 'scratch scopes: values, captures and exceptions preserved'
