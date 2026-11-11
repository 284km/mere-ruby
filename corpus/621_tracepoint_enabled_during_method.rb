$late_trace_events = []
class SourceLateTrace
  def call
    value = :kept
    GC.start
    $late_trace = TracePoint.new(:return) do |event|
      if event.method_id == :call && event.defined_class == SourceLateTrace
        $late_trace_events << [event.event, event.method_id, event.return_value]
      end
    end
    $late_trace.enable
    value
  end
end
result = SourceLateTrace.new.call
$late_trace.disable
p [result, $late_trace_events]
