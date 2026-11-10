# Keep warnings enabled while making their destination deterministic.
class FinalizerWarningSink
  def write(text)
    text.bytesize
  end
  def puts(*)
  end
end
$stderr = FinalizerWarningSink.new
$VERBOSE = true
$delivered_after_reporting_error = {}
class UninspectableFinalizer
  def call(id)
    raise "callback failed"
  end
  def inspect
    raise "inspect failed"
  end
end
class UnreportableFinalizerError < StandardError
  def message
    raise "message failed"
  end
end
def good_reporting_callback(label)
  proc { $delivered_after_reporting_error[label] = true }
end
def bad_message_callback
  proc { raise UnreportableFinalizerError, "callback failed" }
end
def reporting_targets(bad, label)
  Fiber.new do
    10.times { ObjectSpace.define_finalizer(Object.new, bad) }
    100.times { ObjectSpace.define_finalizer(Object.new, good_reporting_callback(label)) }
  end.resume
end
reporting_targets(UninspectableFinalizer.new, :inspect)
30.times { GC.start }
p [:after_bad_inspect, $delivered_after_reporting_error[:inspect] == true]
reporting_targets(bad_message_callback, :message)
30.times { GC.start }
p [:after_bad_message, $delivered_after_reporting_error[:message] == true]
