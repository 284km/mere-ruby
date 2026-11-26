# Usage: mere-ruby bench/string_format_literals.rb CASE --seed=1
# Deterministic inputs; compare alternating main/candidate runs with tight GC.
total = 0
case ARGV.fetch(0)
when 'mixed'
  200_000.times { |i| total += format('%d %s %5.2f', i, 'abc', 1.5).bytesize }
when 'single'
  300_000.times { total += ('%s' % 'abc').bytesize }
when 'message'
  100_000.times do |i|
    total += ('Expected %s to be equal to %s, but the value was %d instead.' % ['abc', 'def', i]).bytesize
  end
when 'japanese'
  100_000.times do |i|
    total += ('名前は%sで、年齢は%d歳、住所は%sです。' % ['abc', i, 'def']).bytesize
  end
when 'long_ascii'
  template = 'a' * 600 + '%s' + 'b' * 600
  5_000.times { total += (template % 'abc').bytesize }
when 'long_utf8'
  template = 'あ' * 300 + '%s' + 'い' * 300
  10_000.times { total += (template % 'abc').bytesize }
else
  raise ArgumentError, 'unknown benchmark case'
end
p total
