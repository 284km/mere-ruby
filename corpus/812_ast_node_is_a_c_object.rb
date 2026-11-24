# RubyVM::AbstractSyntaxTree::Node is a C object: it has no instance
# variables, it cannot be copied or dumped, and its readers are methods of
# Node itself -- answered with a receiver, called bare in a method a program
# adds to Node, and named by reflection. A program's own reader wins, but
# not in #inspect or #locations; a reader removed or undefined is gone. A
# Node held across collections keeps its values; the trees dropped beside it
# are reclaimed.
src = "x = 1 + 2\nfoo(x) { |y| y }\nclass K; def m = 1; end\n"
n = RubyVM::AbstractSyntaxTree.parse(src, keep_script_lines: true, keep_tokens: true)
p n.instance_variables, n.instance_variable_get(:@type)
p n.type, n.first_lineno, n.first_column, n.last_lineno, n.last_column
p n, n.children.size, n.children[2].type
p n.source, n.script_lines.size, n.all_tokens.size > 0, n.tokens.size > 0
p n.locations.map(&:inspect)
k = n.children[2].children[2]
p k.type, k.locations.size
begin; n.type(1); rescue ArgumentError => e; p e.message; end

[:dup, :clone].each do |m|
  n.__send__(m)
rescue TypeError => e
  p [m, e.message]
end
begin
  Marshal.dump(n)
rescue TypeError => e
  p e.message
end

p n.respond_to?(:first_lineno), n.method(:type).owner, n.frozen?
p RubyVM::AbstractSyntaxTree::Node.instance_methods(false).sort

class RubyVM::AbstractSyntaxTree::Node
  def span812 = [type, first_lineno, last_lineno, children.size]
end
p n.span812, n.children[2].span812

def walk(x) = x.is_a?(RubyVM::AbstractSyntaxTree::Node) ? [x.type, *x.children.map { walk(_1) }] : x
before = walk(n)
20.times { RubyVM::AbstractSyntaxTree.parse(src * 50).children; GC.start }
p walk(n) == before, n.inspect, n.children[2].children.map(&:class).uniq

class RubyVM::AbstractSyntaxTree::Node
  def type = :mine
  def mine812 = [type, first_lineno]
end
p n.type, n.mine812, n.inspect, n.locations.map(&:inspect)
class RubyVM::AbstractSyntaxTree::Node
  remove_method :type
  undef_method :last_column
  def method_missing(m, *a) = [:mm, m]
end
p n.type, n.mine812, n.last_column, n.respond_to?(:type), n.inspect
p RubyVM::AbstractSyntaxTree::Node.instance_methods(false).sort
