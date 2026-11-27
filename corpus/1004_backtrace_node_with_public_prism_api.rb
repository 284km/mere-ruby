require 'prism'
require 'tmpdir'
# An installed native Prism has no interpreter-specific helper methods.
if Prism.respond_to?(:__node_id_for_location)
  class << Prism
    remove_method :__node_id_for_location
  end
end

# Eval-generated methods need IDs from their compilation unit, including when
# its filename is synthetic or names a different file on disk.
def eval_node_result1004(label, source, error)
  location = error.backtrace_locations.first
  id = RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(location)
  node = Prism.parse(source).value.breadth_first_search { |entry| entry.node_id == id }
  p [label, node&.type, node.respond_to?(:name) ? node.name : nil,
     location.base_label, location.lineno]
end

module EvalNodeOwner1004
end

source1004 = "def render_node1004\n  nil.missing_eval1004\nend\n"
EvalNodeOwner1004.module_eval(source1004, 'synthetic-template1004', 17)
receiver1004 = Object.new.extend(EvalNodeOwner1004)
begin
  receiver1004.render_node1004
rescue NoMethodError => error
  retained1004 = error
  eval_node_result1004(:eval_offset, source1004, error)
end

old_method1004 = receiver1004.method(:render_node1004)
EvalNodeOwner1004.module_eval("def render_node1004\n  value = 1\n  nil.new_eval1004\nend\n",
                            'synthetic-template1004', 17)
begin
  old_method1004.call
rescue NoMethodError => error
  eval_node_result1004(:old_method, source1004, error)
end
EvalNodeOwner1004.remove_method(:render_node1004)
GC.start
eval_node_result1004(:retained_exception, source1004, retained1004)

class EvalNodeClass1004
end
class_source1004 = "def class_node1004\n  1.times { nil.missing_block1004 }\nend\n"
EvalNodeClass1004.class_eval(class_source1004, __FILE__, 31)
EvalNodeClass1004.alias_method(:saved_node1004, :class_node1004)
begin
  EvalNodeClass1004.new.saved_node1004
rescue NoMethodError => error
  eval_node_result1004(:class_alias_block, class_source1004, error)
end

object1004 = Object.new
instance_source1004 = "def instance_node1004\n  nil.missing_instance1004\nend\n"
object1004.instance_eval(instance_source1004, 'synthetic-instance1004', 0)
begin
  object1004.instance_node1004
rescue NoMethodError => error
  eval_node_result1004(:instance_eval, instance_source1004, error)
end

def backtrace_node_probe1004
  nil.missing_call1004
end

begin
  backtrace_node_probe1004
rescue NoMethodError => error
  location = error.backtrace_locations.first
  id = RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(location)
  queue = [Prism.parse_file(__FILE__).value]
  found = nil
  until queue.empty?
    node = queue.shift
    if node.node_id == id
      found = node
      break
    end
    queue.concat(node.compact_child_nodes)
  end
  p [found&.type, found&.name, found&.location&.start_line == location.lineno]
end

# Internal metadata must not introduce a Ruby local or a callable identifier.
EvalNodeOwner1004.module_eval("def ordinary_identifier1004; __node_info; end", "identifier-control1004", 1)
begin
  receiver1004.ordinary_identifier1004
  p [:ordinary_identifier, :leaked]
rescue NameError
  p [:ordinary_identifier, :missing]
end

[["def integer_fail1004\n  Integer('not-an-integer1004')\nend\n", :integer_fail1004, ArgumentError],
 ["def ruby_raise1004\n  raise 'eval-raise1004'\nend\n", :ruby_raise1004, RuntimeError]].each do |source, name, error_class|
  EvalNodeOwner1004.module_eval(source, "synthetic-raise1004", 41)
  begin
    receiver1004.public_send(name)
  rescue error_class => error
    eval_node_result1004(name, source, error)
  end
end

# A method on a shared core class must recover its own compact metadata after
# another Box replaces that method. This raw-location invariant also works
# while Prism's existing boxed-load path is unavailable. Ruby has no such
# private metadata and compares its absent values; the interpreter's probe
# separately verifies that both sides actually carry indexed method data.
box_source1004 = <<~'RUBY_BOX'
  source_a = "def box_node1004\n  Integer(:invalid)\nend\n"
  source_b = "def box_node1004\n  11; 12; Integer(:invalid)\nend\n"
  filename = "box-node1004.rb"
  String.class_eval(source_a, filename, 1)
  collect = -> {
    begin
      "".box_node1004
    rescue StandardError => error
      error.backtrace_locations.select { |location| location.path.end_with?(filename) }
           .map { |location| location.instance_variable_get(:@__eval_nodes) }
    end
  }
  before = collect.call
  box = Ruby::Box.new
  box.eval("String.class_eval(#{source_b.dump}, #{filename.dump}, 1)")
  p [:box_metadata, before == collect.call]
  box.eval("String.define_method(:box_node1004) { Integer(:invalid) }")
  p [:box_plain_method_metadata, before == collect.call]
  box.eval("String.remove_method(:box_node1004)")
  p [:box_removed_metadata, before == collect.call]
  GC.start
  p [:box_metadata_gc, before == collect.call]
RUBY_BOX
print IO.popen([{'RUBY_BOX' => '1'}, RbConfig.ruby, '--disable-gems', '-W0', '-e', box_source1004, err: File::NULL], &:read)
p $?.exitstatus

# Compound writes have their own Prism nodes. Keep the file-backed lookup that
# worked before eval metadata existed, and use the same node in synthetic files.
operator_sources1004 = {
  local: "  value = nil\n  value += 1",
  instance: "  @operator_value1004 = nil\n  @operator_value1004 += 1",
  global: "  $operator_value1004 = nil\n  $operator_value1004 += 1",
  class_variable: "  @@operator_value1004 = nil\n  @@operator_value1004 += 1",
  attribute: "  holder = Struct.new(:value).new\n  holder.value += 1",
  index: "  holder = [nil]\n  holder[0] += 1",
  attribute_and: "  nil.operator_value1004 &&= 1",
  attribute_or: "  nil.operator_value1004 ||= 1",
  index_and: "  nil[0] &&= 1",
  index_or: "  nil[0] ||= 1"
}
Dir.mktmpdir('eval-node-operators-') do |directory|
  operator_sources1004.each do |kind, body|
    source = "def operator_node1004\n#{body}\nend\n"
    path = File.join(directory, "#{kind}.rb")
    File.write(path, source)
    [[:file, path], [:synthetic, 'operator-template1004']].each do |label, filename|
      EvalNodeOwner1004.module_eval(source, filename, 1)
      begin
        Object.new.extend(EvalNodeOwner1004).operator_node1004
      rescue NoMethodError => error
        eval_node_result1004([kind, label], source, error)
      end
    end
  end
end
