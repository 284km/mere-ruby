def report(label, expected_line, expected_name = "<main>")
  yield
rescue ArgumentError => error
  loc = error.backtrace_locations.first
  p [label, error.class.name, loc.lineno == expected_line, loc.base_label == expected_name]
end
native = method(:raise).to_proc
report(:index, __LINE__) { native[ArgumentError] }
report(:call, __LINE__) { native.call(ArgumentError) }
report(:paren, __LINE__) { native.(ArgumentError) }
report(:yield, __LINE__) { native.yield(ArgumentError) }
report(:case, __LINE__) { native === ArgumentError }
def ruby_raise(type)
  raise type
end
ruby_line = __LINE__ - 2
ruby_proc = method(:ruby_raise).to_proc
report(:ruby, ruby_line, "ruby_raise") { ruby_proc[ArgumentError] }
p [Integer.method(:sqrt).to_proc[9], "ab".method(:upcase).to_proc.call]
report(:arity, __LINE__) { Integer.method(:sqrt).to_proc[] }

copy = native.dup
report(:native_dup, __LINE__) { copy[ArgumentError] }
copy = native.clone
report(:native_clone, __LINE__) { copy.call(ArgumentError) }
copy = ruby_proc.dup
report(:ruby_dup, ruby_line, "ruby_raise") { copy[ArgumentError] }
p [native.source_location, native.dup.source_location, native.clone.source_location]
GC.start
report(:after_gc, __LINE__) { native[ArgumentError] }

held = begin
  raise ArgumentError, "same"
rescue ArgumentError => error
  error
end
custom = ["kept.rb:7:in 'original'"]
held.set_backtrace(custom)
report(:fresh_same_message, __LINE__) { native[ArgumentError, "same"] }
p [:retained_backtrace, held.backtrace == custom]
begin
  raise held
rescue ArgumentError => error
  p [:explicit_reraise, error.equal?(held), error.backtrace == custom]
end
held.set_backtrace(nil)
report(:cleared_backtrace, __LINE__) { native[held] }
