# Anonymous method positions survive active and suspended collections.
klass = Class.new do
  def suspended_position
    before = caller(0, 1).first.include?("suspended_position")
    Fiber.yield :ready
    GC.start
    [before, caller(0, 1).first.include?("suspended_position")]
  end

  def active_position
    GC.start
    caller(0, 1).first.include?("active_position")
  end

  def raised_position
    raise "position retained"
  end
end

fiber = Fiber.new { klass.new.suspended_position }
p fiber.resume
300.times do
  temporary = Class.new do
    def temporary_position
      caller(0, 1).first.include?("temporary_position")
    end
  end
  raise "wrong temporary label" unless temporary.new.temporary_position
end
3.times { GC.start }
p fiber.resume
p klass.new.active_position
begin
  klass.new.raised_position
rescue => error
  saved = error.backtrace
end
klass = nil
fiber = nil
3.times { GC.start }
p saved.any? { |line| line.include?("raised_position") }
