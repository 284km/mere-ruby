require 'prism'

def node1142(error, index = 0)
  loc = error.backtrace_locations.fetch(index)
  id = RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(loc)
  node = Prism.parse_file(__FILE__).value.breadth_first_search { |item| item.node_id == id }
  p [node&.type, node.respond_to?(:name) ? node.name : nil,
     node.respond_to?(:message_loc) ? node.message_loc&.slice : nil]
end

def capture1142(index = 0)
  yield
rescue => error
  node1142(error, index)
end

capture1142 { nil.send(:missing1142, 1) }
capture1142 { nil.__send__('missing1142', 1) }
capture1142 { nil.public_send(:missing1142, 1) }
capture1142 { Object.const_get(:Missing1142) }
capture1142 { Object.const_get('Missing1142') }

literal = -> {}
method = lambda {}
capture1142(1) { literal.call(1) }
capture1142(1) { method.call(1) }
capture1142(1) { literal[1] }
capture1142(1) { literal.(1) }
capture1142(1) { literal.yield(1) }
capture1142(1) { literal === 1 }

# A failure in the body retains its own callee; the caller marker belongs
# only to argument binding, which precedes the body.
inside = -> { nil.inside_missing1142 }
capture1142 { inside.call }
GC.start
capture1142(1) { literal.call(1) }

# === has its own native entry; replacing #call does not replace it.
callable = ->(value) { [:body, value] }
def callable.call(value) = [:override, value]
p [callable.call(1), callable === 1]
p(case 1; when callable; :matched; else :missed; end)

class CallTarget1142
  def run(value) = [:method_body, value]
end
bound = CallTarget1142.new.method(:run)
def bound.call(value) = [:method_override, value]
p [bound.call(2), bound === 2]
p(case 2; when bound; :matched; else :missed; end)

# Rejecting a backtrace replacement must preserve the original caller id.
def saved_error1142
  yield
rescue ArgumentError => error
  error
end
retained = saved_error1142 { literal.call(1) }
node1142(retained, 1)
begin
  retained.set_backtrace(42)
rescue TypeError
end
node1142(retained, 1)
retained.set_backtrace(nil)
p retained.backtrace
