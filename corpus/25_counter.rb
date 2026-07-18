class Counter
  def initialize
    @count = 0
  end
  def inc
    @count = @count + 1
  end
  def dec
    @count = @count - 1
  end
  def count
    @count
  end
end
c = Counter.new
c.inc
c.inc
c.inc
c.dec
puts c.count
i = 0
while i < 5
  c.inc
  i = i + 1
end
puts c.count
