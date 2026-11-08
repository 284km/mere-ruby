require 'psych'
require 'stringio'

YamlAnchorStruct = Struct.new(:value)
class YamlAnchorObject
  attr_accessor :value
  def hash; raise 'identity tracking called hash'; end
  def eql?(_); raise 'identity tracking called eql?'; end
end

def anchor_examples
  cycle = []; cycle << cycle
  mapping = {}; mapping['self'] = mapping
  left = []; right = {'back' => left}; left << right
  shared = [1, {'value' => 'text'}]
  empty = []; empty_map = {}
  structure = YamlAnchorStruct.new; structure.value = structure
  object = YamlAnchorObject.new; object.value = object
  key = [1]
  key_hash = {}.compare_by_identity; key_hash[key_hash] = key_hash
  nested = {'left' => [], 'right' => []}
  shared_text = 'text'
  [cycle, mapping, left, [shared, shared], {'a' => shared, 'b' => shared},
   [empty, empty, empty_map, empty_map], structure, object,
   {key => key}, key_hash, {empty => empty}, {empty_map => empty_map},
   [[mapping, mapping], {'value' => cycle}], nested, [shared_text, shared_text],
   [cycle, cycle, mapping, mapping], [1, nil, true, false, :symbol, 'text']]
end

[2, 3, 4, 9].each do |width|
  anchor_examples.each { |value| p Psych.dump(value, indentation: width) }
end

# Identity is distinct from value equality. Frozen containers still emit aliases.
a = [1].freeze; b = [1].freeze
p Psych.dump([a, b, a, b].freeze)
x = []; x << x; x.freeze
p Psych.dump(x)
p Psych.dump_stream(x, x)
p Psych.dump([x, x])
p Psych.dump(x)
io = StringIO.new
p Psych.dump(x, io).equal?(io)
p io.string

# A failed document must not leave references in the next dump.
begin
  Psych.dump(x, indentation: nil)
rescue TypeError => e
  p e.class
end
p Psych.dump(x)

# Drop each dump graph, retaining only its output, across collections.
saved = []
20.times do
  value = []; value << value
  saved << Psych.dump(value)
  GC.start
end
p saved.uniq
