# Shared definition sites must not change the observable source location.
kept = []
100.times do |i|
  name = "source-#{i}.rb"
  original = eval("proc { :ok }", binding, name, i + 10)
  copy = original.dup
  location = original.source_location
  location[0].replace("changed")
  raise "source alias" unless original.source_location == [name, i + 10]
  raise "duplicate source" unless copy.source_location == [name, i + 10]
  kept << copy if i % 9 == 0
  original = copy = nil
  GC.start
end
kept.each_with_index do |callback, index|
  raise "collected source" unless callback.source_location == ["source-#{index * 9}.rb", index * 9 + 10]
  raise "collected body" unless callback.call == :ok
end
puts :ok
