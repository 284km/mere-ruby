# Allocation diagnostic: expected T_DATA deltas are none=0, unused=0, used=1.
# Keep the actual counts visible; this does not suppress an allocated Proc.
mode = ARGV.fetch(0, "unused")
def capture_unused(&block)
end
def capture_used(&block)
  block
end
before = {}
after = {}
ObjectSpace.count_objects(before)
GC.start
GC.disable
ObjectSpace.count_objects(before)
if mode == "unused"
  capture_unused {}
elsif mode == "used"
  capture_used {}
end
ObjectSpace.count_objects(after)
p after.fetch(:T_DATA, 0) - before.fetch(:T_DATA, 0)
