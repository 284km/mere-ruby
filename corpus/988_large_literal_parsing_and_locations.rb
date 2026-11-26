# Long lines must not rescan to their beginning/end for every literal item.
# Define before counting, so compiler-owned temporary values are outside the
# user allocation window, as in ruby/test_allocation.rb.
size = 100_000
eval('def large_array; [' + '1,' * size + ']; end', binding, 'large_array.rb', 1)
entries = size.times.map { |i| "key#{i}:1" }.join(',')
eval('def large_hash; {' + entries + '}; end', binding, 'large_hash.rb', 1)
$literal_counts = {}
def measure_literal(label)
  ObjectSpace.count_objects($literal_counts)
  arrays = $literal_counts[:T_ARRAY]
  hashes = $literal_counts[:T_HASH]
  value = yield
  ObjectSpace.count_objects($literal_counts)
  p [label, value.length, $literal_counts[:T_ARRAY] - arrays,
     $literal_counts[:T_HASH] - hashes]
end
GC.start
GC.disable
measure_literal(:array) { large_array }
measure_literal(:hash) { large_hash }
GC.enable
# Literal elements need no call-site line marker; actual calls still do.
def literal_call_line
  caller_locations(1, 1).first.lineno
end
p eval("[\n literal_call_line,\n literal_call_line()\n]", binding, 'locations.rb', 40)
p eval("[\n [literal_call_line],\n literal_call_line()\n]", binding, 'locations.rb', 50)
p eval("[\"first\nsecond\", literal_call_line]", binding, 'locations.rb', 60)
p eval('[1, ' + "\\" + "\n literal_call_line]", binding, 'locations.rb', 80)
# Only a possible value before ':' needs alias/undef's statement-head check.
class LiteralAliasNames
  def original = :ok
  alias :"copy" :"original"
  alias :"again" :"copy"; undef :"original"
end
p [LiteralAliasNames.new.copy, LiteralAliasNames.new.again,
   LiteralAliasNames.new.respond_to?(:original)]
p [true ? 'left' : :right, false ? 1 : 2, {end: 1, if: 2, name123: 3}]
# The native seen-key set shares nested literal double-splats, but computed
# keys remain runtime questions and do not produce a static duplicate warning.
$literal_warnings = []
Warning.singleton_class.alias_method(:saved_literal_warn, :warn)
Warning.define_singleton_method(:warn) { |message, **_| $literal_warnings << message }
p eval('{a:1, **{b:2,a:3}, a:4}', binding, 'duplicates.rb', 70)
p $literal_warnings
$literal_warnings.clear
key = :a
p eval('{key=>1, a:2}', binding, 'computed.rb', 80)
p $literal_warnings
Warning.singleton_class.alias_method(:warn, :saved_literal_warn)
Warning.singleton_class.remove_method(:saved_literal_warn)
