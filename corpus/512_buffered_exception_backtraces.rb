require 'digest'

# Compare every output byte without printing thousands of frames. Bottom-up
# reports need aligned multi-digit frame numbers as well as reversed order.
[1, 2, 12, 2_000].each do |count|
  error = RuntimeError.new("boom\nmore")
  error.set_backtrace(Array.new(count) { |i| "trace.rb:#{i + 1}:in 'frame'" })
  [:top, :bottom].each do |order|
    [false, true].each do |highlight|
      message = error.full_message(order: order, highlight: highlight)
      p [count, order, highlight, message.bytesize, Digest::SHA256.hexdigest(message)]
    end
  end
end

inner = ArgumentError.new('inner')
inner.set_backtrace(['inner.rb:1', 'inner.rb:2'])
outer = RuntimeError.new('outer')
outer.set_backtrace(Array.new(12) { |i| "outer.rb:#{i + 1}" })
begin
  raise outer, cause: inner
rescue RuntimeError => error
  [:top, :bottom].each { |order| puts error.full_message(order: order, highlight: false) }
end
