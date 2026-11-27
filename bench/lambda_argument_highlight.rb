mode = ARGV.fetch(0, 'ordinary')
count = Integer(ARGV.fetch(1, '10000'))
seed = ARGV.find { |arg| arg.start_with?('--seed=') }
srand(seed ? Integer(seed.split('=', 2).last) : 1)
callable = ->(value) { value + 1 }
sum = 0
if mode == 'ordinary'
  count.times { |i| sum += callable.call(i) }
elsif mode == 'plain_cases'
  matcher = Object.new
  value = Object.new
  count.times { sum += (case value; when matcher; 1; else 0; end) }
elsif mode == 'arity_errors'
  count.times do
    begin
      callable.call
    rescue ArgumentError
      sum += 1
    end
  end
else
  raise ArgumentError, mode
end
GC.start
p [mode, count, sum]
