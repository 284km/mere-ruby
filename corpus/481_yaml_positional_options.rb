require 'yaml'
require 'stringio'
value = {'hello' => 'world'}
p value.to_yaml({})
p value.to_yaml(line_width: 80)
p YAML.dump(value, {})
io = StringIO.new
p YAML.dump(value, io, {}).equal?(io)
p io.string

# Nondefault indentation must propagate through mappings, sequences and literals.
[0, 1, 2, 3, 9, 10, -1].each do |width|
  [{'a' => [['b']]}, {'outer' => {'inner' => ['one', {'value' => [1, 2]}]}},
   [['a', 'b'], ['c']], "multi\nline\n"].each do |object|
    p [width, YAML.dump(object, indentation: width)]
  end
end

class IndentWidth
  def to_int; 3; end
end
p YAML.dump([['a']], indentation: IndentWidth.new)
p YAML.dump([['a']], indentation: 3.9)
[nil, false, '3', 2**31].each do |width|
  begin
    YAML.dump(value, indentation: width)
  rescue TypeError, RangeError => error
    p error.class
  end
end
