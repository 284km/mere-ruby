verbose = $VERBOSE
$VERBOSE = nil
Ractor.new {}.value
$VERBOSE = verbose

3.times do
  result = Ractor.new do
    [Process.clock_gettime(Process::CLOCK_MONOTONIC).class,
     Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond).class,
     Process.clock_getres(Process::CLOCK_MONOTONIC).class,
     Process.clock_gettime(:GETTIMEOFDAY_BASED_CLOCK_REALTIME).class,
     Process.clock_getres(:GETTIMEOFDAY_BASED_CLOCK_REALTIME).class]
  end
  p result.value
end

GC.start
p Process.instance_variables.grep(/clock/)
p Process.constants.grep(/__clock/)
p Process.clock_gettime(Process::CLOCK_MONOTONIC).class

module UserClockClosure1138
  value = 1
  define_singleton_method(:read) { value }
end
p Ractor.new {
  begin
    UserClockClosure1138.read
  rescue RuntimeError => error
    [error.class, error.message]
  end
}.value

p Ractor.new {
  begin
    Process.clock_gettime("not a clock")
  rescue TypeError => error
    error.class
  end
}.value
