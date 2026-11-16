require 'objspace'

if GC.count.zero?
  raise 'invented collection cause' unless GC.latest_gc_info[:gc_by].nil?
end
GC.start
info = GC.latest_gc_info
raise 'explicit collection cause' unless info[:gc_by] == :method
raise 'sweep state' unless info[:state] == :none && info[:immediate_sweep]
filled = { preserved: true }
raise 'info hash identity' unless GC.latest_gc_info(filled).equal?(filled) && filled[:preserved]
begin
  GC.latest_gc_info(:not_a_stat)
  raise 'unknown stat accepted'
rescue ArgumentError
end

garbage = Array.new(300) { proc {} }
issued = GC.stat(:total_allocated_objects)
garbage = nil
GC.start
raise 'allocation count decreased after sweep' if GC.stat(:total_allocated_objects) < issued

GC::Profiler.enable
GC::Profiler.clear
2.times { GC.start }
records = GC::Profiler.raw_data
raise 'missing collection records' unless records.size >= 2
raise 'unmeasured time' unless records.all? { |row| row[:GC_TIME] > 0 }
raise 'missing total' unless GC::Profiler.total_time > 0
raise 'missing report' if GC::Profiler.result.empty?
GC::Profiler.clear
raise 'records not cleared' unless GC::Profiler.raw_data.empty?
GC::Profiler.disable
raise 'disabled raw data' unless GC::Profiler.raw_data.nil?
raise 'profiler time type' unless GC::Profiler.total_time.is_a?(Float)

unless GC.respond_to?(:compact)
  [:compact, :auto_compact, :latest_compact_info, :verify_compaction_references].each do |method|
    raise 'unsupported method advertised' if GC.respond_to?(method)
    begin
      GC.send(method)
      raise 'unsupported method returned'
    rescue NotImplementedError
    end
  end
  raise 'invented slot constants' unless GC::INTERNAL_CONSTANTS.empty?
  raise 'invented slot heaps' unless GC.stat_heap.empty?
end

GC.disable
text = 'payload' * 17
array = [text]
hash = { text => array }
[[String, text], [Array, array], [Hash, hash]].each do |klass, object|
  raise 'object missing from store snapshot' unless ObjectSpace.each_object(klass).any? { |item| item.equal?(object) }
end
raise 'missing array references' unless ObjectSpace.reachable_objects_from(array).any? { |item| item.equal?(text) }
GC.enable
puts 'real GC measurements and value store enumeration'
