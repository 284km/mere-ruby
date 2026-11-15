# Every Prism node of every file under <ruby-src>/test, as text: its type,
# its flags, its node id, where it is and each of its fields -- a String by
# its encoding and bytes, a Float by its bits, a Symbol by its bytes and
# encoding. Run by the reference ruby it is what Prism's own loader makes;
# run by mere-ruby it is what the builtin loader makes (m_prism_load.mere),
# and the two directories are compared with diff:
#
#   . ./tools/ref_ruby.sh && ruby tools/prism_tree_dump.rb <ruby-src> /tmp/ref
#   ./mere-ruby tools/prism_tree_dump.rb <ruby-src> /tmp/mere
#   diff -rq /tmp/ref /tmp/mere
#
# A few seconds for the reference, a few minutes here (850 files, a million
# nodes, 114 MB of text a side).
require "prism"
src, out = ARGV
abort "usage: prism_tree_dump.rb <ruby-src> <out-dir>" unless src && out && File.directory?(out)

def dump_value(v, o)
  case v
  when Prism::Node then dump_node(v, o)
  when Prism::Location then o << "@" << v.start_offset.to_s << "+" << v.length.to_s
  when Array then o << "["; v.each { |x| dump_value(x, o); o << "," }; o << "]"
  when String then o << v.encoding.name << ":" << v.unpack1("H*")
  when Float then o << "F" << [v].pack("D").unpack1("H*")
  when Symbol then o << ":" << v.name.unpack1("H*") << "/" << v.encoding.name
  when nil then o << "nil"
  else o << v.inspect
  end
end

def dump_node(n, o)
  o << "(" << n.type.to_s << " f" << n.send(:flags).to_s << " i" << n.node_id.to_s
  n.deconstruct_keys(nil).each do |k, v|
    next if k == :node_id
    o << " " << k.name << "="
    dump_value(v, o)
  end
  o << ")\n"
end

paths = Dir.glob("test/**/*.rb", base: src).sort
paths.each do |p|
  r = Prism.parse_file(File.join(src, p))
  o = +""
  dump_node(r.value, o)
  o << "errors=" << r.errors.size.to_s << " warnings=" << r.warnings.size.to_s << " comments=" << r.comments.size.to_s << "\n"
  File.binwrite(File.join(out, p.tr("/", "_") + ".txt"), o)
end
puts "files=#{paths.size}"
