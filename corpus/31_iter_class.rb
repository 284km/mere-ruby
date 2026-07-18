class NumberList
  def initialize
    @nums = []
  end
  def add(n)
    @nums = @nums + [n]
    self
  end
  def each
    @nums.each { |n| yield(n) }
  end
  def sum
    total = 0
    each { |n| total = total + n }
    total
  end
end
list = NumberList.new
list.add(1)
list.add(2)
list.add(3)
list.each { |n| puts n }
puts list.sum

class Range3
  def initialize(limit)
    @limit = limit
  end
  def do_each
    (1..@limit).each { |i| yield(i * 10) }
  end
end
r = Range3.new(4)
r.do_each { |v| puts v }
