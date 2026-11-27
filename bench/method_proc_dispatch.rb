mode = ARGV.fetch(0)
count = Integer(ARGV.fetch(1, "100000"))
srand(1)
if mode == "native_churn"
  sum = 0
  count.times do |i|
    sum += Integer.method(:sqrt).to_proc.call(9)
    GC.start if i % 100 == 99
  end
  GC.start
  p sum
  exit
end
def add_one(value) = value + 1
callable = case mode
when "ordinary" then proc { |value| value + 1 }
when "ruby" then method(:add_one).to_proc
when "native" then Integer.method(:sqrt).to_proc
else raise ArgumentError, mode
end
sum = 0
count.times { sum += callable.call(9) }
p sum
