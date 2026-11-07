# Alternate callees so all three argument-error marker names are rewritten.
class FirstArgumentMarker
  def self.identity(value)
    value
  end
end
class SecondArgumentMarker
  def self.identity(value)
    value
  end
end
count = (ARGV[0] || "100000").to_i
i = 0
while i < count
  raise "first" unless FirstArgumentMarker.identity(i) == i
  raise "second" unless SecondArgumentMarker.identity(i) == i
  i += 1
end
GC.start
puts "argument markers: values preserved"
