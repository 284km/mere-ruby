require 'objspace'

GC.start
GC.disable
held = Array.new(1_000) { |i| "live-string-#{i}" }
held << ''.dup
before_empty = ObjectSpace.count_objects.fetch(:T_STRING)
empty_strings = Array.new(1_000) { String.new }
after_empty = ObjectSpace.count_objects.fetch(:T_STRING)
raise 'empty live strings omitted' unless after_empty - before_empty >= empty_strings.size
held.concat(empty_strings)
empty_strings = nil
visible = ObjectSpace.each_object(String).count
result = { marker: 123 }
raise 'result hash identity' unless ObjectSpace.count_objects(result).equal?(result)
raise 'old keys not reset' unless result[:marker] == 0
raise 'live strings omitted' unless result.fetch(:T_STRING) >= visible
raise 'held strings omitted' unless result[:T_STRING] >= held.size
total = result.reject { |key, _| key == :TOTAL }.values.sum
raise 'inconsistent live totals' unless total == result[:TOTAL]
GC.enable
GC.start
peak = ObjectSpace.count_objects.fetch(:T_STRING)
held.clear
held = nil
2.times { GC.start }
remaining = ObjectSpace.count_objects.fetch(:T_STRING)
raise 'reclaimed strings still counted' unless remaining < peak
puts 'count_objects counts live String stores, not issued or nonempty slots'
