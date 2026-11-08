# Cross the schoolbook/NTT threshold and exercise square/non-square paths.
[1196, 1200, 1204, 2048, 4097].each do |digits|
  a = Integer(('314159265358979323846' * (digits / 21 + 1))[0, digits])
  b = Integer(('271828182845904523536' * (digits / 21 + 1))[0, digits])
  [a * a, a * b, -a * b, a * -b].each do |product|
    GC.start
    puts product.to_s
  end
  raise 'square differs' unless a**2 == a * a
  raise 'product quotient' unless (a * b).div(a) == b
end
[10001, 20003].each do |exponent|
  power = 4**exponent
  raise 'rational power' unless 4r**exponent == power && (1/4r)**exponent == 1r/power
  puts power.to_s
end
puts 'NTT results survive scratch release and collection'
