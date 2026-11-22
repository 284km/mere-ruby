array = [1, 2, 3]
array.shift
array << 4
p [:contents, array.length, array.size, array.empty?]
array.clear
p [:cleared, array.length, array.size, array.empty?]
array.freeze
p [:frozen, array.length, array.empty?]
begin
  array.length(1)
rescue ArgumentError => error
  p [:arity, error.message]
end
singleton = [1]
def singleton.length
  :singleton
end
p [:singleton, singleton.length, singleton.size]
class CustomArrayRead < Array
  def size
    :custom_size
  end
end
p [:subclass, CustomArrayRead.new.size]
events = []
traced = [1, 2]
trace = TracePoint.new(:c_call, :c_return) do |event|
  if event.method_id == :length && event.self.equal?(traced)
    events << [event.event, event.method_id, event.defined_class]
  end
end
trace.enable
result = traced.length
trace.disable
p [:trace, result, events]
module ArrayReadRefinement
  refine Array do
    def empty?
      :refined
    end
  end
end
using ArrayReadRefinement
p [:refinement, [].empty?]
class Array
  def length
    :replacement
  end
end
p [:replacement, [1].length]
