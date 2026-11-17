require 'objspace'
Warning[:deprecated] = false

def released_string_ids
  Array.new(300) { |i| ("released-string-#{i}" * 3).object_id }
end

kept = [String.new, 'still-live' * 7]
kept_ids = kept.map(&:object_id)
released = released_string_ids
3.times { GC.start }
rejected = 0
released.each do |id|
  begin
    ObjectSpace._id2ref(id)
  rescue RangeError
    rejected += 1
  end
end
raise 'collected String IDs resurrected swept slots' unless rejected > 0
kept.zip(kept_ids).each do |object, id|
  raise 'held String identity lost' unless ObjectSpace._id2ref(id).equal?(object)
end

was_disabled = GC.disable
begin
  fresh = String.new
  raise 'fresh empty String rejected' unless ObjectSpace._id2ref(fresh.object_id).equal?(fresh)
ensure
  GC.enable unless was_disabled
end
puts 'ObjectSpace rejects collected String IDs and preserves empty live Strings'
