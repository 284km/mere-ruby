$callback_trace_events = []
$callback_trace = nil
class SourceCallbackTrace
  def observed
    :observed_value
  end
end
set_trace_func(proc do |event, _file, _line, method, _binding, klass|
  if event == 'call' && method == :observed && klass == SourceCallbackTrace && !$callback_trace
    $callback_trace = TracePoint.new(:return) do |point|
      if point.method_id == :observed && point.defined_class == SourceCallbackTrace
        $callback_trace_events << [point.event, point.method_id]
      end
    end
    $callback_trace.enable
  end
end)
result = SourceCallbackTrace.new.observed
set_trace_func(nil)
$callback_trace.disable if $callback_trace
p [result, $callback_trace_events]
